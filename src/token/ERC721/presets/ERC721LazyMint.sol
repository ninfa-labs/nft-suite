// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./ERC721Base.sol";
import "src/utils/Address.sol";
import "src/utils/cryptography/ECDSA.sol";
import "src/utils/cryptography/SignatureChecker.sol";
import "../../common/EIP712.sol";
import "../../common/EncodeType.sol";

/**
 *
 * @title ERC721LazyMint                                     *
 *                                                           *
 * @notice Self-sovereign ERC-721 minter preset              *
 *                                                           *
 * @dev {ERC721} token                                       *
 *                                                           *
 * @author cosimo.demedici.eth                               *
 *                                                           *
 */
contract ERC721LazyMint is ERC721Base, EIP712 {
    /**
     * @notice for verifying EOA signatures, i.e. recover(bytes32 _digest, bytes memory _signature)
     */
    using ECDSA for bytes32;
    /**
     * @notice for sending value to an address, i.e. sendValue(address _receiver, uint256 _amount)
     */
    using Address for address;
    /**
     * @notice for verifying EIP-1271 signatures, i.e. isValidSignatureNow(address _signer, bytes32 _hash, bytes memory
     * _signature)
     */
    using SignatureChecker for address;

    /// @dev `keccak256("EncodeType.TokenVoucher(bytes32 tokenURI,uint256 price,uint256 endTime,uint256 tokenId,uint256
    /// ERC1155Value,uint256 salt,address buyer,address ERC1271Account,address royaltyRecipient,uint96
    /// royaltyBps,uint96[] commissionBps,address[] commissionRecipients)");`
    bytes32 private constant _VOUCHER_TYPEHASH = 0x42496782cf3e7555d82117811afa0bdaee1320050e381001920fcb0da51bd83e;

    /**
     * @notice Constructs the contract and sets the factory address.
     * @param factory_ The address of the factory contract.
     */
    constructor(address factory_) ERC721Base(factory_) { }

    /**
     * @notice Mints a new token.
     * @dev Ensures that signer has MINTER_ROLE and that tokenIds are incremented sequentially.
     * @param _voucher voucher struct containing the tokenId metadata.
     * @param _signature The signature of the voucher.
     * @param _to buyer, needed if using a external payment gateway, so that the
     * minted tokenId value is sent to the
     * address specified insead of `msg.sender`
     * @param _data _data bytes are passed to `onErc1155Received` function if the
     * `_to` address is a contract, for
     * example a marketplace.
     *      `onErc1155Received` is not being called on the minter's address when
     * a new tokenId is minted however, even
     * if it was contract.
     */
    function lazyMint(
        EncodeType.TokenVoucher calldata _voucher,
        bytes calldata _signature,
        bytes calldata _data,
        address _to
    )
        external
        payable
    {
        require(_voucher.price == msg.value);
        /**
         * @dev ensuring that signer has MINTER_ROLE and that tokenIds are incremented sequentially
         * @dev trying to replay the same voucher and signature will revert as the tokenURI will be the same,
         * i.e. no need to void vouchers
         */
        uint256 tokenId = _owners.length;
        bytes32 digest = getTypedDataDigest(_voucher);
        address signer;

        if (_voucher.ERC1271Account == ZERO_ADDRESS) {
            signer = digest.recover(_signature);
        } else {
            signer = _voucher.ERC1271Account;
            require(signer.isValidSignatureNow(digest, _signature));
        }
        // check the voucher is not voided even if the token has not been minted yet as the artist could have voided it
        // independently
        require(hasRole(MINTER_ROLE, signer) && !_void[signer][digest]);

        _handlePayment(_voucher, digest, _to, signer, msg.value);

        _void[signer][digest] = true; // void the voucher before minting to prevent replay attacks

        /**
         * @dev _voucher.tokenURI is prepended to the _data bytes, since it is bytes32 id doesn't need to be padded
         * hence encodePacked is used.
         * @dev since the new token is being minted to the signer, there is no risk of reentrancy due to untrusted
         * external contracts.
         *
         */
        _mint(
            signer,
            tokenId,
            abi.encode(_voucher.tokenURI, abi.encode(_voucher.royaltyRecipient, _voucher.royaltyBps, ""))
        );

        _safeTransfer(signer, _to, tokenId, _data);
    }

    /**
     * @notice Buys a token.
     * @dev Handles payment and transfers the token to the buyer.
     * @param _voucher The voucher struct containing the tokenId metadata.
     * @param _signature The signature of the voucher.
     * @param _data The data bytes are passed to `onErc1155Received` function if the `_to` address is a contract.
     * @param _to The address to receive the bought token.
     */
    function lazyBuy(
        EncodeType.TokenVoucher calldata _voucher,
        bytes calldata _signature,
        bytes calldata _data,
        address _to
    )
        external
        payable
    {
        bytes32 digest = getTypedDataDigest(_voucher);
        address signer;
        uint256 sellerAmount = _voucher.price;

        if (_voucher.ERC1271Account == ZERO_ADDRESS) {
            signer = digest.recover(_signature);
        } else {
            signer = _voucher.ERC1271Account;
            require(signer.isValidSignatureNow(digest, _signature));
        }
        require(!_void[signer][digest]);

        if (sellerAmount > 0) {
            // required check for allowing to create free nft vouchers or airdrops
            require(sellerAmount == msg.value);

            (address royaltyRecipient, uint256 royaltyAmount) = royaltyInfo(_voucher.tokenId, sellerAmount);

            sellerAmount -= royaltyAmount;
            royaltyRecipient.sendValue(royaltyAmount);
        }
        /**
         * @dev _handlePayment outside of if statement as it contains require statements that should be executed
         * regardless
         * of
         * price. voucher.price is checked again inside _handlePayment
         */
        _handlePayment(_voucher, digest, _to, signer, sellerAmount);

        _void[signer][digest] = true;

        _safeTransfer(signer, _to, _voucher.tokenId, _data);
    }

    /// @dev lazyMint allows the owner of the voucher to mint or sell a token,
    /// the derived contract implements the logic for either minting or transfering a token after `_handlePayment` is
    /// called,
    /// and any additional logic needed for the specific use case such as payments, royalties, etc.
    function _handlePayment(
        EncodeType.TokenVoucher calldata _voucher,
        bytes32 _digest,
        address _to,
        address _signer,
        uint256 _sellerAmount
    )
        internal
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
             * @dev it is not necessary to check if bps and recipients arrays are the same length, since the voucher is
             * signed by the artist.
             * if they were different lengths by mistake, the tx would either revert with index out of bounds,
             * or if `(_voucher.commissionBps.length < _voucher.commissionRecipients.length)`,
             * the loop would not revert but any additional address in _voucher.commissionRecipients would be ignored.
             */
            uint256 i = _voucher.commissionRecipients.length;
            if (i > 0) {
                uint256 commissionAmount;
                do {
                    --i;
                    commissionAmount = (msg.value * _voucher.commissionBps[i]) / 10_000;
                    _sellerAmount -= commissionAmount;
                    _voucher.commissionRecipients[i].sendValue(commissionAmount);
                } while (i > 0);
            }

            _signer.sendValue(_sellerAmount);
        }
    }

    /// @dev returns `hashStruct(s : 𝕊) = keccak256(typeHash ‖ encodeData(s)) where typeHash =
    /// keccak256(encodeType(typeOf(s)))`
    function getTypedDataDigest(EncodeType.TokenVoucher calldata _voucher) public view returns (bytes32 _digest) {
        _digest = _hashTypedData(
            keccak256(
                abi.encode(
                    _VOUCHER_TYPEHASH,
                    _voucher.tokenURI,
                    _voucher.price,
                    _voucher.endTime,
                    _voucher.tokenId,
                    _voucher.ERC1155Value,
                    _voucher.salt,
                    _voucher.buyer,
                    _voucher.ERC1271Account,
                    _voucher.royaltyRecipient,
                    _voucher.royaltyBps,
                    keccak256(abi.encodePacked(_voucher.commissionBps)),
                    keccak256(abi.encodePacked(_voucher.commissionRecipients))
                )
            )
        );
    }

    /**
     * @notice Initializes the contract, setting the initial state and granting roles.
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `CURATOR_ROLE` and `MINTER_ROLE` to the account that deploys the contract.
     * @param _data The initialization data. It MUST be encoded in the following way: `(symbol, deployer,
     * defaultRoyaltyBps, name) = abi.decode(_data, (string, address, uint96, string));`. The string `name` is passed to
     * the overridden initialize function as data bytes.
     */
    function initialize(bytes memory _data) public override(ERC721Base, EIP712) {
        ERC721Base.initialize(_data);
        // initialize Base contract before EIP712 because
        // "name" metadata MUST to be set prior calling EIP712's initialize()
        EIP712.initialize("");
    }

    /**
     * @dev required solidity override for EIP712
     * @return The name of the token.
     */
    function name() public view override(EIP712, Metadata) returns (string memory) {
        return super.name();
    }
}
