import { useState, useEffect } from 'react'
import {
  Box,
  VStack,
  HStack,
  Text,
  Portal
} from '@chakra-ui/react'
import { chakra } from '@chakra-ui/react'
import { FaSearch, FaTimes, FaChevronDown } from 'react-icons/fa'
import { useChainId } from 'wagmi'
import EthereumLogo from '../assets/ethereum-eth-logo.svg'
import USDCLogo from '../assets/usd-coin-usdc-logo.svg'
import ProtoLogo from '../assets/proto-logo-vector.png'
import { CONTRACT_ADDRESSES } from '../config/wagmi'

// Create custom components
const Input = chakra('input', {
  base: {
    appearance: 'none',
    border: '1px solid',
    borderRadius: '12px',
    px: 4,
    py: 3,
    fontSize: '16px',
    outline: 'none',
    bg: 'transparent',
    color: 'white',
    _placeholder: { color: 'rgba(255, 255, 255, 0.5)' },
    _focus: { borderColor: '#FFD700', boxShadow: '0 0 0 1px #FFD700' }
  }
})

const Button = chakra('button', {
  base: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: '12px',
    fontWeight: '600',
    cursor: 'pointer',
    outline: 'none',
    transition: 'all 0.2s',
    px: 4,
    py: 2,
    border: 'none'
  }
})

const ZERO = '0x0000000000000000000000000000000000000000'

const TOKEN_CARD_STYLE = {
  ETH:   { bg: 'linear-gradient(145deg, #c4b5fd 0%, #8b5cf6 100%)', iconBg: 'rgba(255,255,255,0.18)' },
  WETH:  { bg: 'linear-gradient(145deg, #93c5fd 0%, #3b82f6 100%)', iconBg: 'rgba(255,255,255,0.18)' },
  PROTO: { bg: 'linear-gradient(145deg, #f472b6 0%, #9333ea 100%)', iconBg: 'rgba(255,255,255,0.18)' },
  USDC:  { bg: 'linear-gradient(145deg, #38bdf8 0%, #2563eb 100%)', iconBg: 'rgba(255,255,255,0.18)' },
}

function buildTokenList(addresses) {
  const tokens = [
    { symbol: 'ETH',   name: 'Ethereum',         address: 'ETH',              decimals: 18, logo: EthereumLogo },
    { symbol: 'WETH',  name: 'Wrapped Ethereum',  address: addresses?.weth,    decimals: 18, logo: EthereumLogo },
    { symbol: 'PROTO', name: 'Proto Token',        address: addresses?.dexToken,decimals: 18, logo: ProtoLogo    },
    { symbol: 'USDC',  name: 'Mock USDC',          address: addresses?.mockUsdc,decimals: 6,  logo: USDCLogo     },
  ]
  // Only include tokens whose address is set and non-zero
  return tokens.filter(t => t.address && t.address !== ZERO)
}

export function TokenSelector({
  selectedToken,
  onTokenSelect,
  excludeToken,
  placeholder = "Select token"
}) {
  const chainId = useChainId()
  const addresses = CONTRACT_ADDRESSES[chainId] || CONTRACT_ADDRESSES[31337]
  const POPULAR_TOKENS = buildTokenList(addresses)

  const [isOpen, setIsOpen] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')
  const [filteredTokens, setFilteredTokens] = useState(POPULAR_TOKENS)

  // Filter tokens based on search
  useEffect(() => {
    const filtered = POPULAR_TOKENS.filter(token => {
      const matchesSearch = token.symbol.toLowerCase().includes(searchTerm.toLowerCase()) ||
                            token.name.toLowerCase().includes(searchTerm.toLowerCase())
      const notExcluded = !excludeToken || token.address !== excludeToken
      return matchesSearch && notExcluded
    })
    setFilteredTokens(filtered)
  }, [searchTerm, excludeToken, chainId])

  const selectedTokenData = POPULAR_TOKENS.find(token => {
    // Handle both string tokens and token objects
    if (typeof selectedToken === 'object' && selectedToken !== null) {
      return token.address === selectedToken.address || token.symbol === selectedToken.symbol
    }
    return token.address === selectedToken || token.symbol === selectedToken
  })

  const handleTokenSelect = (token) => {
    onTokenSelect(token.address || token.symbol)
    setIsOpen(false)
    setSearchTerm('')
  }

  return (
    <Box position="relative">
      {/* Token Selector Button */}
      <Button
        onClick={() => setIsOpen(!isOpen)}
        bg="#393939"
        borderRadius="16px"
        border="1px solid"
        borderColor="rgba(255, 215, 0, 0.3)"
        _hover={{ 
          bg: "#242424",
          borderColor: "#FFD700"
        }}
        fontSize="16px"
        fontWeight="600"
        color="#FFD700"
        minW="175px"
        h="48px"
        px={3}
      >
        <HStack gap={2} justify="space-between" w="full">
          <HStack gap={2}>
            {selectedTokenData?.logo && (
              <Box w="24px" h="24px">
                <img 
                  src={selectedTokenData.logo} 
                  alt={selectedTokenData.symbol}
                  style={{
                    width: '100%',
                    height: '100%',
                    objectFit: 'contain',
                    borderRadius: '50%'
                  }}
                />
              </Box>
            )}
            <Text>
              {selectedTokenData?.symbol || placeholder}
            </Text>
          </HStack>
          <FaChevronDown 
            size="12px"
            style={{ 
              transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)',
              transition: 'transform 0.2s'
            }} 
          />
        </HStack>
      </Button>

      {/* Token Selection Modal */}
      {isOpen && (
        <Portal>
          <Box
            position="fixed"
            top="0"
            left="0"
            right="0"
            bottom="0"
            bg="rgba(6, 5, 20, 0.88)"
            backdropFilter="blur(12px)"
            zIndex={1000}
            display="flex"
            flexDir="column"
            alignItems="center"
            pt="80px"
            px={6}
            onClick={() => setIsOpen(false)}
          >
            {/* Close button — top right corner */}
            <Button
              position="fixed"
              top={5}
              right={5}
              onClick={() => setIsOpen(false)}
              bg="rgba(255,255,255,0.08)"
              color="rgba(255, 255, 255, 0.7)"
              _hover={{ bg: "rgba(255, 255, 255, 0.15)" }}
              borderRadius="12px"
              w="40px"
              h="40px"
              p={0}
            >
              <FaTimes />
            </Button>

            <Box
              w="full"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Search */}
              <Box pb={8} maxW="520px" mx="auto">
                <Box position="relative">
                  <FaSearch
                    style={{
                      position: 'absolute',
                      left: '18px',
                      top: '50%',
                      transform: 'translateY(-50%)',
                      color: 'rgba(255, 255, 255, 0.45)',
                      fontSize: '16px'
                    }}
                  />
                  <Input
                    placeholder="Find a token"
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    w="full"
                    pl="52px"
                    py="14px"
                    fontSize="17px"
                    borderRadius="16px"
                    bg="rgba(255, 255, 255, 0.07)"
                    border="1px solid rgba(139, 92, 246, 0.22)"
                    _focus={{
                      borderColor: "#8b5cf6",
                      bg: "rgba(139, 92, 246, 0.08)"
                    }}
                  />
                </Box>
              </Box>

              {/* Token Grid */}
              <Box
                display="grid"
                gridTemplateColumns="repeat(4, 175px)"
                gap={5}
                p={2}
                mx="auto"
                w="fit-content"
              >
                {filteredTokens.map((token) => {
                  const style = TOKEN_CARD_STYLE[token.symbol] || {
                    bg: 'linear-gradient(145deg, #374151 0%, #1f2937 100%)',
                    iconBg: 'rgba(255,255,255,0.12)'
                  }
                  return (
                    <Box
                      key={token.address}
                      cursor="pointer"
                      borderRadius="22px"
                      background={style.bg}
                      w="175px"
                      h="175px"
                      display="flex"
                      flexDir="column"
                      alignItems="center"
                      justifyContent="center"
                      gap={3}
                      onClick={() => handleTokenSelect(token)}
                      transition="all 0.18s cubic-bezier(0.4,0,0.2,1)"
                      _hover={{ transform: 'scale(1.05)', filter: 'brightness(1.1)' }}
                      border="1.5px solid rgba(255,255,255,0.18)"
                      boxShadow="0 8px 32px rgba(0,0,0,0.35)"
                    >
                      <Box
                        w="96px"
                        h="96px"
                        borderRadius="50%"
                        bg={style.iconBg}
                        display="flex"
                        alignItems="center"
                        justifyContent="center"
                        p="8px"
                      >
                        <img
                          src={token.logo}
                          alt={token.symbol}
                          style={{ width: '100%', height: '100%', objectFit: 'contain' }}
                        />
                      </Box>
                      <Text fontSize="13px" fontWeight="700" color="white" textAlign="center" lineHeight="1.3">
                        {token.name}
                      </Text>
                    </Box>
                  )
                })}
              </Box>

              {/* No results */}
              {filteredTokens.length === 0 && (
                <Box p={8} textAlign="center">
                  <Text color="rgba(255, 255, 255, 0.5)">
                    No tokens found
                  </Text>
                </Box>
              )}
            </Box>
          </Box>
        </Portal>
      )}
    </Box>
  )
}