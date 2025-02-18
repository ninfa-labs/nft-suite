// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./ERC1155Base.sol";
import "src/utils/Address.sol";
import "src/utils/cryptography/ECDSA.sol";
import "src/utils/cryptography/SignatureChecker.sol";
import "../../common/EIP712.sol";
import "../../common/EncodeType.sol";

/**
 *
 * @title ERC1155LazyMint                                      *
 *                                                             *
 * @notice Self-sovereign ERC-1155 minter & lazy minter preset *
 *                                                           *
 * @author cosimo.demedici.eth                               *
 *                                                           *
 */
contract ERC1155LazyMint is ERC1155Base, EIP712 {
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
     * @notice Keeps track of the sales counter for each byte signature.
     */
    mapping(bytes => uint256) private _salesCounter;
    /**
     * @notice Keeps track of the minted URIs. Each URI is mapped to a boolean indicating whether it has been minted.
     */
    mapping(bytes32 => bool) private _mintedURI;

    /*----------------------------------------------------------*|
    |*  # MINTING                                               *|
    |*----------------------------------------------------------*/

    /**
     * @dev Mints new tokens or increases the supply of existing ones.
     * @param _voucher The voucher struct containing the tokenId metadata.
     * @param _value The amount/supply of `tokenId` to be minted. A max supply limit must be handled at the contract
     * level.
     * @param _to The buyer's address. Needed if using an external payment gateway, so that the minted tokenId value is
     * sent to this address instead of `msg.sender`.
     * @param _data The data bytes are passed to `onErc1155Received` function if the `_to` address is a contract, for
     * example a marketplace.
     * @param _tokenId The tokenId to mint.
     * @param _signature The signature bytes.
     */
    function lazyMint(
        EncodeType.TokenVoucher calldata _voucher,
        bytes calldata _signature,
        bytes calldata _data,
        address _to,
        uint256 _value,
        uint256 _tokenId
    )
        external
        payable
    {
        uint256 sellerAmount = _voucher.price * _value;
        require(sellerAmount == msg.value);

        bytes32 digest = getTypedDataDigest(_voucher);

        address signer;
        /// @dev since signer is the minter/artist as enforced by roles, and since the minter will not sell their own
        /// tokens via lazyBuy,
        /// it is not possible to replay the signature, i.e. to use a signed voucher meant for lazyBuy in order to mint.
        if (_voucher.ERC1271Account == address(0)) {
            signer = digest.recover(_signature);
            require(hasRole(MINTER_ROLE, signer));
        } else {
            signer = _voucher.ERC1271Account;
            require(hasRole(MINTER_ROLE, signer) && signer.isValidSignatureNow(digest, _signature));
        }

        /**
         * @dev ensuring that signer has MINTER_ROLE and that tokenIds are incremented sequentially
         * @dev since signer is artist as enforced by roles, and since the minter will not sell their own tokens via
         * lazyBuy,
         * it is not possible to replay the signature, i.e. to use a signed voucher meant for lazyBuy
         */
        if (exists(_tokenId)) {
            require(_voucher.tokenURI == _tokenURIs[_tokenId]);
            unchecked {
                _totalSupply[_tokenId] += _value;
            }
            ERC1155._mint(signer, _tokenId, _value, _data);
        } else {
            if (_mintedURI[_voucher.tokenURI]) revert();
            _mintedURI[_voucher.tokenURI] = true;

            _tokenId = totalSupply();

            /**
             * @dev _voucher.tokenURI is prepended to the _data bytes, since it is bytes32 id doesn't need to be padded
             * hence encodePacked is used.
             * @dev since the new token is being minted to the signer, there is no risk of reentrancy due to untrusted
             * external contracts.
             *
             */
            _mint(
                _to,
                _tokenId,
                _value,
                abi.encode(_voucher.tokenURI, abi.encode(_voucher.royaltyRecipient, _voucher.royaltyBps, _data))
            );
        }
        /// @dev placing this require statement after _mint saves gas as _value is added to the totalSupply
        /// @dev it is not a reentrancy issue because the current total supply is checked which is updated for each
        /// mint.
        require(totalSupply(_tokenId) <= _voucher.ERC1155Value);

        _handlePayment(_voucher, digest, _to, signer, sellerAmount);
    }

    /**
     * @dev Buys tokens lazily.
     * @param _voucher The voucher struct containing the tokenId metadata.
     * @param _signature The signature bytes.
     * @param _data The data bytes.
     * @param _to The buyer's address.
     * @param _value The amount of tokens to buy.
     */
    function lazyBuy(
        EncodeType.TokenVoucher calldata _voucher,
        bytes calldata _signature,
        bytes calldata _data,
        address _to,
        uint256 _value
    )
        external
        payable
    {
        uint256 sellerAmount = _voucher.price;

        bytes32 digest = getTypedDataDigest(_voucher);
        address signer;
        unchecked {
            _salesCounter[_signature] += _value;
        }
        require(_voucher.ERC1155Value <= _salesCounter[_signature]);

        if (_voucher.ERC1271Account == address(0)) {
            signer = digest.recover(_signature);
        } else {
            signer = _voucher.ERC1271Account;
            require(signer.isValidSignatureNow(digest, _signature));
        }

        if (sellerAmount > 0) {
            sellerAmount *= _value;
            // required check for allowing to create free nft vouchers or airdrops
            require(sellerAmount == msg.value);

            (address royaltyRecipient, uint256 royaltyAmount) = royaltyInfo(_voucher.tokenId, sellerAmount);

            sellerAmount -= royaltyAmount;
            royaltyRecipient.sendValue(royaltyAmount);
        }

        _handlePayment(_voucher, digest, _to, signer, sellerAmount);

        _safeTransferFrom(signer, _to, _voucher.tokenId, _value, _data);
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

    /*----------------------------------------------------------*|
    |*  # SETUP                                                 *|
    |*----------------------------------------------------------*/

    /**
     * @dev Initializes the contract.
     * @param _data The initialization data.
     */
    function initialize(bytes memory _data) public override(ERC1155Base, EIP712) {
        // initialize Base contract before EIP712 because
        // "name" metadata MUST to be set prior calling EIP712's initialize()
        ERC1155Base.initialize(_data);
        EIP712.initialize(_data);
    }

    /**
     * @notice Creates `DOMAIN_SEPARATOR` and `VOUCHER_TYPEHASH` and assigns address to `FACTORY`.
     * @param factory_ The factory address is used for access control on self-sovereign ERC-1155 collection rather than
     * using the `initializer` modifier. This is cheaper because the clones won't need to write `initialized = true;` to
     * storage each time they are initialized. Instead `FACTORY` is only assigned once in the `constructor` of the
     * master copy therefore it can be read by all clones.
     */
    constructor(address factory_) ERC1155Base(factory_) { }

    /*----------------------------------------------------------*|
    |*  # OVERRIDES                                             *|
    |*----------------------------------------------------------*/

    /**
     * @dev Overrides the name function.
     * @return The name of the token.
     */
    function name() public view override(EIP712, Metadata) returns (string memory) {
        return super.name();
    }
}
