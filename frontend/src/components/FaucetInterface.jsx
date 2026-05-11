import { useState } from 'react'
import { Box, VStack, HStack, Text } from '@chakra-ui/react'
import { chakra } from '@chakra-ui/react'
import { FaTint, FaCheckCircle, FaExclamationTriangle } from 'react-icons/fa'
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useChainId } from 'wagmi'
import { CONTRACT_ADDRESSES } from '../config/wagmi'
import { toaster } from './ui/toaster'
import USDCLogo from '../assets/usd-coin-usdc-logo.svg'

const Button = chakra('button', {
  base: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 'md',
    fontWeight: 'semibold',
    cursor: 'pointer',
    outline: 'none',
    px: 4,
    py: 2,
    fontSize: 'md',
    _disabled: { opacity: 0.4, cursor: 'not-allowed' },
  },
})

const FAUCET_ABI = [
  {
    name: 'faucet',
    type: 'function',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    name: 'lastFaucetClaim',
    type: 'function',
    inputs: [{ name: '', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
]

const FAUCET_TOKENS = [
  { symbol: 'USDC', name: 'Mock USDC', key: 'mockUsdc', logo: USDCLogo, amount: '1,000' },
]

export function FaucetInterface() {
  const { address } = useAccount()
  const chainId = useChainId()
  const contracts = CONTRACT_ADDRESSES[chainId]
  const { writeContract, data: hash, isPending } = useWriteContract()
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash })
  const [claimingToken, setClaimingToken] = useState(null)

  const handleClaim = async (tokenKey, symbol) => {
    const tokenAddress = contracts?.[tokenKey]
    if (!tokenAddress) return
    setClaimingToken(tokenKey)
    try {
      await writeContract({
        address: tokenAddress,
        abi: FAUCET_ABI,
        functionName: 'faucet',
      })
      toaster.create({
        title: 'Claim submitted',
        description: `Claiming 1,000 ${symbol} — confirm in your wallet`,
        status: 'info',
        duration: 5000,
      })
    } catch (err) {
      const msg = err?.message?.includes('cooldown')
        ? 'You already claimed today. Try again in 24 hours.'
        : err.message
      toaster.create({ title: 'Claim failed', description: msg, status: 'error', duration: 5000 })
    } finally {
      setClaimingToken(null)
    }
  }

  const noTokens = FAUCET_TOKENS.every(t => !contracts?.[t.key])

  return (
    <Box
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
        <HStack justify="space-between" mb={1}>
          <Text fontSize="22px" fontWeight="700" color="white">Test Token Faucet</Text>
          <FaTint color="#DC143C" size="20px" />
        </HStack>

        <Box p={3} borderRadius="12px" bg="rgba(255, 215, 0, 0.1)" border="1px solid rgba(255, 215, 0, 0.25)">
          <Text fontSize="13px" color="#FFD700">
            Claim free test tokens once every 24 hours. Use them to try swapping and adding liquidity.
          </Text>
        </Box>

        {!address && (
          <Box p={3} borderRadius="12px" bg="rgba(220, 20, 60, 0.1)" border="1px solid rgba(220, 20, 60, 0.25)">
            <HStack gap={2}>
              <FaExclamationTriangle color="#DC143C" />
              <Text fontSize="14px" color="#DC143C">Connect your wallet to claim tokens</Text>
            </HStack>
          </Box>
        )}

        {noTokens && (
          <Box p={3} borderRadius="12px" bg="rgba(255,255,255,0.06)">
            <Text fontSize="14px" color="rgba(255,255,255,0.5)" textAlign="center">
              No faucet tokens available on this network.
            </Text>
          </Box>
        )}

        {FAUCET_TOKENS.filter(t => contracts?.[t.key]).map(token => (
          <Box
            key={token.key}
            p={4}
            borderRadius="18px"
            bg="rgba(255, 255, 255, 0.06)"
            border="1px solid rgba(255, 255, 255, 0.12)"
          >
            <HStack justify="space-between">
              <HStack gap={3}>
                <Box w="36px" h="36px">
                  <img src={token.logo} alt={token.symbol} style={{ width: '100%', height: '100%', objectFit: 'contain', borderRadius: '50%' }} />
                </Box>
                <VStack align="start" gap={0}>
                  <Text fontWeight="700" color="white">{token.symbol}</Text>
                  <Text fontSize="13px" color="rgba(255,255,255,0.5)">{token.name}</Text>
                </VStack>
              </HStack>
              <Button
                onClick={() => handleClaim(token.key, token.symbol)}
                disabled={!address || isPending || isConfirming || claimingToken === token.key}
                bg="#DC143C"
                color="white"
                borderRadius="14px"
                h="42px"
                px={5}
                fontSize="15px"
                _hover={{ bg: '#B71C1C' }}
                _disabled={{ bg: '#393939', color: 'rgba(255,255,255,0.4)', cursor: 'not-allowed' }}
              >
                {claimingToken === token.key && (isPending || isConfirming) ? 'Claiming…' : `Claim ${token.amount}`}
              </Button>
            </HStack>
          </Box>
        ))}

        {hash && (
          <Box bg="rgba(255, 215, 0, 0.1)" border="1px solid rgba(255,215,0,0.3)" p={3} borderRadius="14px">
            <HStack gap={2}>
              <FaCheckCircle color="#FFD700" />
              <Text fontSize="13px" color="#FFD700">
                Tx submitted: {hash.slice(0, 10)}…{hash.slice(-8)}
              </Text>
            </HStack>
          </Box>
        )}

        <Box pt={2} borderTop="1px solid rgba(255,255,255,0.08)">
          <Text fontSize="13px" color="rgba(255,255,255,0.4)" textAlign="center">
            Need Base Sepolia ETH?{' '}
            <chakra.a
              href="https://www.coinbase.com/developer-platform/faucet"
              target="_blank"
              rel="noopener noreferrer"
              color="#FFD700"
              textDecoration="underline"
            >
              Get it from the Base faucet
            </chakra.a>
          </Text>
        </Box>
      </VStack>
    </Box>
  )
}
