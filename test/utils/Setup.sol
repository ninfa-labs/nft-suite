// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./mocks/ETHUSDPriceFeed.sol";
import "./mocks/USDC.sol";
import "src/factory/CuratedFactory.sol";
import "src/token/ERC721/presets/ERC721Base.sol";
import "src/token/ERC721/presets/ERC721Generative.sol";
import "src/token/ERC721/presets/ERC721LazyMint.sol";
import "src/token/ERC1155/presets/ERC1155Base.sol";
import "src/token/ERC1155/presets/ERC1155LazyMint.sol";
import "src/token/ERC1155/presets/ERC1155OpenEdition.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

contract Setup is Test {
    CuratedFactory internal immutable _CURATED_FACTORY;
    ERC721Base internal immutable _ERC721_BASE_MASTER;

    ERC721LazyMint internal immutable _ERC721_SOVEREIGN_MASTER;
    ERC721Generative internal immutable _ERC721_GENERATIVE_MASTER;
    ERC1155Base internal immutable _ERC1155_BASE_MASTER;
    ERC1155LazyMint internal immutable _ERC1155_SOVEREIGN_MASTER;
    ERC1155OpenEdition internal immutable _ERC1155_OPEN_EDITION_MASTER;
    // https://docs.chain.link/data-feeds/price-feeds/addresses
    ETHUSDPriceFeed internal immutable _ETHUSDPriceFeed;
    USDC internal immutable _USDC;

    bytes32 internal constant _MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant _CURATOR_ROLE = keccak256("CURATOR_ROLE");
    /// @dev // random token URI, must not be 0x0 or `uri()` getter function will revert
    bytes32 internal constant _TOKEN_URI = 0x1111111111111111111111111111111111111111111111111111111111111111;

    /// @dev the deployer is the account that deploys the CuratedFactory and grants the _CURATOR_ROLE to the curator
    address internal immutable _DEPLOYER;
    /// @dev the curator is the account that deploys the CuratedFactory and grants the _MINTER_ROLE to this contract
    address internal immutable _CURATOR;
    /// @dev the minter is the account for testing lazy mint signatures from an EOA, normal minting is done from the
    /// testing contract (this)
    /// @dev the minter is the account for testing lazy mint signatures from an EOA, normal minting is done from the
    /// testing contract (this). Only needed if the ERC721 contract implements eip-712.
    address internal immutable _LAZY_MINTER;
    /// @dev _MINTER is used most often and therefore we use address(this) in order to avoid using vm.prank() when
    /// minting etc.
    address internal immutable _MINTER;
    /// @dev the collector is the account for testing buying operations (primary sales)
    address internal immutable _COLLECTOR_PRIMARY;
    /// @dev the collector is the account for testing buying operations (secondary sales)
    address internal immutable _COLLECTOR_SECONDARY;
    /// @dev the operator is the account for testing operator approval and transfers
    address internal immutable _OPERATOR;
    /// @dev the anon is the account for testing unauthorised operations. used for testing functions where the
    /// address/role is not important, mainly failing tests
    address internal immutable _ANON;
    address internal immutable _FEES_RECIPIENT;

    /// @dev Private Key used for lazy minting eip-712 structured data signing
    uint256 internal immutable _LAZY_MINTER_PK;
    /// @dev Private Key used for lazy minting eip-712 structured data signing
    uint256 internal immutable _COLLECTOR_PRIMARY_PK;
    uint256 internal immutable _UNIT_PRICE;
    uint256 internal immutable _ERC1155_VALUE;
    uint256 internal immutable _STARTING_BALANCE;
    uint256 internal immutable _TOTAL_BPS;
    uint256 internal immutable _FEE_BPS;

    uint96 internal immutable _ROYALTY_BPS;

    /// @dev strings and arrays cannot be immutable, 'Immutable variables cannot have a non-value type'

    string internal _MNEMONIC_ANVIL;
    string internal _NAME;
    string internal _SYMBOL;
    uint256[] internal _ZERO_COMMISSION_BPS;
    uint256[] internal _COMMISSION_BPS;
    uint96[] internal _COMMISSION_BPS_UINT96;
    address[] internal _ZERO_COMMISSION_RECEIVERS;
    address[] internal _COMMISSION_RECEIVERS;

    constructor() {
        // DERIVE ADDRESSES FROM MNEMONIC

        _MNEMONIC_ANVIL = vm.envString("MNEMONIC_ANVIL");

        (_DEPLOYER,) = deriveRememberKey(_MNEMONIC_ANVIL, 0);
        (_CURATOR,) = deriveRememberKey(_MNEMONIC_ANVIL, 1);
        (_LAZY_MINTER, _LAZY_MINTER_PK) = deriveRememberKey(_MNEMONIC_ANVIL, 2);
        (_COLLECTOR_PRIMARY, _COLLECTOR_PRIMARY_PK) = deriveRememberKey(_MNEMONIC_ANVIL, 3);
        (_COLLECTOR_SECONDARY,) = deriveRememberKey(_MNEMONIC_ANVIL, 4);
        (_OPERATOR,) = deriveRememberKey(_MNEMONIC_ANVIL, 5);
        (_ANON,) = deriveRememberKey(_MNEMONIC_ANVIL, 6);
        (_FEES_RECIPIENT,) = deriveRememberKey(_MNEMONIC_ANVIL, 7);

        // SET IMMUTABLES

        /// @dev _MINTER is used most often and therefore we use address(this) in order to avoid using vm.prank() when
        /// minting etc.
        _MINTER = address(this);
        _UNIT_PRICE = 1 ether;
        _ERC1155_VALUE = 10;
        _STARTING_BALANCE = 100 ether;
        _TOTAL_BPS = 10_000;
        _FEE_BPS = 500;
        _ROYALTY_BPS = 1000; // 10 %
        _NAME = "Ninfa Labs";
        _SYMBOL = "NINFA";
        _ZERO_COMMISSION_BPS;
        _COMMISSION_BPS = new uint256[](1);
        _COMMISSION_BPS_UINT96 = new uint96[](1);
        _ZERO_COMMISSION_RECEIVERS;
        _COMMISSION_RECEIVERS = new address[](1);
        _COMMISSION_BPS[0] = 1000; // 10%
        _COMMISSION_RECEIVERS[0] = _ANON;

        // DEPLOY FACTORY

        _CURATED_FACTORY = new CuratedFactory(500, _FEES_RECIPIENT);
        _CURATED_FACTORY.grantRole(_MINTER_ROLE, _MINTER);

        // DEPLOY MASTER CONTRACTS

        _ERC721_BASE_MASTER = new ERC721Base(address(_CURATED_FACTORY));
        _ERC721_GENERATIVE_MASTER = new ERC721Generative(address(_CURATED_FACTORY));
        _ERC721_SOVEREIGN_MASTER = new ERC721LazyMint(address(_CURATED_FACTORY));
        _ERC1155_BASE_MASTER = new ERC1155Base(address(_CURATED_FACTORY));
        _ERC1155_SOVEREIGN_MASTER = new ERC1155LazyMint(address(_CURATED_FACTORY));
        _ERC1155_OPEN_EDITION_MASTER = new ERC1155OpenEdition(address(_CURATED_FACTORY));
        _ETHUSDPriceFeed = new ETHUSDPriceFeed();
        _USDC = new USDC(1_000_000_000_000_000); // 1 billion USDC starting supply

        // SET WHITELISTED ADDRESSED USED BY FACTORY

        _CURATED_FACTORY.setMaster(address(_ERC721_BASE_MASTER), true);
        _CURATED_FACTORY.setMaster(address(_ERC721_GENERATIVE_MASTER), true);
        _CURATED_FACTORY.setMaster(address(_ERC721_SOVEREIGN_MASTER), true);
        _CURATED_FACTORY.setMaster(address(_ERC1155_BASE_MASTER), true);
        _CURATED_FACTORY.setMaster(address(_ERC1155_SOVEREIGN_MASTER), true);
        _CURATED_FACTORY.setMaster(address(_ERC1155_OPEN_EDITION_MASTER), true);

        // FUND ACCOUNTS

        // ETH needed for secondary sales
        vm.deal(_COLLECTOR_PRIMARY, 100 ether);
        vm.deal(_COLLECTOR_SECONDARY, 100 ether);
        vm.deal(_ANON, 100 ether);
        // transfer 1M USDC to the collector accounts for testing
        _USDC.transfer(_COLLECTOR_PRIMARY, 500_000_000_000_000);
        _USDC.transfer(_COLLECTOR_SECONDARY, 500_000_000_000_000);
    }
}
