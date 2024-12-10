// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {WalletDeployer} from "script/WalletDeployer.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Stasher} from "src/Stasher.sol";

contract StasherTest is Test {
    Stasher wallet;
    HelperConfig.NetworkConfig config;

    function setUp() public {
        (wallet, config) = (new WalletDeployer()).run();
    }

    
}