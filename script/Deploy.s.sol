// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// import "forge-std/Test.sol";
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import "src/token/ERC721/presets/ERC721Base.sol";
import "src/token/ERC1155/presets/ERC1155OpenEdition.sol";
import "src/factory/OpenFactory.sol";
import "src/OnChainMarketplace.sol";
import "src/EnglishAuction.sol";

contract Mainnet is Script {
    ERC721Base private _ERC721Base;
    ERC1155OpenEdition private _ERC1155OpenEdition;
    OpenFactory private _openFactory;
    OnChainMarketplace private _onChainMarketplace;
    EnglishAuction private _englishAuction;

    // Mainnet USDC 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address private constant _USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // https://docs.chain.link/data-feeds/price-feeds/addresses
    address private constant _ETHUSD_PRICE_FEED_MAINNET = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // Mainnet ETH/USD
    address private _FEE_RECIPIENT;
    uint256 private constant _FEE_BPS = 500;
    uint256 private _PK_DEPLOYER;

    function run() public {
        _PK_DEPLOYER = vm.envUint("PK_DEPLOYER");
        _FEE_RECIPIENT = vm.envAddress("FEE_RECIPIENT_ACCOUNT");

        vm.startBroadcast(_PK_DEPLOYER);

        _openFactory = new OpenFactory(_FEE_BPS, _FEE_RECIPIENT);

        address factory = address(_openFactory);
        console2.log("factory", factory);

        _ERC721Base = new ERC721Base(factory);
        _openFactory.setMaster(address(_ERC721Base), true);
        console2.log("ERC721Base", address(_ERC721Base));

        _ERC1155OpenEdition = new ERC1155OpenEdition(factory);
        _openFactory.setMaster(address(_ERC1155OpenEdition), true);
        console2.log("ERC1155OpenEdition", address(_ERC1155OpenEdition));

        _onChainMarketplace = new OnChainMarketplace(
            _USDC_MAINNET, // USDC
            _ETHUSD_PRICE_FEED_MAINNET, // ETH/USD
            _FEE_RECIPIENT, // fee recipient (deployer)
            _FEE_BPS
        );

        console2.log("onChainMarketplace", address(_onChainMarketplace));

        _englishAuction = new EnglishAuction(_FEE_RECIPIENT, _FEE_BPS);

        console2.log("EnglishAuction", address(_englishAuction));
    }
}

contract Goerli is Script {
    ERC721Base private _ERC721Base;
    ERC1155OpenEdition private _ERC1155OpenEdition;
    OpenFactory private _openFactory;
    OnChainMarketplace private _onChainMarketplace;
    EnglishAuction private _englishAuction;

    address private constant _USDC_GOERLI = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F; // (deprecated)
    address private constant _ETHUSD_PRICE_FEED_GOERLI = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e; // (deprecated)
    address private _FEE_RECIPIENT;
    uint256 private constant _FEE_BPS = 500;
    uint256 private _PK_DEPLOYER;

    function run() public {
        // Extract the first account from the mnemonic using Foundry
        _PK_DEPLOYER = vm.deriveKey(vm.envString("MNEMONIC_GANACHE"), 0);

        _FEE_RECIPIENT = vm.envAddress("FEE_RECIPIENT_ACCOUNT");

        vm.startBroadcast(_PK_DEPLOYER);

        _openFactory = new OpenFactory(_FEE_BPS, _FEE_RECIPIENT);

        address factory = address(_openFactory);
        console2.log("factory", factory);

        _ERC721Base = new ERC721Base(factory);
        _openFactory.setMaster(address(_ERC721Base), true);
        console2.log("ERC721Base", address(_ERC721Base));

        _ERC1155OpenEdition = new ERC1155OpenEdition(factory);
        _openFactory.setMaster(address(_ERC1155OpenEdition), true);
        console2.log("ERC1155OpenEdition", address(_ERC1155OpenEdition));

        _onChainMarketplace = new OnChainMarketplace(
            _USDC_GOERLI, // USDC
            _ETHUSD_PRICE_FEED_GOERLI, // ETH/USD
            _FEE_RECIPIENT, // fee recipient (deployer)
            _FEE_BPS
        );

        console2.log("onChainMarketplace", address(_onChainMarketplace));

        _englishAuction = new EnglishAuction(_FEE_RECIPIENT, _FEE_BPS);

        console2.log("EnglishAuction", address(_englishAuction));
    }
}
