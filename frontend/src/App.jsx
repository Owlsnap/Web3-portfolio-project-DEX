import { useState } from 'react'
import { WagmiProvider, useAccount, useChainId } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Button, ChakraProvider, defaultSystem } from '@chakra-ui/react'
import { RainbowKitProvider, darkTheme } from '@rainbow-me/rainbowkit'
import '@rainbow-me/rainbowkit/styles.css'
import {
  Box,
  Container,
  VStack,
  HStack,
  Text,
} from '@chakra-ui/react'
import { FaExchangeAlt, FaWater, FaTint } from 'react-icons/fa'
import ProtoSwapLogo from './assets/proto-logo-vector.png'

import { config, SUPPORTED_CHAIN_IDS } from './config/wagmi'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { SwapInterface } from './components/SwapInterface'
import { LiquidityInterface } from './components/LiquidityInterface'
import { FaucetInterface } from './components/FaucetInterface'
import { Toaster } from './components/ui/toaster'
import './App.css'

const queryClient = new QueryClient()

function WrongNetworkBanner() {
  const { isConnected } = useAccount()
  const chainId = useChainId()

  if (!isConnected || SUPPORTED_CHAIN_IDS.includes(chainId)) return null

  return (
    <Box bg="rgba(220, 20, 60, 0.9)" py={2} textAlign="center">
      <Text fontSize="14px" fontWeight="600" color="white">
        Unsupported network — please switch to Base Sepolia in your wallet.
      </Text>
    </Box>
  )
}

function AppInner() {
  const [activeTab, setActiveTab] = useState('swap')

  const tabs = [
    { id: 'swap',   label: 'Swap',   icon: <FaExchangeAlt /> },
    { id: 'pool',   label: 'Pool',   icon: <FaWater /> },
    { id: 'faucet', label: 'Faucet', icon: <FaTint /> },
  ]

  return (
    <Box minH="100vh" bg="transparent">
      <WrongNetworkBanner />

      {/* Header */}
      <Box bg="transparent" borderBottom="1px" borderColor="rgba(255, 255, 255, 0.12)" backdropFilter="blur(12px)">
        <Container maxW="1200px" py={4} mx="auto">
          <HStack justify="space-between" w="full">
            <HStack gap={3}>
              <img
                src={ProtoSwapLogo}
                alt="ProtoSwap Logo"
                style={{ width: '62px', height: '62px', objectFit: 'contain', borderRadius: '8px' }}
              />
              <Text
                fontSize="38px"
                fontWeight="700"
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
            <ConnectButton />
          </HStack>
        </Container>
      </Box>

      {/* Main Content */}
      <Box display="flex" justifyContent="center" alignItems="center" minH="calc(100vh - 80px)" py={8}>
        <VStack gap={8} w="full" maxW="420px">
          {/* Navigation Tabs */}
          <HStack gap={1} bg="#1F1F1F" p={1} borderRadius="16px" w="fit-content" mx="auto" border="1px solid rgba(255, 215, 0, 0.2)">
            {tabs.map(tab => (
              <Button
                key={tab.id}
                px={6}
                py={3}
                borderRadius="12px"
                bg={activeTab === tab.id ? '#DC143C' : 'transparent'}
                shadow={activeTab === tab.id ? '0 4px 12px rgba(220, 20, 60, 0.3)' : 'none'}
                fontSize="16px"
                fontWeight={activeTab === tab.id ? '600' : '500'}
                color={activeTab === tab.id ? 'white' : '#FFD700'}
                _hover={{
                  bg: activeTab === tab.id ? '#B71C1C' : '#242424',
                  transform: activeTab === tab.id ? 'translateY(-1px)' : 'none',
                }}
                transition="all 0.2s"
                onClick={() => setActiveTab(tab.id)}
              >
                <HStack gap={2}>
                  {tab.icon}
                  <Text>{tab.label}</Text>
                </HStack>
              </Button>
            ))}
          </HStack>

          {/* Main Interface */}
          {activeTab === 'swap'   && <SwapInterface />}
          {activeTab === 'pool'   && <LiquidityInterface />}
          {activeTab === 'faucet' && <FaucetInterface />}

          {/* Footer */}
          <Box pt={8} textAlign="center">
            <Text fontSize="14px" color="rgba(255, 255, 255, 0.5)">
              Built with Solidity, Foundry, React, and Wagmi
            </Text>
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
