import { useEffect } from 'react'
import { Box, Button, VStack, HStack, Text, Portal, chakra } from '@chakra-ui/react'
import { FaTimes, FaGithub } from 'react-icons/fa'
import {
  GITHUB_README_URL,
  BASE_SEPOLIA_FAUCET_URL,
  VERIFIED_CONTRACTS,
  basescanCodeUrl,
} from '../config/links'

const A = chakra('a')
const Ol = chakra('ol')
const Ul = chakra('ul')

const Link = (props) => (
  <A target="_blank" rel="noopener noreferrer" color="#FFD700" textDecoration="underline" {...props} />
)

const STEPS = [
  <>Install a wallet such as MetaMask or Rabby and connect it with the button in the top right.</>,
  <>Switch to <b>Base Sepolia</b>. The app offers a one-click switch if you're on another network.</>,
  <>Get free test ETH from the <Link href={BASE_SEPOLIA_FAUCET_URL}>Base Sepolia faucet</Link>.</>,
  <>Claim test USDC and PROTO on the <b>Faucet</b> tab (once every 24 hours).</>,
  <>Swap between ETH, PROTO and USDC, or add liquidity on the <b>Pool</b> tab to earn LP tokens.</>,
  <>On the <b>Govern</b> tab, activate your PROTO votes, then propose fee changes or vote on open proposals.</>,
]

const FEATURES = [
  'Uniswap V2-style constant-product AMM (x · y = k) with a governance-set swap fee (0.3% by default)',
  'Factory, Pair and Router contracts written from scratch in Solidity',
  'Multi-hop routing, native ETH support via WETH, slippage and deadline protection',
  'Flash swaps with their own fee, and an optional protocol fee paid to the treasury',
  'On-chain governance: PROTO holders propose and vote, and a timelock executes the result',
  'Tested with Foundry (unit and fuzz tests); all contracts verified on Basescan',
]

function SectionTitle({ children }) {
  return (
    <Text fontSize="13px" fontWeight="700" color="#FFD700" textTransform="uppercase" letterSpacing="0.06em">
      {children}
    </Text>
  )
}

export function AboutDialog({ isOpen, onClose }) {
  useEffect(() => {
    if (!isOpen) return
    const onKey = (e) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [isOpen, onClose])

  if (!isOpen) return null

  return (
    <Portal>
      <Box
        position="fixed"
        inset="0"
        bg="rgba(6, 5, 20, 0.88)"
        backdropFilter="blur(12px)"
        zIndex={1000}
        display="flex"
        alignItems="flex-start"
        justifyContent="center"
        overflowY="auto"
        py={{ base: 4, md: 16 }}
        px={4}
        onClick={onClose}
      >
        <Box
          role="dialog"
          aria-modal="true"
          aria-labelledby="about-title"
          position="relative"
          w="full"
          maxW="560px"
          p={{ base: 5, md: 7 }}
          borderRadius="24px"
          bg="#1F1F1F"
          border="1px solid rgba(255, 215, 0, 0.2)"
          shadow="0px 12px 48px rgba(0, 0, 0, 0.5)"
          onClick={(e) => e.stopPropagation()}
        >
          <Button
            position="absolute"
            top={4}
            right={4}
            onClick={onClose}
            aria-label="Close"
            bg="rgba(255,255,255,0.08)"
            color="rgba(255, 255, 255, 0.7)"
            _hover={{ bg: 'rgba(255, 255, 255, 0.15)' }}
            borderRadius="12px"
            w="36px"
            h="36px"
            display="flex"
            alignItems="center"
            justifyContent="center"
            minW="36px"
            p={0}
          >
            <FaTimes size={16} color="rgba(255, 255, 255, 0.8)" />
          </Button>

          <VStack align="stretch" gap={5} color="rgba(255,255,255,0.85)" fontSize="15px">
            <Box pr={10}>
              <Text id="about-title" fontSize="24px" fontWeight="700" color="white">
                About ProtoSwap
              </Text>
              <Text mt={2}>
                ProtoSwap is a decentralized exchange I built from the ground up as a portfolio project:
                Solidity smart contracts, Foundry tests, and this React + wagmi frontend. It runs on the
                Base Sepolia testnet, so every token here is free and has no real-world value.
              </Text>
            </Box>

            <VStack align="stretch" gap={2}>
              <SectionTitle>Try it in six steps</SectionTitle>
              <Ol pl={5} listStyleType="decimal" display="flex" flexDir="column" gap={1.5}>
                {STEPS.map((step, i) => <li key={i}>{step}</li>)}
              </Ol>
            </VStack>

            <VStack align="stretch" gap={2}>
              <SectionTitle>What's under the hood</SectionTitle>
              <Ul pl={5} listStyleType="disc" display="flex" flexDir="column" gap={1.5}>
                {FEATURES.map((f) => <li key={f}>{f}</li>)}
              </Ul>
            </VStack>

            <VStack align="stretch" gap={2}>
              <SectionTitle>Verified contracts</SectionTitle>
              <HStack gap={2} flexWrap="wrap">
                {VERIFIED_CONTRACTS.map(({ name, address }) => (
                  <A
                    key={name}
                    href={basescanCodeUrl(address)}
                    target="_blank"
                    rel="noopener noreferrer"
                    px={3}
                    py={1}
                    borderRadius="10px"
                    fontSize="13px"
                    bg="rgba(255,255,255,0.06)"
                    border="1px solid rgba(255,255,255,0.12)"
                    color="white"
                    _hover={{ bg: 'rgba(255,255,255,0.12)' }}
                  >
                    {name} ↗
                  </A>
                ))}
              </HStack>
            </VStack>

            <Box pt={4} borderTop="1px solid rgba(255,255,255,0.08)">
              <A
                href={GITHUB_README_URL}
                target="_blank"
                rel="noopener noreferrer"
                display="flex"
                alignItems="center"
                justifyContent="center"
                gap={2}
                h="46px"
                borderRadius="14px"
                bg="#DC143C"
                color="white"
                fontWeight="600"
                _hover={{ bg: '#B71C1C', color: 'white' }}
              >
                <FaGithub /> Read the full README on GitHub
              </A>
            </Box>
          </VStack>
        </Box>
      </Box>
    </Portal>
  )
}
