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
        minW="140px"
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
            bg="rgba(0, 0, 0, 0.7)"
            zIndex={1000}
            display="flex"
            alignItems="center"
            justifyContent="center"
            onClick={() => setIsOpen(false)}
          >
            <Box
              bg="#1F1F1F"
              border="1px solid rgba(255, 215, 0, 0.2)"
              borderRadius="24px"
              w="420px"
              maxH="600px"
              onClick={(e) => e.stopPropagation()}
              overflow="hidden"
              boxShadow="0 20px 60px rgba(0, 0, 0, 0.5)"
            >
              {/* Header */}
              <HStack justify="space-between" p={5} borderBottom="1px solid rgba(255, 255, 255, 0.1)">
                <Text fontSize="20px" fontWeight="700" color="white">
                  Select a token
                </Text>
                <Button
                  onClick={() => setIsOpen(false)}
                  bg="transparent"
                  color="rgba(255, 255, 255, 0.7)"
                  _hover={{ bg: "rgba(255, 255, 255, 0.1)" }}
                  borderRadius="12px"
                  w="36px"
                  h="36px"
                  p={0}
                >
                  <FaTimes />
                </Button>
              </HStack>

              {/* Search */}
              <Box p={5}>
                <Box position="relative">
                  <FaSearch 
                    style={{
                      position: 'absolute',
                      left: '16px',
                      top: '50%',
                      transform: 'translateY(-50%)',
                      color: 'rgba(255, 255, 255, 0.5)',
                      fontSize: '16px'
                    }}
                  />
                  <Input
                    placeholder="Search name or paste address"
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    pl="48px"
                    bg="rgba(255, 255, 255, 0.12)"
                    border="1px solid rgba(255, 255, 255, 0.12)"
                    _focus={{ 
                      borderColor: "#FFD700",
                      bg: "rgba(255, 255, 255, 0.08)"
                    }}
                  />
                </Box>
              </Box>

              {/* Popular Tokens */}
              <Box px={5} pb={2}>
                <Text fontSize="14px" fontWeight="600" color="rgba(255, 255, 255, 0.7)" mb={3}>
                  Popular tokens
                </Text>
              </Box>

              {/* Token List */}
              <VStack gap={0} maxH="400px" overflowY="auto" pb={4}>
                {filteredTokens.map((token) => (
                  <Box
                    key={token.address}
                    w="full"
                    px={5}
                    py={3}
                    cursor="pointer"
                    _hover={{ bg: "rgba(255, 215, 0, 0.1)" }}
                    onClick={() => handleTokenSelect(token)}
                    transition="all 0.2s"
                  >
                    <HStack justify="space-between" w="full">
                      <HStack gap={3}>
                        <Box w="36px" h="36px">
                          <img 
                            src={token.logo} 
                            alt={token.symbol}
                            style={{
                              width: '100%',
                              height: '100%',
                              objectFit: 'contain',
                              borderRadius: '50%'
                            }}
                          />
                        </Box>
                        <VStack align="start" gap={0}>
                          <Text fontSize="16px" fontWeight="600" color="white">
                            {token.symbol}
                          </Text>
                          <Text fontSize="14px" color="rgba(255, 255, 255, 0.6)">
                            {token.name}
                          </Text>
                        </VStack>
                      </HStack>
                      <VStack align="end" gap={0}>
                        <Text fontSize="16px" fontWeight="600" color="white">
                          0.00
                        </Text>
                        <Text fontSize="14px" color="rgba(255, 255, 255, 0.6)">
                          {token.price}
                        </Text>
                      </VStack>
                    </HStack>
                  </Box>
                ))}
              </VStack>

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