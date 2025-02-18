// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "test/utils/ERC1155Validator.sol";
import "test/utils/Setup.sol";
import "src/token/ERC1155/presets/ERC1155LazyMint.sol";

contract ERC1155LazyMintTest is Setup, ERC1155Validator {
    // define contract instances

    ERC1155LazyMint private _ERC1155LazyMintClone;

    // utility variables

    address private _ERC1155LazyMintCloneAddress;

    function setUp() public {
        // deploy clones

        bytes32 salt; // 0x0
        bytes memory data = abi.encode(_MINTER, 1000, _SYMBOL, _NAME);

        _ERC1155LazyMintCloneAddress = _CURATED_FACTORY.clone(address(_ERC1155_SOVEREIGN_MASTER), salt, data);

        // instanciate clones

        _ERC1155LazyMintClone = ERC1155LazyMint(_ERC1155LazyMintCloneAddress);

        // assign MINER_ROLE to _LAZY_MINTER
        _ERC1155LazyMintClone.grantRole(_MINTER_ROLE, _LAZY_MINTER);

        // mint tokenId 0 to address(this)

        bytes32 tokenURI = keccak256("FOOBAR"); // random tokenURI, must not be 0x0 or uri() will fail

        _ERC1155LazyMintClone.mint(_MINTER, 1, abi.encode(tokenURI, abi.encode(_MINTER, _ROYALTY_BPS, "")));
    }

    /*----------------------------------------------------------*|
    |*  # EIP-712 i.e. lazy minting                             *|
    |*----------------------------------------------------------*/

    function testEIP712Domain() public view {
        _testEIP712Domain(_ERC1155LazyMintCloneAddress);
    }

    function testLazyMint() public {
        uint256 tokenId = IERC1155Supply(_ERC1155LazyMintCloneAddress).totalSupply();

        _testLazyMint(
            _ERC1155LazyMintCloneAddress,
            _LAZY_MINTER_PK,
            1 ether,
            tokenId,
            _ROYALTY_BPS,
            _COMMISSION_BPS_UINT96,
            _COLLECTOR_PRIMARY,
            _LAZY_MINTER,
            _COMMISSION_RECEIVERS
        );

        // tokenId = IERC1155Supply(_ERC1155LazyMintCloneAddress).totalSupply();

        // _testLazyMint(
        //     _ERC1155LazyMintCloneAddress,
        //     _LAZY_MINTER_PK,
        //     0, // eth value
        //     tokenId,
        //     _ROYALTY_BPS,
        //     _COMMISSION_BPS_UINT96,
        //     _COLLECTOR_PRIMARY,
        //     _LAZY_MINTER,
        //     _COMMISSION_RECEIVERS
        // );

        // tokenId = IERC1155Supply(_ERC1155LazyMintCloneAddress).totalSupply();

        // address to = address(new ERC1155Recipient());
        // _testLazyMint(
        //     _ERC1155LazyMintCloneAddress,
        //     _LAZY_MINTER_PK,
        //     1 ether,
        //     tokenId,
        //     _ROYALTY_BPS,
        //     _COMMISSION_BPS_UINT96,
        //     to,
        //     _LAZY_MINTER,
        //     _COMMISSION_RECEIVERS
        // );
    }
}
