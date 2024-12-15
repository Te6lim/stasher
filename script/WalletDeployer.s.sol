// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Stasher} from "src/Stasher.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract WalletDeployer is Script {

    Stasher private wallet;

    function run() external returns(Stasher, HelperConfig.NetworkConfig memory) {
        HelperConfig.NetworkConfig memory config = new HelperConfig().getActiveNetworkConfig();
        vm.startBroadcast();
        wallet = new Stasher(config.ethPriceFeed);
        vm.stopBroadcast();
        return (wallet, config);
    }
}