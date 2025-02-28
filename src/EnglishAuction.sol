// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./utils/Counters.sol";
import "./utils/RoyaltyEngineV1.sol";
import "./utils/Address.sol";
import "./utils/interfaces/AggregatorV3Interface.sol";
import "./access/Owned.sol";

/**
 * @title OnChainMarketplace
 * @notice On-chain English Auction
 * @author cosimo.demedici.eth (https://github.com/ninfa-labs/nft-suite)
 */
contract EnglishAuction is Owned, RoyaltyEngineV1 {
    // @dev implements sendValue() function only
    using Address for address;
    /// @dev Use Counters library for Counter datatype
    using Counters for Counters.Counter;

    /// @notice Chainlink ETH/USDC price feed aggregator interface
    AggregatorV3Interface private immutable _dataFeed;

    /// @dev Duration of an auction once the first bid has been received. Set to 1 day.
    uint256 private constant _DURATION = 1 days;
    /// @dev Window for auction extensions. Any bid placed in the final 15 minutes of an auction will reset the time
    /// remaining to 15 minutes.
    uint256 private constant _EXTENSION_DURATION = 15 minutes;
    /// @dev The last highest bid is divided by this number to obtain the minimum bid increment.
    /// @notice For example, _MIN_BID_RAISE = 10 is a 10% increment, 20 is 5%, 2 is 50%. I.e., 100 / _MIN_BID_RAISE.
    uint256 private constant _MIN_BID_RAISE = 20;
    /// @dev Denominator for basis points calculation. 10,000 basis points = 100% shares sale price.
    uint256 private constant _BPS_DENOMINATOR = 10_000;

    /// @dev Counter for tracking the number of auctions
    Counters.Counter public auctionCount;

    /// @dev The address for receiving auction sales fees. Typically, this is a multisig address.
    address private _feeRecipient;

    /// @dev The Ninfa fee percentage on primary sales, expressed in basis points.
    uint256 private _feeBps;

    /// @dev Mapping from auction IDs to auction data. This is deleted when an auction is finalized or canceled.
    /// @notice This needs to be public so that it can be called by a frontend as the auction creation event only emits
    /// auction id.
    mapping(uint256 => Auction) private _auctions;

    /**
     * @dev This struct stores the auction configuration for a specific NFT.
     * @param operator The address of the operator. This is necessary because if the order creator is a gallery (i.e.,
     * the commission receiver), they wouldn't be able to cancel or update the order without knowing whether the order
     * creator was the seller or the commissionReceiver.
     * @param end The time at which this auction will stop accepting any new bids. This is `0` until the first bid is
     * placed.
     * @param bidder The address of the highest bidder. This address must be payable to receive a refund in case of
     * being outbid.
     * @param price The reserve price, the highest bid, and all bids in between.
     * @param erc1155Amount This is 0 for ERC721 tokens, and greater than 1 for ERC1155 tokens.
     */
    struct Auction {
        address operator;
        address seller;
        address collection;
        address bidder;
        uint256 tokenId;
        uint256 bidPrice;
        uint256 end;
        uint256[] commissionBps;
        address[] commissionReceivers;
    }

    /// @notice Emitted when an auction is created.
    /// All auction data is stored in db by reading Auction struct after events are emitted,
    /// therefore information can be retrieved even after an AuctionFinalized event has been emitted and
    /// the corresponding auction struct deleted from storage.
    event AuctionCreated(uint256 auctionId);
    /// @notice Emitted when an auction is canceled.
    event AuctionCanceled(uint256 auctionId);
    /// @notice Emitted when an auction is updated.
    event AuctionUpdated(uint256 auctionId);
    /// @notice Emitted when an auction is finalized.
    event AuctionFinalized(uint256 auctionId);
    /// @notice Emitted when a bid is placed in an auction.
    event Bid(uint256 auctionId);

    /**
     * @param feeRecipient_ address (multisig) controlled by Ninfa that will receive any market fees.
     */
    constructor(address feeRecipient_, uint256 feeBps_) {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        _feeRecipient = feeRecipient_;
        _feeBps = feeBps_;
    }

    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this
     * contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the
     * recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with
     * `IERC721.onERC721Received.selector`.
     *
     * @notice Creates an auction for the given NFT. The NFT is held in escrow
     * until the auction is finalized or
     * canceled.
     * @param _operator The address which called `safeTransferFrom` function
     * @param _from The address which previously owned the token
     * @param _tokenId The NFT identifier which is being transferred
     * @param _data Additional data with no specified format
     * @return bytes4 Returns `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     */
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    )
        external
        returns (bytes4)
    {
        auctionCount.increment(); // start counter at 1

        uint256 _auctionId = auctionCount.current();

        /**
         * reservePrice is the initial reserve price for the auction.
         * Reserve price may also be 0, clearly a mistake but not strictly
         * required, only done in order to save gas by
         * removing the need for a condition such as `if (_price == 0) revert
         * InvalidAmount(_price)`
         *
         * commissionReceivers address of sale commissions receiver
         * if `msg.sender` is also the `_commissionReceiver`, e.g. if
         * `msg.sender` is a gallery, they must put their
         * own address as the `_commissionReceiver`, and set the `_seller` parameter
         * with the artist's/collector's address.
         * if there is no commission receiver, it must be set to address(0)
         * it is not required for `_commissionReceiver` and `_seller` addresses
         * to be different (in order to save gas),
         * although it would likely be a mistake, it cannot be exploited as the
         * total amount paid out will never exceed the
         * price set for the order. I.e. in the worst case the same address will
         * receive both principal sale profit and
         * commissions.
         */
        (uint256 reservePrice, uint256[] memory commissionBps, address[] memory commissionReceivers) =
            abi.decode(_data, (uint256, uint256[], address[]));

        _auctions[_auctionId] = Auction(
            _operator,
            _from, // auction beneficiary, needs to be payable in order to
                // receive funds from the auction sale
            msg.sender,
            address(0), // bidder is only known once a bid has been placed. //
                // highest bidder, needs to be payable in
                // order to receive refund in case of being outbid
            _tokenId,
            reservePrice,
            0,
            commissionBps,
            commissionReceivers
        );

        emit AuctionCreated(_auctionId);

        return 0x150b7a02;
    }

    /**
     * @notice This function is to be used only for the first bid on any auction,
     * in order to avoid code repetition and improve gas costs for all bids.
     * @dev This function integrates third party credit card payment solution,
     * as payment gateways will use their own contracts to call this function it is not possible to rely on msg.sender.
     * It is also possible for the buyer to use this parameter simply in order to transfer the NFT to an address other
     * than their own, this can be useful for external contract buying NFTs.
     * @param _bidder The address of the bidder
     */
    function firstBid(uint256 _auctionId, address _bidder) external payable {
        Auction storage _auction = _auctions[_auctionId];

        // _auction.end is set after the first bid is placed, preventing from calling this function once an auction has
        // started or ended (deleted).
        require(_auction.end == 0);
        // msg.value must be greater or equal to reserve price
        if (msg.value < _auction.bidPrice) revert Unauthorized();

        unchecked {
            // start the auction timer on the first bid, setting end time to now + duration.
            // `_DURATION` is a  constant set to 24hrs therefore the below
            // addition can't overflow.
            _auction.end = block.timestamp + _DURATION;
        }
        // new highest bid is set only if it is higher than the reserve price
        if (msg.value > _auction.bidPrice) _auction.bidPrice == msg.value;
        // new highest bidder
        _auction.bidder = _bidder;

        emit Bid(_auctionId);
    }

    /**
     * @notice Places a bid in an auction. The bid must be at least the amount defined by `getMinBidAmount`.
     * If this is the first bid on the auction, the countdown will begin. If there is already an outstanding bid,
     * the previous bidder will be refunded at this time. If the bid is placed in the final moments of the auction,
     * the countdown may be extended.
     * @dev Bids must be at least 5% higher than the previous bid. The `_auctionId` must exist, the auction must have
     * begun,
     * and must not have ended. The `_bidder` parameter is needed to integrate third-party credit card payment
     * solutions.
     * @param _auctionId The id of the auction to bid on.
     * @param _bidder The address of the bidder.
     */
    function bid(uint256 _auctionId, address _bidder) external payable {
        Auction storage _auction = _auctions[_auctionId];
        /**
         * @dev reverts if auction doesn't exist yet;, i.e. if _auction.end == 0
         * @dev reverts if auction has been created but no one has called
         * firstBid() yet. i.e. if _auction.end == 0
         * @dev reverts if auction has ended, i.e. if block.timestamp > _auction.end
         * @dev Reverts if raise is less than minimum raise pct required, i.e. bids Delta must be greater than or equal
         * to the old bid value divided by _MIN_BID_RAISE.
         */
        if (block.timestamp > _auction.end || msg.value - _auction.bidPrice < _auction.bidPrice / _MIN_BID_RAISE) {
            revert Unauthorized();
        }

        // Increment end time by 15 minutes on every bid (except for the very first bid),
        // as opposed to only incrementing the timer only if block.timestamp is close to _auction.end.
        if (block.timestamp > _auction.end - _EXTENSION_DURATION) {
            unchecked {
                _auction.end += _EXTENSION_DURATION;
            }
        }

        // refund the previous bidder
        _auction.bidder.sendValue(_auction.bidPrice);

        /**
         * @dev Does not follow check-effects-interactions pattern in order to avoid storing
         * previous bidder and amount in memory variables.
         * No reentrancy exploit is possible in practice however; _auction.bidPrice and _auction.bidder are not used by
         * any other function that may be reentered, namely `onERC721Received()` and `firstBid()`.
         */
        _auction.bidPrice = msg.value; // new highest bid
        _auction.bidder = _bidder; // new highest bidder

        emit Bid(_auctionId);
    }

    /*
        * @notice Finalizes an auction. The NFT is held in escrow until the auction is finalized or canceled.
        * @param _auctionId The id of the auction to finalize.
        */
    function finalize(uint256 _auctionId) external {
        Auction memory auction = _auctions[_auctionId];
        /**
         * @dev reverts if auction has started but not ended yet, i.e. block.timestamp < auction.end
         * @dev reverts if auction does not exist or was already finalized/deleted, i.e. auction.end == 0
         */
        if (block.timestamp < auction.end || auction.end == 0) {
            revert Unauthorized();
        }
        // delete the auction struct from storage.
        delete _auctions[_auctionId];

        // amount owed to seller after fees, royalties (if any) and commissions (if any)
        uint256 sellerAmount = auction.bidPrice;

        /*----------------------------------------------------------*|
        |*  # PAY MARKETPLACE FEE                                   *|
        |*----------------------------------------------------------*/

        uint256 marketplaceAmount = (auction.bidPrice * _feeBps) / _BPS_DENOMINATOR;
        // subtracting primary or secondary fee amount from seller
        // amount, this is a security check (will revert
        // on underflow) as well as a variable assignment.
        sellerAmount -= marketplaceAmount; // subtract before external
            // call
        _feeRecipient.sendValue(marketplaceAmount);

        /*----------------------------------------------------------*|
        |*  # PAY ROYALTIES (if any)                                *|
        |*----------------------------------------------------------*/

        (address payable[] memory royaltyRecipients, uint256[] memory royaltyAmounts) =
            getRoyalty(auction.collection, auction.tokenId, auction.bidPrice);

        uint256 royaltyRecipientsLength = royaltyRecipients.length;

        if (royaltyRecipientsLength > 0) {
            // The collection implements some royalty standard, otherwise the length of the arrays returned would be 0.
            do {
                royaltyRecipientsLength--;
                // subtract from seller amount before external call
                sellerAmount -= royaltyAmounts[royaltyRecipientsLength];
                address(royaltyRecipients[royaltyRecipientsLength]).sendValue(royaltyAmounts[royaltyRecipientsLength]);
            } while (royaltyRecipientsLength > 0);
        }

        /*----------------------------------------------------------*|
        |*  # PAY SELLER COMMISSIONS (if any)                       *|
        |*----------------------------------------------------------*/
        uint256 commissionReceiversLength = auction.commissionReceivers.length;

        if (commissionReceiversLength > 0) {
            do {
                commissionReceiversLength--;
                uint256 commissionAmount =
                    (auction.commissionBps[commissionReceiversLength] * auction.bidPrice) / _BPS_DENOMINATOR;

                sellerAmount -= commissionAmount; // subtract before external

                auction.commissionReceivers[commissionReceiversLength].sendValue(commissionAmount);
            } while (commissionReceiversLength > 0);
        }

        /*----------------------------------------------------------*|
        |*  # PAY SELLER                                            *|
        |*----------------------------------------------------------*/

        auction.seller.sendValue(sellerAmount);

        /*----------------------------------------------------------*|
        |*  # TRANSFER NFT                                          *|
        |*----------------------------------------------------------*/

        auction.collection.transferFrom(address(this), auction.bidder, auction.tokenId);

        emit AuctionFinalized(_auctionId);
    }

    /**
     * @notice Finalizes an auction. The NFT is held in escrow until the auction is finalized or canceled.
     * @dev The reserve price may also be 0.
     * @param _auctionIds The ids of the auctions to finalize.
     */
    function finalize(uint256[] calldata _auctionIds) external {
        uint256 auctionsLength = _auctionIds.length;

        do {
            auctionsLength--;

            Auction memory auction = _auctions[_auctionIds[auctionsLength]];
            /**
             * @dev reverts if auction has started but not ended yet, i.e. block.timestamp < auction.end
             * @dev reverts if auction does not exist or was already finalized/deleted, i.e. auction.end == 0
             */
            if (block.timestamp < auction.end || auction.end == 0) {
                revert Unauthorized();
            }
            // delete the auction struct from storage.
            delete _auctions[_auctionIds[auctionsLength]];

            // amount owed to seller after fees, royalties (if any) and commissions (if any)
            uint256 sellerAmount = auction.bidPrice;

            /*----------------------------------------------------------*|
            |*  # PAY MARKETPLACE FEE                                   *|
            |*----------------------------------------------------------*/

            uint256 marketplaceAmount = (auction.bidPrice * _feeBps) / _BPS_DENOMINATOR;
            // subtracting primary or secondary fee amount from seller
            // amount, this is a security check (will revert
            // on underflow) as well as a variable assignment.
            sellerAmount -= marketplaceAmount; // subtract before external
                // call
            _feeRecipient.sendValue(marketplaceAmount);

            /*----------------------------------------------------------*|
            |*  # PAY ROYALTIES (if any)                                *|
            |*----------------------------------------------------------*/

            (address payable[] memory royaltyRecipients, uint256[] memory royaltyAmounts) =
                getRoyalty(auction.collection, auction.tokenId, auction.bidPrice);

            uint256 royaltyRecipientsLength = royaltyRecipients.length;

            if (royaltyRecipientsLength > 0) {
                // The collection implements some royalty standard, otherwise the length of the arrays returned would be
                // 0.
                do {
                    royaltyRecipientsLength--;
                    // subtract from seller amount before external call
                    sellerAmount -= royaltyAmounts[royaltyRecipientsLength];
                    address(royaltyRecipients[royaltyRecipientsLength]).sendValue(
                        royaltyAmounts[royaltyRecipientsLength]
                    );
                } while (royaltyRecipientsLength > 0);
            }

            /*----------------------------------------------------------*|
            |*  # PAY SELLER COMMISSIONS (if any)                       *|
            |*----------------------------------------------------------*/
            uint256 commissionReceiversLength = auction.commissionReceivers.length;

            if (commissionReceiversLength > 0) {
                do {
                    commissionReceiversLength--;
                    uint256 commissionAmount =
                        (auction.commissionBps[commissionReceiversLength] * auction.bidPrice) / _BPS_DENOMINATOR;

                    sellerAmount -= commissionAmount; // subtract before external

                    auction.commissionReceivers[commissionReceiversLength].sendValue(commissionAmount);
                } while (commissionReceiversLength > 0);
            }

            /*----------------------------------------------------------*|
            |*  # PAY SELLER                                            *|
            |*----------------------------------------------------------*/

            auction.seller.sendValue(sellerAmount);

            /*----------------------------------------------------------*|
            |*  # TRANSFER NFT                                          *|
            |*----------------------------------------------------------*/

            auction.collection.transferFrom(address(this), auction.bidder, auction.tokenId);

            emit AuctionFinalized(_auctionIds[auctionsLength]);
        } while (auctionsLength > 0);
    }

    /**
     * @notice If an auction has been created but has not yet received bids, the
     * `reservePrice` may be edited by the
     * seller.
     * @param _auctionId The id of the auction to change.
     * @param _newReservePrice The new reserve price for this auction, may be
     * higher or lower than the previoius price.
     * @dev `_newReservePrice` may be equal to old price
     * (`_auctions[_auctionId].price`); although this doesn't make much
     * sense it isn't a security requirement, hence `require(_auction.bidPrice
     * != _price)` it has been omitted in order
     * to save the user some gas
     * @dev `_newReservePrice` may also be 0, clearly a mistake but not a
     * security requirement,  hence `require(_price >
     * 0)` has been omitted in order to save the user some gas
     */
    function updateReservePrice(uint256 _auctionId, uint256 _newReservePrice) external {
        Auction storage _auction = _auctions[_auctionId];
        // code duplication because modifiers can't pass variables to functions,
        // meanining that storage pointer cannot
        // be instantiated in modifier
        require(_auction.operator == msg.sender && _auction.end == 0);

        // Update the current reserve price.
        _auction.bidPrice = _newReservePrice;

        emit AuctionUpdated(_auctionId);
    }

    /**
     * @notice If an auction has been created but has not yet received bids, the
     * `commissionBps` may be edited by the
     * seller.
     * @param _auctionId The id of the auction to change.
     * @param _commissionBps The new commission basis points for this auction.
     * @param _commissionReceivers The new commission receivers for this auction.
     */
    function updateCommissionBps(
        uint256 _auctionId,
        uint256[] memory _commissionBps,
        address[] memory _commissionReceivers
    )
        external
    {
        require(msg.sender == _auctions[_auctionId].operator);
        _auctions[_auctionId].commissionBps = _commissionBps;
        _auctions[_auctionId].commissionReceivers = _commissionReceivers;
        emit AuctionUpdated(_auctionId);
    }

    /**
     * @notice If an auction has been created but has not yet received bids, it
     * may be canceled by the seller.
     * @dev The NFT is transferred back to the owner unless there is still a buy
     * price set.
     * @param _auctionId The id of the auction to cancel.
     */
    function cancelAuction(uint256 _auctionId) external {
        Auction memory _auction = _auctions[_auctionId];

        require(_auction.operator == msg.sender && _auction.end == 0);

        // Delete the _auction.
        delete _auctions[_auctionId];

        _auction.collection.transferFrom(address(this), msg.sender, _auction.tokenId);

        emit AuctionCanceled(_auctionId);
    }

    /**
     * @dev Setter function only callable by contract admin used to change the
     * address to which fees are paid.
     * @param _newFeeRecipient is the address owned by NINFA that will collect
     * sales fees.
     */
    function setFeeRecipient(address _newFeeRecipient) external onlyOwner {
        _feeRecipient = _newFeeRecipient;
    }

    /**
     * @dev Setter function only callable by contract admin used to change the
     * fee percentage on primary sales.
     * @param _newFeeBps is the new fee percentage in basis points.
     */
    function setFeeBps(uint256 _newFeeBps) external onlyOwner {
        _feeBps = _newFeeBps;
    }

    /**
     * @notice Returns the minimum bid amount for an auction.
     * @param _auctionId The id of the auction to get the minimum bid amount for.
     * @return The minimum bid amount.
     */
    function getAuction(uint256 _auctionId) external view returns (Auction memory) {
        return _auctions[_auctionId];
    }

    /**
     * @dev See {IERC165-supportsInterface}. A wallet/broker/auction application
     * MUST implement the wallet interface if it will accept safe transfers.
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // Interface ID for IERC165
            || interfaceId == 0x150b7a02; // Interface ID for IERC721Receiver.
    }
}
