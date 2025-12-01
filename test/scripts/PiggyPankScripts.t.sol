// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {PiggyBank} from "../../src/PiggyBank.sol";
import {PiggyBankScript} from "../../script/PiggyBankScript.s.sol";

contract PiggyBankScriptTest is Test {
    PiggyBankScript script;
    PiggyBank piggy;

    function setUp() public {
        // Deploy the script contract
        script = new PiggyBankScript();

        script.setUp();

        // Run the script like Foundry would
        piggy = script.run();
    }

    function testScriptDeploysPiggyBank() public {
        // address is non-zero
        assert(address(piggy) != address(0));

        // contract actually has code
        assertGt(address(piggy).code.length, 0, "PiggyBank should have code");
    }
}
