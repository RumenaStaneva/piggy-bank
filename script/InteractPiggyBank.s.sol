// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PiggyBank} from "../src/PiggyBank.sol";

contract InteractPiggyBank is Script {
    function run() external {
        // Read the deployed PiggyBank address from env
        address piggyBankAddr = vm.envAddress("PIGGYBANK_ADDRESS");
        PiggyBank piggyBank = PiggyBank(piggyBankAddr);

        vm.startBroadcast();

        // Deposit 0.1 ETH
        piggyBank.deposit{value: 0.1 ether}();
        console.log("Deposited 0.1 ETH into PiggyBank");

        // Withdraw some amount (e.g. 0.05 ETH)
        // piggyBank.withdraw(0.05 ether);
        // console.log("Withdrew 0.05 ETH");

        // Claim rewards
        // piggyBank.claimRewards();
        // console.log("Claimed rewards");

        vm.stopBroadcast();
    }
}
