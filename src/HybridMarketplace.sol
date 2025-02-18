// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "src/OnChainMarketplace.sol";
import "src/token/common/EncodeType.sol";
import "src/token/common/EIP712.sol";
import "src/utils/cryptography/ECDSA.sol";
import "src/utils/cryptography/SignatureChecker.sol";

/**
 *
 * @title OnChainMarketplace                                            *
 *                                                                      *
 * @notice On-chain (escrowed) and off-chain (lazy) NFT marketplace,    *
 * allowing users to create orders without locking their NFTs.          *
 *                                                                      *
 * @dev inherits from OnChainMarketplace and EIP712                     *
 *                                                                      *
 * @author cosimo.demedici.eth (https://github.com/ninfa-labs/ninfa-contracts)
 *                                                                      *
 */
contract HybridMarketplace is OnChainMarketplace, EIP712 {
    /// @notice for verifying EOA signatures, i.e. recover(bytes32 _digest, bytes memory _signature)
    using ECDSA for bytes32;
    /// @notice for verifying EIP-1271 signatures, i.e. isValidSignatureNow(address _signer, bytes32 _hash, bytes memory
    /// _signature)
    using SignatureChecker for address;
    /// @notice for sending value to an address, i.e. sendValue(address _receiver, uint256 _amount)
    using Address for address;

    // variables for off-chain order matching via EIP-712 signature standard
    bytes32 private immutable _VOUCHER_TYPEHASH;

    event VoucherVoided(address, bytes32[] digests);

    /**
     * @param feeRecipient_ address (multisig) controlled by Ninfa that will receive any market fees
     */
    constructor(
        address _USDC,
        address _AggregatorV3Interface,
        address feeRecipient_,
        uint256 _salesFeeBps_
    )
        OnChainMarketplace(_USDC, _AggregatorV3Interface, feeRecipient_, _salesFeeBps_)
    {
        owner = msg.sender;

        initialize(""); // calls EIP712 constructor, i.e. inititlize()

        // The MarketplaceVoucher typehash is the hash of the MarketplaceVoucher struct in the following string
        _VOUCHER_TYPEHASH = keccak256(
            "EncodeType.MarketplaceVoucher(uint256 price,uint256 endTime,uint256 tokenId,uint256 ERC1155Value,uint256 salt,address collection,address buyer,address ERC1271Account,uint96[] commissionBps,address[] commissionReceivers)"
        );
    }

    /**
     * @param _to contains the address to which the NFT will be sent,
     * this is usually the same as msg.sender but sometimes different
     * like in the case of credit card payment providers
     */
    function lazyBuy(
        EncodeType.MarketplaceVoucher calldata _voucher,
        bytes calldata _signature,
        address _to,
        uint256 _value
    )
        external
        payable
    {
        bytes32 digest = getTypedDataDigest(_voucher);

        address signer;
        uint256 sellerAmount = _voucher.price;

        if (_voucher.ERC1271Account == address(0)) {
            signer = digest.recover(_signature);
        } else {
            signer = _voucher.ERC1271Account;
            require(signer.isValidSignatureNow(digest, _signature));
        }

        /**
         * @dev _lazyBuy outside of if statement as it contains require statements that should be executed regardless of
         * price
         */
        _lazyBuy(_voucher, digest, _to, signer, sellerAmount);

        _transferNFT(_voucher.collection, signer, _to, _voucher.tokenId, _value);

        _void[signer][digest] = true;
    }

    /**
     * @dev returns `hashStruct(s : 𝕊) = keccak256(typeHash ‖ encodeData(s))`
     * where `typeHash = keccak256(encodeType(typeOf(s)))`
     */
    function getTypedDataDigest(EncodeType.MarketplaceVoucher calldata _voucher)
        public
        view
        returns (bytes32 _digest)
    {
        _digest = _hashTypedData(
            keccak256(
                abi.encode(
                    _VOUCHER_TYPEHASH,
                    _voucher.price,
                    _voucher.endTime,
                    _voucher.tokenId,
                    _voucher.ERC1155Value,
                    _voucher.salt,
                    _voucher.collection,
                    _voucher.buyer,
                    _voucher.ERC1271Account,
                    keccak256(abi.encodePacked(_voucher.commissionBps)),
                    keccak256(abi.encodePacked(_voucher.commissionReceivers))
                )
            )
        );
    }

    /**
     * @dev required Solidity override needed for eip712 domain
     */
    function name() public pure override(EIP712) returns (string memory) {
        return "HybridMarketplace";
    }

    function _lazyBuy(
        EncodeType.MarketplaceVoucher calldata _voucher,
        bytes32 _digest,
        address _to,
        address _signer,
        uint256 _sellerAmount
    )
        private
    {
        require(
            // allows to set an expiration date for the voucher
            _voucher.endTime > block.timestamp
            // prevents invalid signatures to be used
            && !_void[_signer][_digest]
            // if the voucher buyer is not empty, it must be the same as the _to address, or else the voucher is
            // not valid because it was not minted for the _to address
            && (_voucher.buyer == address(0) || _voucher.buyer == _to)
        );

        if (_voucher.price > 0) {
            /**
             * @dev it is not necessary to check if bps and receivers arrays are the same length, since the voucher is
             * signed by the artist.
             * if they were different lengths by mistake, the tx would either revert with index out of bounds,
             * or if `(_voucher.commissionBps.length < _voucher.commissionReceivers.length)`,
             * the loop would not revert but any additional address in _voucher.commissionReceivers would be ignored.
             */
            uint256 i = _voucher.commissionReceivers.length;
            if (i > 0) {
                uint256 commissionAmount;
                address commissionReceiver;
                do {
                    --i;
                    commissionAmount = (msg.value * _voucher.commissionBps[i]) / 10_000;
                    commissionReceiver = _voucher.commissionReceivers[i];
                    // subtract from seller amount before external call to prevent reentrancy
                    _sellerAmount -= commissionAmount;
                    commissionReceiver.sendValue(commissionAmount);
                } while (i > 0);
            }

            uint256 feeAmount = _salesFeeBps * msg.value / 10_000;
            _salesFeeRecipient.sendValue(feeAmount);
            _sellerAmount -= feeAmount;

            _signer.sendValue(_sellerAmount);
        }
    }
}
