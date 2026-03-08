import { http, createConfig } from 'wagmi'
import { mainnet, sepolia, hardhat } from 'wagmi/chains'
import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { getAddress } from 'viem'

// Vite environment variables (prefixed with VITE_)
const WALLETCONNECT_PROJECT_ID = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID

// Contract addresses - update these when deployed
export const CONTRACT_ADDRESSES = {
  // Local Anvil/Hardhat (default) - Updated with correct deployment addresses from broadcast
  31337: {
    factory: getAddress('0x5fbdb2315678afecb367f032d93f642f64180aa3'),
    router: getAddress('0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0'),
    weth: getAddress('0xe7f1725e7734ce288f8367e1bb143e90bb3f0512'),
    dexToken: getAddress('0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9'),
    governor: getAddress('0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9'),
    timelock: getAddress('0x5FC8d32690cc91D4c39d9d3abcBD16989F875707'),
    treasury: getAddress('0x0165878A594ca255338adfa4d48449f69242Eb8F')
  },
  // Sepolia Testnet
  11155111: {
    factory: '0x...',  // Update when deployed
    router: '0x...',
    weth: '0x...',
    dexToken: '0x...',
    governor: '0x...',
    timelock: '0x...',
    treasury: '0x...'
  }
}

export const config = getDefaultConfig({
  appName: 'ProtoSwap',
  projectId: WALLETCONNECT_PROJECT_ID || 'd443677fde6c25722cf564b5be924c10', // Fallback to ensure we have a project ID
  chains: [hardhat, sepolia, mainnet],
  transports: {
    [hardhat.id]: http('http://localhost:8545'),
    [sepolia.id]: http(),
    [mainnet.id]: http(),
  },
  ssr: false, // Explicitly set SSR to false for client-side apps
})