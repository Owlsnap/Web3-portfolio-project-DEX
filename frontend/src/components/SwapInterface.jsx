import { useState, useEffect, useMemo } from 'react'
import { 
  Box, 
  VStack, 
  HStack, 
  Text
} from '@chakra-ui/react'
import { chakra } from '@chakra-ui/react'

// Create custom components using chakra factory since Input, Button, Select are not available in v3
const Input = chakra('input', {
  base: {
    appearance: 'none',
    border: '1px solid',
    borderColor: 'gray.200',
    borderRadius: 'md',
    px: 3,
    py: 2,
    fontSize: 'md',
    outline: 'none',
    _focus: {
      borderColor: 'blue.500',
      boxShadow: '0 0 0 1px blue.500'
    }
  }
})

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
    _disabled: {
      opacity: 0.4,
      cursor: 'not-allowed'
    }
  },
  variants: {
    colorPalette: {
      blue: {
        bg: 'blue.500',
        color: 'white',
        _hover: { bg: 'blue.600' }
      },
      red: {
        bg: 'red.500',
        color: 'white',
        _hover: { bg: 'red.600' }
      }
    },
    size: {
      sm: { px: 3, py: 1, fontSize: 'sm' },
      lg: { px: 6, py: 3, fontSize: 'lg' }
    },
    variant: {
      ghost: {
        bg: 'transparent',
        _hover: { bg: 'gray.100' }
      }
    }
  }
})

// Select component removed - now using TokenSelector
import { toaster } from './ui/toaster'
import { FaExclamationTriangle, FaCheckCircle, FaArrowDown, FaCog, FaSpinner } from 'react-icons/fa'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useBalance } from 'wagmi'
import { parseUnits, formatUnits, getAddress } from 'viem'
import { CONTRACT_ADDRESSES } from '../config/wagmi'
import { TokenSelector } from './TokenSelector'

// Complete Router ABI in JSON format (works reliably with wagmi for both reads and writes)
const ROUTER_ABI_JSON = [
  {
    "inputs": [
      {"internalType": "uint256", "name": "amountIn", "type": "uint256"},
      {"internalType": "address[]", "name": "path", "type": "address[]"}
    ],
    "name": "getAmountsOut",
    "outputs": [
      {"internalType": "uint256[]", "name": "amounts", "type": "uint256[]"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "amountOutMin", "type": "uint256"},
      {"internalType": "address[]", "name": "path", "type": "address[]"},
      {"internalType": "address", "name": "to", "type": "address"},
      {"internalType": "uint256", "name": "deadline", "type": "uint256"}
    ],
    "name": "swapExactETHForTokens",
    "outputs": [
      {"internalType": "uint256[]", "name": "amounts", "type": "uint256[]"}
    ],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "amountIn", "type": "uint256"},
      {"internalType": "uint256", "name": "amountOutMin", "type": "uint256"},
      {"internalType": "address[]", "name": "path", "type": "address[]"},
      {"internalType": "address", "name": "to", "type": "address"},
      {"internalType": "uint256", "name": "deadline", "type": "uint256"}
    ],
    "name": "swapExactTokensForETH",
    "outputs": [
      {"internalType": "uint256[]", "name": "amounts", "type": "uint256[]"}
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "amountIn", "type": "uint256"},
      {"internalType": "uint256", "name": "amountOutMin", "type": "uint256"},
      {"internalType": "address[]", "name": "path", "type": "address[]"},
      {"internalType": "address", "name": "to", "type": "address"},
      {"internalType": "uint256", "name": "deadline", "type": "uint256"}
    ],
    "name": "swapExactTokensForTokens",
    "outputs": [
      {"internalType": "uint256[]", "name": "amounts", "type": "uint256[]"}
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]

// ERC20 ABI for reading token balances
const ERC20_ABI = [
  {
    "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
    "stateMutability": "view",
    "type": "function"
  }
]

// Factory ABI (getPair)
const FACTORY_ABI = [
  {
    "inputs": [
      { "internalType": "address", "name": "tokenA", "type": "address" },
      { "internalType": "address", "name": "tokenB", "type": "address" }
    ],
    "name": "getPair",
    "outputs": [{ "internalType": "address", "name": "pair", "type": "address" }],
    "stateMutability": "view",
    "type": "function"
  }
]

// Pair ABI (getReserves)
const PAIR_ABI = [
  {
    "inputs": [],
    "name": "getReserves",
    "outputs": [
      { "internalType": "uint112", "name": "_reserve0", "type": "uint112" },
      { "internalType": "uint112", "name": "_reserve1", "type": "uint112" },
      { "internalType": "uint32", "name": "_blockTimestampLast", "type": "uint32" }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]

// Token list is now handled by TokenSelector component

export function SwapInterface() {
  const { address, chainId } = useAccount()
  const { writeContract, data: hash, isPending } = useWriteContract()
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash })

  const contractAddresses = CONTRACT_ADDRESSES[chainId || 31337]

  const [fromToken, setFromToken] = useState('ETH')
  const [toToken, setToToken] = useState({
    symbol: 'PROTO',
    name: 'Proto Token',
    address: '0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9',
    decimals: 18
  }) // Default to PROTO token
  const [fromAmount, setFromAmount] = useState('')
  const [toAmount, setToAmount] = useState('')
  const [slippage, setSlippage] = useState('0.5') // 0.5% default slippage
  const [debouncedFromAmount, setDebouncedFromAmount] = useState('')
  const [isLoadingQuote, setIsLoadingQuote] = useState(false)
  const [quoteError, setQuoteError] = useState(null)

  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

  // Update toToken address when contractAddresses change
  useEffect(() => {
    if (contractAddresses?.dexToken && typeof toToken === 'object' && toToken.symbol === 'PROTO') {
      setToToken(prev => ({
        ...prev,
        address: contractAddresses.dexToken
      }))
    }
  }, [contractAddresses?.dexToken, toToken?.symbol])

  // Get ETH balance
  const { data: ethBalance, refetch: refetchEthBalance } = useBalance({
    address: address,
    enabled: !!address,
    watch: true, // Watch for changes
    poll: 3000 // Poll every 3 seconds
  })

  // Get fromToken balance
  const { data: fromTokenBalance, refetch: refetchFromTokenBalance } = useReadContract({
    address: fromToken !== 'ETH' && typeof fromToken === 'object' ? getAddress(fromToken.address) : undefined,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address],
    enabled: !!address && fromToken !== 'ETH' && typeof fromToken === 'object',
    watch: true, // Watch for changes
    poll: 3000 // Poll every 3 seconds
  })

  // Get toToken balance
  const { data: toTokenBalance, refetch: refetchToTokenBalance } = useReadContract({
    address: toToken !== 'ETH' && typeof toToken === 'object' ? getAddress(toToken.address) : undefined,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address],
    enabled: !!address && toToken !== 'ETH' && typeof toToken === 'object',
    watch: true, // Watch for changes
    poll: 3000 // Poll every 3 seconds
  })

  // Helper function to format balance
  const formatBalance = (token, balance) => {
    if (!balance) return '0.00'
    
    try {
      if (token === 'ETH') {
        return parseFloat(formatUnits(balance.value || balance, 18)).toFixed(4)
      } else {
        const decimals = typeof token === 'object' ? token.decimals || 18 : 18
        return parseFloat(formatUnits(balance, decimals)).toFixed(4)
      }
    } catch (error) {
      return '0.00'
    }
  }

  // Get current balances for display
  const currentFromBalance = fromToken === 'ETH' ? ethBalance : fromTokenBalance
  const currentToBalance = toToken === 'ETH' ? ethBalance : toTokenBalance

  // Function to refetch all balances
  const refetchAllBalances = () => {
    refetchEthBalance()
    refetchFromTokenBalance()
    refetchToTokenBalance()
  }

  // Helper function to check if tokens are the same
  const areTokensSame = () => {
    if (!fromToken || !toToken) return false
    
    const addressFrom = fromToken === 'ETH' ? 'ETH' : (typeof fromToken === 'object' ? fromToken.address : fromToken)
    const addressTo = toToken === 'ETH' ? 'ETH' : (typeof toToken === 'object' ? toToken.address : toToken)
    
    return addressFrom === addressTo
  }

  // Debounce fromAmount input (500ms delay)
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedFromAmount(fromAmount)
    }, 500)

    return () => clearTimeout(timer)
  }, [fromAmount])

  // Reset quote error when inputs change
  useEffect(() => {
    setQuoteError(null)
  }, [fromAmount, fromToken, toToken])

  // Watch for transaction confirmations and refetch balances
  useEffect(() => {
    if (hash && !isConfirming && !isPending) {
      // Transaction completed, refetch balances after a short delay
      setTimeout(() => {
        refetchAllBalances()
      }, 2000) // 2 second delay to ensure blockchain state is updated
    }
  }, [hash, isConfirming, isPending])

  // Refetch balances when tokens change
  useEffect(() => {
    refetchAllBalances()
  }, [fromToken, toToken])

  // Helper function to validate and parse amount
  const parseValidAmount = (amount) => {
    if (!amount || amount === '') return 0n
    
    // Check if amount is a valid number
    const numAmount = parseFloat(amount)
    if (isNaN(numAmount) || numAmount < 0) return 0n
    
    try {
      return parseUnits(amount.toString(), 18)
    } catch (error) {
      console.warn('Invalid amount:', amount)
      return 0n
    }
  }

  // Build token path for quote
  const tokenPath = useMemo(() => {
    if (!fromToken || !toToken) return []
    
    try {
      const fromAddress = fromToken === 'ETH' ? contractAddresses?.weth : (typeof fromToken === 'object' ? fromToken.address : fromToken)
      const toAddress = toToken === 'ETH' ? contractAddresses?.weth : (typeof toToken === 'object' ? toToken.address : toToken)
      
      if (!fromAddress || !toAddress) return []
      
      // Check if same token (compare addresses, not objects)
      if (fromAddress === toAddress) return []
      
      // Ensure addresses are properly checksummed
      return [getAddress(fromAddress), getAddress(toAddress)]
    } catch (error) {
      console.warn('Invalid address in token path:', error)
      return []
    }
  }, [fromToken, toToken, contractAddresses?.weth])

  // Debug logging
  // Get pair address for this path (via Factory) and then fetch reserves
  const { data: swapPairAddress } = useReadContract({
    address: contractAddresses?.factory,
    abi: FACTORY_ABI,
    functionName: 'getPair',
    args: tokenPath.length === 2 ? [tokenPath[0], tokenPath[1]] : undefined,
    query: {
      enabled: tokenPath.length === 2 && !!contractAddresses?.factory,
      refetchInterval: 5000
    }
  })

  const { data: pairReserves } = useReadContract({
    address: swapPairAddress,
    abi: PAIR_ABI,
    functionName: 'getReserves',
    args: [],
    query: {
      enabled: !!swapPairAddress && swapPairAddress !== '0x0000000000000000000000000000000000000000',
      refetchInterval: 5000
    }
  })

  // If there's no pair or reserves are empty, set a helpful quote error so the UI doesn't try to call getAmountsOut
  useEffect(() => {
    if (!debouncedFromAmount || parseFloat(debouncedFromAmount) <= 0) return

    if (tokenPath.length === 2) {
      if (!swapPairAddress || swapPairAddress === ZERO_ADDRESS) {
        setQuoteError('No liquidity pool exists for the selected token pair.')
        setToAmount('')
        setIsLoadingQuote(false)
        return
      }

      if (pairReserves && (pairReserves[0] === 0n || pairReserves[1] === 0n)) {
        setQuoteError('Insufficient liquidity in the pool to provide a quote.')
        setToAmount('')
        setIsLoadingQuote(false)
        return
      }
    }
  }, [tokenPath, swapPairAddress, pairReserves, debouncedFromAmount])

  console.log('Quote Debug:', {
    debouncedFromAmount,
    fromToken,
    toToken,
    tokenPath,
    contractAddresses: contractAddresses?.router,
    parsedAmount: parseValidAmount(debouncedFromAmount).toString(),
    swapPairAddress,
    pairReserves,
    enabled: Boolean(
      debouncedFromAmount && 
      fromToken && 
      toToken && 
      parseFloat(debouncedFromAmount) > 0 && 
      tokenPath.length === 2 &&
      contractAddresses?.router
    )
  })

  // Get quote for swap with debounced amount
  const { data: quoteData, isError: quoteIsError, isLoading: quoteIsLoading, error: quoteErrorObj } = useReadContract({
    address: contractAddresses?.router ? getAddress(contractAddresses.router) : undefined,
    abi: ROUTER_ABI_JSON,
    functionName: 'getAmountsOut',
    args: [
      parseValidAmount(debouncedFromAmount),
      tokenPath
    ],
    enabled: Boolean(
      debouncedFromAmount && 
      fromToken && 
      toToken && 
      parseFloat(debouncedFromAmount) > 0 && 
      tokenPath.length === 2 &&
      contractAddresses?.router &&
      parseValidAmount(debouncedFromAmount) > 0n &&
      // only call quote if pair exists and reserves are non-zero
      swapPairAddress &&
      pairReserves &&
      (pairReserves[0] > 0n) &&
      (pairReserves[1] > 0n)
    )
  })

  // Track loading state for UI - only show loading when we have an amount and are actively fetching
  useEffect(() => {
    if (fromAmount && fromAmount !== debouncedFromAmount && parseFloat(fromAmount) > 0) {
      setIsLoadingQuote(true)
    } else if (debouncedFromAmount && parseFloat(debouncedFromAmount) > 0) {
      setIsLoadingQuote(quoteIsLoading)
    } else {
      setIsLoadingQuote(false)
    }
  }, [fromAmount, debouncedFromAmount, quoteIsLoading])

  // Update toAmount when quote changes
  useEffect(() => {
    // Only process quotes when we have a debounced amount
    if (!debouncedFromAmount || parseFloat(debouncedFromAmount) <= 0) {
      setToAmount('')
      setQuoteError(null)
      setIsLoadingQuote(false)
      return
    }
    
    if (quoteIsError) {
      console.error('Quote error details:', {
        isError: quoteIsError,
        errorObject: quoteErrorObj,
        errorMessage: quoteErrorObj?.message,
        debouncedFromAmount,
        fromToken,
        toToken,
        tokenPath,
        contractAddress: contractAddresses?.router,
        parsedAmount: parseValidAmount(debouncedFromAmount).toString()
      })
      setQuoteError('Unable to get price quote. Please check if there is sufficient liquidity.')
      setToAmount('')
      setIsLoadingQuote(false)
      return
    }

    if (quoteData && quoteData.length > 1) {
      const outputAmount = formatUnits(quoteData[quoteData.length - 1], toToken?.decimals || 18)
      setToAmount(outputAmount)
      setQuoteError(null)
      setIsLoadingQuote(false)
    } else if (!quoteIsLoading) {
      setToAmount('')
    }
  }, [quoteData, quoteIsError, quoteIsLoading, debouncedFromAmount, toToken?.decimals])

  const handleSwap = async () => {
    if (!fromAmount || !toAmount || !fromToken || !toToken) {
      toaster.create({
        title: 'Error',
        description: 'Please enter all required fields',
        status: 'error',
        duration: 3000,
      })
      return
    }

    // Check if tokens are the same
    if (areTokensSame()) {
      toaster.create({
        title: 'Invalid Token Selection',
        description: 'From and To tokens cannot be the same. Please select different tokens.',
        status: 'error',
        duration: 4000,
      })
      return
    }

    // Validate amounts are valid numbers
    const fromAmountNum = parseFloat(fromAmount)
    const toAmountNum = parseFloat(toAmount)
    
    if (isNaN(fromAmountNum) || fromAmountNum <= 0) {
      toaster.create({
        title: 'Invalid Amount',
        description: 'Please enter a valid amount',
        status: 'error',
        duration: 3000,
      })
      return
    }

    try {
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200) // 20 minutes
      const amountIn = parseValidAmount(fromAmount)
      const amountOutMin = parseUnits((toAmountNum * (1 - parseFloat(slippage) / 100)).toString(), 18)

      if (fromToken === 'ETH') {
        // ETH -> Token
        const toAddress = toToken === 'ETH' ? contractAddresses.weth : (typeof toToken === 'object' ? toToken.address : toToken)
        const path = [getAddress(contractAddresses.weth), getAddress(toAddress)]
        await writeContract({
          address: getAddress(contractAddresses.router),
          abi: ROUTER_ABI_JSON,
          functionName: 'swapExactETHForTokens',
          args: [amountOutMin, path, getAddress(address), deadline],
          value: amountIn
        })
      } else if (toToken === 'ETH') {
        // Token -> ETH
        const fromAddress = fromToken === 'ETH' ? contractAddresses.weth : (typeof fromToken === 'object' ? fromToken.address : fromToken)
        const path = [getAddress(fromAddress), getAddress(contractAddresses.weth)]
        await writeContract({
          address: getAddress(contractAddresses.router),
          abi: ROUTER_ABI_JSON,
          functionName: 'swapExactTokensForETH',
          args: [amountIn, amountOutMin, path, getAddress(address), deadline]
        })
      } else {
        // Token -> Token
        const fromAddress = fromToken === 'ETH' ? contractAddresses.weth : (typeof fromToken === 'object' ? fromToken.address : fromToken)
        const toAddress = toToken === 'ETH' ? contractAddresses.weth : (typeof toToken === 'object' ? toToken.address : toToken)
        const path = [getAddress(fromAddress), getAddress(toAddress)]
        await writeContract({
          address: getAddress(contractAddresses.router),
          abi: ROUTER_ABI_JSON,
          functionName: 'swapExactTokensForTokens',
          args: [amountIn, amountOutMin, path, getAddress(address), deadline]
        })
      }

      toaster.create({
        title: 'Swap Submitted',
        description: 'Your swap transaction has been submitted',
        status: 'info',
        duration: 5000,
      })
    } catch (error) {
      toaster.create({
        title: 'Swap Failed',
        description: error.message,
        status: 'error',
        duration: 5000,
      })
    }
  }

  // Handle amount input with validation
  const handleAmountChange = (value) => {
    // Allow empty string
    if (value === '') {
      setFromAmount('')
      return
    }
    
    // Allow only numbers and one decimal point
    const regex = /^[0-9]*\.?[0-9]*$/
    if (regex.test(value)) {
      // Prevent multiple decimal points
      const decimalCount = (value.match(/\./g) || []).length
      if (decimalCount <= 1) {
        setFromAmount(value)
      }
    }
  }

  const handleFlipTokens = () => {
    setFromToken(toToken)
    setToToken(fromToken)
    setFromAmount(toAmount)
    setToAmount(fromAmount)
  }

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
      <VStack gap={2}>
        {/* Header */}
        <HStack justify="space-between" w="full" mb={3}>
          <Text fontSize="22px" fontWeight="700" color="white">Swap</Text>
          <Button size="sm" variant="ghost" p={2} borderRadius="12px" _hover={{ bg: "#242424" }}>
            <FaCog color="rgba(255, 255, 255, 0.7)" />
          </Button>
        </HStack>

        {/* From Token */}
        <Box 
          w="full" 
          p={4} 
          borderRadius="18px" 
          bg="rgba(255, 255, 255, 0.12)"
          border="1px"
          borderColor="rgba(255, 255, 255, 0.12)"
          position="relative"
          _hover={{ bg: "#242424" }}
          transition="all 0.2s"
        >
          <VStack gap={3} align="stretch">
            <HStack justify="space-between" w="full">
              <Text fontSize="14px" fontWeight="600" color="rgba(255, 255, 255, 0.8)">From</Text>
              <Text fontSize="14px" color="rgba(255, 255, 255, 0.6)">
                Balance: {address ? formatBalance(fromToken, currentFromBalance) : '0.00'}
              </Text>
            </HStack>
            <HStack w="full" gap={3}>
              <Input
                placeholder="0.0"
                value={fromAmount}
                onChange={(e) => handleAmountChange(e.target.value)}
                fontSize="28px"
                fontWeight="700"
                border="none"
                bg="transparent"
                p={0}
                h="auto"
                color="white"
                _placeholder={{ color: "rgba(255, 255, 255, 0.4)" }}
                _focus={{ boxShadow: 'none', outline: 'none' }}
                flex={1}
              />
              <TokenSelector
                selectedToken={fromToken}
                onTokenSelect={setFromToken}
                excludeToken={toToken}
                placeholder="Select token"
              />
            </HStack>
          </VStack>
        </Box>

        {/* Flip Button */}
        <Box position="relative" my={-2} zIndex={1}>
          <Button
            w="44px"
            h="44px"
            p={0}
            borderRadius="14px"
            bg="#1F1F1F"
            border="2px"
            borderColor="rgba(255, 255, 255, 0.12)"
            shadow="0px 4px 16px rgba(0, 0, 0, 0.3)"
            _hover={{ 
              bg: "#242424",
              borderColor: "#DC143C",
              transform: "rotate(180deg) scale(1.05)"
            }}
            transition="all 0.3s cubic-bezier(0.4, 0, 0.2, 1)"
            onClick={handleFlipTokens}
          >
            <FaArrowDown color="rgba(255, 255, 255, 0.8)" size="16px" />
          </Button>
        </Box>

        {/* Same Token Error Message */}
        {areTokensSame() && (
          <Box w="full" p={3} borderRadius="12px" bg="rgba(239, 68, 68, 0.15)" border="1px" borderColor="rgba(239, 68, 68, 0.3)">
            <HStack gap={2}>
              <FaExclamationTriangle color="rgb(239, 68, 68)" size="14px" />
              <Text fontSize="14px" color="rgb(239, 68, 68)" fontWeight="500">
                From and To tokens cannot be the same. Please select different tokens.
              </Text>
            </HStack>
          </Box>
        )}

        {/* To Token */}
        <Box 
          w="full" 
          p={4} 
          borderRadius="18px" 
          bg="rgba(255, 255, 255, 0.12)"
          border="1px"
          borderColor="rgba(255, 255, 255, 0.12)"
          position="relative"
          _hover={{ bg: "#242424" }}
          transition="all 0.2s"
        >
          <VStack gap={3} align="stretch">
            <HStack justify="space-between" w="full">
              <HStack gap={2}>
                <Text fontSize="14px" fontWeight="600" color="rgba(255, 255, 255, 0.8)">To</Text>
                {isLoadingQuote && (
                  <Text fontSize="12px" color="#FFD700" fontWeight="500">
                    (Updating price...)
                  </Text>
                )}
              </HStack>
              <Text fontSize="14px" color="rgba(255, 255, 255, 0.6)">
                Balance: {address ? formatBalance(toToken, currentToBalance) : '0.00'}
              </Text>
            </HStack>
            <HStack w="full" gap={3}>
              <Box position="relative" flex={1}>
                <Input
                  placeholder={isLoadingQuote ? "Getting price..." : "0.0"}
                  value={isLoadingQuote ? "" : toAmount}
                  readOnly
                  fontSize="28px"
                  fontWeight="700"
                  border="none"
                  bg="transparent"
                  p={0}
                  h="auto"
                  color={quoteError ? "rgba(239, 68, 68, 0.8)" : "white"}
                  _placeholder={{ color: isLoadingQuote ? "#FFD700" : "rgba(255, 255, 255, 0.4)" }}
                  _focus={{ boxShadow: 'none', outline: 'none' }}
                />
                {/* Loading Spinner */}
                {isLoadingQuote && (
                  <Box
                    position="absolute"
                    right="0"
                    top="50%"
                    transform="translateY(-50%)"
                  >
                    <FaSpinner 
                      size="20px" 
                      color="#FFD700" 
                      style={{ animation: 'spin 1s linear infinite' }}
                    />
                  </Box>
                )}
              </Box>
              <TokenSelector
                selectedToken={toToken}
                onTokenSelect={setToToken}
                excludeToken={fromToken}
                placeholder="Select token"
              />
            </HStack>
          </VStack>
        </Box>

        {/* Quote Error Display */}
        {quoteError && (
          <Box w="full" p={4} borderRadius="16px" bg="rgba(239, 68, 68, 0.15)" border="1px" borderColor="rgba(239, 68, 68, 0.3)">
            <HStack gap={2}>
              <FaExclamationTriangle color="rgb(239, 68, 68)" size="14px" />
              <Text fontSize="14px" color="rgb(239, 68, 68)" fontWeight="500">
                {quoteError}
              </Text>
            </HStack>
          </Box>
        )}

        {/* Swap Details */}
        {fromAmount && (toAmount || isLoadingQuote) && !quoteError && (
          <Box w="full" p={4} borderRadius="16px" bg="rgba(255, 255, 255, 0.12)" border="1px" borderColor="rgba(255, 255, 255, 0.12)">
            <VStack gap={3} align="stretch">
              <HStack justify="space-between" fontSize="14px">
                <Text color="rgba(255, 255, 255, 0.7)">Expected Output</Text>
                {isLoadingQuote ? (
                  <HStack gap={2}>
                    <FaSpinner size="12px" color="#FFD700" style={{ animation: 'spin 1s linear infinite' }} />
                    <Text color="#FFD700" fontWeight="600">Loading...</Text>
                  </HStack>
                ) : (
                  <Text 
                    color="white" 
                    fontWeight="600"
                    textAlign="right"
                    wordBreak="break-all"
                    lineHeight="1.2"
                    maxW="200px"
                  >
                    {parseFloat(toAmount || 0).toFixed(6)} {typeof toToken === 'object' ? toToken.symbol : toToken}
                  </Text>
                )}
              </HStack>
              <HStack justify="space-between" fontSize="14px">
                <Text color="rgba(255, 255, 255, 0.7)">Price Impact</Text>
                <Text color="#FFD700" fontWeight="600">{"<0.01%"}</Text>
              </HStack>
              <HStack justify="space-between" fontSize="14px">
                <Text color="rgba(255, 255, 255, 0.7)">Slippage Tolerance</Text>
                <HStack gap={1}>
                  <Input
                    value={slippage}
                    onChange={(e) => setSlippage(e.target.value)}
                    w="45px"
                    h="28px"
                    fontSize="14px"
                    textAlign="center"
                    border="1px"
                    borderColor="rgba(255, 255, 255, 0.12)"
                    borderRadius="8px"
                    bg="#393939"
                    color="white"
                    p={1}
                    _hover={{ bg: "#242424" }}
                    _focus={{ borderColor: "#FFD700" }}
                  />
                  <Text color="rgba(255, 255, 255, 0.7)">%</Text>
                </HStack>
              </HStack>
            </VStack>
          </Box>
        )}

        {/* Swap Button */}
        <Button
          w="full"
          h="60px"
          borderRadius="18px"
          fontSize="18px"
          fontWeight="700"
          bg={!address ? "rgba(220, 20, 60, 0.2)" : 
              (!fromAmount || !toAmount || areTokensSame()) ? "#393939" :
              "#DC143C"}
          color={!address ? "#DC143C" :
                (!fromAmount || !toAmount || areTokensSame()) ? "rgba(255, 255, 255, 0.5)" :
                "white"}
          border={!address ? "1px solid rgba(220, 20, 60, 0.3)" :
                 (!fromAmount || !toAmount || areTokensSame()) ? "1px solid rgba(255, 255, 255, 0.12)" :
                 "none"}
          shadow={(!address || !fromAmount || !toAmount || areTokensSame()) ? "none" : "0 8px 24px rgba(220, 20, 60, 0.3)"}
          _hover={{
            bg: !address ? "rgba(220, 20, 60, 0.3)" :
                (!fromAmount || !toAmount || areTokensSame()) ? "#242424" :
                "#B71C1C",
            transform: (!address || !fromAmount || !toAmount || areTokensSame()) ? "none" : "translateY(-2px)",
            shadow: (!address || !fromAmount || !toAmount || areTokensSame()) ? "none" : "0 12px 32px rgba(220, 20, 60, 0.4)"
          }}
          _disabled={{
            opacity: 1,
            cursor: "not-allowed"
          }}
          transition="all 0.3s cubic-bezier(0.4, 0, 0.2, 1)"
          onClick={handleSwap}
          disabled={!address || !fromAmount || !toAmount || areTokensSame() || isPending || isConfirming}
        >
          {isPending ? 'Confirming...' : 
           isConfirming ? 'Swapping...' : 
           !address ? 'Connect Wallet' : 
           !fromAmount || !toAmount ? 'Enter an amount' :
           'Swap'}
        </Button>

        {/* Connection Check */}
        {!address && (
          <Box bg="rgba(255, 215, 0, 0.15)" border="1px" borderColor="rgba(255, 215, 0, 0.3)" p={3} borderRadius="16px">
            <HStack gap={2}>
              <FaExclamationTriangle color="#FFD700" />
              <Text color="#FFD700" fontSize="14px" fontWeight="500">Please connect your wallet to start trading</Text>
            </HStack>
          </Box>
        )}

        {/* Transaction Status */}
        {hash && (
          <Box bg="rgba(255, 215, 0, 0.15)" border="1px" borderColor="rgba(255, 215, 0, 0.3)" p={4} borderRadius="16px">
            <HStack align="start" gap={3}>
              <FaCheckCircle color="#FFD700" />
              <VStack align="start" gap={1}>
                <Text fontSize="14px" fontWeight="600" color="#FFD700">Transaction submitted!</Text>
                <Text fontSize="12px" color="rgba(255, 255, 255, 0.7)">
                  Hash: {hash.slice(0, 10)}...{hash.slice(-8)}
                </Text>
              </VStack>
            </HStack>
          </Box>
        )}
      </VStack>
    </Box>
  )
}
