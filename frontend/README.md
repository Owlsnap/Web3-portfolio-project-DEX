# DEX Testnets - Decentralized Exchange Portfolio Project

A full-stack decentralized exchange (DEX) built for testnets, designed as a learning project to master Solidity, Foundry, and modern Web3 frontend development.

## 🎯 Project Overview

This project implements a complete AMM (Automated Market Maker) DEX similar to Uniswap V2, featuring:
- Smart contracts written in Solidity
- Comprehensive testing with Foundry
- Modern React frontend with Web3 integration
- Deployment to multiple testnets

## 🛠️ Tech Stack

### Smart Contracts
- **Solidity** - Smart contract development
- **Foundry** - Development framework, testing, and deployment
- **OpenZeppelin** - Security-audited contract libraries
- **Forge** - Testing and compilation
- **Cast** - Command-line interactions

### Frontend
- **React** - UI framework
- **Vite** - Build tool and dev server
- **Chakra UI** - Component library
- **Tailwind CSS** - Utility-first styling
- **Ethers.js/Wagmi** - Web3 interactions
- **MetaMask** - Wallet integration

## 📋 Development Roadmap

### Phase 1: Core Smart Contracts ✅ (In Progress)
- [x] Project setup and structure
- [ ] ERC-20 Mock Tokens (USDC, DAI, WBTC)
- [ ] Factory Contract (pair creation)
- [ ] Pair Contract (liquidity pools, AMM logic)
- [ ] Router Contract (swap routing, liquidity management)
- [ ] WETH Contract (ETH wrapping)

### Phase 2: Advanced Contract Features
- [ ] Access control and security patterns
- [ ] Events and logging
- [ ] Gas optimization
- [ ] Upgradeable contracts
- [ ] Price oracles integration

### Phase 3: Comprehensive Testing
- [ ] Unit tests for all contracts
- [ ] Integration tests
- [ ] Fuzz testing
- [ ] Fork testing against mainnet
- [ ] Gas profiling and optimization

### Phase 4: Frontend Development
- [ ] Wallet connection (MetaMask)
- [ ] Token swap interface
- [ ] Liquidity pool management
- [ ] Portfolio dashboard
- [ ] Transaction history
- [ ] Responsive design

### Phase 5: Advanced Frontend Features
- [ ] Pool analytics and charts
- [ ] Slippage protection
- [ ] Transaction status tracking
- [ ] Error handling and UX improvements
- [ ] Loading states and animations

### Phase 6: Deployment & DevOps
- [ ] Testnet deployments (Sepolia, Base Sepolia)
- [ ] Contract verification
- [ ] Frontend deployment (Vercel/Netlify)
- [ ] CI/CD pipeline
- [ ] Documentation and guides

## 🏗️ Architecture

```
dex-testnets/
├── contracts/                 # Foundry smart contracts
│   ├── src/                  # Contract source files
│   ├── test/                 # Contract tests
│   ├── script/               # Deployment scripts
│   └── lib/                  # Dependencies
└── frontend/                 # React application
    ├── src/
    │   ├── components/       # UI components
    │   ├── hooks/           # Custom React hooks
    │   ├── utils/           # Utilities and helpers
    │   └── constants/       # Contract addresses, ABIs
    └── public/              # Static assets
```

## 🚀 Getting Started

### Prerequisites
- Node.js (v18+)
- Foundry
- Git

### Smart Contracts Setup
```bash
cd contracts
forge install
forge build
forge test
```

### Frontend Setup
```bash
cd frontend
npm install
npm run dev
```

## 🧪 Testing

### Smart Contract Tests
```bash
cd contracts
forge test -vvv
forge coverage
```

### Frontend Tests
```bash
cd frontend
npm test
```

## 📚 Learning Objectives

This project focuses on mastering:
- **Solidity**: Advanced patterns, security, gas optimization
- **Foundry**: Testing, deployment, debugging
- **DeFi Concepts**: AMMs, liquidity provision, slippage
- **Web3 Frontend**: Wallet integration, contract interactions
- **Testing**: Unit, integration, and fuzz testing strategies

## 🌐 Planned Testnet Deployments

- Ethereum Sepolia
- Base Sepolia
- Polygon Mumbai (if available)
- Arbitrum Sepolia

## 📄 License

MIT License - see LICENSE file for details

## 🤝 Contributing

This is a learning project for my portfolio, feedback is welcomed!
