# PiggyBank 🐷 (or you new fav pyramid scheme)

A decentralized savings contract built with Solidity that lets users deposit ETH, earn rewards over time, and withdraw safely under predictable rules. Rewards are funded by deposit fees, making the system self-sustaining without inflation.

This is a learning-oriented project — and yes, it started as something that looked like a pyramid scheme, but now it’s actually legit 😌

# Features ✨

- **User Deposits:** Anyone can deposit ETH (minimum 0.01 ETH)
- **Passive Rewards:** Earn APR on your deposit (default: 1%)
- **Self-Funded Rewards:** Reward pool grows via a 2% fee on deposits  
  - 1% → reward pool  
  - 1% → owner (profit)
- **Fair Withdrawals (Model B):**  
  - Withdraw ≤ deposit → **only deposit is used**  
  - Withdraw > deposit → **deposit + rewards used**  
  - Rewards untouched unless needed
- **30-Day Lock:** Rewards can only be withdrawn after 30 days
- **No Reward Inflation:** Users stop earning new rewards after deposit becomes 0
- **Clean Accounting:** Stored & fresh rewards handled separately
- **Owner Functions:** Owner can fund reward pool, change APR, claim fees

## How It Works 🔄

## For Users

### 1. Deposit ETH
- Must be at least **0.01 ETH**
- Contract takes a 2% fee  
  - 1% → reward pool  
  - 1% → owner profit  
- You get **98%** credited as deposit
- Rewards start immediately

------

### 2. Earn Rewards Over Time
Rewards accrue continuously:

freshRewards = (deposit * rewardRate * timeElapsed) / (10000 * 365 days)


Rewards consist of:
- **Fresh rewards** (calculated live)
- **Accumulated (committed) rewards**

Rewards stop generating once deposit = 0.

---

### 3. Withdraw ETH

Under **Model B withdrawal logic**:

| Withdrawal Type | What Happens | Rewards? |
|-----------------|--------------|----------|
| `amount < deposit` | Only deposit reduces | Rewards untouched |
| `amount == deposit` | Full principal withdrawn | Rewards remain & stay claimable |
| `amount > deposit` | Deposit + rewards used | Rewards must unlock first |

This gives users maximum control while keeping the contract safe.

---

### 4. Claim Rewards (after 30 days)
- Moves fresh rewards into stored rewards
- Transfers **all** rewards to user
- Deposit stays untouched
- If deposit = 0 but the user has stored rewards, they **can still claim**, but no new rewards accumulate

---

## For Owner

- Earns 1% on every deposit
- Can adjust APR
- Can fund the reward pool
- Can withdraw **ownerBalance** (profit only)
- Cannot take user deposits or user rewards  

---

## Contract Architecture 🏗️

PiggyBank.sol
├── Constants
│   ├── MIN_DEPOSIT_AMOUNT     = 0.01 ETH
│   ├── FEE_BASIS_POINTS       = 200 (2%)
│   ├── MIN_LOCK_PERIOD        = 30 days
│   └── SECONDS_PER_YEAR       = 365 days
├── State Variables
│   ├── owner                  (immutable admin)
│   ├── ownerBalance           (owner profits)
│   ├── rewardPool             (pays rewards)
│   └── rewardRate             (APR, default 1%)
├── Struct Depositor
│   ├── amount                 (principal)
│   ├── depositTimestamp       (for lock)
│   ├── lastRewardClaim        (reward checkpoint)
│   └── accumulatedRewards     (committed rewards)
└── Core Functions
    ├── deposit()
    ├── withdraw(amount)       // Model B logic
    ├── claimRewards()
    ├── getUserBalance(address)
    └── calculateRewards(address)

### Deposit Fee Breakdown

| Portion | Allocation |
|--------|------------|
| 1%     | rewardPool |
| 1%     | ownerBalance |

---

### Reward Calculation (default APR = 1%)

rewards =
(deposit * rewardRate * timeElapsed)
/ (10000 * SECONDS_PER_YEAR)


Example:
- Deposit: 10 ETH  
- APR: 1%  
- One year → ~0.1 ETH reward

---

### Sustainability

Reward pool grows from user deposits → **no inflation**.

System stays sustainable if:
- Reward rate isn’t too high  
- Users deposit occasionally  
- Owner occasionally funds reward pool  

---

# Installation & Setup 🛠️

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Install Dependencies
```bash
git clone <https://github.com/RumenaStaneva/piggy-bank.git>
cd piggy-bank
forge install
```

### Compile
```bash
forge build
```

### Test
```bash
forge test
```

## Deployment 🚀

### Local Deployment (Anvil)

1. **Start local node**
```bash
anvil
```

2. **Deploy contract**
```bash
forge script script/PiggyBankScript.s.sol:PiggyBankScript \
  --rpc-url http://localhost:8545 \
  --broadcast
```

3. **Interact with contract**
```bash
# Set the deployed contract address
export PIGGYBANK_ADDRESS=<deployed-address>

# Run interaction script (deposits 0.1 ETH)
forge script script/InteractPiggyBank.s.sol:InteractPiggyBank \
  --rpc-url http://localhost:8545 \
  --broadcast
```

### Testnet Deployment (e.g., Sepolia)

```bash
forge script script/PiggyBankScript.s.sol:PiggyBankScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```
---

# Security Features 🔒

1. **Minimum Lock Period**: Users cannot claim rewards until 30 days after first deposit
2. **No Reward Inflation**: Fresh rewards require active deposit
3. **Owner Cannot Steal Rewards**: User deposits, owner balance, and reward pool tracked separately
4. **Input Validation**: Minimum deposit amount, sufficient balance checks
5. **Custom Errors**: Gas-efficient error handling


## Contract Functions Reference 📚

### User Functions
## Contract Functions Reference 📚

### User Functions

| Function | Description |
|----------|-------------|
| `deposit()` | Deposit ETH (2% fee applied) |
| `withdraw(uint256 amount)` | Withdraw using **Model B** logic (deposit first, rewards if needed) |
| `claimRewards()` | Claim all rewards (after 30-day lock) |
| `getUserBalance(address user)` | Returns `(deposit, totalRewards)` |
| `calculateRewards(address user)` | Returns total rewards (fresh + stored) |

---

### Owner Functions

| Function | Description |
|----------|-------------|
| `fundRewardPool()` | Add ETH to the reward pool |
| `setRewardRate(uint256 rate)` | Adjust APR (in basis points) |
| `getOwnerBalance()` | View owner's collected profits |
| `withdrawOwner(uint256 amount)` | Withdraw only the owner's profit |

---

### View Helpers

| Function | Returns |
|----------|---------|
| `getMinDepositAmount()` | Minimum required deposit (0.01 ETH) |
| `getMinLockPeriod()` | Lock duration (30 days) |
| `getContractBalance()` | Total ETH held by the contract |
| `canClaimRewards(address user)` | Returns `true` if user passed lock period |

## Testing 🧪

Run the test suite:
```bash
forge test
```

Run with verbosity:
```bash
forge test -vvv
```

Run a single test:
```bash
forge test --match-test testWithdrawMoreThanDepositUsesRewards
```

## Gas Optimization ⚡

- Custom errors (cheap reverts)
- No loops
- Efficient reward math
- Uses storage writes minimally
- No redundant state tracking

## Future Improvements 🚧

- [ ] Add events for all state changes
- [ ] Implement emergency pause mechanism
- [ ] Add compound interest option
- [ ] Multi-token support (not just ETH)
- [ ] Tiered reward rates based on deposit amount
- [ ] Referral system
- [ ] Governance for reward rate changes
- [ ] On-chain analytics

## License 📄

UNLICENSED

## Contributing 🤝

PRs welcome! This is a learning-first project — if you break it, we can fix it together 🫶

## Disclaimer ⚠️

This contract is for educational use. Not audited.
Do not deposit real money unless you enjoy pain.

---

Built with ❤️ using [Foundry](https://getfoundry.sh/)
