import { useState, useEffect } from 'react'
import { Box, VStack, HStack, Text, chakra } from '@chakra-ui/react'
import { FaLandmark, FaExclamationTriangle } from 'react-icons/fa'
import { useAccount, useBlock, useChainId, useReadContracts, useWriteContract } from 'wagmi'
import { waitForTransactionReceipt } from 'wagmi/actions'
import { formatUnits, zeroAddress } from 'viem'
import { config, CONTRACT_ADDRESSES } from '../config/wagmi'
import { BASESCAN_URL } from '../config/links'
import {
  GOVERNOR_ABI,
  VOTES_TOKEN_ABI,
  FACTORY_GOVERNANCE_ABI,
  TIMELOCK_ABI,
  TOKEN_FAUCET_ABI,
  PROPOSAL_STATES,
  PROPOSAL_TEMPLATES,
  VOTE,
  formatBps,
  describeAction,
  errorMessage,
} from '../config/governance'
import { toaster } from './ui/toaster'

const Button = chakra('button', {
  base: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
    borderRadius: '12px',
    fontWeight: '600',
    cursor: 'pointer',
    px: 4,
    h: '40px',
    fontSize: '14px',
    bg: '#DC143C',
    color: 'white',
    _hover: { bg: '#B71C1C' },
    _disabled: { bg: '#393939', color: 'rgba(255,255,255,0.4)', cursor: 'not-allowed' },
  },
})
const Input = chakra('input')
const Textarea = chakra('textarea')
const A = chakra('a')

const MAX_PROPOSALS_SHOWN = 10
const REFRESH_MS = 15_000

const fieldStyles = {
  w: 'full',
  px: 3,
  py: 2,
  borderRadius: '12px',
  bg: 'rgba(255,255,255,0.06)',
  border: '1px solid rgba(255,255,255,0.12)',
  color: 'white',
  fontSize: '14px',
  _focus: { outline: 'none', borderColor: '#FFD700' },
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

const fmtProto = (wei) =>
  wei === undefined ? '…' : Number(formatUnits(wei, 18)).toLocaleString(undefined, { maximumFractionDigits: 0 })

function fmtDuration(seconds) {
  const s = Math.max(0, Math.round(Number(seconds)))
  if (s < 60) return `${s}s`
  if (s < 3600) return `${Math.floor(s / 60)}m ${String(s % 60).padStart(2, '0')}s`
  if (s < 86400) return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`
  return `${Math.floor(s / 86400)}d ${Math.floor((s % 86400) / 3600)}h`
}

// Current chain time in seconds, ticking every second. Governance deadlines are block
// timestamps, so the local clock is corrected by its offset from the latest block.
function useChainNow() {
  const wallClock = () => Math.floor(Date.now() / 1000)
  const [now, setNow] = useState(wallClock)
  const { data: block } = useBlock({ query: { refetchInterval: 60_000 } })
  const [offset, setOffset] = useState(0)

  useEffect(() => {
    if (block) setOffset(Number(block.timestamp) - wallClock())
  }, [block])

  useEffect(() => {
    const id = setInterval(() => setNow(wallClock()), 1000)
    return () => clearInterval(id)
  }, [])
  return now + offset
}

// Sends a transaction, shows toasts, waits for the receipt and refreshes on-chain data.
// Resolves to true when the transaction confirmed successfully.
function useTx(onConfirmed) {
  const { writeContractAsync } = useWriteContract()
  const [pending, setPending] = useState(null)

  const send = async (key, label, request) => {
    setPending(key)
    try {
      const hash = await writeContractAsync(request)
      toaster.create({ title: `${label} submitted`, description: 'Waiting for confirmation…', type: 'info', duration: 4000 })
      const receipt = await waitForTransactionReceipt(config, { hash })
      if (receipt.status !== 'success') throw new Error('Transaction reverted')
      toaster.create({ title: `${label} confirmed`, type: 'success', duration: 4000 })
      onConfirmed?.()
      return true
    } catch (err) {
      toaster.create({ title: `${label} failed`, description: errorMessage(err), type: 'error', duration: 6000 })
      return false
    } finally {
      setPending(null)
    }
  }
  return { send, pending }
}

function Card({ children, ...props }) {
  return (
    <Box p={4} borderRadius="18px" bg="rgba(255, 255, 255, 0.06)" border="1px solid rgba(255, 255, 255, 0.12)" {...props}>
      {children}
    </Box>
  )
}

function SectionTitle({ children }) {
  return (
    <Text fontSize="13px" fontWeight="700" color="#FFD700" textTransform="uppercase" letterSpacing="0.06em" mb={2}>
      {children}
    </Text>
  )
}

function Stat({ label, value }) {
  return (
    <HStack justify="space-between" fontSize="14px">
      <Text color="rgba(255,255,255,0.6)">{label}</Text>
      <Text color="white" fontWeight="600" textAlign="right">{value}</Text>
    </HStack>
  )
}

// ─── Entry point ───────────────────────────────────────────────────────────────

export function GovernanceInterface() {
  const chainId = useChainId()
  const contracts = CONTRACT_ADDRESSES[chainId]

  return (
    <Box
      w="full"
      maxW="420px"
      mx="auto"
      p={5}
      borderRadius="24px"
      border="1px"
      borderColor="rgba(255, 255, 255, 0.12)"
      bg="#1F1F1F"
      shadow="0px 12px 48px rgba(0, 0, 0, 0.3)"
    >
      <VStack gap={4} align="stretch">
        <HStack justify="space-between">
          <Text fontSize="22px" fontWeight="700" color="white">Governance</Text>
          <FaLandmark color="#DC143C" size="20px" />
        </HStack>

        {contracts?.governor ? (
          <Governance contracts={contracts} />
        ) : (
          <Box p={3} borderRadius="12px" bg="rgba(255,255,255,0.06)">
            <Text fontSize="14px" color="rgba(255,255,255,0.6)" textAlign="center">
              Governance isn't deployed on this network yet.
            </Text>
          </Box>
        )}
      </VStack>
    </Box>
  )
}

function Governance({ contracts }) {
  const { address } = useAccount()
  const now = useChainNow()
  const { factory, governor, timelock, treasury, dexToken, protoFaucet } = contracts

  const { data: overview, refetch: refetchOverview } = useReadContracts({
    contracts: [
      { address: factory, abi: FACTORY_GOVERNANCE_ABI, functionName: 'tradingFee' },
      { address: factory, abi: FACTORY_GOVERNANCE_ABI, functionName: 'flashLoanFee' },
      { address: factory, abi: FACTORY_GOVERNANCE_ABI, functionName: 'feeTo' },
      { address: governor, abi: GOVERNOR_ABI, functionName: 'proposalThreshold' },
      { address: governor, abi: GOVERNOR_ABI, functionName: 'votingDelay' },
      { address: governor, abi: GOVERNOR_ABI, functionName: 'votingPeriod' },
      { address: governor, abi: GOVERNOR_ABI, functionName: 'quorumNumerator' },
      { address: governor, abi: GOVERNOR_ABI, functionName: 'quorumDenominator' },
      { address: dexToken, abi: VOTES_TOKEN_ABI, functionName: 'totalSupply' },
      { address: timelock, abi: TIMELOCK_ABI, functionName: 'getMinDelay' },
      { address: governor, abi: GOVERNOR_ABI, functionName: 'proposalCount' },
    ],
    query: { refetchInterval: REFRESH_MS },
  })
  const [tradingFee, flashLoanFee, feeTo, threshold, votingDelay, votingPeriod, quorumNum, quorumDen, totalSupply, timelockDelay, proposalCount] =
    (overview ?? []).map((r) => r?.result)

  const { data: account, refetch: refetchAccount } = useReadContracts({
    contracts: [
      { address: dexToken, abi: VOTES_TOKEN_ABI, functionName: 'balanceOf', args: [address] },
      { address: dexToken, abi: VOTES_TOKEN_ABI, functionName: 'getVotes', args: [address] },
      { address: dexToken, abi: VOTES_TOKEN_ABI, functionName: 'delegates', args: [address] },
      ...(protoFaucet
        ? [{ address: protoFaucet, abi: TOKEN_FAUCET_ABI, functionName: 'nextClaimAt', args: [address] }]
        : []),
    ],
    query: { enabled: Boolean(address), refetchInterval: REFRESH_MS },
  })
  const [balance, votes, delegatee, nextClaimAt] = (account ?? []).map((r) => r?.result)

  const refreshAll = () => {
    refetchOverview()
    refetchAccount()
  }
  const tx = useTx(refreshAll)

  const quorumVotes = totalSupply !== undefined && quorumNum !== undefined && quorumDen
    ? (totalSupply * quorumNum) / quorumDen
    : undefined
  const protocolFeeOn = feeTo !== undefined && feeTo !== zeroAddress
  const isDelegated = delegatee && address && delegatee.toLowerCase() === address.toLowerCase()
  const canPropose = votes !== undefined && threshold !== undefined && votes >= threshold

  return (
    <>
      <Box p={3} borderRadius="12px" bg="rgba(255, 215, 0, 0.1)" border="1px solid rgba(255, 215, 0, 0.25)">
        <Text fontSize="13px" color="#FFD700">
          PROTO holders control the DEX's fees. Claim PROTO, activate your votes, then create or vote on a proposal.
          Voting opens {votingDelay !== undefined ? fmtDuration(votingDelay) : '…'} after a proposal is created and
          lasts {votingPeriod !== undefined ? fmtDuration(votingPeriod) : '…'}. Passed proposals wait
          {timelockDelay !== undefined ? ` ${fmtDuration(timelockDelay)}` : ''} in the timelock before anyone can execute them.
        </Text>
      </Box>

      {/* Current parameters */}
      <Card>
        <SectionTitle>Protocol parameters</SectionTitle>
        <VStack align="stretch" gap={1.5}>
          <Stat label="Trading fee" value={tradingFee !== undefined ? formatBps(tradingFee) : '…'} />
          <Stat label="Flash loan fee" value={flashLoanFee !== undefined ? formatBps(flashLoanFee) : '…'} />
          <Stat
            label="Protocol fee"
            value={feeTo === undefined ? '…' : protocolFeeOn ? '1/6 of trading fees → treasury' : 'Off'}
          />
          <Stat label="Quorum" value={quorumVotes !== undefined ? `${fmtProto(quorumVotes)} PROTO` : '…'} />
          <Stat label="Needed to propose" value={threshold !== undefined ? `${fmtProto(threshold)} PROTO` : '…'} />
        </VStack>
        <HStack gap={3} mt={3} fontSize="12px" flexWrap="wrap">
          {[['Governor', governor], ['Timelock', timelock], ['Treasury', treasury]].map(([name, addr]) => (
            <A key={name} href={`${BASESCAN_URL}/address/${addr}#code`} target="_blank" rel="noopener noreferrer"
              color="rgba(255,255,255,0.5)" _hover={{ color: '#FFD700' }}>
              {name} ↗
            </A>
          ))}
        </HStack>
      </Card>

      {/* Voting power */}
      <Card>
        <SectionTitle>Your voting power</SectionTitle>
        {!address ? (
          <HStack gap={2}>
            <FaExclamationTriangle color="#DC143C" />
            <Text fontSize="14px" color="#DC143C">Connect your wallet to take part</Text>
          </HStack>
        ) : (
          <VStack align="stretch" gap={3}>
            <Stat label="PROTO balance" value={fmtProto(balance)} />
            <Stat label="Active votes" value={fmtProto(votes)} />

            {protoFaucet && (
              <Button
                bg="transparent"
                border="1px solid rgba(255, 215, 0, 0.5)"
                color="#FFD700"
                _hover={{ bg: 'rgba(255, 215, 0, 0.12)' }}
                disabled={tx.pending !== null || (nextClaimAt !== undefined && nextClaimAt > 0n)}
                onClick={() => tx.send('claim', 'PROTO claim', { address: protoFaucet, abi: TOKEN_FAUCET_ABI, functionName: 'claim' })}
              >
                {tx.pending === 'claim'
                  ? 'Claiming…'
                  : nextClaimAt > 0n
                    ? `Next PROTO claim in ${fmtDuration(Number(nextClaimAt) - now)}`
                    : 'Claim 10,000 PROTO'}
              </Button>
            )}

            {balance > 0n && !isDelegated && (
              <>
                <Button
                  disabled={tx.pending !== null}
                  onClick={() => tx.send('delegate', 'Vote activation', {
                    address: dexToken, abi: VOTES_TOKEN_ABI, functionName: 'delegate', args: [address],
                  })}
                >
                  {tx.pending === 'delegate' ? 'Activating…' : 'Activate my votes'}
                </Button>
                <Text fontSize="12px" color="rgba(255,255,255,0.5)">
                  Tokens only count as votes once delegated (here, to yourself). Proposals created before you
                  activate can't use these votes.
                </Text>
              </>
            )}
          </VStack>
        )}
      </Card>

      {address && (
        <NewProposal
          contracts={contracts}
          canPropose={canPropose}
          threshold={threshold}
          protocolFeeOn={protocolFeeOn}
          tx={tx}
        />
      )}

      <ProposalList
        contracts={contracts}
        count={proposalCount}
        account={address}
        now={now}
        tx={tx}
      />
    </>
  )
}

// ─── New proposal form ─────────────────────────────────────────────────────────

function NewProposal({ contracts, canPropose, threshold, protocolFeeOn, tx }) {
  const [open, setOpen] = useState(false)
  const [templateId, setTemplateId] = useState(PROPOSAL_TEMPLATES[0].id)
  const [value, setValue] = useState('')
  const [reason, setReason] = useState('')

  const template = PROPOSAL_TEMPLATES.find((t) => t.id === templateId)
  const numeric = Number(value)
  const valueValid = template.id === 'protocolFee' || (value !== '' && numeric >= template.min && numeric <= template.max)

  const action = valueValid
    ? template.build({ factory: contracts.factory, treasury: contracts.treasury, value: numeric, enabled: !protocolFeeOn })
    : null
  const summary = action ? describeAction(action.target, action.calldata, contracts) : null

  const submit = async () => {
    const description = reason.trim() ? `${summary}\n\n${reason.trim()}` : summary
    const ok = await tx.send('propose', 'Proposal', {
      address: contracts.governor,
      abi: GOVERNOR_ABI,
      functionName: 'propose',
      args: [[action.target], [0n], [action.calldata], description],
    })
    if (!ok) return
    setValue('')
    setReason('')
    setOpen(false)
  }

  if (!open) {
    return (
      <Button onClick={() => setOpen(true)} h="46px" fontSize="15px">
        New proposal
      </Button>
    )
  }

  return (
    <Card>
      <SectionTitle>New proposal</SectionTitle>
      <VStack align="stretch" gap={3}>
        <HStack gap={2} flexWrap="wrap">
          {PROPOSAL_TEMPLATES.map((t) => (
            <Button
              key={t.id}
              h="34px"
              px={3}
              fontSize="13px"
              bg={t.id === templateId ? '#DC143C' : 'rgba(255,255,255,0.06)'}
              color={t.id === templateId ? 'white' : 'rgba(255,255,255,0.8)'}
              _hover={{ bg: t.id === templateId ? '#B71C1C' : 'rgba(255,255,255,0.12)' }}
              onClick={() => { setTemplateId(t.id); setValue('') }}
            >
              {t.label}
            </Button>
          ))}
        </HStack>

        {template.id === 'protocolFee' ? (
          <Text fontSize="14px" color="rgba(255,255,255,0.8)">
            The protocol fee is currently <b>{protocolFeeOn ? 'on' : 'off'}</b>. This proposal turns it{' '}
            <b>{protocolFeeOn ? 'off' : 'on'}</b>{protocolFeeOn ? '' : ', sending 1/6 of trading fees to the treasury'}.
          </Text>
        ) : (
          <Box>
            <Text fontSize="13px" color="rgba(255,255,255,0.6)" mb={1}>
              {template.inputLabel}, between {template.min}% and {template.max}%
            </Text>
            <Input
              {...fieldStyles}
              type="number"
              inputMode="decimal"
              min={template.min}
              max={template.max}
              step={template.step}
              placeholder={`e.g. ${template.min}`}
              value={value}
              onChange={(e) => setValue(e.target.value)}
            />
          </Box>
        )}

        <Textarea
          {...fieldStyles}
          rows={2}
          placeholder="Why? (optional)"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
        />

        {summary && (
          <Text fontSize="13px" color="#FFD700">Proposal: {summary}</Text>
        )}
        {!canPropose && (
          <Text fontSize="13px" color="rgba(255,255,255,0.6)">
            You need at least {fmtProto(threshold)} active votes to propose. Claim PROTO and activate your votes above.
          </Text>
        )}

        <HStack gap={2}>
          <Button
            flex="1"
            bg="rgba(255,255,255,0.06)"
            _hover={{ bg: 'rgba(255,255,255,0.12)' }}
            onClick={() => setOpen(false)}
          >
            Cancel
          </Button>
          <Button flex="2" disabled={!action || !canPropose || tx.pending !== null} onClick={submit}>
            {tx.pending === 'propose' ? 'Submitting…' : 'Submit proposal'}
          </Button>
        </HStack>
      </VStack>
    </Card>
  )
}

// ─── Proposal list ─────────────────────────────────────────────────────────────

function ProposalList({ contracts, count, account, now, tx }) {
  const total = count !== undefined ? Number(count) : 0
  const indexes = Array.from({ length: Math.min(total, MAX_PROPOSALS_SHOWN) }, (_, i) => total - 1 - i)

  const { data: details } = useReadContracts({
    contracts: indexes.map((i) => ({
      address: contracts.governor, abi: GOVERNOR_ABI, functionName: 'proposalDetailsAt', args: [BigInt(i)],
    })),
    query: { enabled: total > 0 },
  })

  return (
    <Box>
      <SectionTitle>Proposals</SectionTitle>
      {count === undefined ? (
        <Text fontSize="14px" color="rgba(255,255,255,0.5)">Loading…</Text>
      ) : total === 0 ? (
        <Card>
          <Text fontSize="14px" color="rgba(255,255,255,0.6)" textAlign="center">
            No proposals yet. Be the first!
          </Text>
        </Card>
      ) : (
        <VStack align="stretch" gap={3}>
          {indexes.map((index, i) => {
            const d = details?.[i]?.result
            return d ? (
              <ProposalCard
                key={d[0].toString()}
                number={index + 1}
                proposalId={d[0]}
                targets={d[1]}
                calldatas={d[3]}
                contracts={contracts}
                account={account}
                now={now}
                tx={tx}
              />
            ) : null
          })}
          {total > MAX_PROPOSALS_SHOWN && (
            <Text fontSize="12px" color="rgba(255,255,255,0.4)" textAlign="center">
              Showing the latest {MAX_PROPOSALS_SHOWN} of {total} proposals
            </Text>
          )}
        </VStack>
      )}
    </Box>
  )
}

const STATE_COLORS = {
  Pending: '#9f7aea',
  Active: '#4299e1',
  Succeeded: '#48bb78',
  Queued: '#FFD700',
  Executed: '#48bb78',
  Defeated: '#DC143C',
  Canceled: 'rgba(255,255,255,0.4)',
  Expired: 'rgba(255,255,255,0.4)',
}

function ProposalCard({ number, proposalId, targets, calldatas, contracts, account, now, tx }) {
  const g = { address: contracts.governor, abi: GOVERNOR_ABI }

  const { data, refetch } = useReadContracts({
    contracts: [
      { ...g, functionName: 'state', args: [proposalId] },
      { ...g, functionName: 'proposalVotes', args: [proposalId] },
      { ...g, functionName: 'proposalSnapshot', args: [proposalId] },
      { ...g, functionName: 'proposalDeadline', args: [proposalId] },
      { ...g, functionName: 'proposalEta', args: [proposalId] },
      { ...g, functionName: 'proposalDescriptions', args: [proposalId] },
    ],
    query: { refetchInterval: REFRESH_MS },
  })
  const [stateIndex, tally, snapshot, deadline, eta, description] = (data ?? []).map((r) => r?.result)

  // Quorum and the voter's weight are measured at the snapshot, which can only be read once it has passed
  const snapshotPassed = snapshot !== undefined && Number(snapshot) < now
  const { data: quorumData } = useReadContracts({
    contracts: [{ ...g, functionName: 'quorum', args: [snapshot] }],
    query: { enabled: snapshotPassed },
  })
  const quorum = quorumData?.[0]?.result
  const { data: voterData, refetch: refetchVoter } = useReadContracts({
    contracts: [
      { address: contracts.dexToken, abi: VOTES_TOKEN_ABI, functionName: 'getPastVotes', args: [account, snapshot] },
      { ...g, functionName: 'hasVoted', args: [proposalId, account] },
    ],
    query: { enabled: snapshotPassed && Boolean(account), refetchInterval: REFRESH_MS },
  })
  const [myWeight, hasVoted] = (voterData ?? []).map((r) => r?.result)

  if (stateIndex === undefined) return null

  const state = PROPOSAL_STATES[stateIndex]
  const [against = 0n, forVotes = 0n, abstain = 0n] = tally ?? []
  const totalVotes = against + forVotes + abstain
  const title = description?.split('\n')[0] || describeAction(targets[0], calldatas[0], contracts)
  const reason = description?.split('\n').slice(2).join('\n')
  const actionSummary = describeAction(targets[0], calldatas[0], contracts)
  const quorumReached = quorum !== undefined && forVotes + abstain >= quorum

  const refresh = () => { refetch(); refetchVoter() }
  const send = (key, label, request) => tx.send(`${proposalId}-${key}`, label, request).then(refresh)
  const isPending = (key) => tx.pending === `${proposalId}-${key}`

  const pct = (v) => (totalVotes > 0n ? Number((v * 10000n) / totalVotes) / 100 : 0)

  let timing = null
  if (state === 'Pending') timing = `Voting opens in ${fmtDuration(Number(snapshot) - now)}`
  if (state === 'Active') timing = `Voting ends in ${fmtDuration(Number(deadline) - now)}`
  if (state === 'Succeeded') timing = 'Passed. Queue it to start the timelock.'
  if (state === 'Queued') timing = Number(eta) > now ? `Executable in ${fmtDuration(Number(eta) - now)}` : 'Ready to execute'
  if (state === 'Defeated') timing = quorumReached ? 'Rejected by vote' : 'Did not reach quorum'

  return (
    <Card>
      <HStack justify="space-between" align="start" gap={3}>
        <Text fontSize="15px" fontWeight="700" color="white">#{number} {title}</Text>
        <Box
          px={2}
          py={0.5}
          borderRadius="8px"
          fontSize="12px"
          fontWeight="700"
          whiteSpace="nowrap"
          color={STATE_COLORS[state]}
          border={`1px solid ${STATE_COLORS[state]}`}
        >
          {state}
        </Box>
      </HStack>
      {title !== actionSummary && (
        <Text fontSize="13px" color="rgba(255,255,255,0.6)" mt={1}>Action: {actionSummary}</Text>
      )}
      {reason && <Text fontSize="13px" color="rgba(255,255,255,0.7)" mt={1} whiteSpace="pre-wrap">{reason}</Text>}

      {/* Vote tally */}
      <VStack align="stretch" gap={1} mt={3}>
        {[['For', forVotes, '#48bb78'], ['Against', against, '#DC143C'], ['Abstain', abstain, 'rgba(255,255,255,0.4)']].map(([label, v, color]) => (
          <Box key={label}>
            <HStack justify="space-between" fontSize="12px" color="rgba(255,255,255,0.7)">
              <Text>{label}</Text>
              <Text>{fmtProto(v)} ({pct(v)}%)</Text>
            </HStack>
            <Box h="4px" borderRadius="2px" bg="rgba(255,255,255,0.08)">
              <Box h="4px" borderRadius="2px" bg={color} w={`${pct(v)}%`} />
            </Box>
          </Box>
        ))}
        {quorum !== undefined && (
          <Text fontSize="12px" color={quorumReached ? '#48bb78' : 'rgba(255,255,255,0.5)'}>
            Quorum: {fmtProto(forVotes + abstain)} / {fmtProto(quorum)} PROTO {quorumReached ? '✓' : ''}
          </Text>
        )}
      </VStack>

      {timing && <Text fontSize="13px" color="rgba(255,255,255,0.6)" mt={2}>{timing}</Text>}

      {/* Actions */}
      {state === 'Active' && account && (
        hasVoted ? (
          <Text fontSize="13px" color="#FFD700" mt={2}>You voted on this proposal.</Text>
        ) : myWeight === 0n ? (
          <Text fontSize="13px" color="rgba(255,255,255,0.5)" mt={2}>
            You had no active votes when this proposal was created, so you can't vote on it.
          </Text>
        ) : (
          <HStack gap={2} mt={3}>
            {[['For', VOTE.for, '#2f855a', '#276749'], ['Against', VOTE.against, '#DC143C', '#B71C1C'], ['Abstain', VOTE.abstain, '#4a4a4a', '#3a3a3a']].map(([label, support, bg, hover]) => (
              <Button
                key={label}
                flex="1"
                h="36px"
                bg={bg}
                _hover={{ bg: hover }}
                disabled={tx.pending !== null}
                onClick={() => send(`vote-${support}`, `Vote ${label}`, { ...g, functionName: 'castVote', args: [proposalId, support] })}
              >
                {isPending(`vote-${support}`) ? '…' : label}
              </Button>
            ))}
          </HStack>
        )
      )}
      {state === 'Succeeded' && account && (
        <Button w="full" mt={3} disabled={tx.pending !== null}
          onClick={() => send('queue', 'Queue', { ...g, functionName: 'queue', args: [proposalId] })}>
          {isPending('queue') ? 'Queueing…' : 'Queue for execution'}
        </Button>
      )}
      {state === 'Queued' && account && (
        <Button w="full" mt={3} disabled={tx.pending !== null || Number(eta) > now}
          onClick={() => send('execute', 'Execute', { ...g, functionName: 'execute', args: [proposalId] })}>
          {isPending('execute') ? 'Executing…' : 'Execute'}
        </Button>
      )}
    </Card>
  )
}
