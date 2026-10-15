import { CONTRACT_ADDRESSES } from './wagmi'

export const GITHUB_URL = 'https://github.com/Owlsnap/Web3-portfolio-project-DEX'
export const GITHUB_README_URL = `${GITHUB_URL}#readme`
// Chainlink's faucet; Coinbase's developer-platform faucet page no longer exists
export const BASE_SEPOLIA_FAUCET_URL = 'https://faucets.chain.link/base-sepolia'
export const BASESCAN_URL = 'https://sepolia.basescan.org'

const deployed = CONTRACT_ADDRESSES[84532]

// Verified Base Sepolia contracts, shown in the About popup and footer
export const VERIFIED_CONTRACTS = [
  { name: 'Router',     address: deployed.router },
  { name: 'Factory',    address: deployed.factory },
  { name: 'WETH',       address: deployed.weth },
  { name: 'PROTO',      address: deployed.dexToken },
  { name: 'Mock USDC',  address: deployed.mockUsdc },
]

export const basescanCodeUrl = (address) => `${BASESCAN_URL}/address/${address}#code`
