# Micro-Lending DeFi Platform

A decentralized micro-lending platform built on Stacks blockchain that enables community-driven lending with risk-based interest rates and reputation scoring.

## 🌟 Overview

This platform allows lenders to deposit STX tokens into a shared pool and borrowers to request loans that are approved through community voting. The system features automated risk assessment, dynamic interest rates, and a reputation system that rewards good borrowers with better rates over time.

## ✨ Key Features

### For Lenders
- **Deposit STX** into the lending pool
- **Earn Interest** from loan repayments
- **Community Voting** on loan approvals (weighted by stake)
- **Liquidity Management** with available withdrawal options
- **Risk Sharing** across the entire lending pool

### For Borrowers
- **Credit Scoring** system (0-1000 scale, starts at 500)
- **Risk-Based Interest Rates** calculated dynamically
- **Flexible Loan Terms** with customizable duration
- **Optional Collateral** for better loan terms
- **Reputation Building** through successful repayments

### Platform Features
- **Community Governance** with configurable voting thresholds
- **Admin Controls** for emergency situations
- **Grace Period** for loan defaults
- **Protocol Fees** for platform sustainability
- **Event Logging** for transparency

## 🔧 Technical Architecture

### Smart Contract Functions

#### Public Functions (For Users)

**Lender Functions:**
- `deposit(amount)` - Deposit STX into the lending pool
- `withdraw(amount)` - Withdraw available balance from the pool
- `vote-on-loan(loan-id)` - Vote on loan approval (requires minimum stake)

**Borrower Functions:**
- `request-loan(amount, term-blocks, risk-tier, collateral-amount)` - Submit loan request
- `repay-loan(loan-id, repay-amount)` - Make loan repayments (partial or full)

**General Functions:**
- `disburse-loan(loan-id)` - Disburse approved loan to borrower
- `handle-default(loan-id)` - Process loan defaults after grace period

#### Admin Functions (Contract Owner Only)
- `set-vote-threshold(new-threshold)` - Adjust voting threshold (1-100%)
- `set-grace-period(new-period)` - Set grace period for defaults
- `toggle-pause()` - Pause/unpause contract operations
- `admin-approve-loan(loan-id)` - Fast-track loan approval

#### Read-Only Functions
- `get-loan-details(loan-id)` - Get complete loan information
- `get-lender-balance(lender)` - Check lender's pool balance
- `get-pool-stats()` - View pool statistics and liquidity
- `get-borrower-reputation(borrower)` - Check credit score and history
- `get-loan-votes(loan-id)` - View current votes for a loan
- `get-governance-params()` - View platform parameters

### Interest Rate Calculation

Interest rates are calculated using the formula:
```
Interest Rate = (risk-tier × 200) + (1000 - credit-score) basis points
```

**Example:**
- Risk Tier 3, Credit Score 600: `(3 × 200) + (1000 - 600) = 1000 basis points = 10%`
- Risk Tier 1, Credit Score 800: `(1 × 200) + (1000 - 800) = 400 basis points = 4%`

### Credit Score System

- **Starting Score:** 500 (new borrowers)
- **Range:** 0-1000
- **Successful Repayment:** +10 points (max 1000)
- **Default:** -50 points (min 0)

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) - Stacks development environment
- [Node.js](https://nodejs.org/) - For running tests and scripts

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ejirocastro/micro-lending.git
   cd micro-lending
   ```

2. **Navigate to project directory:**
   ```bash
   cd micro_lend
   ```

3. **Install dependencies:**
   ```bash
   npm install
   ```

### Development

1. **Check contract syntax:**
   ```bash
   clarinet check
   ```

2. **Run tests:**
   ```bash
   npm test
   ```

3. **Start local devnet:**
   ```bash
   clarinet integrate
   ```

### Deployment

Deploy to different networks using Clarinet:

```bash
# Deploy to testnet
clarinet deploy --testnet

# Deploy to mainnet
clarinet deploy --mainnet
```

## 📊 Default Configuration

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| Vote Threshold | 51% | Percentage of pool required to approve loans |
| Grace Period | 144 blocks (~1 day) | Time before default can be processed |
| Max Loan per Borrower | 1,000,000 μSTX | Maximum loan amount per borrower |
| Protocol Fee | 5% | Fee taken from repayments |
| Min Stake to Vote | 100,000 μSTX | Minimum deposit required to vote |

## 💡 Usage Examples

### For Lenders

**Deposit STX into the pool:**
```clarity
(contract-call? .micro-lending deposit u1000000) ;; Deposit 1 STX
```

**Vote on a loan:**
```clarity
(contract-call? .micro-lending vote-on-loan u1) ;; Vote on loan ID 1
```

**Withdraw funds:**
```clarity
(contract-call? .micro-lending withdraw u500000) ;; Withdraw 0.5 STX
```

### For Borrowers

**Request a loan:**
```clarity
(contract-call? .micro-lending request-loan 
  u2000000    ;; 2 STX loan amount
  u1008       ;; ~1 week term (1008 blocks)
  u2          ;; Risk tier 2
  u200000)    ;; 0.2 STX collateral
```

**Repay loan:**
```clarity
(contract-call? .micro-lending repay-loan u1 u1000000) ;; Repay 1 STX on loan 1
```

### Query Functions

**Check pool statistics:**
```clarity
(contract-call? .micro-lending get-pool-stats)
```

**Check your reputation:**
```clarity
(contract-call? .micro-lending get-borrower-reputation 'SP1ABC...)
```

## 🔒 Security Features

- **Pause Mechanism:** Admin can pause operations in emergencies
- **Access Controls:** Function-level permissions and validations
- **Overflow Protection:** Safe arithmetic operations
- **State Validation:** Comprehensive checks for loan states and transitions

## 🧪 Testing

The project includes comprehensive tests covering:
- Deposit and withdrawal functionality
- Loan request and approval processes
- Voting mechanisms
- Interest calculations
- Default handling
- Edge cases and error conditions

Run tests with:
```bash
npm test
```

## 📈 Future Enhancements

- **Oracle Integration:** External credit scoring and risk assessment
- **Governance Tokens:** Community-owned platform governance
- **Insurance Pool:** Protection against defaults
- **Multi-Asset Support:** Support for other tokens beyond STX
- **Automated Market Making:** Dynamic interest rate adjustments

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This is experimental DeFi software. Use at your own risk. Always conduct thorough testing and audits before deploying to mainnet with real funds.

## 📞 Support

- **GitHub Issues:** [Report bugs or request features](https://github.com/ejirocastro/micro-lending/issues)
- **Documentation:** Check the code comments for detailed function documentation
- **Stacks Community:** Join the [Stacks Discord](https://discord.gg/stacks) for general support

---

Built with ❤️ on Stacks blockchain
