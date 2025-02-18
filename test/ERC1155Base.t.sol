// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "test/utils/ERC1155Validator.sol";
import "test/utils/Setup.sol";
import "src/token/ERC1155/presets/ERC1155Base.sol";
import "src/token/ERC1155/presets/ERC1155LazyMint.sol";
import "src/token/ERC1155/presets/ERC1155OpenEdition.sol";

contract ERC1155BaseTest is Setup, ERC1155Validator {
    // define contract instances

    ERC1155Base private _ERC1155BaseClone;
    ERC1155LazyMint private _ERC1155LazyMintClone;
    ERC1155OpenEdition private _ERC1155OpenEditionClone;

    // utility variables

    address private _ERC1155BaseCloneAddress;
    address private _ERC1155LazyMintCloneAddress;
    address private _ERC1155OpenEditionCloneAddress;

    function ERC1155Value() internal view override(ERC1155Validator) returns (uint256) {
        return _ERC1155_VALUE;
    }

    function setUp() public {
        // deploy clones

        bytes32 salt; // 0x0
        bytes memory data = abi.encode(_MINTER, 1000, _SYMBOL, _NAME);

        _ERC1155BaseCloneAddress = _CURATED_FACTORY.clone(address(_ERC1155_BASE_MASTER), salt, data);
        _ERC1155LazyMintCloneAddress = _CURATED_FACTORY.clone(address(_ERC1155_SOVEREIGN_MASTER), salt, data);
        _ERC1155OpenEditionCloneAddress = _CURATED_FACTORY.clone(address(_ERC1155_OPEN_EDITION_MASTER), salt, data);

        // instanciate clones

        _ERC1155BaseClone = ERC1155Base(_ERC1155BaseCloneAddress);
        _ERC1155LazyMintClone = ERC1155LazyMint(_ERC1155LazyMintCloneAddress);
        _ERC1155OpenEditionClone = ERC1155OpenEdition(_ERC1155OpenEditionCloneAddress);

        // assign MINER_ROLE to _LAZY_MINTER
        _ERC1155LazyMintClone.grantRole(_MINTER_ROLE, _LAZY_MINTER);

        // mint tokenId 0 to address(this)

        bytes32 tokenURI = keccak256("FOOBAR"); // random tokenURI, must not be 0x0 or uri() will fail

        _ERC1155BaseClone.mint(_MINTER, 1, abi.encode(tokenURI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        _ERC1155LazyMintClone.mint(_MINTER, 1, abi.encode(tokenURI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
        _ERC1155OpenEditionClone.mint(_MINTER, 1, abi.encode(tokenURI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
    }

    /*----------------------------------------------------------*|
    |*  # CUSTOM TESTS                                          *|
    |*----------------------------------------------------------*/

    function testSupportsInterface() public view {
        _testSupportsInterface(_ERC1155BaseCloneAddress);
        _testSupportsInterface(_ERC1155OpenEditionCloneAddress);
        _testSupportsInterface(_ERC1155LazyMintCloneAddress);
    }

    function testERC1155Metadata() public view {
        _testERC1155Metadata(_ERC1155BaseCloneAddress);
        _testERC1155Metadata(_ERC1155OpenEditionCloneAddress);
        _testERC1155Metadata(_ERC1155LazyMintCloneAddress);
    }

    function testERC1155Enumerable() public view {
        _testERC1155Enumerable(_ERC1155BaseCloneAddress);
        _testERC1155Enumerable(_ERC1155OpenEditionCloneAddress);
        _testERC1155Enumerable(_ERC1155LazyMintCloneAddress);
    }

    /*----------------------------------------------------------*|
    |*  # SOLMATE TESTS                                         *|
    |*----------------------------------------------------------*/

    function invariant_ERC1155Metadata() public view {
        _invariantERC1155Metadata(_ERC1155BaseCloneAddress, _NAME, _SYMBOL);
        _invariantERC1155Metadata(_ERC1155OpenEditionCloneAddress, _NAME, _SYMBOL);
    }

    function testMintToEOA() public view {
        _testMintToEOA(_ERC1155BaseCloneAddress);
        _testMintToEOA(_ERC1155OpenEditionCloneAddress);
        _testMintToEOA(_ERC1155LazyMintCloneAddress);
    }

    function testMintToERC1155Recipient() public {
        _testMintToERC1155Recipient(_ERC1155BaseCloneAddress, _ROYALTY_BPS, _MINTER);
        _testMintToERC1155Recipient(_ERC1155OpenEditionCloneAddress, _ROYALTY_BPS, _MINTER);
        _testMintToERC1155Recipient(_ERC1155LazyMintCloneAddress, _ROYALTY_BPS, _MINTER);
    }

    /// @dev batch operations were removed from Ninfa editions

    // function testMintBatchToEOA() public { }

    // function testMintBatchToERC1155Recipient() public { }

    function testBurn() public {
        _testBurn(_ERC1155BaseCloneAddress);
        _testBurn(_ERC1155OpenEditionCloneAddress);
        _testBurn(_ERC1155LazyMintCloneAddress);
    }

    // function testBatchBurn() public {
    // _testBatchBurn(_ERC1155BaseCloneAddress);
    // }

    function testApproveAll() public {
        _testApproveAll(_ERC1155BaseCloneAddress);
        _testApproveAll(_ERC1155OpenEditionCloneAddress);
        _testApproveAll(_ERC1155LazyMintCloneAddress);
    }

    function testSafeTransferFromToEOA() public {
        _testSafeTransferFromToEOA(_ERC1155BaseCloneAddress);
        _testSafeTransferFromToEOA(_ERC1155OpenEditionCloneAddress);
        _testSafeTransferFromToEOA(_ERC1155LazyMintCloneAddress);
    }

    function testSafeTransferFromToERC1155Recipient() public {
        _testSafeTransferFromToERC1155Recipient(_ERC1155BaseCloneAddress);
        _testSafeTransferFromToERC1155Recipient(_ERC1155OpenEditionCloneAddress);
        _testSafeTransferFromToERC1155Recipient(_ERC1155LazyMintCloneAddress);
    }

    function testSafeTransferFromSelf() public {
        _testSafeTransferFromSelf(_ERC1155BaseCloneAddress);
        _testSafeTransferFromSelf(_ERC1155OpenEditionCloneAddress);
        _testSafeTransferFromSelf(_ERC1155LazyMintCloneAddress);
    }

    function testSafeBatchTransferFromToEOA() public {
        _testSafeBatchTransferFromToEOA(_ERC1155BaseCloneAddress);
        _testSafeBatchTransferFromToEOA(_ERC1155OpenEditionCloneAddress);
        _testSafeBatchTransferFromToEOA(_ERC1155LazyMintCloneAddress);
    }

    function testSafeBatchTransferFromToERC1155Recipient() public {
        _testSafeBatchTransferFromToERC1155Recipient(_ERC1155BaseCloneAddress);
        _testSafeBatchTransferFromToERC1155Recipient(_ERC1155OpenEditionCloneAddress);
        _testSafeBatchTransferFromToERC1155Recipient(_ERC1155LazyMintCloneAddress);
    }

    function testBatchBalanceOf() public {
        _testBatchBalanceOf(_ERC1155BaseCloneAddress);
        _testBatchBalanceOf(_ERC1155OpenEditionCloneAddress);
        _testBatchBalanceOf(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_MintToZero() public {
        _testFailMintToZero(_ERC1155BaseCloneAddress);
        _testFailMintToZero(_ERC1155OpenEditionCloneAddress);
        _testFailMintToZero(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_MintToNonERC1155Recipient() public {
        _testFailMintToNonERC1155Recipient(_ERC1155BaseCloneAddress);
        _testFailMintToNonERC1155Recipient(_ERC1155OpenEditionCloneAddress);
        _testFailMintToNonERC1155Recipient(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_MintToRevertingERC1155Recipient() public {
        _testFailMintToRevertingERC1155Recipient(_ERC1155BaseCloneAddress);
        _testFailMintToRevertingERC1155Recipient(_ERC1155OpenEditionCloneAddress);
        _testFailMintToRevertingERC1155Recipient(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_MintToWrongReturnDataERC1155Recipient() public {
        _testFailMintToWrongReturnDataERC1155Recipient(_ERC1155BaseCloneAddress);
        _testFailMintToWrongReturnDataERC1155Recipient(_ERC1155OpenEditionCloneAddress);
        _testFailMintToWrongReturnDataERC1155Recipient(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeTransferFromInsufficientBalance() public {
        _testFailSafeTransferFromInsufficientBalance(_ERC1155BaseCloneAddress);
        _testFailSafeTransferFromInsufficientBalance(_ERC1155OpenEditionCloneAddress);
        _testFailSafeTransferFromInsufficientBalance(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeTransferFromSelfInsufficientBalance() public {
        _testFailSafeTransferFromSelfInsufficientBalance(_ERC1155BaseCloneAddress);
        _testFailSafeTransferFromSelfInsufficientBalance(_ERC1155OpenEditionCloneAddress);
        _testFailSafeTransferFromSelfInsufficientBalance(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeTransferFromToZero() public {
        _testFailSafeTransferFromToZero(_ERC1155BaseCloneAddress);
        _testFailSafeTransferFromToZero(_ERC1155OpenEditionCloneAddress);
        _testFailSafeTransferFromToZero(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeTransferFromToNonERC1155Recipient() public {
        _testFailSafeTransferFromToNonERC1155Recipient(_ERC1155BaseCloneAddress);
        _testFailSafeTransferFromToNonERC1155Recipient(_ERC1155OpenEditionCloneAddress);
        _testFailSafeTransferFromToNonERC1155Recipient(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeTransferFromToRevertingERC1155Recipient() public {
        _testFailSafeTransferFromToRevertingERC1155Recipient(_ERC1155BaseCloneAddress);
        _testFailSafeTransferFromToRevertingERC1155Recipient(_ERC1155OpenEditionCloneAddress);
        _testFailSafeTransferFromToRevertingERC1155Recipient(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeTransferFromToWrongReturnDataERC1155Recipient() public {
        _testFailSafeTransferFromToWrongReturnDataERC1155Recipient(_ERC1155BaseCloneAddress);
        _testFailSafeTransferFromToWrongReturnDataERC1155Recipient(_ERC1155OpenEditionCloneAddress);
        _testFailSafeTransferFromToWrongReturnDataERC1155Recipient(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeBatchTransferInsufficientBalance() public {
        _testFailSafeBatchTransferInsufficientBalance(_ERC1155BaseCloneAddress);
        _testFailSafeBatchTransferInsufficientBalance(_ERC1155OpenEditionCloneAddress);
        _testFailSafeBatchTransferInsufficientBalance(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeBatchTransferFromToZero() public {
        _testFailSafeBatchTransferFromToZero(_ERC1155BaseCloneAddress);
        _testFailSafeBatchTransferFromToZero(_ERC1155OpenEditionCloneAddress);
        _testFailSafeBatchTransferFromToZero(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeBatchTransferFromToNonERC1155Recipient() public {
        _testFailSafeBatchTransferFromToNonERC1155Recipient(_ERC1155BaseCloneAddress);
        _testFailSafeBatchTransferFromToNonERC1155Recipient(_ERC1155OpenEditionCloneAddress);
        _testFailSafeBatchTransferFromToNonERC1155Recipient(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeBatchTransferFromToWrongReturnDataERC1155Recipient() public {
        _testFailSafeBatchTransferFromToWrongReturnDataERC1155Recipient(_ERC1155BaseCloneAddress);
        _testFailSafeBatchTransferFromToWrongReturnDataERC1155Recipient(_ERC1155OpenEditionCloneAddress);
        _testFailSafeBatchTransferFromToWrongReturnDataERC1155Recipient(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_SafeBatchTransferFromWithArrayLengthMismatch() public {
        _testFailSafeBatchTransferFromWithArrayLengthMismatch(_ERC1155BaseCloneAddress);
        _testFailSafeBatchTransferFromWithArrayLengthMismatch(_ERC1155OpenEditionCloneAddress);
        _testFailSafeBatchTransferFromWithArrayLengthMismatch(_ERC1155LazyMintCloneAddress);
    }

    function test_RevertWhen_BatchMintToZero() public {
        vm.skip(true);
        _testFailBatchMintToZero(_ERC1155BaseCloneAddress);
    }

    function test_RevertWhen_BatchMintToNonERC1155Recipient() public {
        vm.skip(true);
        _testFailBatchMintToNonERC1155Recipient(_ERC1155BaseCloneAddress);
    }

    function test_RevertWhen_BatchMintToRevertingERC1155Recipient() public {
        vm.skip(true);
        _testFailBatchMintToRevertingERC1155Recipient(_ERC1155BaseCloneAddress);
    }

    function test_RevertWhen_BatchMintToWrongReturnDataERC1155Recipient() public {
        vm.skip(true);
        _testFailBatchMintToWrongReturnDataERC1155Recipient(_ERC1155BaseCloneAddress);
    }

    function test_RevertWhen_BatchMintWithArrayMismatch() public {
        vm.skip(true);
        _testFailBatchMintWithArrayMismatch(_ERC1155BaseCloneAddress);
    }

    function test_RevertWhen_BatchBurnInsufficientBalance() public {
        vm.skip(true);
        _testFailBatchBurnInsufficientBalance(_ERC1155BaseCloneAddress);
    }

    function test_RevertWhen_BatchBurnWithArrayLengthMismatch() public {
        vm.skip(true);
        _testFailBatchBurnWithArrayLengthMismatch(_ERC1155BaseCloneAddress);
    }

    function test_RevertWhen_BalanceOfBatchWithArrayMismatch() public {
        _testFailBalanceOfBatchWithArrayMismatch(_ERC1155BaseCloneAddress);
        _testFailBalanceOfBatchWithArrayMismatch(_ERC1155OpenEditionCloneAddress);
        _testFailBalanceOfBatchWithArrayMismatch(_ERC1155LazyMintCloneAddress);
    }
}
