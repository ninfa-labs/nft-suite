// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract ETHUSDPriceFeed {
    function latestRoundData() external pure returns (uint80, int256, uint256, uint256, uint80) {
        // mock ETH/USD price feed, `answer` return argument equals 4000 USDC per ETH
        // chainlink `answer` has 8 decimal places
        return (0, 300_000_000_000, 0, 0, 0); // mock answer 3,000 USD, i.e. 3e8
    }
}
