import { http } from 'wagmi'
import { mainnet, hardhat, baseSepolia } from 'wagmi/chains'
import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { getAddress } from 'viem'

const WALLETCONNECT_PROJECT_ID = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID
const BASE_SEPOLIA_RPC = import.meta.env.VITE_BASE_SEPOLIA_RPC || 'https://sepolia.base.org'

// ─── Contract Addresses ───────────────────────────────────────────────────────
// After running DeployBaseSepolia.s.sol, paste the logged addresses into the
// 84532 block below, then redeploy the frontend.

export const CONTRACT_ADDRESSES = {
  // Base Sepolia (chainId 84532) — update after deployment
  84532: {
    factory:  getAddress('0x43F2994dAF377A52F31ddBDD8D47D80865375a59'),
    router:   getAddress('0x026113cd45123B5B30B8E7316a019F49fD46c6Ba'),
    weth:     getAddress('0xb0F800aa76233B5d89e31bFE37cDc2CBcC32ad39'),
    dexToken: getAddress('0x599C2c44aAB318D6537A5C873aBa4654A4f87db4'),
    mockUsdc: getAddress('0x7DD41ED04666FFE286f288AB1393bc261c2E0794'),
  },

  // Local Anvil/Hardhat — existing deployment for local dev
  31337: {
    factory:  getAddress('0x5fbdb2315678afecb367f032d93f642f64180aa3'),
    router:   getAddress('0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0'),
    weth:     getAddress('0xe7f1725e7734ce288f8367e1bb143e90bb3f0512'),
    dexToken: getAddress('0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9'),
    mockUsdc: null,
  },
}

export const SUPPORTED_CHAIN_IDS = Object.keys(CONTRACT_ADDRESSES).map(Number)

export const config = getDefaultConfig({
  appName: 'ProtoSwap',
  projectId: WALLETCONNECT_PROJECT_ID || 'd443677fde6c25722cf564b5be924c10',
  chains: [baseSepolia, hardhat, mainnet],
  transports: {
    [baseSepolia.id]: http(BASE_SEPOLIA_RPC),
    [hardhat.id]:    http('http://localhost:8545'),
    [mainnet.id]:    http(),
  },
  ssr: false,
})
