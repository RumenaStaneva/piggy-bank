// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {PiggyBank} from "../src/PiggyBank.sol";
contract PiggyBankTest is Test {
    PiggyBank public piggyBank;
    address OWNER = makeAddr("owner");

    uint256 constant MIN_DEPOSIT = 0.01 ether;
    uint256 constant FEE_BASIS_POINTS = 200; // 2% total fee
    uint256 constant SECONDS_PER_YEAR = 365 days;

    receive() external payable {}

    function setUp() public {
        vm.prank(OWNER);
        piggyBank = new PiggyBank();
    }

    function testDepositTooSmallReverts() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        vm.expectRevert();
        piggyBank.deposit{value: 0.005 ether}();
        vm.stopPrank();
    }

    function testDepositAndCheckBalance() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        uint256 depositAmount = 0.1 ether;

        piggyBank.deposit{value: depositAmount}();
        (uint256 deposit, uint256 rewards) = piggyBank.getUserBalance(user);
        uint256 fee = (depositAmount * FEE_BASIS_POINTS) / 10000;
        uint256 netDeposit = depositAmount - fee;
        assertEq(deposit, netDeposit);
        assertEq(rewards, 0);
        vm.stopPrank();
    }

    function testGetOwnerBalanceRevertsForNonOwner() public {
        address nonOwner = makeAddr("nonOwner");
        vm.prank(nonOwner);
        vm.deal(nonOwner, 1 ether);

        vm.expectRevert();
        piggyBank.getOwnerBalance();
        vm.stopPrank();
    }

    function testDepositAsOwner() public {
        address owner = OWNER;
        vm.deal(owner, 1 ether);

        uint256 depositAmount = 0.1 ether;

        vm.startPrank(owner);
        piggyBank.deposit{value: depositAmount}();
        uint256 ownerBalance = piggyBank.getOwnerBalance();

        vm.stopPrank();
        assertEq(ownerBalance, depositAmount);
    }

    function testOwnerWithdrawMoreThanBalanceReverts() public {
        uint256 initialDeposit = 0.1 ether;
        vm.startPrank(OWNER);
        vm.deal(OWNER, 1 ether);
        piggyBank.deposit{value: initialDeposit}();

        vm.expectRevert();
        piggyBank.withdraw(initialDeposit + 0.01 ether);
        vm.stopPrank();
    }

    function testOwnerWithdraw() public {
        uint256 initialDeposit = 0.1 ether;
        vm.startPrank(OWNER);
        vm.deal(OWNER, 1 ether);
        piggyBank.deposit{value: initialDeposit}();

        uint256 withdrawAmount = 0.05 ether;
        piggyBank.withdraw(withdrawAmount);
        uint256 ownerBalance = piggyBank.getOwnerBalance();
        assertEq(ownerBalance, initialDeposit - withdrawAmount);
        vm.stopPrank();
    }

    function testUserWithdrawMoreThanDepositReverts() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        piggyBank.deposit{value: 0.1 ether}();
        vm.expectRevert();
        piggyBank.withdraw(0.2 ether);
        vm.stopPrank();
    }

    function testUserWithdraw() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        piggyBank.deposit{value: 0.1 ether}();
        uint256 withdrawAmount = 0.05 ether;
        piggyBank.withdraw(withdrawAmount);
        (uint256 deposit, ) = piggyBank.getUserBalance(user);
        uint256 fee = (0.1 ether * FEE_BASIS_POINTS) / 10000;
        uint256 netDeposit = 0.1 ether - fee;
        assertEq(deposit, netDeposit - withdrawAmount);
        vm.stopPrank();
    }

    function testGetTotalRewardsNoTimeElapsed() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        piggyBank.deposit{value: 0.1 ether}();
        (, uint256 rewards) = piggyBank.getUserBalance(user);
        assertEq(rewards, 0);
        vm.stopPrank();
    }

    function testUserHasNoRewardsAfterImmediateDeposit() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        piggyBank.deposit{value: 0.1 ether}();
        (, uint256 rewards) = piggyBank.getUserBalance(user);
        assertEq(rewards, 0);
        vm.stopPrank();
    }

    function testUserExpectsRewardsButHasNoDepositMade() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        (, uint256 rewards) = piggyBank.getUserBalance(user);
        // note to muself - it won't revert, just returns 0
        // solidity can't revert on reading from mapping with no entry
        assertEq(rewards, 0);
        vm.stopPrank();
    }

    function testRewardsAccrual() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        piggyBank.deposit{value: 0.1 ether}();
        vm.stopPrank();
        // Fast forward time by 1 month
        vm.warp(block.timestamp + 30 days);

        // Get user's current deposit and rewards from the contract
        (uint256 userDeposit, uint256 rewards) = piggyBank.getUserBalance(user);

        // Get reward rate from the contract (it’s public)
        uint256 rewardRate = piggyBank.rewardRate();

        // Expected reward
        uint256 timeElapsed = 30 days;
        uint256 expectedRewards = (userDeposit * rewardRate * timeElapsed) /
            (10000 * SECONDS_PER_YEAR);

        assertApproxEqAbs(rewards, expectedRewards, 1); // 1 wei tolerance
    }

    function testUserRewardsAfterMultipleDeposits() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        piggyBank.deposit{value: 0.1 ether}();

        // Fast forward time by 15 days
        vm.warp(block.timestamp + 15 days);

        // Make another deposit
        piggyBank.deposit{value: 0.2 ether}();

        // Fast forward another 15 days
        vm.warp(block.timestamp + 15 days);

        // Get user's current deposit and rewards from the contract
        (uint256 userDeposit, uint256 rewards) = piggyBank.getUserBalance(user);

        // Get reward rate from the contract (it’s public)
        uint256 rewardRate = piggyBank.rewardRate();

        // Calculate expected rewards
        uint256 firstDeposit = 0.1 ether -
            (0.1 ether * FEE_BASIS_POINTS) /
            10000;
        uint256 secondDeposit = 0.2 ether -
            (0.2 ether * FEE_BASIS_POINTS) /
            10000;

        uint256 rewardsFromFirstDeposit = (firstDeposit *
            rewardRate *
            30 days) / (10000 * SECONDS_PER_YEAR);
        uint256 rewardsFromSecondDeposit = (secondDeposit *
            rewardRate *
            15 days) / (10000 * SECONDS_PER_YEAR);

        uint256 expectedRewards = rewardsFromFirstDeposit +
            rewardsFromSecondDeposit;

        assertApproxEqAbs(rewards, expectedRewards, 1); // 1 wei tolerance
        assertEq(userDeposit, firstDeposit + secondDeposit);
        vm.stopPrank();
    }

    function testFundRewardPoolByOwner() public {
        uint256 fundAmount = 1 ether;
        vm.deal(OWNER, 2 ether);
        vm.startPrank(OWNER);
        piggyBank.fundRewardPool{value: fundAmount}();
        vm.stopPrank();

        // Check that the reward pool increased
        uint256 contractBalance = piggyBank.getContractBalance();
        assertEq(contractBalance, fundAmount);
    }

    function testFundRewardPoolByNonOwnerReverts() public {
        address nonOwner = makeAddr("nonOwner");
        vm.deal(nonOwner, 1 ether);
        vm.startPrank(nonOwner);
        vm.expectRevert();
        piggyBank.fundRewardPool{value: 0.5 ether}();
        vm.stopPrank();
    }

    function testUserWithdrawsMoreThanDepositedReverts() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        // piggyBank.deposit{value: 0.1 ether}();
        vm.expectRevert();
        piggyBank.withdraw(0.2 ether);
        vm.stopPrank();
    }

    function testUserWithdrawsExactDepositButHasAccruedRewards() public {
        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        piggyBank.deposit{value: 0.1 ether}();

        // Fast forward time by 1 month to accrue rewards
        vm.warp(block.timestamp + 30 days);

        // Get user's current deposit and rewards from the contract
        (uint256 userDeposit, uint256 rewards) = piggyBank.getUserBalance(user);

        // Withdraw the exact deposit amount
        piggyBank.withdraw(userDeposit);

        // After withdrawal, check that deposit is zero but rewards remain
        (uint256 finalDeposit, uint256 finalRewards) = piggyBank.getUserBalance(
            user
        );
        assertEq(finalDeposit, 0);
        assertEq(finalRewards, rewards);
        vm.stopPrank();
    }
}
