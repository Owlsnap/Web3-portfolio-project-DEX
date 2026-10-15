import { parseAbi, encodeFunctionData, decodeFunctionData, zeroAddress } from 'viem'

export const GOVERNOR_ABI = parseAbi([
  'function proposalCount() view returns (uint256)',
  'function proposalDetailsAt(uint256 index) view returns (uint256 proposalId, address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash)',
  'function proposalDescriptions(uint256 proposalId) view returns (string)',
  'function state(uint256 proposalId) view returns (uint8)',
  'function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)',
  'function proposalSnapshot(uint256 proposalId) view returns (uint256)',
  'function proposalDeadline(uint256 proposalId) view returns (uint256)',
  'function proposalEta(uint256 proposalId) view returns (uint256)',
  'function proposalProposer(uint256 proposalId) view returns (address)',
  'function hasVoted(uint256 proposalId, address account) view returns (bool)',
  'function quorum(uint256 timepoint) view returns (uint256)',
  'function quorumNumerator() view returns (uint256)',
  'function quorumDenominator() view returns (uint256)',
  'function proposalThreshold() view returns (uint256)',
  'function votingDelay() view returns (uint256)',
  'function votingPeriod() view returns (uint256)',
  'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)',
  'function castVote(uint256 proposalId, uint8 support) returns (uint256)',
  'function queue(uint256 proposalId)',
  'function execute(uint256 proposalId) payable',
  'error GovernorInsufficientProposerVotes(address proposer, uint256 votes, uint256 threshold)',
  'error GovernorUnexpectedProposalState(uint256 proposalId, uint8 current, bytes32 expectedStates)',
  'error GovernorAlreadyCastVote(address voter)',
  'error GovernorOnlyProposer(address account)',
])

export const VOTES_TOKEN_ABI = parseAbi([
  'function balanceOf(address account) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function getVotes(address account) view returns (uint256)',
  'function getPastVotes(address account, uint256 timepoint) view returns (uint256)',
  'function delegates(address account) view returns (address)',
  'function delegate(address delegatee)',
])

export const FACTORY_GOVERNANCE_ABI = parseAbi([
  'function tradingFee() view returns (uint256)',
  'function flashLoanFee() view returns (uint256)',
  'function feeTo() view returns (address)',
  'function owner() view returns (address)',
  'function setTradingFee(uint256 _tradingFee)',
  'function setFlashLoanFee(uint256 _flashLoanFee)',
  'function setFeeTo(address _feeTo)',
])

export const TIMELOCK_ABI = parseAbi([
  'function getMinDelay() view returns (uint256)',
])

export const TOKEN_FAUCET_ABI = parseAbi([
  'function claim()',
  'function nextClaimAt(address account) view returns (uint256)',
  'function dripAmount() view returns (uint256)',
])

// OpenZeppelin IGovernor.ProposalState
export const PROPOSAL_STATES = [
  'Pending', 'Active', 'Canceled', 'Defeated', 'Succeeded', 'Queued', 'Expired', 'Executed',
]

export const VOTE = { against: 0, for: 1, abstain: 2 }

// Fees are stored in basis points (30 = 0.30%)
export const formatBps = (bps) => `${(Number(bps) / 100).toFixed(2)}%`

/**
 * Proposal templates offered in the UI. Each builds a single call executed by the timelock.
 * Ranges match the require() checks in Factory.sol so proposals can't fail at execution.
 */
export const PROPOSAL_TEMPLATES = [
  {
    id: 'tradingFee',
    label: 'Change trading fee',
    inputLabel: 'New trading fee (%)',
    min: 0.05,
    max: 1,
    step: 0.01,
    build: ({ factory, value }) => ({
      target: factory,
      calldata: encodeFunctionData({
        abi: FACTORY_GOVERNANCE_ABI,
        functionName: 'setTradingFee',
        args: [BigInt(Math.round(value * 100))],
      }),
    }),
  },
  {
    id: 'flashLoanFee',
    label: 'Change flash loan fee',
    inputLabel: 'New flash loan fee (%)',
    min: 0.01,
    max: 0.5,
    step: 0.01,
    build: ({ factory, value }) => ({
      target: factory,
      calldata: encodeFunctionData({
        abi: FACTORY_GOVERNANCE_ABI,
        functionName: 'setFlashLoanFee',
        args: [BigInt(Math.round(value * 100))],
      }),
    }),
  },
  {
    id: 'protocolFee',
    label: 'Turn protocol fee on/off',
    build: ({ factory, treasury, enabled }) => ({
      target: factory,
      calldata: encodeFunctionData({
        abi: FACTORY_GOVERNANCE_ABI,
        functionName: 'setFeeTo',
        args: [enabled ? treasury : zeroAddress],
      }),
    }),
  },
]

/**
 * Human-readable summary of a proposal action, e.g. "Set trading fee to 0.10%"
 */
export function describeAction(target, calldata, { factory, treasury }) {
  if (target?.toLowerCase() !== factory?.toLowerCase()) return `Call ${target}`
  try {
    const { functionName, args } = decodeFunctionData({ abi: FACTORY_GOVERNANCE_ABI, data: calldata })
    if (functionName === 'setTradingFee') return `Set trading fee to ${formatBps(args[0])}`
    if (functionName === 'setFlashLoanFee') return `Set flash loan fee to ${formatBps(args[0])}`
    if (functionName === 'setFeeTo') {
      if (args[0] === zeroAddress) return 'Turn the protocol fee off'
      if (args[0].toLowerCase() === treasury?.toLowerCase()) return 'Send the protocol fee to the treasury'
      return `Send the protocol fee to ${args[0]}`
    }
    return functionName
  } catch {
    return 'Unknown action'
  }
}

/**
 * Pull a readable message out of a wagmi/viem error, preferring decoded contract errors
 */
export function errorMessage(err) {
  const name = err?.cause?.data?.errorName ?? err?.data?.errorName
  const known = {
    GovernorInsufficientProposerVotes: 'You need more voting power to create a proposal. Delegate your PROTO first.',
    GovernorUnexpectedProposalState: 'The proposal is not in the right state for this (or an identical proposal already exists).',
    GovernorAlreadyCastVote: 'You already voted on this proposal.',
  }
  if (name && known[name]) return known[name]
  if (err?.shortMessage?.includes('User rejected') || err?.name === 'UserRejectedRequestError') return 'Transaction rejected in wallet.'
  if (err?.shortMessage?.includes('cooldown') || err?.message?.includes('cooldown')) return 'You already claimed today. Try again in 24 hours.'
  return err?.shortMessage ?? err?.message ?? 'Transaction failed'
}
