// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {PiggyBank} from "../src/PiggyBank.sol";

contract PiggyBankScript is Script {
    PiggyBank public piggyBank;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        piggyBank = new PiggyBank();

        vm.stopBroadcast();
    }
}
