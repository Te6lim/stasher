// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Stasher} from "src/Stasher.sol";

contract WalletDeployer is Script {

    Stasher private wallet;

    function run() external returns(Stasher) {
        vm.startBroadcast();
        wallet = new Stasher();
        vm.stopBroadcast();
        return wallet;
    }
}