// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console2 } from "forge-std/console2.sol";
import "./utils/Setup.sol";
import "./interfaces/IERC165.sol";
import "./interfaces/IERC1155.sol";
import "./interfaces/IERC1155Supply.sol";
import "./interfaces/IERC721Enumerable.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC20.sol";
import "src/OnChainMarketplace.sol";
import "src/factory/CuratedFactory.sol";

/**
 * @title OnChainMarketplaceTest
 * @dev Test suite for the OnChainMarketplace contract
 * @dev constants are defined in the Setup contract
 */
contract OnChainMarketplaceTest is Setup {
    // instances of marketplace and collections
    OnChainMarketplace private _marketplace;
    ERC721Base private _ERC721BaseClone;
    ERC721Generative private _ERC721GenerativeClone;
    ERC721LazyMint private _ERC721LazyMintClone;
    ERC1155Base private _ERC1155BaseClone;
    ERC1155LazyMint private _ERC1155LazyMintClone;
    ERC1155OpenEdition private _ERC1155OpenEditionClone;

    // util variable enumerates tokens accepted by the marketplace
    enum QuoteToken {
        ETH,
        USDC
    }

    // collections contracts addresses, cloned via factory pattern
    address private _ERC721BaseCloneAddress;
    address private _ERC721GenerativeAddres;
    address private _ERC721LazyMintCloneAddress;
    address private _ERC1155BaseCloneAddress;
    address private _ERC1155LazyMintCloneAddress;
    address private _ERC1155OpenEditionCloneAddress;

    // The following variables are used for holding before and after balances oa accounts,
    // used by _setStartingAccountsBalance and _setFinalAccountsBalance private functions.

    // starting ETH or USDC accounts balance
    uint256 private startingSellerBalance;
    uint256 private startingBuyerBalance;
    uint256 private startingFeeAccountBalance;
    uint256 private startingMinterBalance;
    uint256 private startingCommissionReceiverBalance;
    // final ETH or USDC accounts balance
    uint256 private finalSellerBalance;
    uint256 private finalBuyerBalance;
    uint256 private finalFeeAccountBalance;
    uint256 private finalMinterBalance;
    uint256 private finalCommissionReceiverBalance;
    // starting token accounts balance
    uint256 private startingSellerTokenBalance;
    uint256 private startingBuyerTokenBalance;
    uint256 private startingMarketplaceTokenBalance;
    // final ERC721 accounts balances
    uint256 private finalSellerTokenBalance;
    uint256 private finalBuyerTokenBalance;
    uint256 private finalMarketplaceTokenBalance;

    /*----------------------------------------------------------*|
    |*  # SETUP                                                 *|
    |*----------------------------------------------------------*/

    function setUp() public {
        /*----------------------------------------------------------*|
        |*  # DEPLOY MARKETPLACE                                    *|
        |*----------------------------------------------------------*/

        bytes32 salt = bytes32(0);
        _marketplace = new OnChainMarketplace(
            address(_USDC), // mock USDC
            address(_ETHUSDPriceFeed), // mock ETH/USD chainlink feed
            _FEES_RECIPIENT, // fee recipient
            500 // 5% (500 BPS) marketplace fee on every sale
        );

        /*----------------------------------------------------------*|
        |*  # APPROVE USDC TOKEN SPENDING                           *|
        |*----------------------------------------------------------*/

        vm.prank(_COLLECTOR_PRIMARY);
        _USDC.approve(address(_marketplace), 500_000_000_000_000);

        vm.prank(_COLLECTOR_SECONDARY);
        _USDC.approve(address(_marketplace), 500_000_000_000_000);

        /*----------------------------------------------------------*|
        |*  # DEPLOY ERC-721 / ERC-1155                             *|
        |*----------------------------------------------------------*/

        _ERC721BaseCloneAddress =
            _CURATED_FACTORY.clone(address(_ERC721_BASE_MASTER), salt, abi.encode(_MINTER, 1000, _SYMBOL, _NAME));
        //_ERC721GenerativeAddres =
        //   _CURATED_FACTORY.clone(address(_ERC721_GENERATIVE_MASTER), salt, abi.encode(_MINTER, 1000, _SYMBOL,
        // _NAME));
        _ERC721LazyMintCloneAddress =
            _CURATED_FACTORY.clone(address(_ERC721_SOVEREIGN_MASTER), salt, abi.encode(_MINTER, 1000, _SYMBOL, _NAME));
        _ERC1155BaseCloneAddress =
            _CURATED_FACTORY.clone(address(_ERC1155_BASE_MASTER), salt, abi.encode(_MINTER, 1000, _SYMBOL, _NAME));
        _ERC1155LazyMintCloneAddress =
            _CURATED_FACTORY.clone(address(_ERC1155_SOVEREIGN_MASTER), salt, abi.encode(_MINTER, 1000, _SYMBOL, _NAME));
        _ERC1155OpenEditionCloneAddress = _CURATED_FACTORY.clone(
            address(_ERC1155_OPEN_EDITION_MASTER), salt, abi.encode(_MINTER, 1000, _SYMBOL, _NAME)
        );

        _ERC721BaseClone = ERC721Base(_ERC721BaseCloneAddress);
        _ERC721LazyMintClone = ERC721LazyMint(_ERC721LazyMintCloneAddress);
        _ERC1155BaseClone = ERC1155Base(_ERC1155BaseCloneAddress);
        _ERC1155LazyMintClone = ERC1155LazyMint(_ERC1155LazyMintCloneAddress);
        _ERC1155OpenEditionClone = ERC1155OpenEdition(_ERC1155OpenEditionCloneAddress);

        /*----------------------------------------------------------*|
        |*  # MINT                                                  *|
        |*----------------------------------------------------------*/

        _ERC721BaseClone.mint(_MINTER, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        _ERC721LazyMintClone.mint(_MINTER, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        _ERC1155BaseClone.mint(_MINTER, 10, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        _ERC1155LazyMintClone.mint(_MINTER, 10, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        _ERC1155OpenEditionClone.mint(_MINTER, 10, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        // test token balances and total supply after minting
        _checkBalances(_ERC721BaseCloneAddress, _MINTER);
        _checkBalances(_ERC721LazyMintCloneAddress, _MINTER);
        _checkBalances(_ERC1155BaseCloneAddress, _MINTER);
        _checkBalances(_ERC1155LazyMintCloneAddress, _MINTER);
        _checkBalances(_ERC1155OpenEditionCloneAddress, _MINTER);
    }

    /// @dev this contracts's address is used as the minter address for minting tokens and therefore we use
    /// address(this) in
    /// order to avoid using vm.prank() when minting, this require the testing contract to be `payable`.
    receive() external payable { }

    /// @dev this contracts's address is used as the minter address for minting tokens and therefore we use
    /// address(this) in
    /// order to avoid using vm.prank() when minting, this require the testing contract to support the ERC721Receiver
    /// and ERC1155Receiver interfaces.
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return 0xf23a6e61;
    }

    /// @dev this contracts's address is used as the minter address for minting tokens and therefore we use
    /// address(this) in
    /// order to avoid using vm.prank() when minting, this require the testing contract to support the ERC721Receiver
    /// and ERC1155Receiver interfaces.
    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return 0x150b7a02; // ERC721TokenReceiver.onERC721Received.selector;
    }

    /// @dev testing interface support for IERC721Receiver, IERC1155Receiver and ERC165
    function testSupportsInterface() public view {
        // Interface ID for IERC721Receiver
        assertEq(_marketplace.supportsInterface(0x150b7a02), true);
        // Interface ID for IERC1155Receiver
        assertEq(_marketplace.supportsInterface(0x4e2312e0), true);
        // Interface ID for ERC165
        assertEq(_marketplace.supportsInterface(0x01ffc9a7), true);
    }

    function testOnERC721Received() public {
        bool setCommissions = true;
        uint256 ERC1155Value;
        uint256 offerId;
        uint256 orderId;
        uint256 tokenId;
        QuoteToken quoteToken = QuoteToken.ETH;
        /*----------------------------------------------------------*|
        |*  # CREATE ORDER                                          *|
        |*----------------------------------------------------------*/
        // if the offer id parameter is 0, create a new order
        // there are two paths to test, one for ETh and one for USDC
        _createOrder(_ERC721BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        orderId += 1;
        _createOrder(_ERC721LazyMintCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        orderId += 1;

        quoteToken = QuoteToken.USDC;

        // mint more tokens since only 1 token was minted in the _setUp function for each ERC721 collection
        _ERC721BaseClone.mint(_MINTER, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        _ERC721LazyMintClone.mint(_MINTER, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));

        tokenId += 1;

        _createOrder(_ERC721BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        orderId += 1;
        _createOrder(_ERC721LazyMintCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        orderId += 1;

        /**
         * quoteToken = QuoteToken.ETH;
         *
         *     _testMintAndCreateOrder(_ERC721BaseCloneAddress, setCommissions, quoteToken);
         *     _testMintAndCreateOrder(_ERC721LazyMintCloneAddress, setCommissions, quoteToken);
         *
         *     quoteToken = QuoteToken.USDC;
         *
         *     _testMintAndCreateOrder(_ERC721BaseCloneAddress, setCommissions, quoteToken);
         *     _testMintAndCreateOrder(_ERC721LazyMintCloneAddress, setCommissions, quoteToken);
         *
         */

        /*----------------------------------------------------------*|
        |*  # ACCEPT OFFER                                          *|
        |*----------------------------------------------------------*/
        // accepting offers by sending a token to the marketplace that matches the offer
        // if the offer id parameter is not 0, accept an existing offer
        // there are two paths to test, one for ETh and one for USDC

        quoteToken = QuoteToken.ETH;
        // mint new 721 tokens
        _ERC721BaseClone.mint(_MINTER, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        _ERC721LazyMintClone.mint(_MINTER, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        // increase tokenId
        tokenId += 1;
        // primary sale not on escrow
        _createOffer(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, address(0), tokenId, ERC1155Value, quoteToken);
        offerId += 1;

        _acceptOffer(
            _ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _MINTER, 0, offerId, tokenId, ERC1155Value, quoteToken
        );
        // secondary sale on escrow
        //quoteToken = QuoteToken.USDC;
        // mint new 721 tokens
        _ERC721BaseClone.mint(_MINTER, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        _ERC721LazyMintClone.mint(_MINTER, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        // increase tokenId
        tokenId += 1;

        // primary sale not on escrow
        _createOffer(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, address(0), tokenId, ERC1155Value, quoteToken);
        offerId += 1;
        _acceptOffer(
            _ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _MINTER, 0, offerId, tokenId, ERC1155Value, quoteToken
        );
    }

    function testOnERC1155Received() public {
        bool setCommissions = true;
        uint256 tokenId;
        uint256 offerId;
        uint256 ERC1155Value = 1;
        QuoteToken quoteToken;

        /*----------------------------------------------------------*|
        |*  # CREATE ORDER                                          *|
        |*----------------------------------------------------------*/
        // if the offer id parameter is 0, create a new order
        // there are two paths to test, one for ETH and one for USDC

        /*----------------------------------------------------------------------------*|
        |*  # UPDATE ORDER (raise ERC1155 value and optionally set new unit price)    *|
        |*----------------------------------------------------------------------------*/
        // `_unitPrice > 0 && _orderOrOfferId > 0`

        // the Marketplace contract keeps different counters for ETH and USDC orders,
        // meaning that the order id for ETH orders is different from the order id for USDC orders

        quoteToken = QuoteToken.ETH;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        _updateOrder(_ERC1155BaseCloneAddress, tokenId, 1, ERC1155Value, quoteToken);

        _createOrder(_ERC1155LazyMintCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        _updateOrder(_ERC1155LazyMintCloneAddress, tokenId, 2, ERC1155Value, quoteToken);

        _createOrder(_ERC1155OpenEditionCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        _updateOrder(_ERC1155OpenEditionCloneAddress, tokenId, 3, ERC1155Value, quoteToken);

        // the Marketplace contract keeps different counters for ETH and USDC orders,
        // meaning that the order id for ETH orders is different from the order id for USDC orders
        quoteToken = QuoteToken.USDC;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        _updateOrder(_ERC1155BaseCloneAddress, tokenId, 1, ERC1155Value, quoteToken);

        _createOrder(_ERC1155LazyMintCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        _updateOrder(_ERC1155LazyMintCloneAddress, tokenId, 2, ERC1155Value, quoteToken);

        _createOrder(_ERC1155OpenEditionCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        _updateOrder(_ERC1155OpenEditionCloneAddress, tokenId, 3, ERC1155Value, quoteToken);

        /*----------------------------------------------------------*|
        |*  # ACCEPT OFFER                                          *|
        |*----------------------------------------------------------*/
        // accepting offers by sending a token to the marketplace that matches the offer
        // if the offer id parameter is not 0, accept an existing offer
        // there are two paths to test, one for ETh and one for USDC
        quoteToken = QuoteToken.ETH;

        // primary sale NOT on escrow
        _createOffer(_ERC1155BaseCloneAddress, _COLLECTOR_PRIMARY, address(0), 0, ERC1155Value, quoteToken);
        offerId = _marketplace.ETHOfferCount();

        _acceptOffer(_ERC1155BaseCloneAddress, _COLLECTOR_PRIMARY, _MINTER, 0, offerId, 0, ERC1155Value, quoteToken);

        /**
         *     quoteToken = QuoteToken.ETH;
         *
         *     _testMintAndCreateOrder(_ERC1155BaseCloneAddress, setCommissions, quoteToken);
         *     _testMintAndCreateOrder(_ERC1155LazyMintCloneAddress, setCommissions, quoteToken);
         *     _testMintAndCreateOrder(_ERC1155OpenEditionCloneAddress, setCommissions, quoteToken);
         *
         *     quoteToken = QuoteToken.USDC;
         *
         *     _testMintAndCreateOrder(_ERC1155BaseCloneAddress, setCommissions, quoteToken);
         *     _testMintAndCreateOrder(_ERC1155LazyMintCloneAddress, setCommissions, quoteToken);
         *     _testMintAndCreateOrder(_ERC1155OpenEditionCloneAddress, setCommissions, quoteToken);
         *
         */
    }

    function testUpdateOrderPrice() public {
        bool setCommissions;
        uint256 ERC1155Value;
        uint256 offerId;
        uint256 orderId;

        _createOrder(_ERC721BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, QuoteToken.ETH);
        orderId += 1;
        _testUpdateOrderPrice(orderId);

        _createOrder(_ERC721LazyMintCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, QuoteToken.ETH);
        orderId += 1;
        _testUpdateOrderPrice(orderId);

        ERC1155Value = 1;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, QuoteToken.ETH);
        orderId += 1;
        _testUpdateOrderPrice(orderId);

        _createOrder(_ERC1155OpenEditionCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, QuoteToken.ETH);
        orderId += 1;
        _testUpdateOrderPrice(orderId);
    }

    function testRaiseOrderERC1155Value() public {
        bool setCommissions;
        uint256 ERC1155Value = 1;
        uint256 offerId;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, QuoteToken.ETH);
        _raiseOrderERC1155Value(_ERC1155BaseCloneAddress);
    }

    function testLowerOrderERC1155Value() public {
        uint256 ERC1155RedeemAmount = 1;
        uint256 ERC1155Value = 1;
        uint256 offerId;
        uint256 orderId;
        bool setCommissions;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, QuoteToken.ETH);

        orderId = _marketplace.ETHOrderCount();

        OnChainMarketplace.Order memory order = _marketplace.getETHOrder(orderId);

        ERC1155Value = order.ERC1155Value;

        _marketplace.updateETHOrder(orderId, ERC1155RedeemAmount, order.unitPrice);

        order = _marketplace.getETHOrder(orderId);

        assertEq(_ERC1155BaseClone.balanceOf(_MINTER, 0), 10, "balance of minter should be 10");
        assertEq(_ERC1155BaseClone.balanceOf(address(_marketplace), 0), 0, "balance of marketplace should be 0");
        assertEq(order.ERC1155Value, ERC1155Value - ERC1155RedeemAmount, "ERC1155Value should be the updated amount");
    }

    function test_RevertWhen_LowerOrderERC1155Value() public {
        uint256 orderId;
        uint256 offerId;
        uint256 ERC1155RedeemValue = 2;
        uint256 ERC1155Value = 1;
        bool setCommissions;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, QuoteToken.ETH);

        // fails to withdraw more tokens than deposited
        vm.expectRevert();
        _marketplace.updateETHOrder(orderId, ERC1155RedeemValue, _UNIT_PRICE);
    }

    function testDeleteOrder() public {
        uint256 ERC1155Value;
        uint256 offerId;
        uint256 orderId = 1;
        bool setCommissions;
        QuoteToken quoteToken = QuoteToken.ETH;

        _createOrder(_ERC721BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        _testDeleteOrder(_ERC721BaseCloneAddress, _MINTER, orderId, QuoteToken.ETH);

        orderId += 1;
        ERC1155Value = 1;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        _testDeleteOrder(_ERC1155BaseCloneAddress, _MINTER, orderId, QuoteToken.ETH);
    }

    function testFillETHOrderPrimary() public {
        // _quoteToken determines if the order is filled with ETH or USDC
        QuoteToken _quoteToken = QuoteToken.ETH;
        uint256 ERC1155Value;
        uint256 offerId;
        bool setCommissions;

        _createOrder(_ERC721BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, _quoteToken);

        _testFillETHOrder(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _quoteToken);

        ERC1155Value = 1;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, _quoteToken);

        _testFillETHOrder(_ERC1155BaseCloneAddress, _COLLECTOR_PRIMARY, _quoteToken);
    }

    function testFillETHOrderPrimary_withUSDC() public {
        // _quoteToken determines if the order is filled with ETH or USDC
        QuoteToken _quoteToken = QuoteToken.ETH;

        uint256 ERC1155Value;
        uint256 offerId;
        bool setCommissions;

        _createOrder(_ERC721BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, _quoteToken);
        _testFillETHOrder(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _quoteToken);
    }

    function testFillETHOrderSecondary() public {
        // _quoteToken determines if the order is filled with ETH or USDC
        QuoteToken _quoteToken = QuoteToken.ETH;
        uint256 ERC1155Value;
        uint256 offerId;
        bool setCommissions;

        _createOrder(_ERC721BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, _quoteToken);
        _testFillETHOrder(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _quoteToken);

        _createOrder(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, offerId, ERC1155Value, setCommissions, _quoteToken);
        _testFillETHOrder(_ERC721BaseCloneAddress, _COLLECTOR_SECONDARY, _quoteToken);

        ERC1155Value = 1;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, _quoteToken);
        _testFillETHOrder(_ERC1155BaseCloneAddress, _COLLECTOR_PRIMARY, _quoteToken);

        _createOrder(_ERC1155BaseCloneAddress, _COLLECTOR_PRIMARY, offerId, ERC1155Value, setCommissions, _quoteToken);
        _testFillETHOrder(_ERC1155BaseCloneAddress, _COLLECTOR_SECONDARY, _quoteToken);
    }

    function testFillETHOrderWithCommissions() public {
        // _quoteToken determines if the order is filled with ETH or USDC
        QuoteToken _quoteToken = QuoteToken.ETH;

        uint256 offerId;
        uint256 ERC1155Value;
        bool setCommissions;

        _createOrder(_ERC721BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, _quoteToken);
        _testFillETHOrder(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _quoteToken);

        ERC1155Value = 1;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, _quoteToken);
        _testFillETHOrder(_ERC1155BaseCloneAddress, _COLLECTOR_PRIMARY, _quoteToken);

        // _createOrder(_ERC1155OpenEditionCloneAddress, _MINTER, offerId, true, QuoteToken.ETH);
        // _testFillETHOrder_1155(_ERC1155OpenEditionCloneAddress, _COLLECTOR_PRIMARY);
    }

    function testFillETHOrderPartial() public {
        // _quoteToken determines if the order is filled with ETH or USDC
        QuoteToken _quoteToken = QuoteToken.ETH;

        uint256 offerId;
        uint256 ERC1155Value = 1;
        bool setCommissions;

        _createOrder(_ERC1155BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, _quoteToken);
        _raiseOrderERC1155Value(_ERC1155BaseCloneAddress);
        _raiseOrderERC1155Value(_ERC1155BaseCloneAddress);
        _testFillETHOrder(_ERC1155BaseCloneAddress, _COLLECTOR_PRIMARY, _quoteToken);
    }

    function testCreateOffer() public {
        uint256 ERC1155Value;
        uint256 tokenId;
        QuoteToken quoteToken = QuoteToken.ETH;

        _createOffer(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);
        _createOffer(_ERC721LazyMintCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);

        ERC1155Value = 1;

        // primary sale ERC1155
        _createOffer(_ERC1155BaseCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);
        _createOffer(_ERC1155LazyMintCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);
        _createOffer(_ERC1155OpenEditionCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);
    }

    function testDeleteOffer() public {
        uint256 ERC1155Value;
        uint256 tokenId;
        uint256 offerId;
        QuoteToken quoteToken = QuoteToken.ETH;

        _createOffer(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);
        offerId += 1;
        _testDeleteOffer(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, offerId, quoteToken);

        _createOffer(_ERC721LazyMintCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);
        offerId += 1;
        _testDeleteOffer(_ERC721LazyMintCloneAddress, _COLLECTOR_PRIMARY, offerId, quoteToken);

        ERC1155Value = 1;

        _createOffer(_ERC1155BaseCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);
        offerId += 1;
        _testDeleteOffer(_ERC1155BaseCloneAddress, _COLLECTOR_PRIMARY, offerId, quoteToken);

        _createOffer(_ERC1155LazyMintCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);
        offerId += 1;
        _testDeleteOffer(_ERC1155LazyMintCloneAddress, _COLLECTOR_PRIMARY, offerId, quoteToken);

        _createOffer(_ERC1155OpenEditionCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);
        offerId += 1;
        _testDeleteOffer(_ERC1155OpenEditionCloneAddress, _COLLECTOR_PRIMARY, offerId, quoteToken);
    }

    function testRaiseOfferPrice() public {
        uint256 ERC1155Value;
        uint256 tokenId;
        QuoteToken quoteToken = QuoteToken.ETH;

        _createOffer(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);

        vm.prank(_COLLECTOR_PRIMARY);
        _marketplace.raiseETHOfferPrice{ value: _UNIT_PRICE }(1, 0, _UNIT_PRICE * 2);

        OnChainMarketplace.Offer memory offer = _marketplace.getETHOffer(1);

        assertEq(offer.tokenId, 0);
        assertEq(offer.ERC1155Value, 0);
        assertEq(offer.from, _COLLECTOR_PRIMARY);
        assertEq(offer.unitPrice, _UNIT_PRICE * 2);
        assertEq(offer.collection, address(_ERC721BaseClone));
        assertEq(_COLLECTOR_PRIMARY.balance, _STARTING_BALANCE - _UNIT_PRICE * 2);
    }

    function testLowerOfferPrice() public {
        uint256 ERC1155Value;
        uint256 tokenId;
        QuoteToken quoteToken = QuoteToken.ETH;

        _createOffer(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _MINTER, tokenId, ERC1155Value, quoteToken);

        vm.prank(_COLLECTOR_PRIMARY);
        _marketplace.lowerETHOfferPrice(1, 0, _UNIT_PRICE);

        OnChainMarketplace.Offer memory offer = _marketplace.getETHOffer(1);

        assertEq(offer.tokenId, 0);
        assertEq(offer.ERC1155Value, 0);
        assertEq(offer.from, _COLLECTOR_PRIMARY);
        assertEq(offer.unitPrice, _UNIT_PRICE);
        assertEq(offer.collection, address(_ERC721BaseClone));
        assertEq(_COLLECTOR_PRIMARY.balance, _STARTING_BALANCE - _UNIT_PRICE);
    }

    function testAcceptETHOffer() public {
        QuoteToken quoteToken = QuoteToken.ETH;

        uint256 ERC1155Value;
        uint256 orderId;
        uint256 offerId;
        uint256 tokenId;
        bool setCommissions; // set to false for now

        _createOrder(_ERC721BaseCloneAddress, _MINTER, offerId, ERC1155Value, setCommissions, quoteToken);
        orderId += 1;

        _createOffer(_ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, address(0), tokenId, ERC1155Value, quoteToken);
        offerId += 1;

        _acceptOffer(
            _ERC721BaseCloneAddress, _COLLECTOR_PRIMARY, _MINTER, orderId, offerId, tokenId, ERC1155Value, quoteToken
        );
    }

    function _createOffer(
        address _collection,
        address _buyer,
        address _seller,
        uint256 _tokenId,
        uint256 _ERC1155Value,
        QuoteToken _quoteToken
    )
        private
    {
        OnChainMarketplace.Offer memory offer;
        uint256 offerId;

        _setStartingAccountsBalance(_tokenId, _ERC1155Value, _collection, _buyer, _seller, address(0), _quoteToken);

        vm.prank(_buyer);

        if (_quoteToken == QuoteToken.ETH) {
            _marketplace.createOffer{ value: _UNIT_PRICE }(_tokenId, _UNIT_PRICE, _ERC1155Value, _collection, _buyer);
        } else {
            _marketplace.createOffer(_tokenId, _ERC1155Value, _UNIT_PRICE, _collection, _buyer);
        }

        _setFinalAccountsBalance(_tokenId, _ERC1155Value, _collection, _buyer, _seller, address(0), _quoteToken);

        if (_quoteToken == QuoteToken.ETH) {
            offerId = _marketplace.ETHOfferCount();
            offer = _marketplace.getETHOffer(offerId);
        } else {
            offerId = _marketplace.USDCOfferCount();
            offer = _marketplace.getUSDCOffer(offerId);
        }

        assertEq(offer.tokenId, _tokenId, "tokenId mismatch");
        assertEq(offer.ERC1155Value, _ERC1155Value, "ERC1155Value should be 0");
        assertEq(offer.from, _buyer, "from should be buyer");
        assertEq(offer.unitPrice, _UNIT_PRICE, "unitPrice should be 1 ether");
        assertEq(offer.collection, _collection, "collection should be the collection");

        assertEq(finalBuyerBalance, startingBuyerBalance - _UNIT_PRICE, "incorrect buyer token balance");
    }

    function _updateOrder(
        address _collection,
        uint256 _tokenId,
        uint256 _orderId,
        uint256 _ERC1155Value,
        QuoteToken _quoteToken
    )
        private
    {
        address to = address(_marketplace);
        address[] memory commissionReceivers;
        uint256[] memory commissionBps;
        bytes memory data;
        // Send an extra token to the marketplace to update the order's ERC1155 value and encode the new unit price
        data = abi.encode(_orderId, _UNIT_PRICE * 2, commissionBps, commissionReceivers, _quoteToken);
        _transferNFT(_collection, _MINTER, to, _tokenId, _ERC1155Value, data);
    }

    function _acceptOffer(
        address _collection,
        address _buyer,
        address _seller,
        uint256 _orderId,
        uint256 _offerId,
        uint256 _tokenId,
        uint256 _ERC1155Value,
        QuoteToken _quoteToken
    )
        private
    {
        OnChainMarketplace.Order memory order;
        OnChainMarketplace.Offer memory offer;

        uint256[] memory _commissionBps;
        address[] memory _commissionRecipient;

        bool setCommissions;

        //_setStartingAccountsBalance(0, 0, _collection, _buyer, _seller, address(0), _quoteToken);

        if (_orderId == 0) {
            _createOrder(_collection, _seller, _offerId, _ERC1155Value, setCommissions, _quoteToken);
        } else {
            vm.prank(_seller);
            if (_quoteToken == QuoteToken.ETH) {
                _marketplace.acceptETHOffer(_orderId, _offerId, _ERC1155Value);
            } else {
                _marketplace.acceptUSDCOffer(_orderId, _offerId, _ERC1155Value, _commissionBps, _commissionRecipient);
            }
        }

        //_setFinalAccountsBalance(0, 0, _collection, _buyer, _seller, address(0), _quoteToken);

        // order should be deleted

        if (_orderId > 0) {
            if (_quoteToken == QuoteToken.ETH) {
                order = _marketplace.getETHOrder(_orderId);
            } else {
                order = _marketplace.getUSDCOrder(_orderId);
            }

            assertEq(order.tokenId, 0, "tokenId should be 0");
            assertEq(order.unitPrice, 0, "unitPrice should be 0 ether");
            assertEq(order.ERC1155Value, 0, "ERC1155Value should be 0");
            assertEq(order.collection, address(0), "collection should be the collection");
            assertEq(order.from, address(0), "from should be address(0)");
            assertEq(order.operator, address(0), "operator should be address(0)");
            assertEq(order.commissionBps.length, 0, "commissionBps should be empty");
            assertEq(order.commissionRecipient.length, 0, "commissionRecipient should be empty");
        }

        // offer should be deleted as well

        if (_quoteToken == QuoteToken.ETH) {
            offer = _marketplace.getETHOffer(_offerId);
        } else {
            offer = _marketplace.getUSDCOffer(_offerId);
        }

        assertEq(offer.tokenId, 0, "fail tokenIdOffer");
        assertEq(offer.unitPrice, 0, "fail _unitPriceOffer");
        assertEq(offer.ERC1155Value, 0, "fail _ERC1155ValueOffer");
        assertEq(offer.collection, address(0), "fail _collectionOffer");
        assertEq(offer.from, address(0), "fail _fromOffer");

        // check ETH or USDC balances
        /**
         * assertEq(
         *         finalBuyerBalance,
         *         startingBuyerBalance,
         *         "buyer balance stays the same actually because the offer is escrowed before calling acceptOffer"
         *     );
         *     assertEq(
         *         finalSellerBalance,
         *         startingSellerBalance
         *             + _UNIT_PRICE * (_TOTAL_BPS - _FEE_BPS - (_seller == _MINTER ? 0 : _ROYALTY_BPS)) / _TOTAL_BPS,
         *         "_MINTER balance not correct"
         *     );
         *     assertEq(
         *         finalFeeAccountBalance,
         *         startingFeeAccountBalance + _UNIT_PRICE * (_FEE_BPS) / _TOTAL_BPS,
         *         "fee account balance not correct"
         *     );
         */
        // check token balances and ownership

        //assertEq(finalBuyerTokenBalance, startingBuyerTokenBalance + 1, "incorrect buyer token balance");
        //assertEq(finalMarketplaceTokenBalance, startingMarketplaceTokenBalance - 1, "incorrect marketplace token
        // balance");
        //assertEq(finalSellerTokenBalance, startingSellerTokenBalance, "incorrect seller token balance");

        if (_ERC1155Value == 0) {
            assertEq(IERC721(_collection).ownerOf(_tokenId), _buyer, "owner of token should be buyer address");
        }
    }

    /// @param _seller needed for secondary sales (otherwise the seller is always adress(this))
    function _createOrder(
        address _collection,
        address _seller,
        uint256 _offerId,
        uint256 _ERC1155Value,
        bool _setCommissions,
        QuoteToken _quoteToken
    )
        internal
    {
        bytes memory data;
        uint256 tokenId;
        address buyer; // 0 address, not used
        address commissionReceiver;
        address[] memory commissionReceivers;
        uint256[] memory commissionBps;

        if (_setCommissions) {
            commissionReceivers = _COMMISSION_RECEIVERS;
            commissionReceiver = commissionReceivers[0];
            commissionBps = _COMMISSION_BPS;
        }
        // this data is passed to and decoded by the OnChainMarketplace contract when the token is transferred, in the
        // onERC1155Received or onERC721Received function
        // if there is no offerId, create a new order, else accept an existing offer (by passing a unit price of 0)
        if (_offerId == 0) {
            data = abi.encode(_offerId, _UNIT_PRICE, commissionBps, commissionReceivers, _quoteToken);
        } else {
            data = abi.encode(_offerId, 0, commissionBps, commissionReceivers, _quoteToken);
        }
        // if collection supports `IERC721Enumerable` interface or implements (OpenZeppelin's)
        // {ERC115Supply-totalSupply} we can get the totalSupply
        // try catch is needed because the totalSupply function might not be implemented
        try IERC721Enumerable(_collection).totalSupply() returns (uint256 totalSupply) {
            // 0 indexed, assuming the seller is selling the last token minted in the collection
            tokenId = totalSupply - 1;
        } catch {
            revert("collection does not implement totalSupply, update test parameters to include tokenId");
        }
        // set the starting balances of the accounts before the transfer
        _setStartingAccountsBalance(
            tokenId, _ERC1155Value, _collection, buyer, _seller, commissionReceiver, _quoteToken
        );
        // transfer the token to the marketplace with the order data
        _transferNFT(_collection, _seller, address(_marketplace), tokenId, _ERC1155Value, data);
        // set the final balances of the accounts after the transfer
        _setFinalAccountsBalance(tokenId, _ERC1155Value, _collection, buyer, _seller, commissionReceiver, _quoteToken);

        // check token balances and ownership

        assertEq(
            finalSellerTokenBalance,
            startingSellerTokenBalance - (_ERC1155Value == 0 ? 1 : _ERC1155Value),
            "incorrect seller token balance"
        );
        // the marketplace should have the token
        // since _createOrder is called also in order to accept an offer for tokens,
        // i.e. if offerId is 0, the token should be owned by the marketplace as the transfer created an order,
        // otherwise the token should be owned by the buyer as the transfer triggered an offer acceptance
        if (_offerId == 0) {
            assertEq(
                finalMarketplaceTokenBalance,
                startingMarketplaceTokenBalance + (_ERC1155Value == 0 ? 1 : _ERC1155Value),
                "incorrect marketplace token balance"
            );
            // the token should be owned by the marketplace
            // if collection supports ierc721 interface we can check the owner of the token
            if (IERC165(_collection).supportsInterface(0x80ac58cd)) {
                assertEq(
                    IERC721(_collection).ownerOf(tokenId), address(_marketplace), "owner of token should be marketplace"
                );
            }
            // check order details
            OnChainMarketplace.Order memory order;
            // check order details
            if (_quoteToken == QuoteToken.ETH) {
                order = _marketplace.getETHOrder(_marketplace.ETHOrderCount());
            } else {
                order = _marketplace.getUSDCOrder(_marketplace.USDCOrderCount());
            }

            assertEq(order.tokenId, tokenId, "tokenId should be 0");
            assertEq(order.unitPrice, _UNIT_PRICE, "incorrect _UNIT_PRICE");
            assertEq(order.ERC1155Value, _ERC1155Value, "Incorrect ERC1155Value");
            assertEq(order.collection, _collection, "incorrect collection");
            assertEq(order.from, _seller, "incorrect seller");
            assertEq(order.operator, _seller, "incorrect operator");
            if (_setCommissions) {
                assertEq(order.commissionBps.length, _COMMISSION_BPS.length, "incorrect commissionBps");
                assertEq(
                    order.commissionRecipient.length, _COMMISSION_RECEIVERS.length, "incorrect commissionReceivers"
                );
            } else {
                assertEq(order.commissionBps.length, 0, "commissionBps should be empty");
                assertEq(order.commissionRecipient.length, 0, "commissionRecipient should be empty");
            }
        }
    }

    function _testMintAndCreateOrder(address _collection, bool _setCommissions, QuoteToken _quoteToken) internal {
        bytes memory data;
        uint256 tokenId;
        uint256 offerId; // 0, not used
        uint256 ERC1155Value;
        address buyer; // 0 address, not used
        address commissionReceiver;
        address[] memory commissionReceivers;
        uint256[] memory commissionBps;

        if (_setCommissions) {
            commissionReceivers = _COMMISSION_RECEIVERS;
            commissionReceiver = commissionReceivers[0];
            commissionBps = _COMMISSION_BPS;
        }

        data = abi.encode(offerId, _UNIT_PRICE, commissionBps, commissionReceivers, _quoteToken);

        // if collection supports `IERC721Enumerable` interface or implements (OpenZeppelin's)
        // {ERC115Supply-totalSupply} we can get the totalSupply
        // try catch is needed because the totalSupply function might not be implemented
        try IERC721Enumerable(_collection).totalSupply() returns (uint256 totalSupply) {
            // 0 indexed, assuming the seller is selling the last token minted in the collection
            // since token has not been minted yet, `tokenId = totalSupply` (next id to be minted)
            tokenId = totalSupply;
        } catch {
            revert("collection does not implement totalSupply, update test parameters to include tokenId");
        }

        // set the starting balances of the accounts before the transfer

        _setStartingAccountsBalance(tokenId, ERC1155Value, _collection, buyer, _MINTER, commissionReceiver, _quoteToken);

        // transfer the token to the marketplace with the order data
        // check if the collection is ERC1155
        if (IERC165(_collection).supportsInterface(0xd9b67a26)) ERC1155Value = 1;

        if (ERC1155Value == 0) {
            IERC721(_collection).mint(
                address(_marketplace), abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, data))
            );
        } else {
            IERC1155(_collection).mint(
                address(_marketplace), 1, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, data))
            );
        }

        // set the final balances of the accounts after the transfer
        _setFinalAccountsBalance(tokenId, ERC1155Value, _collection, buyer, _MINTER, commissionReceiver, _quoteToken);

        // check token balances and ownership

        // seller balance remains the same since the token is escrowed to marketplace
        assertEq(finalSellerTokenBalance, startingSellerTokenBalance, "incorrect seller token balance");
        // the marketplace should have the token
        assertEq(
            finalMarketplaceTokenBalance, startingMarketplaceTokenBalance + 1, "incorrect marketplace token balance"
        );

        // the token should be owned by the marketplace
        // if collection supports ierc721 interface we can check the owner of the token
        if (IERC165(_collection).supportsInterface(0x80ac58cd)) {
            assertEq(
                IERC721(_collection).ownerOf(tokenId), address(_marketplace), "owner of token should be marketplace"
            );
        }

        OnChainMarketplace.Order memory order;
        // check order details
        if (_quoteToken == QuoteToken.ETH) {
            order = _marketplace.getETHOrder(_marketplace.ETHOrderCount());
        } else {
            order = _marketplace.getUSDCOrder(_marketplace.USDCOrderCount());
        }

        assertEq(order.tokenId, tokenId, "tokenId should be 0");
        assertEq(order.unitPrice, _UNIT_PRICE, "incorrect _UNIT_PRICE");
        assertEq(order.ERC1155Value, ERC1155Value, "Incorrect ERC1155Value");
        assertEq(order.collection, _collection, "incorrect collection");
        assertEq(order.from, _MINTER, "incorrect seller");
        assertEq(order.operator, _MINTER, "incorrect operator");
        if (_setCommissions) {
            assertEq(order.commissionBps.length, _COMMISSION_BPS.length, "incorrect commissionBps");
            assertEq(order.commissionRecipient.length, _COMMISSION_RECEIVERS.length, "incorrect commissionReceivers");
        } else {
            assertEq(order.commissionBps.length, 0, "commissionBps should be empty");
            assertEq(order.commissionRecipient.length, 0, "commissionRecipient should be empty");
        }
    }

    /// @param _quoteToken determines if the order is filled with ETH or USDC
    function _testFillETHOrder(address _collection, address _buyer, QuoteToken _quoteToken) internal {
        // fetch latest ETH order id
        uint256 orderId = _marketplace.ETHOrderCount();
        // fetch order details
        OnChainMarketplace.Order memory order = _marketplace.getETHOrder(orderId);
        // declare common order variables (balances are set in the helper functions below)

        address seller = order.from;
        address commissionReceiver;
        uint256 commissionBps;
        uint256 tokenId = order.tokenId;
        uint256 ERC1155Value = order.ERC1155Value;
        uint256 tokenAmount = ERC1155Value == 0 ? 1 : ERC1155Value;
        uint256 ETHValue = order.unitPrice;
        uint256 USDValue;
        uint256 NFTValue = ETHValue;
        // if `ERC1155Value > 0` the contract is an edition,
        // only multiply by `order.value` if `ERC1155Value > 1` since multiplying by 1 is pointless
        if (ERC1155Value > 1) {
            ETHValue *= ERC1155Value;
            NFTValue *= ERC1155Value;
        }
        // if the calling test function is using USDC to fill the order, the USDValue must be calculated
        if (_quoteToken == QuoteToken.USDC) {
            // fetch latest ETH/USD price from Chainlink price feed
            (, int256 ETHUSDPrice,,,) = _ETHUSDPriceFeed.latestRoundData();
            // The `order.unitPrice`, assumed to be in ETH, must be converted to USDC
            // Adjust for price feed decimals (8) i.e. `1e8`
            // by dividing by 1e2 which truncates the last two decimal places not needed for precision
            // since USDC only has 6 decimals
            USDValue = ETHValue * (uint256(ETHUSDPrice) / 100) / 1 ether;
            NFTValue = USDValue;
        }
        // fetch order commission details, if any are set
        if (order.commissionBps.length == 1) {
            commissionBps = order.commissionBps[0];
            commissionReceiver = order.commissionRecipient[0];
        }
        // fetch starting balances of all parties involved to be used for assertion testing later
        _setStartingAccountsBalance(
            tokenId, ERC1155Value, _collection, _buyer, seller, commissionReceiver, QuoteToken.ETH
        );

        vm.prank(_buyer);

        if (_quoteToken == QuoteToken.ETH) {
            // if ETH is used to fill the order, the value must be sent with the function call
            _marketplace.fillETHOrder{ value: ETHValue }(orderId, _buyer, ERC1155Value);
        } else {
            // if USDC is used to fill the order, enough USDC has been approved for the marketplace contract in the
            // `setup()` function already
            _marketplace.fillETHOrder(orderId, _buyer, ERC1155Value);
        }
        // fetch final balances of all parties involved to be used for assertion testing (compare with starting
        // balances)
        _setFinalAccountsBalance(tokenId, ERC1155Value, _collection, _buyer, seller, commissionReceiver, QuoteToken.ETH);

        assertEq(
            finalBuyerTokenBalance, startingBuyerTokenBalance + tokenAmount, "Incorrect buyer's final token balance"
        );
        assertEq(
            finalSellerTokenBalance,
            startingSellerTokenBalance,
            "balance of seller should not have changed since the token was escrowed"
        );
        assertEq(
            finalMarketplaceTokenBalance,
            startingMarketplaceTokenBalance - tokenAmount,
            "balance of marketplace should be 0"
        );

        if (ERC1155Value == 0) {
            assertEq(
                IERC721(_collection).ownerOf(tokenId), _buyer, "owner of ERC721 token should be buyer/collector account"
            );
        }

        if (order.commissionBps.length == 1) {
            assertEq(
                finalCommissionReceiverBalance - startingCommissionReceiverBalance,
                NFTValue * commissionBps / _TOTAL_BPS,
                "commission receiver balance not correct"
            );
        }

        // if seller is different than MINTER, I.e. secondary sale (primary sale don't pay out royalties to minter)
        if (seller != _MINTER) {
            assertEq(
                finalSellerBalance - startingSellerBalance,
                NFTValue * (_TOTAL_BPS - _FEE_BPS - _ROYALTY_BPS - commissionBps) / _TOTAL_BPS,
                "seller balance not correct"
            );
            assertEq(
                finalMinterBalance - startingMinterBalance,
                NFTValue * _ROYALTY_BPS / _TOTAL_BPS,
                "_MINTER balance not correct"
            );
        } else {
            // if seller is minter then no royalties are paid out
            assertEq(
                finalSellerBalance - startingSellerBalance,
                NFTValue * (_TOTAL_BPS - _FEE_BPS - commissionBps) / _TOTAL_BPS,
                "seller balance not correct"
            );
        }

        assertEq(startingBuyerBalance - finalBuyerBalance, NFTValue, "_buyer balance not correct");

        assertEq(
            finalFeeAccountBalance - startingFeeAccountBalance,
            NFTValue * _FEE_BPS / _TOTAL_BPS,
            "fee account balance not correct"
        );
    }

    function _setStartingAccountsBalance(
        uint256 _tokenId,
        uint256 _ERC1155Value,
        address _collection,
        address _buyer,
        address _seller,
        address _commissionReceiver,
        QuoteToken _quoteToken
    )
        private
    {
        // if `msg.value > 0` then the balances are in ETH (fill order with ETH),
        // else they are in USDC (fill order with USDC)
        if (_quoteToken == QuoteToken.ETH) {
            startingSellerBalance = _seller.balance;
            if (_buyer != address(0)) {
                startingBuyerBalance = _buyer.balance;
                if (startingBuyerBalance == 0) {
                    revert("starting ETH buyer balance is 0");
                }
            }
            startingCommissionReceiverBalance = _commissionReceiver.balance;
            startingFeeAccountBalance = _FEES_RECIPIENT.balance;
            startingMinterBalance = _MINTER.balance;
        } else {
            if (_seller != address(0)) {
                startingSellerBalance = IERC20(_USDC).balanceOf(_seller);
            }
            if (_buyer != address(0)) {
                startingBuyerBalance = IERC20(_USDC).balanceOf(_buyer);
                if (startingBuyerBalance == 0) {
                    revert("starting USDC buyer balance is 0");
                }
            }
            if (_commissionReceiver != address(0)) {
                startingCommissionReceiverBalance = IERC20(_USDC).balanceOf(_commissionReceiver);
            }
            if (_FEES_RECIPIENT != address(0)) {
                startingFeeAccountBalance = IERC20(_USDC).balanceOf(_FEES_RECIPIENT);
            }
            if (_MINTER != address(0)) {
                startingMinterBalance = IERC20(_USDC).balanceOf(_MINTER);
            }
        }
        // if `ERC1155Value == 0` use the ERC721 interface to check balances and ownership,
        // else use the ERC1155 interface to check balances
        if (_ERC1155Value == 0) {
            if (_buyer != address(0)) {
                startingBuyerTokenBalance = IERC721(_collection).balanceOf(_buyer);
            }
            if (_seller != address(0)) {
                startingSellerTokenBalance = IERC721(_collection).balanceOf(_seller);
            }
            if (address(_marketplace) != address(0)) {
                startingMarketplaceTokenBalance = IERC721(_collection).balanceOf(address(_marketplace));
            }
        } else {
            if (_buyer != address(0)) {
                startingBuyerTokenBalance = IERC1155(_collection).balanceOf(_buyer, _tokenId);
            }
            if (_seller != address(0)) {
                startingSellerTokenBalance = IERC1155(_collection).balanceOf(_seller, _tokenId);
            }
            if (address(_marketplace) != address(0)) {
                startingMarketplaceTokenBalance = IERC1155(_collection).balanceOf(address(_marketplace), _tokenId);
            }
        }
    }

    function _setFinalAccountsBalance(
        uint256 _tokenId,
        uint256 _ERC1155Value,
        address _collection,
        address _buyer,
        address _seller,
        address _commissionReceiver,
        QuoteToken _quoteToken
    )
        private
    {
        if (_quoteToken == QuoteToken.ETH) {
            finalSellerBalance = _seller.balance;
            if (_buyer != address(0)) {
                finalBuyerBalance = _buyer.balance;
                if (finalBuyerBalance == 0) {
                    revert("Final ETH buyer balance is 0");
                }
            }
            finalBuyerBalance = _buyer.balance;
            finalFeeAccountBalance = _FEES_RECIPIENT.balance;
            finalMinterBalance = _MINTER.balance;
            finalCommissionReceiverBalance = _commissionReceiver.balance;
        } else {
            finalSellerBalance = IERC20(_USDC).balanceOf(_seller);
            if (_buyer != address(0)) {
                finalBuyerBalance = IERC20(_USDC).balanceOf(_buyer);
                if (finalBuyerBalance == 0) {
                    revert("Final USDC buyer balance is 0");
                }
            }
            finalFeeAccountBalance = IERC20(_USDC).balanceOf(_FEES_RECIPIENT);
            finalMinterBalance = IERC20(_USDC).balanceOf(_MINTER);
            finalCommissionReceiverBalance = IERC20(_USDC).balanceOf(_commissionReceiver);
        }
        // if `ERC1155Value == 0` use the ERC721 interface to check balances and ownership,
        // else use the ERC1155 interface to check balances
        if (_ERC1155Value == 0) {
            if (_seller != address(0)) {
                finalSellerTokenBalance = IERC721(_collection).balanceOf(_seller);
            }

            if (_buyer != address(0)) {
                finalBuyerTokenBalance = IERC721(_collection).balanceOf(_buyer);
            }

            finalMarketplaceTokenBalance = IERC721(_collection).balanceOf(address(_marketplace));
        } else {
            if (_seller != address(0)) {
                finalSellerTokenBalance = IERC1155(_collection).balanceOf(_seller, _tokenId);
            }

            if (_buyer != address(0)) {
                finalBuyerTokenBalance = IERC1155(_collection).balanceOf(_buyer, _tokenId);
            }

            finalMarketplaceTokenBalance = IERC1155(_collection).balanceOf(address(_marketplace), _tokenId);
        }
    }

    function _raiseOrderERC1155Value(address _ERC1155) private {
        uint256 tokenId = IERC1155Supply(_ERC1155).totalSupply() - 1;
        uint256 orderId = _marketplace.ETHOrderCount();
        uint256 minterTokenBalance = IERC1155(_ERC1155).balanceOf(_MINTER, tokenId);
        uint256 marketplaceTokenBalance = IERC1155(_ERC1155).balanceOf(address(_marketplace), tokenId);
        uint256 ERC1155Value = 1;
        QuoteToken quoteToken = QuoteToken.ETH;

        require(minterTokenBalance > ERC1155Value, "minter doesn't own enough tokens");

        IERC1155(_ERC1155).safeTransferFrom(
            _MINTER,
            address(_marketplace),
            tokenId,
            ERC1155Value,
            abi.encode(orderId, _UNIT_PRICE, _ZERO_COMMISSION_BPS, _ZERO_COMMISSION_RECEIVERS, quoteToken)
        );

        OnChainMarketplace.Order memory order = _marketplace.getETHOrder(orderId);

        assertEq(IERC1155(_ERC1155).balanceOf(address(_marketplace), tokenId), order.ERC1155Value);
        assertEq(IERC1155(_ERC1155).balanceOf(_MINTER, tokenId), minterTokenBalance - ERC1155Value);

        assertEq(order.tokenId, tokenId, "incorrect tokenId");
        assertEq(order.unitPrice, _UNIT_PRICE, "incorrect _UNIT_PRICE");
        assertEq(order.ERC1155Value, marketplaceTokenBalance + ERC1155Value, "incorrect ERC1155Value");
        assertEq(order.collection, address(_ERC1155BaseClone), "incorrect collection");
        assertEq(order.from, _MINTER, "incorrect seller");
        assertEq(order.operator, _MINTER, "incorrect operator");
        assertEq(order.commissionBps.length, 0, "commissionBps should be empty");
        assertEq(order.commissionRecipient.length, 0, "commissionRecipient should be empty");
    }

    function _testUpdateOrderPrice(uint256 _orderId) internal {
        _marketplace.updateETHOrder(_orderId, 0, _UNIT_PRICE * 2);

        OnChainMarketplace.Order memory order = _marketplace.getETHOrder(_orderId);

        assertEq(order.unitPrice, _UNIT_PRICE * 2, "unitPrice should be 2 ether");
    }

    function _testDeleteOrder(address _collection, address _from, uint256 _orderId, QuoteToken _quoteToken) internal {
        OnChainMarketplace.Order memory order;

        uint256 ERC1155Value;
        uint256 tokenId;

        // fetch order before deletion
        if (_quoteToken == QuoteToken.ETH) {
            ERC1155Value = _marketplace.getETHOrder(_orderId).ERC1155Value;
            tokenId = _marketplace.getETHOrder(_orderId).tokenId;
        } else {
            ERC1155Value = _marketplace.getUSDCOrder(_orderId).ERC1155Value;
            tokenId = _marketplace.getUSDCOrder(_orderId).tokenId;
        }
        // fetch balances before deletion

        // set the starting balances of the accounts before the deletion
        _setStartingAccountsBalance(tokenId, ERC1155Value, _collection, address(0), _MINTER, address(0), _quoteToken);

        if (_quoteToken == QuoteToken.ETH) {
            vm.prank(_from);
            _marketplace.deleteETHOrder(_orderId);
        } else {
            vm.prank(_from);
            _marketplace.deleteUSDCOrder(_orderId);
        }

        _setFinalAccountsBalance(tokenId, ERC1155Value, _collection, address(0), _MINTER, address(0), _quoteToken);

        // check token balances and ownership

        // if the collection is ERC-721, set ERC1155Value should to 1
        // set ERC1155Value to 1 for ERC-721 tokens don't have an ERC1155Value and are always 1
        if (ERC1155Value == 0) ERC1155Value = 1;

        assertEq(finalSellerTokenBalance, startingSellerTokenBalance + ERC1155Value, "incorrect seller token balance");
        assertEq(
            finalMarketplaceTokenBalance,
            startingMarketplaceTokenBalance - ERC1155Value,
            "Incorrect marketplace token balance"
        );

        // fetch order after deletion

        if (_quoteToken == QuoteToken.ETH) {
            order = _marketplace.getETHOrder(_orderId);
        } else {
            order = _marketplace.getUSDCOrder(_orderId);
        }

        assertEq(order.tokenId, 0, "tokenId should be 0");
        assertEq(order.unitPrice, 0, "unitPrice should be 1 ether");
        assertEq(order.ERC1155Value, 0, "ERC1155Value should be 0");
        assertEq(order.collection, address(0), "collection should be the address(0)");
        assertEq(order.from, address(0), "from should be address(0)");
        assertEq(order.operator, address(0), "operator should be address(0)");
        assertEq(order.commissionBps.length, 0, "commissionBps should be empty");
        assertEq(order.commissionRecipient.length, 0, "commissionRecipient should be empty");
    }

    function _testDeleteOffer(address _collection, address _from, uint256 _offerId, QuoteToken _quoteToken) internal {
        OnChainMarketplace.Offer memory offer;

        uint256 ERC1155Value;
        uint256 unitPrice;
        uint256 tokenId;

        // fetch offer before deletion
        if (_quoteToken == QuoteToken.ETH) {
            offer = _marketplace.getETHOffer(_offerId);
            ERC1155Value = offer.ERC1155Value;
            unitPrice = offer.unitPrice;
            tokenId = offer.tokenId;
        } else {
            offer = _marketplace.getUSDCOffer(_offerId);
            ERC1155Value = offer.ERC1155Value;
            unitPrice = offer.unitPrice;
            tokenId = offer.tokenId;
        }
        // fetch balances before deletion

        // set the starting balances of the accounts before the deletion
        _setStartingAccountsBalance(tokenId, ERC1155Value, _collection, _from, address(0), address(0), _quoteToken);

        if (_quoteToken == QuoteToken.ETH) {
            vm.prank(_from);
            _marketplace.deleteETHOffer(_offerId);
        } else {
            vm.prank(_from);
            _marketplace.deleteUSDCOffer(_offerId);
        }

        _setFinalAccountsBalance(tokenId, ERC1155Value, _collection, _from, address(0), address(0), _quoteToken);

        // check token balances and ownership
        // fetch offer after deletion

        if (_quoteToken == QuoteToken.ETH) {
            offer = _marketplace.getETHOffer(_offerId);
        } else {
            offer = _marketplace.getUSDCOffer(_offerId);
        }

        assertEq(offer.tokenId, 0, "tokenId should be 0");
        assertEq(offer.unitPrice, 0, "unitPrice should be 1 ether");
        assertEq(offer.ERC1155Value, 0, "ERC1155Value should be 0");
        assertEq(offer.collection, address(0), "collection should be the address 0");
        assertEq(offer.from, address(0), "from should be address 0");
        // buyer should get offer amount back after canceling
        assertEq(
            finalBuyerBalance - startingBuyerBalance,
            ERC1155Value > 0 ? unitPrice * ERC1155Value : unitPrice,
            "buyer balance not correct"
        );
    }

    function _checkBalances(address _collection, address _owner) private view {
        uint256 tokenId;
        // if collection supports IERC721 then check ERC721 balances and ownership
        if (IERC165(_collection).supportsInterface(0x80ac58cd)) {
            // if collection supports `IERC721Enumerable` interface or implements (OpenZeppelin's)
            // {ERC115Supply-totalSupply} we can get the totalSupply
            // try catch is needed because the totalSupply function might not be implemented
            try IERC721Enumerable(_collection).totalSupply() returns (uint256 totalSupply) {
                require(totalSupply > 0, "totalSupply should be greater than 0");
                // 0 indexed, assuming the seller is selling the last token minted in the collection
                tokenId = totalSupply - 1;
            } catch {
                revert("collection does not implement totalSupply");
            }

            assertEq(IERC721(_collection).balanceOf(_owner), 1, "balance of minter should be 1");
            assertEq(IERC721(_collection).ownerOf(tokenId), _owner, "owner of token should be minter address");
        } else {
            try IERC1155Supply(_collection).totalSupply() returns (uint256 totalSupply) {
                require(totalSupply > 0, "totalSupply should be greater than 0");
                // 0 indexed, assuming the seller is selling the last token minted in the collection
                tokenId = totalSupply - 1;
            } catch {
                revert("collection does not implement totalSupply");
            }
            // if collection supports IERC1155 then check ERC1155 balances
            assertEq(IERC1155(_collection).balanceOf(_owner, tokenId), 10, "balance of minter should be 10");
        }
    }

    /**
     * @dev ERC-721 tokens are transferred to the buyer via `transferFrom`
     * rather than `safeTransferFrom`.
     * The caller is responsible to confirm that the recipient if a contract is
     * capable of receiving and handling ERC721 and ERC1155 tokens
     * If the minter is a smart contract, it needs to implement onERC721Received (see `ERC721-_mint`),
     * however this is not the case here.
     */
    function _transferNFT(
        address _collection,
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _ERC1155Value,
        bytes memory _data
    )
        internal
    {
        // interface ID for ERC721 == 0x80ac58cd
        if (IERC165(_collection).supportsInterface(0x80ac58cd)) {
            vm.prank(_from);
            // 0xb88d4fde is the selector for `safeTransferFrom(address,address,uint256,bytes)`
            (bool success,) = _collection.call(abi.encodeWithSelector(0xb88d4fde, _from, _to, _tokenId, _data));
            require(success);
        } else {
            vm.prank(_from);
            // 0xf242432a is the selector for `safeTransferFrom(address,address,uint256,uint256,bytes)`
            (bool success,) =
                _collection.call(abi.encodeWithSelector(0xf242432a, _from, _to, _tokenId, _ERC1155Value, _data));
            require(success);
        }
    }
}
