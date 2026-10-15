import { Box, HStack, Text, chakra } from '@chakra-ui/react'
import { useAccount, useChainId, useSwitchChain } from 'wagmi'
import { baseSepolia } from 'wagmi/chains'
import { SUPPORTED_CHAIN_IDS } from '../config/wagmi'
import { BASE_SEPOLIA_FAUCET_URL } from '../config/links'

const A = chakra('a')

const BannerButton = chakra('button', {
  base: {
    px: 3,
    h: '28px',
    display: 'inline-flex',
    alignItems: 'center',
    borderRadius: '8px',
    fontSize: '13px',
    fontWeight: '600',
    cursor: 'pointer',
    whiteSpace: 'nowrap',
    _disabled: { opacity: 0.6, cursor: 'not-allowed' },
  },
})

export function TestnetBanner({ onOpenAbout }) {
  const { isConnected } = useAccount()
  const chainId = useChainId()
  const { switchChain, isPending } = useSwitchChain()

  if (isConnected && !SUPPORTED_CHAIN_IDS.includes(chainId)) {
    return (
      <Box bg="rgba(220, 20, 60, 0.9)" py={2} px={4}>
        <HStack justify="center" gap={3} flexWrap="wrap">
          <Text fontSize="14px" fontWeight="600" color="white">
            Unsupported network. ProtoSwap runs on Base Sepolia.
          </Text>
          <BannerButton
            bg="white"
            color="#B71C1C"
            onClick={() => switchChain({ chainId: baseSepolia.id })}
            disabled={isPending}
          >
            {isPending ? 'Switching…' : 'Switch to Base Sepolia'}
          </BannerButton>
        </HStack>
      </Box>
    )
  }

  return (
    <Box bg="rgba(255, 215, 0, 0.1)" borderBottom="1px solid rgba(255, 215, 0, 0.25)" py={2} px={4}>
      <HStack justify="center" gap={3} flexWrap="wrap">
        <Text fontSize="14px" color="#FFD700" textAlign="center">
          Testnet demo on <b>Base Sepolia</b>. Tokens are free and have no real value.{' '}
          <A
            href={BASE_SEPOLIA_FAUCET_URL}
            target="_blank"
            rel="noopener noreferrer"
            color="#FFD700"
            textDecoration="underline"
            _hover={{ color: 'white' }}
          >
            Get test ETH
          </A>
        </Text>
        <BannerButton
          bg="transparent"
          color="#FFD700"
          border="1px solid rgba(255, 215, 0, 0.5)"
          _hover={{ bg: 'rgba(255, 215, 0, 0.15)' }}
          onClick={onOpenAbout}
        >
          How it works
        </BannerButton>
      </HStack>
    </Box>
  )
}
