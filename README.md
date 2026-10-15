# ProtoSwap: a Uniswap V2-style DEX

A full-stack decentralized exchange built from scratch as a portfolio project: an AMM written in Solidity, tested with Foundry, deployed and verified on **Base Sepolia**, with a React + wagmi frontend.

**▶ Live demo: [protoswap-lemon.vercel.app](https://protoswap-lemon.vercel.app)**

> This runs on a testnet. Every token is free and has no real-world value.

## Try it

1. Install a browser wallet (MetaMask, Rabby, Coinbase Wallet…) and open the [live demo](https://protoswap-lemon.vercel.app).
2. Connect and switch to **Base Sepolia**. The app shows a one-click switch button if you're on another network.
3. Get free test ETH from the [Base Sepolia faucet](https://www.coinbase.com/developer-platform/faucet).
4. Claim test USDC and PROTO on the **Faucet** tab (once every 24 hours).
5. Swap between ETH, PROTO and USDC, or provide liquidity on the **Pool** tab.
6. On the **Govern** tab, activate your PROTO votes, propose a fee change, vote, and execute it. A proposal goes from creation to execution in about an hour.

## Features

**Smart contracts**
- Constant-product AMM (`x · y = k`) modelled on Uniswap V2, with a governance-set swap fee (0.3% default)
- `Factory` deploys one `Pair` per token pair with CREATE2; `Pair` issues ERC-20 LP tokens
- `Router` handles add/remove liquidity, exact-in/exact-out swaps, multi-hop paths, native ETH via `WETH`, and slippage and deadline protection
- Flash swaps (optimistic transfers repaid within the same transaction) with their own fee, and an example borrower contract
- Uniswap V2's protocol fee switch: when on, pairs mint 1/6 of trading fees to the treasury as LP tokens
- On-chain governance: `DEXToken` (ERC20Votes) → `DEXGovernor` → `DEXTimelock`, which owns the Factory and the `Treasury`. PROTO holders vote on the trading fee, flash loan fee and protocol fee
- 93 Foundry tests across pairs, routing, multi-hop, ETH, flash loans, governance, treasury, and governed fees (including fuzz tests)

**Frontend**
- React 19 + Vite, Chakra UI, wagmi 2 + viem, RainbowKit wallet connection
- Live quotes with price impact, slippage settings, token approvals, LP position management
- Governance tab: claim PROTO, delegate, create proposals from templates, vote, queue and execute, with live countdowns
- In-app testnet token faucets (USDC and PROTO) and a network-switch prompt

## Deployed contracts (Base Sepolia)

All contracts are verified on Basescan.

| Contract | Address |
| --- | --- |
| Router | [`0xB48D44bE7A38EB70524D88A3896a175351044DDb`](https://sepolia.basescan.org/address/0xB48D44bE7A38EB70524D88A3896a175351044DDb#code) |
| Factory | [`0x85ECd75a865E182B32767719c2489d3d6F38F3B6`](https://sepolia.basescan.org/address/0x85ECd75a865E182B32767719c2489d3d6F38F3B6#code) |
| WETH | [`0xb0F800aa76233B5d89e31bFE37cDc2CBcC32ad39`](https://sepolia.basescan.org/address/0xb0F800aa76233B5d89e31bFE37cDc2CBcC32ad39#code) |
| PROTO (DEXToken) | [`0x599C2c44aAB318D6537A5C873aBa4654A4f87db4`](https://sepolia.basescan.org/address/0x599C2c44aAB318D6537A5C873aBa4654A4f87db4#code) |
| Mock USDC | [`0x7DD41ED04666FFE286f288AB1393bc261c2E0794`](https://sepolia.basescan.org/address/0x7DD41ED04666FFE286f288AB1393bc261c2E0794#code) |
| Governor | [`0x6b9e3E8d59840147021757606cc755f596e3a983`](https://sepolia.basescan.org/address/0x6b9e3E8d59840147021757606cc755f596e3a983#code) |
| Timelock | [`0xde10E2b5B770bA067022982C111009d51e2927b5`](https://sepolia.basescan.org/address/0xde10E2b5B770bA067022982C111009d51e2927b5#code) |
| Treasury | [`0xc2A89b8597DBcA98EE311e52B0092f56F679Ec55`](https://sepolia.basescan.org/address/0xc2A89b8597DBcA98EE311e52B0092f56F679Ec55#code) |
| PROTO faucet | [`0xF6F081a4eF1aF165165386F3C7e6aB87A230BACD`](https://sepolia.basescan.org/address/0xF6F081a4eF1aF165165386F3C7e6aB87A230BACD#code) |
| ETH/PROTO pair | [`0xcFd7134928C71bB890abB30EA27Ca7128C677f13`](https://sepolia.basescan.org/address/0xcFd7134928C71bB890abB30EA27Ca7128C677f13#code) |
| PROTO/USDC pair | [`0x093121754605026bEcdfb8f68dE77e748EcfF77F`](https://sepolia.basescan.org/address/0x093121754605026bEcdfb8f68dE77e748EcfF77F#code) |

## Repository layout

```
contracts/        Foundry project
  src/            Factory, Pair, Router, WETH, DEXToken, governance, treasury, faucet, mocks
  test/           Foundry test suites
  script/         Deploy (local + Base Sepolia) and liquidity scripts
frontend/         React + Vite app (deployed to Vercel)
  src/components/ Swap, Pool, Faucet, Governance, token selector, banner, about dialog
  src/config/     wagmi config, contract addresses, ABIs, governance templates
```

More detail on the contract architecture is in [`contracts/README.md`](contracts/README.md).

## Running locally

Prerequisites: Node.js 18+, [Foundry](https://getfoundry.sh) ≥ 1.8.

```bash
# Contracts
cd contracts
forge install
forge build
forge test

# Frontend
cd frontend
npm install
npm run dev
```

To run against a local chain, start `anvil`, deploy with `forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast`, and pick the Localhost network in the app. See [`contracts/STARTUP.txt`](contracts/STARTUP.txt) for the full walkthrough.

> **Note:** The frontend is pinned to wagmi 2 until RainbowKit supports wagmi 3. The remaining `npm audit` warnings come from wagmi 2's connectors, so don't run `npm audit fix --force`.

## Deploying to Base Sepolia

```bash
cd contracts
cp .env.example .env   # fill in PRIVATE_KEY, BASE_SEPOLIA_RPC_URL, ETHERSCAN_API_KEY
source .env
forge script script/DeployBaseSepolia.s.sol --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
```

This deploys the DEX, seeds the ETH/PROTO and PROTO/USDC pools, deploys the Governor, Timelock, Treasury and PROTO faucet, and hands the Factory to the Timelock. Set `WETH`, `PROTO` and `USDC` to reuse existing token contracts, and `OLD_ROUTER` to first withdraw your liquidity from a previous deployment.

Then copy the logged addresses into `CONTRACT_ADDRESSES[84532]` in `frontend/src/config/wagmi.js`. Vercel redeploys the frontend on every push to `main`.

The governance timings (1-minute voting delay, 1-hour vote, 5-minute timelock, 0.001% quorum) are deliberately short so visitors can see a proposal through. A mainnet deployment would use days and a much higher quorum.

## Disclaimer

This is a learning and portfolio project. The contracts have not been audited and should not hold real funds.

## License

[MIT](LICENSE)
