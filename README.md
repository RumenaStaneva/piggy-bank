# PiggyBank 🐷

A decentralized savings contract built with Solidity that allows users to deposit ETH, earn rewards over time, and withdraw their funds. The contract features a sustainable reward system funded by deposit fees, with built-in protections for fairness and security.

## Features ✨

- **User Deposits**: Anyone can deposit ETH (minimum 0.01 ETH)
- **Automated Rewards**: Earn 1% APR on deposits
- **Self-Sustaining**: Reward pool funded by 2% deposit fee (split 50/50 between rewards and owner profit)
- **Time-Lock Protection**: 30-day minimum lock period before claiming rewards
- **Fair Withdrawals**: Users can always withdraw their principal; rewards require lock period
- **Protected Reward Pool**: Committed rewards cannot be withdrawn by owner
- **Owner Management**: Owner can fund pool, adjust reward rates, and withdraw profits

## How It Works 🔄

### For Users

1. **Deposit**
   - Send ETH to the contract (min 0.01 ETH)
   - 2% fee is charged: 1% → reward pool, 1% → owner profit
   - You receive 98% as your deposit balance
   - Start earning 1% APR immediately

2. **Earn Rewards**
   - Rewards accrue continuously based on your deposit amount
   - Calculated as: `(deposit × 1% × time) / 1 year`
   - After 30 days, you can claim or withdraw rewards

3. **Withdraw**
   - Withdraw your deposit anytime (no lock)
   - Withdraw rewards after 30-day lock period
   - Can withdraw deposit + rewards together

### For Owner

- **Profit**: Earns 1% on all user deposits automatically
- **Manage Reward Pool**: Can add funds to boost rewards
- **Adjust Rates**: Can change the reward rate (default 1% APR)
- **Withdraw Profits**: Can withdraw earned fees from owner balance
- **Protected**: Cannot withdraw committed user rewards

## Contract Architecture 🏗️

```
PiggyBank.sol
├── Constants
│   ├── MIN_DEPOSIT_AMOUNT: 0.01 ETH
│   ├── FEE_BASIS_POINTS: 200 (2%)
│   └── MIN_LOCK_PERIOD: 30 days
├── State Variables
│   ├── owner
│   ├── ownerBalance (owner's profit)
│   ├── rewardPool (funds for user rewards)
│   ├── committedRewards (rewards owed to users)
│   └── rewardRate (default: 100 = 1% APR)
└── Functions
    ├── User Functions
    │   ├── deposit()
    │   ├── withdraw(amount)
    │   ├── claimRewards()
    │   └── getUserBalance(user)
    └── Owner Functions
        ├── fundRewardPool()
        ├── withdrawFromRewardPool(amount)
        └── setRewardRate(rate)
```

## Economics 💰

### Fee Structure
- **Deposit Fee**: 2% of deposit amount
  - 1% → Reward Pool (funds user rewards)
  - 1% → Owner Balance (owner's profit)

### Reward Calculation
- **Rate**: 1% APR (adjustable by owner)
- **Formula**: `rewards = (deposit × rewardRate × timeElapsed) / (10000 × SECONDS_PER_YEAR)`
- **Example**: 10 ETH deposit for 1 year = 0.1 ETH reward

### Sustainability
With balanced 1% fee to pool and 1% reward rate:
- 100 users deposit 10 ETH each
- Total deposits: 980 ETH (after 2% fee)
- Reward pool receives: 100 ETH
- Annual rewards owed: ~98 ETH (1% of 980)
- ✅ Sustainable with buffer

## Installation & Setup 🛠️

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Install Dependencies
```bash
git clone <your-repo-url>
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

## Usage Examples 📝

### Using the Interaction Script

The easiest way to interact with your deployed contract:

```bash
# Set your deployed contract address
export PIGGYBANK_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3

# Run the interaction script (modify it to suit your needs)
forge script script/InteractPiggyBank.s.sol:InteractPiggyBank \
  --rpc-url http://localhost:8545 \
  --broadcast
```

### Interact via Cast

**Check minimum deposit**
```bash
cast call <PIGGYBANK_ADDRESS> "getMinDepositAmount()" --rpc-url <RPC_URL>
```

**Deposit ETH**
```bash
cast send <PIGGYBANK_ADDRESS> "deposit()" \
  --value 1ether \
  --private-key $PRIVATE_KEY \
  --rpc-url <RPC_URL>
```

**Check your balance**
```bash
cast call <PIGGYBANK_ADDRESS> \
  "getUserBalance(address)(uint256,uint256)" \
  <YOUR_ADDRESS> \
  --rpc-url <RPC_URL>
```

**Withdraw funds**
```bash
cast send <PIGGYBANK_ADDRESS> \
  "withdraw(uint256)" \
  500000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url <RPC_URL>
```

**Claim rewards (after 30 days)**
```bash
cast send <PIGGYBANK_ADDRESS> "claimRewards()" \
  --private-key $PRIVATE_KEY \
  --rpc-url <RPC_URL>
```

### Owner Functions

**Fund reward pool**
```bash
cast send <PIGGYBANK_ADDRESS> "fundRewardPool()" \
  --value 10ether \
  --private-key $OWNER_PRIVATE_KEY \
  --rpc-url <RPC_URL>
```

**Set reward rate to 2% APR**
```bash
cast send <PIGGYBANK_ADDRESS> \
  "setRewardRate(uint256)" \
  200 \
  --private-key $OWNER_PRIVATE_KEY \
  --rpc-url <RPC_URL>
```

**Withdraw owner profits**
```bash
cast send <PIGGYBANK_ADDRESS> \
  "withdraw(uint256)" \
  1000000000000000000 \
  --private-key $OWNER_PRIVATE_KEY \
  --rpc-url <RPC_URL>
```

## Security Features 🔒

1. **Minimum Lock Period**: Users cannot claim rewards until 30 days after first deposit
2. **Protected Rewards**: Owner cannot withdraw committed user rewards
3. **Separate Balances**: User deposits, owner balance, and reward pool tracked separately
4. **Input Validation**: Minimum deposit amount, sufficient balance checks
5. **Custom Errors**: Gas-efficient error handling

## Contract Functions Reference 📚

### User Functions

| Function | Description | Access |
|----------|-------------|--------|
| `deposit()` | Deposit ETH (min 0.01 ETH, 2% fee) | Anyone |
| `withdraw(uint256 amount)` | Withdraw deposit + rewards | Depositors |
| `claimRewards()` | Claim earned rewards only | Depositors (after 30 days) |
| `getUserBalance(address)` | View deposit and rewards | Anyone |
| `calculateRewards(address)` | Calculate earned rewards | Anyone |
| `canClaimRewards(address)` | Check if eligible to claim | Anyone |

### Owner Functions

| Function | Description | Access |
|----------|-------------|--------|
| `fundRewardPool()` | Add ETH to reward pool | Owner only |
| `withdrawFromRewardPool(uint256)` | Withdraw uncommitted rewards | Owner only |
| `setRewardRate(uint256)` | Adjust reward rate (basis points) | Owner only |

### View Functions

| Function | Returns |
|----------|---------|
| `getBalance()` | Total contract balance |
| `getMinDepositAmount()` | Minimum deposit (0.01 ETH) |
| `getMinLockPeriod()` | Lock period in seconds (30 days) |
| `owner()` | Contract owner address |
| `rewardPool()` | Current reward pool balance |
| `committedRewards()` | Total committed rewards |
| `rewardRate()` | Current reward rate (basis points) |

## Testing 🧪

Run the test suite:
```bash
forge test
```

Run with verbosity:
```bash
forge test -vvv
```

Run specific test:
```bash
forge test --match-test testDeposit
```

## Gas Optimization ⚡

- Uses custom errors instead of revert strings
- Minimal storage variables
- Efficient reward calculation
- No loops or unbounded operations

## Future Improvements 🚧

- [ ] Add events for all state changes
- [ ] Implement emergency pause mechanism
- [ ] Add compound interest option
- [ ] Multi-token support (not just ETH)
- [ ] Tiered reward rates based on deposit amount
- [ ] Referral system
- [ ] Governance for reward rate changes

## License 📄

UNLICENSED

## Contributing 🤝

Contributions are welcome! Please open an issue or submit a pull request.

## Disclaimer ⚠️

This contract is for educational purposes. It has not been audited. Use at your own risk. Always conduct thorough testing and auditing before deploying to mainnet.

---

Built with ❤️ using [Foundry](https://getfoundry.sh/)
