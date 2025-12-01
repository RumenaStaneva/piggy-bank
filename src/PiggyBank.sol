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
    uint256 public rewardRate; // In basis points (100 = 1% APR)

    struct Depositor {
        uint256 amount;
        uint256 depositTimestamp; // When the deposit was made
        uint256 lastRewardClaim;
        uint256 accumulatedRewards; // committed rewards for user
    }

    mapping(address => Depositor) public depositors;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
        rewardRate = 100; // Default 1% APR (1%)
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

        Depositor storage dep = depositors[msg.sender];

        // If user has existing deposit, commit pending rewards first
        if (dep.amount > 0) {
            _commitPendingRewards(msg.sender);
        } else {
            // First time deposit, set timestamps
            dep.depositTimestamp = block.timestamp;
            dep.lastRewardClaim = block.timestamp;
        }

        // Add deposit after fee
        dep.amount += msg.value - totalFee;
    }

    function _commitPendingRewards(address user) private {
        Depositor storage dep = depositors[user];
        uint256 pendingRewards = _calculateFreshRewards(user);
        dep.accumulatedRewards += pendingRewards;
        dep.lastRewardClaim = block.timestamp;
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

    /**
     * Model B:
     * - If amount <= deposit: withdraw only from deposit, rewards untouched
     * - If amount > deposit: use all deposit + (amount - deposit) from rewards
     */
    function _withdrawUser(uint256 amount) private {
        Depositor storage dep = depositors[msg.sender];

        uint256 userDeposit = dep.amount;
        if (userDeposit == 0) {
            revert InsufficientBalance();
        }

        uint256 totalRewards = _getTotalRewards(msg.sender);
        uint256 totalAvailable = userDeposit + totalRewards;

        if (amount > totalAvailable) {
            revert CannotWithdrawMoreThanAvailable();
        }

        uint256 fromDeposit;
        uint256 fromRewards;

        // Withdraw only from deposit if possible
        if (amount <= userDeposit) {
            fromDeposit = amount;
            fromRewards = 0;
        } else {
            // Not enough in deposit -> need to use rewards as well
            fromDeposit = userDeposit;
            fromRewards = amount - userDeposit;

            // Using rewards → must respect lock period
            if (block.timestamp < dep.depositTimestamp + MIN_LOCK_PERIOD) {
                revert MinimumLockPeriodNotMet();
            }

            // Bring fresh rewards into accumulatedRewards
            uint256 freshRewards = _calculateFreshRewards(msg.sender);
            dep.accumulatedRewards += freshRewards;
            dep.lastRewardClaim = block.timestamp;

            // Now total user rewards = accumulatedRewards
            if (fromRewards > dep.accumulatedRewards) {
                // Should not happen if totalAvailable check was correct,
                // but we keep this as a safety check.
                revert CannotWithdrawMoreThanAvailable();
            }

            if (fromRewards > rewardPool) {
                revert InsufficientRewardPool();
            }

            dep.accumulatedRewards -= fromRewards;
            rewardPool -= fromRewards;
        }

        // Update deposit balance (only deposit part)
        dep.amount = userDeposit - fromDeposit;

        // If we only touched deposit (amount <= deposit), we intentionally
        // do NOT update lastRewardClaim, so rewards keep accruing smoothly.

        payable(msg.sender).transfer(amount);
    }

    // User claims all their rewards (no principal)
    function claimRewards() public {
        Depositor storage dep = depositors[msg.sender];

        // Must have a deposit to claim rewards
        if (dep.amount == 0) {
            revert CanNotWithdrawWhenNoDeposit();
        }

        // Check minimum lock period
        if (block.timestamp < dep.depositTimestamp + MIN_LOCK_PERIOD) {
            revert MinimumLockPeriodNotMet();
        }

        // Compute fresh rewards and total payable
        uint256 freshRewards = _calculateFreshRewards(msg.sender);
        uint256 payout = dep.accumulatedRewards + freshRewards;

        if (payout == 0) {
            revert NoRewardsAvailable();
        }
        if (payout > rewardPool) {
            revert InsufficientRewardPool();
        }

        // Reset user reward state
        dep.accumulatedRewards = 0;
        dep.lastRewardClaim = block.timestamp;

        // Decrease global pool and pay
        rewardPool -= payout;
        payable(msg.sender).transfer(payout);
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
    ) public view returns (uint256 userDeposit, uint256 userRewards) {
        userDeposit = depositors[user].amount;
        userRewards = _getTotalRewards(user);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getOwnerBalance() public view onlyOwner returns (uint256) {
        return ownerBalance;
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
        // Return 0 if user has not deposited anything
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
