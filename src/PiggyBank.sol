// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Custom errors
error NotOwner();
error DepositTooSmall();
error InsufficientBalance();
error CannotWithdrawMoreThanDeposited();
error NoRewardsAvailable();
error InsufficientRewardPool();
error CannotWithdrawFromRewardPool();
error MinimumLockPeriodNotMet();
error CannotWithdrawMoreThanAvailable();
error CanNotWithdrawWhenNoDeposit();

contract PiggyBank {
    // Constants
    uint256 constant MIN_DEPOSIT_AMOUNT = 0.01 ether;
    uint256 constant SECONDS_PER_YEAR = 365 days;
    uint256 constant FEE_BASIS_POINTS = 200; // 2% total fee
    uint256 constant MIN_LOCK_PERIOD = 30 days; // Minimum time before claiming rewards

    // State variables
    address public owner;
    uint256 public ownerBalance;
    uint256 public rewardPool;
    uint256 public committedRewards; // Rewards owed to users
    uint256 public rewardRate; // In basis points (100 = 1% APR)

    struct Depositor {
        uint256 amount;
        uint256 depositTimestamp; // When the deposit was made
        uint256 lastRewardClaim;
        uint256 accumulatedRewards;
    }
    mapping(address => Depositor) public depositors;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
        rewardRate = 100; // Default 1% APR
    }

    // ============ DEPOSIT FUNCTIONS ============

    function deposit() public payable {
        if (msg.value < MIN_DEPOSIT_AMOUNT) {
            revert DepositTooSmall();
        }

        if (msg.sender == owner) {
            ownerBalance += msg.value;
        } else {
            _processUserDeposit();
        }
    }

    function _processUserDeposit() private {
        // Fee on the deposit
        uint256 totalFee = (msg.value * FEE_BASIS_POINTS) / 10000;
        // Fee for reward pool
        uint256 feeToRewardPool = totalFee / 2;
        // Profit from fee for the owner
        uint256 profit = totalFee - feeToRewardPool;

        rewardPool += feeToRewardPool;
        ownerBalance += profit;

        // Update rewards before modifying deposit amount
        // If user has existing deposit, commit pending rewards
        if (depositors[msg.sender].amount > 0) {
            _commitPendingRewards(msg.sender);
        } else {
            // First time deposit, set timestamps
            depositors[msg.sender].depositTimestamp = block.timestamp;
            depositors[msg.sender].lastRewardClaim = block.timestamp;
        }

        // Add deposit after fee
        depositors[msg.sender].amount += msg.value - totalFee;
    }

    function _commitPendingRewards(address user) private {
        // Rewards earned since last claim
        uint256 pendingRewards = _calculateFreshRewards(user);
        depositors[user].accumulatedRewards += pendingRewards;
        committedRewards += pendingRewards;
        depositors[user].lastRewardClaim = block.timestamp;
    }

    // ============ WITHDRAW FUNCTIONS ============

    function withdraw(uint256 amount) public {
        if (msg.sender == owner) {
            _withdrawOwner(amount);
        } else {
            _withdrawUser(amount);
        }
    }

    function _withdrawOwner(uint256 amount) private {
        if (amount > ownerBalance) {
            revert InsufficientBalance();
        }
        ownerBalance -= amount;
        payable(owner).transfer(amount);
    }

    function _withdrawUser(uint256 amount) private {
        uint256 userDeposit = depositors[msg.sender].amount;
        if (userDeposit == 0) {
            revert InsufficientBalance();
        }

        uint256 totalRewards = _getTotalRewards(msg.sender);
        uint256 totalAvailable = userDeposit + totalRewards;

        if (amount > totalAvailable) revert CannotWithdrawMoreThanAvailable();

        // Calculate how much comes from rewards vs deposit
        uint256 fromDeposit = amount > userDeposit ? userDeposit : amount; // all deposit if amount exceeds deposit
        uint256 fromRewards = amount - fromDeposit; // how much we need from rewards
        // If user withdraws all their deposit, give all rewards too
        if (fromDeposit == userDeposit) {
            fromRewards = totalRewards;
        }

        // If withdrawing rewards, check minimum lock period
        if (
            fromRewards > 0 &&
            block.timestamp <
            depositors[msg.sender].depositTimestamp + MIN_LOCK_PERIOD
        ) {
            revert MinimumLockPeriodNotMet();
        }

        // Check reward pool has enough
        if (fromRewards > rewardPool) {
            revert InsufficientRewardPool();
        }

        // Update balances
        depositors[msg.sender].amount -= fromDeposit;

        if (fromRewards > 0) {
            uint256 freshRewards = _calculateFreshRewards(msg.sender); // Update freshly earned rewards
            committedRewards += freshRewards; // Update all the rewards before deducting

            if (fromRewards <= depositors[msg.sender].accumulatedRewards) {
                depositors[msg.sender].accumulatedRewards -= fromRewards;
            } else {
                depositors[msg.sender].accumulatedRewards = 0;
            }

            rewardPool -= fromRewards;
            committedRewards -= fromRewards;
        }

        depositors[msg.sender].lastRewardClaim = block.timestamp;
        payable(msg.sender).transfer(amount);
    }

    // User claims all his rewards
    function claimRewards() public {
        // We must have a deposit to claim rewards
        if (depositors[msg.sender].amount == 0) {
            revert CanNotWithdrawWhenNoDeposit();
        }

        // Check minimum lock period
        if (
            block.timestamp <
            depositors[msg.sender].depositTimestamp + MIN_LOCK_PERIOD
        ) {
            revert MinimumLockPeriodNotMet();
        }

        uint256 totalRewards = _getTotalRewards(msg.sender);
        if (totalRewards == 0) {
            revert NoRewardsAvailable();
        }
        if (totalRewards > rewardPool) {
            revert InsufficientRewardPool();
        }

        uint256 freshRewards = _calculateFreshRewards(msg.sender);
        committedRewards += freshRewards;

        rewardPool -= totalRewards;
        committedRewards -= totalRewards;
        depositors[msg.sender].accumulatedRewards = 0;
        depositors[msg.sender].lastRewardClaim = block.timestamp;

        payable(msg.sender).transfer(totalRewards);
    }

    // ============ OWNER FUNCTIONS ============

    function fundRewardPool() public payable onlyOwner {
        rewardPool += msg.value;
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        rewardRate = _rewardRate;
    }

    // ============ VIEW FUNCTIONS ============

    function calculateRewards(address user) public view returns (uint256) {
        return _getTotalRewards(user);
    }

    function getUserBalance(
        address user
    ) public view returns (uint256 deposit, uint256 rewards) {
        deposit = depositors[user].amount;
        rewards = _getTotalRewards(user);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getMinDepositAmount() public pure returns (uint256) {
        return MIN_DEPOSIT_AMOUNT;
    }

    function getMinLockPeriod() public pure returns (uint256) {
        return MIN_LOCK_PERIOD;
    }

    function canClaimRewards(address user) public view returns (bool) {
        return
            block.timestamp >=
            depositors[user].depositTimestamp + MIN_LOCK_PERIOD;
    }

    // ============ INTERNAL HELPERS ============

    function _getTotalRewards(address user) private view returns (uint256) {
        return
            depositors[user].accumulatedRewards + _calculateFreshRewards(user);
    }

    function _calculateFreshRewards(
        address user
    ) private view returns (uint256) {
        // Return 0 if no user has not deposited anything
        if (depositors[user].amount == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp -
            depositors[user].lastRewardClaim;
        return
            (depositors[user].amount * rewardRate * timeElapsed) /
            (10000 * SECONDS_PER_YEAR);
    }
}
