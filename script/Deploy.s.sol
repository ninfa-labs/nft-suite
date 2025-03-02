// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import "src/token/ERC721/presets/ERC721Base.sol";
import "src/token/ERC721/presets/ERC721Generative.sol";
import "src/token/ERC721/presets/ERC721LazyMint.sol";
import "src/token/ERC1155/presets/ERC1155Base.sol";
import "src/token/ERC1155/presets/ERC1155LazyMint.sol";
import "src/token/ERC1155/presets/ERC1155OpenEdition.sol";
import "src/factory/OpenFactory.sol";
import "src/OnChainMarketplace.sol";
import "src/EnglishAuction.sol";
import {USDC} from "test/utils/mocks/USDC.sol";
import {ETHUSDPriceFeed} from "test/utils/mocks/ETHUSDPriceFeed.sol";

contract Deploy is Script {
    // Master copies
    ERC721Base private _erc721Base;
    ERC1155Base private _erc1155Base;
    ERC1155OpenEdition private _erc1155OpenEdition;

    // Core contracts
    OpenFactory private _openFactory;
    OnChainMarketplace private _onChainMarketplace;
    EnglishAuction private _englishAuction;

    // Constants
    uint256 private constant _FEE_BPS = 500; // 5% fee

    // Mainnet addresses (chainId = 1)
    address private constant _USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant _ETHUSD_PRICE_FEED_MAINNET = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    // Sepolia addresses (chainId = 11155111)
    address private constant _ETHUSD_PRICE_FEED_SEPOLIA = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    // Fee recipient (non-sensitive, loaded from env)
    address private _feeRecipient;

    function run() external {
        uint256 chainId = block.chainid;
        console2.log("Deploying on chainID:", chainId);

        address usdc;
        address ethUsdPriceFeed;


        // Start broadcasting; if no private key is provided via CLI, Foundry will prompt you.
        vm.startBroadcast();

        if (chainId == 1) {
            // Mainnet
            console2.log("Network: Mainnet");
            usdc = _USDC_MAINNET;
            ethUsdPriceFeed = _ETHUSD_PRICE_FEED_MAINNET;
        } else if (chainId == 11155111) {
            // Sepolia
            // For Sepolia, we'll deploy a mock USDC contract
            console2.log("Network: Sepolia");
            // Deploy a new instance of the mock USDC contract for Sepolia
            USDC mockUSDC = new USDC(1000000000000000); // 1,000,000,000 USDC
            usdc = address(mockUSDC);
            console2.log("Mock USDC :", usdc);
            ethUsdPriceFeed = _ETHUSD_PRICE_FEED_SEPOLIA;
        } else if (chainId == 31337) {
            // Anvil
            console2.log("Network: Anvil");
            // Deploy a new instance of the mock USDC contract for Anvil
            USDC mockUSDC = new USDC(1000000000000000); // 1,000,000,000 usdc
            usdc = address(mockUSDC);
            console2.log("Mock USDC :", usdc);
            // also deploy mock ETH/USD price feed
            ETHUSDPriceFeed mockETHUSDPriceFeed = new ETHUSDPriceFeed();
            ethUsdPriceFeed = address(mockETHUSDPriceFeed);
            console2.log("Mock ETH/USD price feed :", ethUsdPriceFeed);
        } else {
            revert("Unsupported chain. Please deploy on Mainnet or Sepolia.");
        }

        // Hardcode fee receipient to the deployer, chnge if needed
        _feeRecipient = msg.sender;

        // Deploy the OpenFactory contract
        _openFactory = new OpenFactory(_FEE_BPS, _feeRecipient);
        console2.log("OpenFactory :", address(_openFactory));

        // Deploy and whitelist the ERC721Base master copy
        _erc721Base = new ERC721Base(address(_openFactory));
        _openFactory.setMaster(address(_erc721Base), true);
        console2.log("ERC721Base :", address(_erc721Base));

        // Deploy and whitelist the ERC721Generative master copy
        ERC721Generative erc721Generative = new ERC721Generative(address(_openFactory));
        _openFactory.setMaster(address(erc721Generative), true);
        console2.log("ERC721Generative :", address(erc721Generative));

        // Deploy and whitelist the ERC721LazyMint master copy
        ERC721LazyMint erc721LazyMint = new ERC721LazyMint(address(_openFactory));
        _openFactory.setMaster(address(erc721LazyMint), true);
        console2.log("ERC721LazyMint :", address(erc721LazyMint));

        // Deploy and whitelist the ERC1155Base master copy
        _erc1155Base = new ERC1155Base(address(_openFactory));
        _openFactory.setMaster(address(_erc1155Base), true);
        console2.log("ERC1155Base :", address(_erc1155Base));

        // Deploy and whitelist the ERC1155LazyMint master copy
        ERC1155LazyMint erc1155LazyMint = new ERC1155LazyMint(address(_openFactory));
        _openFactory.setMaster(address(erc1155LazyMint), true);
        console2.log("ERC1155LazyMint :", address(erc1155LazyMint));

        // Deploy and whitelist the ERC1155OpenEdition master copy
        _erc1155OpenEdition = new ERC1155OpenEdition(address(_openFactory));
        _openFactory.setMaster(address(_erc1155OpenEdition), true);
        console2.log("ERC1155OpenEdition :", address(_erc1155OpenEdition));

        // Deploy the OnChainMarketplace using the determined USDC and ETH/USD feed addresses
        _onChainMarketplace = new OnChainMarketplace(
            usdc,
            ethUsdPriceFeed,
            _feeRecipient,
            _FEE_BPS
        );
        console2.log("OnChainMarketplace :", address(_onChainMarketplace));

        // Deploy the EnglishAuction contract
        _englishAuction = new EnglishAuction(_feeRecipient, _FEE_BPS);
        console2.log("EnglishAuction :", address(_englishAuction));

        vm.stopBroadcast();
    }
}
