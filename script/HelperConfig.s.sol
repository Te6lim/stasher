// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract HelperConfig is Script {

    struct NetworkConfig {
        address ethPriceFeed;
        uint256 deployKey;
    }

    uint8 private constant DECIMALS = 8;
    int256 private constant ETH_USD_PRICE = 3500e8;
    uint256 private constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig private activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = createSepoliaETHConfig();
        } else {
            activeNetworkConfig = createAnvilChainConfig();
        }
    }

    function createSepoliaETHConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            ethPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            deployKey: vm.envUint("PRIVATE-KEY")
        });
    }
    
    function createAnvilChainConfig() public returns(NetworkConfig memory) {
        vm.startBroadcast();
        MockV3Aggregator priceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        vm.stopBroadcast();
        return NetworkConfig({
            ethPriceFeed: address(priceFeed),
            deployKey: DEFAULT_ANVIL_KEY
        });
    }

    function createETHMainnetConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            ethPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            deployKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getActiveNetworkConfig() public view returns(NetworkConfig memory) {
        return activeNetworkConfig;
    }
}