// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "test/utils/ERC721Validator.sol";
import "test/utils/Setup.sol";
import "src/token/ERC721/presets/ERC721LazyMint.sol";
import "src/factory/CuratedFactory.sol";

contract ERC721LazyMintTest is Setup, ERC721Validator {
    ERC721LazyMint private _ERC721LazyMintMaster;
    ERC721LazyMint private _ERC721LazyMintClone;

    address private _ERC721LazyMintAddress;

    address[] private _feesRecipients = new address[](0);
    address[] private _emptyRecipients = new address[](0);

    // Royalties and commissions

    uint96[] private _feesBps = new uint96[](0); // only for erc712 signing
    uint96[] private _emptyBps = new uint96[](0);

    /*----------------------------------------------------------*|
    |*  # SETUP                                                 *|
    |*----------------------------------------------------------*/

    function setUp() public {
        _feesBps.push(500);
        _feesRecipients.push(_FEES_RECIPIENT);

        _ERC721LazyMintMaster = new ERC721LazyMint(address(_CURATED_FACTORY));

        _CURATED_FACTORY.setMaster(address(_ERC721LazyMintMaster), true);

        _CURATED_FACTORY.grantRole(_MINTER_ROLE, _MINTER);

        /**
         * @dev deploy the ERC721LazyMintClone contract, the deployer/minter will be address(this)
         */
        _ERC721LazyMintAddress = _CURATED_FACTORY.clone(
            address(_ERC721LazyMintMaster), bytes32(0), abi.encode(_MINTER, 1000, _SYMBOL, _NAME)
        );

        _ERC721LazyMintClone = ERC721LazyMint(_ERC721LazyMintAddress);

        _ERC721LazyMintClone.grantRole(_MINTER_ROLE, _LAZY_MINTER);

        _ERC721LazyMintClone.grantRole(_MINTER_ROLE, address(this)); // needed for testing ERC1271
    }

    /*----------------------------------------------------------*|
    |*  # LAZY MINT AND LAZY BUY                                *|
    |*----------------------------------------------------------*/

    function _getDigestAndSignature(
        EncodeType.TokenVoucher memory _voucher,
        uint256 _PK
    )
        private
        view
        returns (bytes32 digest, bytes memory signature)
    {
        digest = _ERC721LazyMintClone.getTypedDataDigest(_voucher);
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(_PK, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /**
     * @dev minting new tokenId and buying it via lazyMint
     * Voucher is signed by EOA and the token is minted to EOA
     */
    function testLazyMint() public {
        _testLazyMint(
            _ERC721LazyMintAddress,
            _LAZY_MINTER,
            _COLLECTOR_PRIMARY,
            _COMMISSION_RECEIVERS,
            _COMMISSION_BPS_UINT96,
            _ROYALTY_BPS,
            _LAZY_MINTER_PK,
            1 ether,
            false
        );
    }

    /**
     * @dev buying tokenId 0 (minted via mint() during setup) from minter to collector
     * Voucher is signed by EOA and the token is safe transferred to EOA
     */
    function testLazyBuy() public {
        uint256 tokenId = _ERC721LazyMintClone.totalSupply(); // calculate tokenId before minting to use in lazybuy

        _testLazyMint(
            _ERC721LazyMintAddress,
            _LAZY_MINTER,
            _COLLECTOR_PRIMARY,
            _COMMISSION_RECEIVERS,
            _COMMISSION_BPS_UINT96,
            _ROYALTY_BPS,
            _LAZY_MINTER_PK,
            1 ether,
            false
        );

        EncodeType.TokenVoucher memory voucher = EncodeType.TokenVoucher(
            bytes32(0),
            2 ether,
            type(uint32).max, // endTime
            tokenId, // tokenid
            0, //value
            0, // salt
            address(0), // buyer
            address(0), // erc1271
            address(0), // royalty recipient
            0, // royalty numerator
            _feesBps, // set sale bps for marketplace fees
            _feesRecipients // set sale recipients for marketplace fees
        );

        (, bytes memory signature) = _getDigestAndSignature(voucher, _COLLECTOR_PRIMARY_PK);

        _testLazyBuy(
            _ERC721LazyMintAddress, _COLLECTOR_PRIMARY, _COLLECTOR_SECONDARY, _FEES_RECIPIENT, voucher, signature, false
        );
    }

    /**
     * @dev test calling voidVoucher() external function from signer, although any account with _MINTER_ROLE could call
     * it
     * if the call to lazyMint fails, the test passes, i.e. the voucher is voided
     */
    function test_RevertWhen_VoidVoucherLazyMint() public {
        _testVoidVoucher(
            _ERC721LazyMintAddress,
            _LAZY_MINTER,
            _COMMISSION_RECEIVERS,
            _COMMISSION_BPS_UINT96,
            _ROYALTY_BPS,
            _LAZY_MINTER_PK,
            1 ether
        );

        _testLazyMint(
            _ERC721LazyMintAddress,
            _LAZY_MINTER,
            _COLLECTOR_PRIMARY,
            _COMMISSION_RECEIVERS,
            _COMMISSION_BPS_UINT96,
            _ROYALTY_BPS,
            _LAZY_MINTER_PK,
            1 ether,
            true
        );
    }

    /**
     * @dev test calling voidVoucher() external function from signer, although any account with _MINTER_ROLE could call
     * it
     * if the call to lazyMint fails, the test passes, i.e. the voucher is voided
     */
    function test_RevertWhen_VoidVoucherLazyBuy() public {
        _testVoidVoucher(
            _ERC721LazyMintAddress,
            _LAZY_MINTER,
            _COMMISSION_RECEIVERS,
            _COMMISSION_BPS_UINT96,
            _ROYALTY_BPS,
            _LAZY_MINTER_PK,
            1 ether
        );
        EncodeType.TokenVoucher memory voucher = EncodeType.TokenVoucher(
            bytes32("foobar"),
            1 ether,
            type(uint32).max,
            0, // tokenid
            0, // value
            block.timestamp,
            address(0),
            address(0),
            _LAZY_MINTER,
            _ROYALTY_BPS,
            _COMMISSION_BPS_UINT96, // since lazyBuy is being used for a primary sale, set sale bps
            _COMMISSION_RECEIVERS // since lazyBuy is being used for a primary sale, set sale recipients
        );

        (, bytes memory signature) = _getDigestAndSignature(voucher, _LAZY_MINTER_PK);
        _testLazyBuy(_ERC721LazyMintAddress, _MINTER, _COLLECTOR_PRIMARY, _FEES_RECIPIENT, voucher, signature, true);
    }

    /**
     * @dev test fails because the tokenURI is required to be unique by the ERC721LazyMint implementation,
     * in order to prevent vouchers from being reused
     */
    function test_RevertWhen_LazyMintReplay() public {
        _testLazyMint(
            _ERC721LazyMintAddress,
            _LAZY_MINTER,
            _COLLECTOR_PRIMARY,
            _COMMISSION_RECEIVERS,
            _COMMISSION_BPS_UINT96,
            _ROYALTY_BPS,
            _LAZY_MINTER_PK,
            1 ether,
            false
        );

        _testLazyMint(
            _ERC721LazyMintAddress,
            _LAZY_MINTER,
            _COLLECTOR_PRIMARY,
            _COMMISSION_RECEIVERS,
            _COMMISSION_BPS_UINT96,
            _ROYALTY_BPS,
            _LAZY_MINTER_PK,
            1 ether,
            true
        );
    }

    function test_RevertWhen_LazyBuyReplay() public {
        vm.skip(true);

        EncodeType.TokenVoucher memory voucher = EncodeType.TokenVoucher(
            bytes32(0),
            2 ether,
            type(uint32).max,
            0, // tokenid
            0, // value
            block.timestamp,
            address(0),
            address(0),
            address(0),
            0,
            _feesBps, // since lazyBuy is being used for a primary sale, set sale bps
            _feesRecipients // since lazyBuy is being used for a primary sale, set sale recipients
        );

        (, bytes memory signature) = _getDigestAndSignature(voucher, _LAZY_MINTER_PK);

        _testLazyBuy(_ERC721LazyMintAddress, _MINTER, _COLLECTOR_PRIMARY, _FEES_RECIPIENT, voucher, signature, false);

        _testLazyBuy(_ERC721LazyMintAddress, _MINTER, _COLLECTOR_PRIMARY, _FEES_RECIPIENT, voucher, signature, true);
    }

    /**
     * /// @dev TODO: test lazyBuy from erc1271
     *     function testMintLazyBuyERC1271() public {
     *
     *         uint256 tokenId = _ERC721LazyMintClone.totalSupply(); // calculate tokenId before minting to use in
     * lazybuy
     *
     *         _ERC721LazyMintClone.mint(_MINTER, abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
     *
     *         EncodeType.TokenVoucher memory voucher = EncodeType.TokenVoucher(
     *             bytes32(0),
     *             2 ether,
     *             type(uint32).max, // endTime
     *             tokenId, // tokenid
     *             0, //value
     *             0, // salt
     *             address(0), // buyer
     *             _MINTER, // erc1271
     *             address(0), // royalty recipient
     *             0, // royalty numerator
     *             _feesBps, // set sale bps for marketplace fees
     *             _feesRecipients // set sale recipients for marketplace fees
     *         );
     *
     *         // (, bytes memory signature) = _getDigestAndSignature(voucher, _COLLECTOR_PRIMARY_PK);
     *         bytes memory signature; // not used if erc1271 param is set
     *
     *         _testLazyBuy(_ERC721LazyMintAddress, _MINTER, _COLLECTOR_SECONDARY, _FEES_RECIPIENT, voucher, signature);
     *     }
     */
}
