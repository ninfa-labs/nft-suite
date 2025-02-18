// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "test/utils/Setup.sol";

contract FactoryTest is Setup {
    ERC721LazyMint private _ERC721LazyMintMaster;
    ERC721LazyMint private _ERC721LazyMintClone;
    // CuratedFactory private _CURATED_FACTORY;

    // address private immutable _deployer;
    // address private immutable _curator;
    // address private immutable _minter;
    // address private immutable _collector;
    // address private immutable _collector2;
    // address private immutable _anon;
    // address private immutable _feesRecipient;
    // address private immutable _lazySigner;

    // /// @dev strings and arrays cannot be immutable
    // string private MNEMONIC_ANVIL;
    // string private NAME;
    // string private SYMBOL;

    // constructor() {
    //     MNEMONIC_ANVIL = vm.envString("MNEMONIC_ANVIL");
    //     NAME = "ninfa.io";
    //     SYMBOL = NAME;

    //     (_deployer,) = deriveRememberKey(MNEMONIC_ANVIL, 0);
    //     (_curator,) = deriveRememberKey(MNEMONIC_ANVIL, 1);
    //     (_minter,) = deriveRememberKey(MNEMONIC_ANVIL, 2);
    //     (_collector,) = deriveRememberKey(MNEMONIC_ANVIL, 3);
    //     (_collector2,) = deriveRememberKey(MNEMONIC_ANVIL, 4);
    //     (_anon,) = deriveRememberKey(MNEMONIC_ANVIL, 5); // used for testing functions where the address/role is not
    //         // important, mainly failing tests
    //     (_feesRecipient,) = deriveRememberKey(MNEMONIC_ANVIL, 6);
    //     (_lazySigner,) = deriveRememberKey(MNEMONIC_ANVIL, 7);
    // }

    function setUp() public {
        /**
         * @dev Prank the Ninfa deployer account, deploying the CuratedFactory and ERC721LazyMintMaster contracts
         */
        // vm.startPrank(_deployer);

        // _CURATED_FACTORY = new CuratedFactory(500, _feesRecipient);

        _ERC721LazyMintMaster = new ERC721LazyMint(address(_CURATED_FACTORY));

        _CURATED_FACTORY.setMaster(address(_ERC721LazyMintMaster), true);

        // _CURATED_FACTORY.grantRole(_CURATOR_ROLE, _curator);

        // vm.stopPrank();

        /**
         * @dev Prank a Ninfa _CURATOR_ROLE account, granting the _MINTER_ROLE to this contract,
         * this avoids having to prank the minter account avoiding code repetition,
         * also allowing to test the ERC-1271: Standard Signature Validation Method for Contracts (for lazy minting and
         * buying)
         */
        // vm.prank(_curator);

        _CURATED_FACTORY.grantRole(_MINTER_ROLE, _MINTER);
    }

    /**
     * @notice deploy the ERC721LazyMintClone contract, the deployer/minter will be address(this)
     * @dev testing gas consumption of the clone function by deploying twice to get min and max values
     * since the first time is always more expensive than the rest
     */
    function testClone() public {
        address instance = _CURATED_FACTORY.clone(
            address(_ERC721LazyMintMaster), bytes32("SALT_0"), abi.encode(_MINTER, 1000, _SYMBOL, _NAME)
        );

        assertEq(instance.code.length > 0, true, "ERC721LazyMintClone contract not deployed");

        // salt needs to differ from the previous one
        instance = _CURATED_FACTORY.clone(
            address(_ERC721LazyMintMaster), bytes32("SALT_1"), abi.encode(_MINTER, 1000, _SYMBOL, _NAME)
        );

        assertEq(instance.code.length > 0, true, "ERC721LazyMintClone contract not deployed");
    }
}
