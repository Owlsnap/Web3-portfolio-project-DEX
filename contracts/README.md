# DEX Smart Contracts - Solidity & Foundry Implementation

A complete decentralized exchange (DEX) smart contract system built with Solidity and Foundry, implementing an Automated Market Maker (AMM) based on the Uniswap V2 model.

## 🎯 Project Overview

This project implements a full-featured DEX with:
- **Automated Market Maker (AMM)** using constant product formula (x * y = k)
- **Liquidity pools** for token pairs with LP tokens
- **Flash loan capabilities** via optimistic execution
- **Community Governance** using OpenZeppelin Governor pattern
- **Treasury Management** for protocol fees and community funds
- **Decentralized Control** over all protocol parameters
- **Factory pattern** for decentralized pair creation

## 🛠️ Technology Stack

### **Smart Contract Development**
- **Solidity ^0.8.28** - Smart contract programming language
- **Foundry** - Complete development framework
  - **Forge** - Testing framework and compilation
  - **Cast** - Command-line tool for blockchain interaction
  - **Anvil** - Local blockchain for testing
- **OpenZeppelin** - Security-audited contract libraries
- **CREATE2** - Deterministic contract deployment

### **Architecture Pattern**
- **Factory Pattern** - Centralized pair creation management
- **Proxy Pattern** - Initialize pattern for pair contracts
- **Reentrancy Guards** - Protection against reentrancy attacks
- **Optimistic Execution** - Flash loan and gas optimization

## 📋 Smart Contract Architecture

### **Core Contracts**
```
src/
├── Factory.sol          # Creates and manages trading pairs (governance-controlled)
├── Pair.sol             # Individual AMM pools (x*y=k formula)
├── Router.sol           # User-friendly interface for swaps/liquidity
├── MockERC20.sol        # Test tokens for development
├── WETH.sol             # Wrapped ETH implementation
├── DEXToken.sol         # Governance token with voting capabilities
├── DEXGovernor.sol      # Main governance contract (proposals, voting, execution)
├── DEXTimelock.sol      # Security delays for governance actions
├── Treasury.sol         # Community-controlled fund management
└── FlashLoanExample.sol # Flash loan implementation example
```

### **Contract Relationships**
```
Governance System:
DEXTimelock (owns everything)
├── Owns → Factory (fee control)
├── Owns → Treasury (fund management)
└── Controlled by → DEXGovernor
    └── Voting power from → DEXToken

AMM System:
Factory (governance-controlled)
├── Creates → Pair (ETH/USDC)
├── Creates → Pair (DAI/USDT) 
├── Creates → Pair (WBTC/DAI)
└── Sends fees to → Treasury

Router (implemented)
├── Interacts with → Factory (find pairs, create pairs)
├── Interacts with → Pair contracts (swaps/liquidity)
├── Handles → Multi-hop routing (A→B→C→D paths)
└── Provides → User-friendly interface with safety checks
```

## 🚀 Development Progress

### Phase 1: Core Infrastructure ✅
- [x] **MockERC20.sol** - Test token contracts with mint/burn functionality
- [x] **Factory.sol** - Pair creation and management with CREATE2
- [x] **Pair.sol** - Complete AMM implementation with:
  - [x] Liquidity provision (mint/burn LP tokens)
  - [x] Token swapping with 0.3% fees
  - [x] Constant product formula enforcement
  - [x] Flash loan capabilities
  - [x] Price oracle accumulator
  - [x] Emergency functions (skim/sync)

### Phase 2: Governance & Treasury System ✅
- [x] **DEXToken.sol** - Governance token with voting capabilities
  - [x] ERC20Votes implementation with delegation
  - [x] Timestamp-based checkpoints for voting power
  - [x] Token distribution and ownership management
- [x] **DEXGovernor.sol** - OpenZeppelin Governor-based governance
  - [x] Proposal creation with threshold requirements (1% of supply)
  - [x] Voting system with 4% quorum requirement
  - [x] 1-day voting delay, 1-week voting period
  - [x] Integration with timelock for security
- [x] **DEXTimelock.sol** - Security delays for governance execution
  - [x] 2-day execution delay for all governance actions
  - [x] Emergency executor roles and access control
  - [x] OpenZeppelin TimelockController integration
- [x] **Treasury.sol** - Community-controlled fund management
  - [x] Multi-token support (ETH + ERC20)
  - [x] Governance-controlled withdrawals and distributions
  - [x] Automated fee collection from Factory
  - [x] Grant distribution and reward programs
  - [x] Emergency recovery functions
- [x] **Factory Integration** - Governance-controlled DEX parameters
  - [x] Community control over trading fees (0.05%-1.0%)
  - [x] Flash loan fee management (0.01%-0.5%)
  - [x] Fee recipient configuration
  - [x] Treasury integration for automated fee collection

### Phase 3: User Interface Contracts ✅
- [x] **Router.sol** - User-friendly interface
  - [x] Add liquidity with automatic pair creation
  - [x] Remove liquidity with slippage protection
  - [x] Token swaps with optimal routing (`swapExactTokensForTokens`)
  - [x] Multi-hop swaps (A→B→C→D) with path calculation
  - [x] Deadline protection (`ensure` modifier)
  - [x] Fee-on-transfer token support
  - [x] Comprehensive quote functions (`getAmountsOut`, `getAmountsIn`)
  - [x] Helper functions for pair management and reserves
- [x] **WETH.sol** - Wrapped ETH for native ETH trading 
- [x] **RouterMultiHopTest.t.sol** - Comprehensive multi-hop routing tests
  - [x] Direct swap testing
  - [x] Multi-hop swap testing (A→B→C→D) 
  - [x] Slippage protection validation
  - [x] Path optimization comparison
  - [x] Error handling for missing pairs

### Phase 4: Advanced Features 📋
- [ ] **Library contracts** for shared math functions
- [ ] **Multicall** functionality for batched operations
- [ ] **Permit** functionality for gasless approvals
- [ ] **Fee-on-transfer** token support

### Phase 5: Testing & Security 🛡️
- [x] **Comprehensive unit tests** for all contracts
  - [x] MockERC20, Factory, Pair contract tests
  - [x] Flash loan functionality and edge cases
  - [x] Governance system comprehensive testing
  - [x] Treasury operations and integration tests
- [x] **Integration tests** for complete user flows
  - [x] Governance + DEX parameter control tests
  - [x] Treasury + Factory fee collection tests
  - [x] Multi-action governance proposals
- [x] **Critical bug fixes** and timing issues
  - [x] ERC20Votes checkpoint timing fixes
  - [x] Governance proposal state transitions
  - [x] Quorum requirement validation
  - [x] K-invariant violation in Pair contract swap function
  - [x] Flash loan invariant enforcement and validation
- [ ] **Fuzz testing** for edge cases and invariants
- [ ] **Fork testing** against mainnet conditions
- [ ] **Gas optimization** analysis

### Phase 6: Deployment 🚀
- [ ] **Local deployment** scripts
- [ ] **Testnet deployment** (Sepolia, Base Sepolia)
- [ ] **Contract verification** on explorers
- [ ] **Documentation** and integration guides

## 🔧 Key Features Implemented

### **Governance System**
- ✅ **DEX Token**: ERC20Votes with delegation and checkpoints
- ✅ **Governor Contract**: OpenZeppelin-based governance with proposals, voting, execution
- ✅ **Timelock Security**: 2-day delays on all governance actions
- ✅ **Community Control**: 1% proposal threshold, 4% quorum requirement
- ✅ **Parameter Management**: Community control over DEX fees and settings

### **Treasury System**
- ✅ **Multi-Asset Support**: Handle ETH and any ERC20 tokens
- ✅ **Governance Control**: All operations require community voting
- ✅ **Automated Collection**: Fees automatically flow from Factory to Treasury
- ✅ **Flexible Distributions**: Support grants, rewards, operational expenses
- ✅ **Emergency Functions**: Governance-controlled recovery mechanisms

### **Factory Contract**
- ✅ CREATE2 deterministic pair addresses
- ✅ Prevents duplicate pairs
- ✅ **Governance-Controlled Fees**: Community sets trading fees (0.05%-1.0%)
- ✅ **Treasury Integration**: Automated fee collection system
- ✅ Complete pair registry

### **Pair Contract**
- ✅ **AMM Core**: Constant product formula (x * y = k)
- ✅ **Liquidity Management**: Mint/burn LP tokens with proper accounting
- ✅ **Trading**: Swap functionality with 0.3% fees
- ✅ **Flash Loans**: Optimistic execution with callback support
- ✅ **Price Oracle**: Cumulative price tracking for external use
- ✅ **Emergency Functions**: skim() and sync() for edge cases
- ✅ **Security**: Reentrancy protection and overflow checks

### **Router Contract**
- ✅ **User-Friendly Interface**: Easy-to-use functions for all DEX operations
- ✅ **Liquidity Management**: Add/remove liquidity with slippage protection
- ✅ **Token Swapping**: Direct and multi-hop swaps with optimal routing
- ✅ **Safety Features**: Deadline protection, minimum output validation
- ✅ **Path Optimization**: Automatic routing through multiple pairs
- ✅ **Fee Handling**: Support for fee-on-transfer tokens
- ✅ **Quote Functions**: Get expected outputs before executing trades

### **Testing Infrastructure**
- ✅ **MockERC20**: Full test token with mint/burn capabilities
- ✅ **Comprehensive tests**: Unit tests with edge cases covered
- ✅ **Multi-hop testing**: Complex routing scenarios validated
- ✅ **Integration testing**: Router + Factory + Pair interactions
- ✅ **Fuzz testing**: Random input validation
- ✅ **Gas optimization**: Efficient storage and computation patterns

## 🧪 Getting Started

### **Prerequisites**
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
forge --version
cast --version
anvil --version
```

### **Development Commands**

```bash
# Install dependencies
forge install

# Compile contracts
forge build

# Run tests
forge test

# Run tests with verbose output
forge test -vvv

# Run specific test
forge test --match-contract MockERC20Test

# Check test coverage
forge coverage

# Format code
forge fmt

# Generate gas snapshots
forge snapshot

# Start local blockchain
anvil
```

### **Testing Specific Contracts**

```bash
# Test MockERC20 functionality
forge test --match-contract MockERC20Test -vvv

# Test Factory pair creation
forge test --match-contract FactoryTest -vvv

# Test Pair AMM functionality  
forge test --match-contract PairTest -vvv

# Test Governance system
forge test --match-contract GovernanceTest -vvv

# Test Treasury functionality
forge test --match-contract TreasuryTest -vvv

# Test Governance + DEX integration
forge test --match-contract GovernanceDEXIntegrationTest -vvv

# Test Router functionality and multi-hop swaps
forge test --match-contract RouterMultiHopTest -vvv

# Fuzz test with more runs
forge test --fuzz-runs 10000
```

## 📚 Learning Objectives

This project demonstrates mastery of:

### **Solidity Advanced Concepts**
- **Inheritance patterns** (ERC20, Ownable)
- **Interface design** and contract interaction
- **Assembly usage** for gas optimization (CREATE2)
- **Storage optimization** (packed structs)
- **Reentrancy protection** patterns
- **Mathematical precision** in DeFi calculations

### **DeFi Mechanisms**
- **Automated Market Makers** (constant product formula)
- **Liquidity provision** and LP token economics
- **Slippage** calculation and protection
- **Flash loans** and atomic transactions
- **Price discovery** through trading
- **Arbitrage** mechanisms and MEV considerations

### **Foundry Mastery**
- **Advanced testing** patterns (setup, mocking, assertions)
- **Fuzz testing** for invariant checking
- **Fork testing** for real-world simulation
- **Gas profiling** and optimization
- **Deployment scripting** and automation

## 🔐 Security Considerations

### **Implemented Protections**
- ✅ **Reentrancy Guards** - Prevents recursive calls
- ✅ **Integer Overflow Protection** - Safe math operations
- ✅ **Access Control** - Factory-only initialization
- ✅ **Input Validation** - Comprehensive parameter checking
- ✅ **Slippage Protection** - Minimum output amounts
- ✅ **Deadline Checks** - Transaction expiration

### **Attack Vectors Addressed**
- ✅ **Front-running** - Slippage and deadline protection
- ✅ **Sandwich attacks** - MEV protection through proper UX
- ✅ **Flash loan attacks** - Invariant checking (k validation)
- ✅ **K-invariant violations** - Critical fix preventing AMM constant product bypass
- ✅ **Precision loss** - Careful rounding and minimum liquidity
- ✅ **Governance attacks** - Decentralized factory pattern

## 🏛️ Governance System

### **Governance Flow**
```
1. Proposal Creation (1% of DEX tokens required)
   ↓
2. Voting Delay (1 day)
   ↓  
3. Voting Period (1 week, 4% quorum required)
   ↓
4. Timelock Queue (if passed)
   ↓
5. Execution Delay (2 days)
   ↓
6. Execution (anyone can execute)
```

### **What Governance Controls**
- **Trading Fees**: Community sets fees between 0.05% - 1.0%
- **Flash Loan Fees**: Independent control from 0.01% - 0.5%
- **Fee Recipients**: Where protocol fees are sent
- **Treasury Operations**: All fund withdrawals and distributions
- **Parameter Updates**: Any protocol configuration changes

### **Treasury Capabilities**
- **Automated Fee Collection**: Factory sends fees directly to Treasury
- **Grant Programs**: Fund development, audits, marketing
- **Liquidity Mining Rewards**: Distribute tokens to users
- **Operational Expenses**: Pay for infrastructure and services
- **Emergency Recovery**: Community-controlled fund recovery

### **Governance Token (DEX)**
- **Total Supply**: 1 billion DEX tokens
- **Voting Power**: Based on delegated token holdings
- **Delegation**: Users must delegate to themselves or others to vote
- **Checkpoints**: Historical voting power tracking for proposals

## 📖 Mathematical Foundation

### **Constant Product Formula**
```
x * y = k (invariant)

Where:
- x = reserve of token A
- y = reserve of token B  
- k = constant product (can only increase due to fees)
```

### **Liquidity Token Calculation**
```solidity
// First liquidity provider
liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY

// Subsequent providers  
liquidity = min(
    amount0 * totalSupply / reserve0,
    amount1 * totalSupply / reserve1
)
```

### **Swap Output Calculation**
```solidity
// With 0.3% fee
amountInWithFee = amountIn * 997
numerator = amountInWithFee * reserveOut  
denominator = reserveIn * 1000 + amountInWithFee
amountOut = numerator / denominator
```

## 🌐 Deployment Targets

- **Local Development**: Anvil local blockchain
- **Ethereum Sepolia**: Primary testnet deployment
- **Base Sepolia**: L2 testing environment
- **Polygon Mumbai**: Alternative L2 testing (if available)

## 📄 License

MIT License - Educational and development purposes

---

**Note**: This is a learning project implementing Uniswap V2 mechanics for educational purposes. Not intended for production use without proper audits and additional security measures.
