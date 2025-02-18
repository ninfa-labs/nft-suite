// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "test/utils/ERC721Validator.sol";
import "test/utils/Setup.sol";
import "src/token/ERC721/presets/ERC721Base.sol";
import "src/factory/CuratedFactory.sol";

contract ERC721BaseTest is Setup, ERC721Validator {
    ERC721Base private _ERC721BaseClone;

    address private _ERC721BaseCloneAddress;
    address[] private _emptyRecipients = new address[](0);

    uint96[] private _emptyBps = new uint96[](0);

    /*----------------------------------------------------------*|
    |*  # SETUP                                                 *|
    |*----------------------------------------------------------*/

    function setUp() public {
        /**
         * @dev deploy the ERC721LazyMintClone contract, the deployer/minter will be address(this)
         */
        _ERC721BaseCloneAddress = _CURATED_FACTORY.clone(
            address(_ERC721_BASE_MASTER), bytes32(0x0), abi.encode(_MINTER, 1000, _SYMBOL, _NAME)
        );

        _ERC721BaseClone = ERC721Base(_ERC721BaseCloneAddress);

        _ERC721BaseClone.mint(address(this), abi.encode(_TOKEN_URI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
    }

    // function _getDigestAndSignature(
    //     EncodeType.Voucher memory _voucher,
    //     uint256 _PK
    // )
    //     private
    //     view
    //     returns (bytes32 digest, bytes memory signature)
    // {
    //     digest = _ERC721BaseClone.getTypedDataDigest(_voucher);
    //     uint8 v;
    //     bytes32 r;
    //     bytes32 s;
    //     (v, r, s) = vm.sign(_PK, digest);
    //     signature = abi.encodePacked(r, s, v);
    // }

    /*----------------------------------------------------------*|
    |*  # ERC-1271                                              *|
    |*----------------------------------------------------------*/

    /*----------------------------------------------------------*|
    |*  # EXTRA TESTS                                           *|
    |*----------------------------------------------------------*/

    function testSupportsInterface() public view {
        _testSupportsInterface(address(_ERC721BaseClone));
    }

    function testERC721Metadata_URI() public view {
        _testERC721Metadata_URI(address(_ERC721BaseClone));
    }

    function testERC721Enumerable() public view {
        _testERC721Enumerable(address(_ERC721BaseClone));
    }

    /*----------------------------------------------------------*|
    |*  # SOLMATE TESTS                                         *|
    |*----------------------------------------------------------*/

    function invariant_ERC721Metadata() public view {
        _invariant_ERC721Metadata(address(_ERC721BaseClone), _NAME, _SYMBOL);
    }

    function testMint() public view {
        _testMint(address(_ERC721BaseClone));
    }

    function testBurn() public {
        _testBurn(address(_ERC721BaseClone));
    }

    function testApprove() public {
        _testApprove(address(_ERC721BaseClone));
    }

    function testApproveBurn() public {
        _testApproveBurn(address(_ERC721BaseClone));
    }

    function testApproveAll() public {
        _testApproveAll(address(_ERC721BaseClone));
    }

    function testTransferFrom() public {
        _testTransferFrom(address(_ERC721BaseClone));
    }

    function testTransferFromSelf() public {
        _testTransferFromSelf(address(_ERC721BaseClone));
    }

    function testTransferFromApproveAll() public {
        _testTransferFromApproveAll(address(_ERC721BaseClone));
    }

    function testSafeTransferFromToEOA() public {
        _testSafeTransferFromToEOA(address(_ERC721BaseClone));
    }

    function testSafeTransferFromToERC721Recipient() public {
        _testSafeTransferFromToERC721Recipient(address(_ERC721BaseClone));
    }

    function testSafeTransferFromToERC721RecipientWithData() public {
        _testSafeTransferFromToERC721RecipientWithData(address(_ERC721BaseClone));
    }

    function testSafeMintToERC721Recipient() public {
        _testSafeMintToERC721Recipient(address(_ERC721BaseClone), _MINTER, _ROYALTY_BPS);
    }

    function testSafeMintToERC721RecipientWithData() public {
        _testSafeMintToERC721RecipientWithData(address(_ERC721BaseClone), _MINTER, _ROYALTY_BPS);
    }

    function test_RevertWhen_MintToZero() public {
        _testFailMintToZero(address(_ERC721BaseClone), _MINTER, _ROYALTY_BPS);
    }

    function test_RevertWhen_DoubleMint() public {
        // as for `_ERC721BaseClone` nothing prevents from minting using the same ipfs hash,
        // in fact sometimes 721 contracts are used to mint editions with the same hash.
        vm.skip(true);
        _testFailDoubleMint(address(_ERC721BaseClone), _MINTER, _ROYALTY_BPS);
    }

    function test_RevertWhen_BurnUnminted() public {
        _testFailBurnUnminted(address(_ERC721BaseClone));
    }

    function test_RevertWhen_DoubleBurn() public {
        _testFailDoubleBurn(address(_ERC721BaseClone));
    }

    function test_RevertWhen_ApproveUnMinted() public {
        _testFailApproveUnMinted(address(_ERC721BaseClone));
    }

    function test_RevertWhen_ApproveUnAuthorized() public {
        _testFailApproveUnAuthorized(address(_ERC721BaseClone));
    }

    function test_RevertWhen_TransferFromUnOwned() public {
        _testFailTransferFromUnOwned(address(_ERC721BaseClone));
    }

    function test_RevertWhen_TransferFromWrongFrom() public {
        _testFailTransferFromWrongFrom(address(_ERC721BaseClone));
    }

    function test_RevertWhen_TransferFromToZero() public {
        _testFailTransferFromToZero(address(_ERC721BaseClone));
    }

    function test_RevertWhen_TransferFromNotOwner() public {
        _testFailTransferFromNotOwner(address(_ERC721BaseClone));
    }

    function test_RevertWhen_SafeTransferFromToNonERC721Recipient() public {
        _testFailSafeTransferFromToNonERC721Recipient(address(_ERC721BaseClone));
    }

    function test_RevertWhen_SafeTransferFromToNonERC721RecipientWithData() public {
        _testFailSafeTransferFromToNonERC721RecipientWithData(address(_ERC721BaseClone));
    }

    function test_RevertWhen_SafeTransferFromToRevertingERC721Recipient() public {
        _testFailSafeTransferFromToRevertingERC721Recipient(address(_ERC721BaseClone));
    }

    function test_RevertWhen_SafeTransferFromToRevertingERC721RecipientWithData() public {
        _testFailSafeTransferFromToRevertingERC721RecipientWithData(address(_ERC721BaseClone));
    }

    function test_RevertWhen_SafeTransferFromToERC721RecipientWithWrongReturnData() public {
        _testFailSafeTransferFromToERC721RecipientWithWrongReturnData(address(_ERC721BaseClone));
    }

    function test_RevertWhen_SafeTransferFromToERC721RecipientWithWrongReturnDataWithData() public {
        _testFailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData(address(_ERC721BaseClone));
    }

    function test_RevertWhen_SafeMintToNonERC721Recipient() public {
        _testFailSafeMintToNonERC721Recipient(address(_ERC721BaseClone), _MINTER, _ROYALTY_BPS);
    }

    function test_RevertWhen_SafeMintToNonERC721RecipientWithData() public {
        _testFailSafeMintToNonERC721RecipientWithData(address(_ERC721BaseClone), _MINTER, _ROYALTY_BPS);
    }

    function test_RevertWhen_SafeMintToRevertingERC721Recipient() public {
        _testFailSafeMintToRevertingERC721Recipient(address(_ERC721BaseClone), _MINTER, _ROYALTY_BPS);
    }

    function test_RevertWhen_SafeMintToRevertingERC721RecipientWithData() public {
        _testFailSafeMintToRevertingERC721RecipientWithData(address(_ERC721BaseClone), _MINTER, _ROYALTY_BPS);
    }

    function test_RevertWhen_SafeMintToERC721RecipientWithWrongReturnData() public {
        _testFailSafeMintToERC721RecipientWithWrongReturnData(address(_ERC721BaseClone), _MINTER, _ROYALTY_BPS);
    }

    function test_RevertWhen_SafeMintToERC721RecipientWithWrongReturnDataWithData() public {
        _testFailSafeMintToERC721RecipientWithWrongReturnDataWithData(address(_ERC721BaseClone), _MINTER, _ROYALTY_BPS);
    }

    function test_RevertWhen_BalanceOfZeroAddress() public {
        _testFailBalanceOfZeroAddress(address(_ERC721BaseClone));
    }

    function test_RevertWhen_OwnerOfUnminted() public {
        _testFailOwnerOfUnminted(address(_ERC721BaseClone));
    }
}
