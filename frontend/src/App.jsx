import { useState } from 'react'
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Button, ChakraProvider, defaultSystem, chakra } from '@chakra-ui/react'
import { RainbowKitProvider, darkTheme } from '@rainbow-me/rainbowkit'
import '@rainbow-me/rainbowkit/styles.css'
import {
  Box,
  Container,
  VStack,
  HStack,
  Text,
} from '@chakra-ui/react'
import { FaExchangeAlt, FaWater, FaTint, FaLandmark, FaInfoCircle, FaGithub } from 'react-icons/fa'
import ProtoSwapLogo from './assets/proto-logo-vector.png'

import { config } from './config/wagmi'
import { GITHUB_URL, VERIFIED_CONTRACTS, basescanCodeUrl } from './config/links'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { SwapInterface } from './components/SwapInterface'
import { LiquidityInterface } from './components/LiquidityInterface'
import { FaucetInterface } from './components/FaucetInterface'
import { GovernanceInterface } from './components/GovernanceInterface'
import { TestnetBanner } from './components/TestnetBanner'
import { AboutDialog } from './components/AboutDialog'
import { Toaster } from './components/ui/toaster'
import './App.css'

const queryClient = new QueryClient()
const FooterLink = chakra('a')

function AppInner() {
  const [activeTab, setActiveTab] = useState('swap')
  const [isAboutOpen, setIsAboutOpen] = useState(false)
  const router = VERIFIED_CONTRACTS.find(c => c.name === 'Router')

  const tabs = [
    { id: 'swap',   label: 'Swap',   icon: <FaExchangeAlt /> },
    { id: 'pool',   label: 'Pool',   icon: <FaWater /> },
    { id: 'faucet', label: 'Faucet', icon: <FaTint /> },
    { id: 'govern', label: 'Govern', icon: <FaLandmark /> },
  ]

  return (
    <Box minH="100vh" bg="transparent">
      <TestnetBanner onOpenAbout={() => setIsAboutOpen(true)} />
      <AboutDialog isOpen={isAboutOpen} onClose={() => setIsAboutOpen(false)} />

      {/* Header */}
      <Box bg="transparent" borderBottom="1px" borderColor="rgba(255, 255, 255, 0.12)" backdropFilter="blur(12px)">
        <Container maxW="1200px" py={4} px={4} mx="auto">
          <HStack justify="space-between" w="full" gap={2}>
            <HStack gap={{ base: 1.5, md: 3 }} minW={0}>
              <img src={ProtoSwapLogo} alt="ProtoSwap Logo" className="app-logo" />
              <Text
                fontSize={{ base: '20px', sm: '24px', md: '38px' }}
                fontWeight="700"
                truncate
                style={{
                  background: 'linear-gradient(45deg, #9f7aea, #4299e1)',
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  backgroundClip: 'text',
                }}
              >
                ProtoSwap
              </Text>
            </HStack>
            <HStack gap={{ base: 1.5, md: 3 }} flexShrink={0} whiteSpace="nowrap">
              <Button
                onClick={() => setIsAboutOpen(true)}
                bg="#1F1F1F"
                color="#FFD700"
                border="1px solid rgba(255, 215, 0, 0.3)"
                borderRadius="12px"
                h="40px"
                minW={{ base: '40px', md: 'auto' }}
                px={{ base: 0, md: 4 }}
                fontWeight="600"
                _hover={{ bg: '#242424' }}
                aria-label="About ProtoSwap"
                // The banner's "How it works" opens the same dialog; make room for the wordmark on narrow phones
                css={{ '@media (max-width: 379px)': { display: 'none' } }}
              >
                <FaInfoCircle />
                <Text as="span" display={{ base: 'none', md: 'inline' }}>About</Text>
              </Button>
              <ConnectButton
                accountStatus={{ smallScreen: 'avatar', largeScreen: 'full' }}
                chainStatus={{ smallScreen: 'icon', largeScreen: 'full' }}
                showBalance={{ smallScreen: false, largeScreen: true }}
              />
            </HStack>
          </HStack>
        </Container>
      </Box>

      {/* Main Content */}
      <Box display="flex" justifyContent="center" alignItems="center" minH="calc(100vh - 80px)" py={{ base: 6, md: 8 }} px={4}>
        <VStack gap={{ base: 6, md: 8 }} w="full" maxW="420px">
          {/* Navigation Tabs: full-width with stacked icon and label on phones */}
          <HStack gap={1} bg="#1F1F1F" p={1} borderRadius="16px" w={{ base: 'full', sm: 'fit-content' }} mx="auto" border="1px solid rgba(255, 215, 0, 0.2)">
            {tabs.map(tab => (
              <Button
                key={tab.id}
                flex={{ base: 1, sm: 'initial' }}
                h={{ base: 'auto', sm: '10' }}
                px={{ base: 1, sm: 4 }}
                py={{ base: 2, sm: 3 }}
                borderRadius="12px"
                bg={activeTab === tab.id ? '#DC143C' : 'transparent'}
                shadow={activeTab === tab.id ? '0 4px 12px rgba(220, 20, 60, 0.3)' : 'none'}
                fontSize={{ base: '13px', sm: '16px' }}
                fontWeight={activeTab === tab.id ? '600' : '500'}
                color={activeTab === tab.id ? 'white' : '#FFD700'}
                _hover={{
                  bg: activeTab === tab.id ? '#B71C1C' : '#242424',
                  transform: activeTab === tab.id ? 'translateY(-1px)' : 'none',
                }}
                transition="all 0.2s"
                onClick={() => setActiveTab(tab.id)}
              >
                <Box display="flex" flexDir={{ base: 'column', sm: 'row' }} alignItems="center" gap={{ base: 1, sm: 2 }}>
                  {tab.icon}
                  <Text>{tab.label}</Text>
                </Box>
              </Button>
            ))}
          </HStack>

          {/* Main Interface */}
          {activeTab === 'swap'   && <SwapInterface />}
          {activeTab === 'pool'   && <LiquidityInterface />}
          {activeTab === 'faucet' && <FaucetInterface />}
          {activeTab === 'govern' && <GovernanceInterface />}

          {/* Footer */}
          <Box pt={8} textAlign="center">
            <Text fontSize="14px" color="rgba(255, 255, 255, 0.5)">
              Built with Solidity, Foundry, React, and Wagmi
            </Text>
            <HStack justify="center" gap={4} mt={2} fontSize="14px" flexWrap="wrap">
              <FooterLink href={GITHUB_URL} target="_blank" rel="noopener noreferrer" color="rgba(255, 255, 255, 0.6)" _hover={{ color: '#FFD700' }} display="inline-flex" alignItems="center" gap={1.5}>
                <FaGithub /> Source
              </FooterLink>
              <FooterLink href={basescanCodeUrl(router.address)} target="_blank" rel="noopener noreferrer" color="rgba(255, 255, 255, 0.6)" _hover={{ color: '#FFD700' }}>
                Verified contracts ↗
              </FooterLink>
            </HStack>
          </Box>
        </VStack>
      </Box>
    </Box>
  )
}

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider
          theme={darkTheme({
            accentColor: '#DC143C',
            accentColorForeground: 'white',
            borderRadius: 'medium',
            fontStack: 'system',
            overlayBlur: 'small',
          })}
        >
          <ChakraProvider value={defaultSystem}>
            <AppInner />
            <Toaster />
          </ChakraProvider>
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}

export default App
