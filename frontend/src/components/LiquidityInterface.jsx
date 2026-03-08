import { useState, useEffect } from 'react'
import { 
  Box, 
  VStack, 
  HStack, 
  Text,
  Tabs
} from '@chakra-ui/react'
import { chakra } from '@chakra-ui/react'

// Create custom components using chakra factory since Input, Button are not available in v3
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

import { toaster } from './ui/toaster'
import { FaExclamationTriangle, FaCheckCircle } from 'react-icons/fa'
import { FaPlus, FaMinus, FaChevronDown } from 'react-icons/fa'
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useBalance, useReadContract } from 'wagmi'
import { parseUnits, formatUnits, isAddress } from 'viem'
import { CONTRACT_ADDRESSES } from '../config/wagmi'
import { TokenSelector } from './TokenSelector'

// Router ABI in JSON format for reliable wagmi integration
const ROUTER_ABI = [
  {
    "inputs": [
      {"internalType": "address", "name": "token", "type": "address"},
      {"internalType": "uint256", "name": "amountTokenDesired", "type": "uint256"},
      {"internalType": "uint256", "name": "amountTokenMin", "type": "uint256"},
      {"internalType": "uint256", "name": "amountETHMin", "type": "uint256"},
      {"internalType": "address", "name": "to", "type": "address"},
      {"internalType": "uint256", "name": "deadline", "type": "uint256"}
    ],
    "name": "addLiquidityETH",
    "outputs": [
      {"internalType": "uint256", "name": "amountToken", "type": "uint256"},
      {"internalType": "uint256", "name": "amountETH", "type": "uint256"},
      {"internalType": "uint256", "name": "liquidity", "type": "uint256"}
    ],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "tokenA", "type": "address"},
      {"internalType": "address", "name": "tokenB", "type": "address"},
      {"internalType": "uint256", "name": "amountADesired", "type": "uint256"},
      {"internalType": "uint256", "name": "amountBDesired", "type": "uint256"},
      {"internalType": "uint256", "name": "amountAMin", "type": "uint256"},
      {"internalType": "uint256", "name": "amountBMin", "type": "uint256"},
      {"internalType": "address", "name": "to", "type": "address"},
      {"internalType": "uint256", "name": "deadline", "type": "uint256"}
    ],
    "name": "addLiquidity",
    "outputs": [
      {"internalType": "uint256", "name": "amountA", "type": "uint256"},
      {"internalType": "uint256", "name": "amountB", "type": "uint256"},
      {"internalType": "uint256", "name": "liquidity", "type": "uint256"}
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "tokenA", "type": "address"},
      {"internalType": "address", "name": "tokenB", "type": "address"},
      {"internalType": "uint256", "name": "liquidity", "type": "uint256"},
      {"internalType": "uint256", "name": "amountAMin", "type": "uint256"},
      {"internalType": "uint256", "name": "amountBMin", "type": "uint256"},
      {"internalType": "address", "name": "to", "type": "address"},
      {"internalType": "uint256", "name": "deadline", "type": "uint256"}
    ],
    "name": "removeLiquidity",
    "outputs": [
      {"internalType": "uint256", "name": "amountA", "type": "uint256"},
      {"internalType": "uint256", "name": "amountB", "type": "uint256"}
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]

// ERC20 ABI for token balance reading
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
  },
  {
    "inputs": [
      {"internalType": "address", "name": "spender", "type": "address"},
      {"internalType": "uint256", "name": "amount", "type": "uint256"}
    ],
    "name": "approve",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "owner", "type": "address"},
      {"internalType": "address", "name": "spender", "type": "address"}
    ],
    "name": "allowance",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  }
]

// Factory ABI for getting pair addresses
const FACTORY_ABI = [
  {
    "inputs": [
      {"internalType": "address", "name": "tokenA", "type": "address"},
      {"internalType": "address", "name": "tokenB", "type": "address"}
    ],
    "name": "getPair",
    "outputs": [{"internalType": "address", "name": "pair", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  }
]

// Pair ABI for LP token operations (Pair contracts are also ERC20 tokens)
const PAIR_ABI = [
  {
    "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalSupply",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "token0",
    "outputs": [{"internalType": "address", "name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "token1",
    "outputs": [{"internalType": "address", "name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  }
]

export function LiquidityInterface() {
  const { address, chainId } = useAccount()
  const { writeContract, data: hash, isPending } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })
  
  // Tab state
  const [activeTab, setActiveTab] = useState('add')
  const [transactionTab, setTransactionTab] = useState(null) // Track which tab initiated the transaction

  const contractAddresses = CONTRACT_ADDRESSES[chainId || 31337]

  // Create LP_PAIRS dynamically with correct WETH address
  const LP_PAIRS = [
    {
      id: 'eth-proto',
      name: 'ETH-PROTO',
      tokenA: 'ETH',
      tokenB: 'PROTO',
      tokenAAddress: contractAddresses?.weth || '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512', // Dynamic WETH
      tokenBAddress: contractAddresses?.dexToken || '0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9'  // DEXToken
    },
    {
      id: 'proto-eth',
      name: 'PROTO-ETH',
      tokenA: 'PROTO',
      tokenB: 'ETH', 
      tokenAAddress: contractAddresses?.dexToken || '0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9', // DEXToken
      tokenBAddress: contractAddresses?.weth || '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'  // Dynamic WETH
    }
  ]

  // Add Liquidity State
  const [tokenA, setTokenA] = useState('ETH')
  const [tokenB, setTokenB] = useState({
    symbol: 'PROTO',
    name: 'Proto Token',
    address: contractAddresses?.dexToken || '0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9',
    decimals: 18
  })
  const [amountA, setAmountA] = useState('1')
  const [amountB, setAmountB] = useState('1000')
  const [slippage, setSlippage] = useState('0.5')

  // Remove Liquidity State
  const [lpToken, setLpToken] = useState('')
  const [lpAmount, setLpAmount] = useState('')
  const [showLpDropdown, setShowLpDropdown] = useState(false)

  // Add state to track approval status
  const [approvalNeeded, setApprovalNeeded] = useState(true)
  const [approvalInProgress, setApprovalInProgress] = useState(false)

  // Check current allowance to determine if approval is needed
  const { data: currentAllowance, refetch: refetchAllowance, error: allowanceError, isLoading: allowanceLoading } = useReadContract({
    address: typeof tokenB === 'object' ? tokenB.address : undefined,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: [address, contractAddresses?.router],
    chainId: chainId || 31337,
    query: { 
      enabled: !!(address && contractAddresses?.router && typeof tokenB === 'object' && tokenB.address),
      refetchInterval: 2000,
      retry: 3,
      retryDelay: 1000
    }
  })

  // Debug the allowance query
  console.log('Allowance query debug:', {
    tokenBAddress: typeof tokenB === 'object' ? tokenB.address : 'not object',
    routerAddress: contractAddresses?.router,
    userAddress: address,
    queryEnabled: !!(address && contractAddresses?.router && typeof tokenB === 'object' && tokenB.address),
    currentAllowance: currentAllowance?.toString(),
    allowanceError: allowanceError?.message,
    allowanceLoading,
    chainId: chainId || 31337
  })

  // Update approval status based on allowance
  useEffect(() => {
    console.log('Checking approval status:', { 
      currentAllowance: currentAllowance?.toString(), 
      amountB, 
      approvalNeeded,
      allowanceError: allowanceError?.message,
      allowanceLoading
    })
    
    if (currentAllowance !== undefined && amountB) {
      try {
        const requiredAmount = parseUnits(amountB.toString(), 18)
        const isApprovalNeeded = currentAllowance < requiredAmount
        setApprovalNeeded(isApprovalNeeded)
        
        console.log('Approval calculation:', {
          required: requiredAmount.toString(),
          current: currentAllowance.toString(),
          needsApproval: isApprovalNeeded
        })
      } catch (error) {
        console.log('Error calculating approval:', error)
        setApprovalNeeded(true)
      }
    } else {
      console.log('Setting approval needed to true - allowance undefined or no amount')
      setApprovalNeeded(true)
    }
  }, [currentAllowance, amountB, allowanceError, allowanceLoading])

  // Handle successful transactions
  useEffect(() => {
    if (isSuccess && approvalInProgress) {
      // Approval transaction completed
      console.log('Approval transaction completed, refetching allowance...')
      setTimeout(() => {
        setApprovalInProgress(false)
        refetchAllowance?.() // Force refetch allowance
        
        // Also refetch after a delay to ensure blockchain state is updated
        setTimeout(() => {
          refetchAllowance?.()
        }, 3000)
        
        toaster.create({
          title: 'Approval Complete!',
          description: 'You can now add liquidity.',
          status: 'success',
          duration: 5000,
        })
      }, 1000)
    }
  }, [isSuccess, approvalInProgress, refetchAllowance])

  // Show success toast when transaction hash is available (same timing as "Transaction submitted!" message)
  useEffect(() => {
    if (hash) {
      // Defer toaster to avoid flushSync warning
      setTimeout(() => {
        toaster.create({
          title: 'Transaction Submitted Successfully',
          description: 'Your transaction has been submitted to the blockchain',
          status: 'success',
          duration: 5000,
        })
      }, 0)
      // Set the transaction tab when hash becomes available (only when hash changes)
      setTransactionTab(activeTab)
    }
  }, [hash])

  // Helper function to check if tokens are the same
  const areTokensSame = () => {
    if (!tokenA || !tokenB) return false
    
    const addressA = tokenA === 'ETH' ? 'ETH' : (typeof tokenA === 'object' ? tokenA.address : tokenA)
    const addressB = tokenB === 'ETH' ? 'ETH' : (typeof tokenB === 'object' ? tokenB.address : tokenB)
    
    return addressA === addressB
  }

  // Balance hooks for token A
  const { data: ethBalanceA, refetch: refetchEthA } = useBalance({
    address,
    query: { enabled: !!address && tokenA === 'ETH' }
  })

  const { data: tokenBalanceA, refetch: refetchTokenA } = useReadContract({
    address: tokenA && typeof tokenA === 'object' ? tokenA.address : undefined,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { 
      enabled: !!address && tokenA && typeof tokenA === 'object' && isAddress(tokenA.address),
      refetchInterval: 5000
    }
  })

  // Balance hooks for token B  
  const { data: ethBalanceB, refetch: refetchEthB } = useBalance({
    address,
    query: { enabled: !!address && tokenB === 'ETH' }
  })

  const { data: tokenBalanceB, refetch: refetchTokenB } = useReadContract({
    address: tokenB && typeof tokenB === 'object' ? tokenB.address : undefined,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { 
      enabled: !!address && tokenB && typeof tokenB === 'object' && isAddress(tokenB.address),
      refetchInterval: 5000
    }
  })

  // Get pair address for current token selection (for LP balance tracking)
  const { data: pairAddress } = useReadContract({
    address: contractAddresses?.factory,
    abi: FACTORY_ABI,
    functionName: 'getPair',
    args: [
      tokenA === 'ETH' ? contractAddresses?.weth : (typeof tokenA === 'object' ? tokenA.address : tokenA),
      tokenB === 'ETH' ? contractAddresses?.weth : (typeof tokenB === 'object' ? tokenB.address : tokenB)
    ],
    query: { 
      enabled: !!(contractAddresses?.factory && tokenA && tokenB && !areTokensSame()),
      refetchInterval: 5000
    }
  })

  // LP token balance for current pair
  const { data: lpTokenBalance, refetch: refetchLpBalance } = useReadContract({
    address: pairAddress,
    abi: PAIR_ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { 
      enabled: !!(pairAddress && address && pairAddress !== '0x0000000000000000000000000000000000000000'),
      refetchInterval: 5000
    }
  })

  // LP token balance for selected LP pair in remove liquidity section
  const selectedPair = LP_PAIRS.find(pair => pair.id === lpToken)
  
  // Get pair address for selected LP pair
  const { data: selectedPairAddress } = useReadContract({
    address: contractAddresses?.factory,
    abi: FACTORY_ABI,
    functionName: 'getPair',
    args: [selectedPair?.tokenAAddress, selectedPair?.tokenBAddress],
    query: { 
      enabled: !!(contractAddresses?.factory && selectedPair?.tokenAAddress && selectedPair?.tokenBAddress),
      refetchInterval: 5000
    }
  })

  const { data: removeLpBalance, refetch: refetchRemoveLpBalance } = useReadContract({
    address: selectedPairAddress,
    abi: PAIR_ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { 
      enabled: !!(selectedPairAddress && address && selectedPairAddress !== '0x0000000000000000000000000000000000000000'),
      refetchInterval: 5000
    }
  })

  // Refetch balances when transaction is confirmed
  useEffect(() => {
    if (hash && !isConfirming && !isPending) {
      // Wait a moment then refetch all balances
      const refetchAll = async () => {
        try {
          await Promise.all([
            refetchEthA?.(),
            refetchEthB?.(), 
            refetchTokenA?.(),
            refetchTokenB?.(),
            refetchLpBalance?.(),
            refetchRemoveLpBalance?.()
          ])
        } catch (error) {
          console.log('Refetch error:', error)
        }
      }
      
      setTimeout(refetchAll, 2000)
    }
  }, [hash, isConfirming, isPending, refetchEthA, refetchEthB, refetchTokenA, refetchTokenB, refetchLpBalance, refetchRemoveLpBalance])

  // Auto-select the current pair in remove liquidity if it has LP tokens and no pair is selected
  const currentAddPairHasLp = pairAddress && pairAddress !== '0x0000000000000000000000000000000000000000' && lpTokenBalance && lpTokenBalance > 0n
  
  useEffect(() => {
    if (currentAddPairHasLp && !lpToken && tokenA && tokenB) {
      const tokenASymbol = tokenA === 'ETH' ? 'ETH' : (typeof tokenA === 'object' ? 'PROTO' : tokenA)
      const tokenBSymbol = tokenB === 'ETH' ? 'ETH' : (typeof tokenB === 'object' ? 'PROTO' : tokenB)
      const pairId = `${tokenASymbol.toLowerCase()}-${tokenBSymbol.toLowerCase()}`
      
      // Check if this pair exists in LP_PAIRS
      const existingPair = LP_PAIRS.find(pair => pair.id === pairId || pair.id === `${tokenBSymbol.toLowerCase()}-${tokenASymbol.toLowerCase()}`)
      if (existingPair) {
        setLpToken(existingPair.id)
      }
    }
  }, [currentAddPairHasLp, lpToken, tokenA, tokenB, LP_PAIRS])

  // Helper function to format balance
  const formatBalance = (balance, decimals = 18) => {
    if (!balance) return '0.00'
    const formatted = formatUnits(balance, decimals)
    const num = parseFloat(formatted)
    if (num < 0.01 && num > 0) return '<0.01'
    return num.toFixed(4)
  }

  // Function to get balance for a token
  const getTokenBalance = (token) => {
    if (!address) return '0.00'
    
    if (token === 'ETH') {
      if (token === tokenA) return formatBalance(ethBalanceA?.value)
      if (token === tokenB) return formatBalance(ethBalanceB?.value)
    } else if (typeof token === 'object' && token.address) {
      if (token === tokenA) return formatBalance(tokenBalanceA, token.decimals || 18)
      if (token === tokenB) return formatBalance(tokenBalanceB, token.decimals || 18)
    }
    
    return '0.00'
  }

  // Function to refetch all balances
  const refetchAllBalances = () => {
    if (tokenA === 'ETH') refetchEthA?.()
    else if (typeof tokenA === 'object') refetchTokenA?.()
    
    if (tokenB === 'ETH') refetchEthB?.()
    else if (typeof tokenB === 'object') refetchTokenB?.()

    refetchLpBalance?.()
    refetchRemoveLpBalance?.()
  }

  // Function to get LP token balance for current pair
  const getCurrentLpBalance = () => {
    if (!address || !pairAddress || pairAddress === '0x0000000000000000000000000000000000000000') {
      return '0.00'
    }
    return formatBalance(lpTokenBalance, 18)
  }

  // Function to get LP token balance for remove liquidity
  const getRemoveLpBalance = () => {
    if (!address || !selectedPairAddress || selectedPairAddress === '0x0000000000000000000000000000000000000000') {
      return '0.00'
    }
    return formatBalance(removeLpBalance, 18)
  }

  // LP Selector Component
  const LpSelector = ({ selectedLp, onLpSelect }) => {
    const selectedPair = LP_PAIRS.find(pair => pair.id === selectedLp)
    
    return (
      <Box position="relative">
        <HStack
          px={4}
          py={3}
          borderRadius="16px"
          border="1px solid"
          borderColor="rgba(255, 215, 0, 0.3)"
          transition="all 0.2s"
          _hover={{ 
            bg: "#242424",
            borderColor: "#FFD700"
          }}
          cursor="pointer"
          onClick={() => setShowLpDropdown(!showLpDropdown)}
          bg="#1A1A1A"
          minW="140px"
          justify="space-between"
        >
          <Text color="white" fontSize="14px" fontWeight="500">
            {selectedPair ? selectedPair.name : 'Select LP'}
          </Text>
          <FaChevronDown color="#FFD700" size="12px" />
        </HStack>

        {showLpDropdown && (
          <Box
            position="absolute"
            top="100%"
            left={0}
            right={0}
            mt={1}
            bg="#1A1A1A"
            border="1px solid rgba(255, 215, 0, 0.2)"
            borderRadius="12px"
            zIndex={10}
            maxH="200px"
            overflowY="auto"
          >
            {LP_PAIRS.map((pair) => (
              <HStack
                key={pair.id}
                p={3}
                cursor="pointer"
                _hover={{ bg: "rgba(255, 215, 0, 0.1)" }}
                onClick={() => {
                  onLpSelect(pair.id)
                  setShowLpDropdown(false)
                }}
              >
                <Text color="white" fontSize="14px">
                  {pair.name}
                </Text>
              </HStack>
            ))}
          </Box>
        )}
      </Box>
    )
  }

  const handleAddLiquidity = async () => {
    if (!amountA || !amountB || !tokenA || !tokenB) {
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
        description: 'Token A and Token B cannot be the same. Please select different tokens.',
        status: 'error',
        duration: 4000,
      })
      return
    }

    try {
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200) // 20 minutes
      const amountADesired = parseUnits(amountA.toString(), 18)
      const amountBDesired = parseUnits(amountB.toString(), 18)
      const amountAMin = parseUnits((parseFloat(amountA) * (1 - parseFloat(slippage) / 100)).toString(), 18)
      const amountBMin = parseUnits((parseFloat(amountB) * (1 - parseFloat(slippage) / 100)).toString(), 18)

      if (tokenA === 'ETH' || tokenB === 'ETH') {
        // Add ETH liquidity
        const token = tokenA === 'ETH' ? 
          (typeof tokenB === 'object' ? tokenB.address : tokenB) : 
          (typeof tokenA === 'object' ? tokenA.address : tokenA)
        const tokenAmount = tokenA === 'ETH' ? amountB : amountA
        const ethAmount = tokenA === 'ETH' ? amountA : amountB
        const tokenAmountMin = tokenA === 'ETH' ? amountBMin : amountAMin
        const ethAmountMin = tokenA === 'ETH' ? amountAMin : amountBMin

        const tokenAmountBigInt = parseUnits(tokenAmount.toString(), 18)
        
        if (approvalNeeded) {
          // Step 1: Approve tokens first
          toaster.create({
            title: 'Approve Tokens First',
            description: 'Please approve PROTO tokens before adding liquidity.',
            status: 'info',
            duration: 5000,
          })

          setApprovalInProgress(true)
          
          writeContract({
            address: token,
            abi: ERC20_ABI,
            functionName: 'approve',
            args: [contractAddresses.router, tokenAmountBigInt]
          })
        } else {
          // Step 2: Add liquidity (approval already done)
          toaster.create({
            title: 'Adding Liquidity',
            description: 'Please confirm the add liquidity transaction.',
            status: 'info',
            duration: 5000,
          })

          writeContract({
            address: contractAddresses.router,
            abi: ROUTER_ABI,
            functionName: 'addLiquidityETH',
            args: [
              token,
              tokenAmountBigInt,
              tokenAmountMin,
              ethAmountMin,
              address,
              deadline
            ],
            value: parseUnits(ethAmount.toString(), 18)
          })
        }

      } else {
        // Add token-token liquidity
        const tokenAddressA = typeof tokenA === 'object' ? tokenA.address : tokenA
        const tokenAddressB = typeof tokenB === 'object' ? tokenB.address : tokenB
        
        // Approve both tokens
        toaster.create({
          title: 'Step 1: Token A Approval',
          description: 'Please approve the first token in your wallet.',
          status: 'info',
          duration: 5000,
        })

        const approveHashA = await writeContract({
          address: tokenAddressA,
          abi: ERC20_ABI,
          functionName: 'approve',
          args: [contractAddresses.router, amountADesired]
        })

        toaster.create({
          title: 'Step 2: Token B Approval',
          description: 'Please approve the second token in your wallet.',
          status: 'info',
          duration: 5000,
        })

        const approveHashB = await writeContract({
          address: tokenAddressB,
          abi: ERC20_ABI,
          functionName: 'approve',
          args: [contractAddresses.router, amountBDesired]
        })

        toaster.create({
          title: 'Step 3: Add Liquidity',
          description: 'Now confirm the add liquidity transaction in your wallet.',
          status: 'info',
          duration: 5000,
        })
        
        await writeContract({
          address: contractAddresses.router,
          abi: ROUTER_ABI,
          functionName: 'addLiquidity',
          args: [
            tokenAddressA,
            tokenAddressB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            address,
            deadline
          ]
        })
      }

      // Success handling is now done via useEffect when hash changes
      
      // Refetch balances after successful transaction
      setTimeout(() => {
        refetchAllBalances()
      }, 1000)
    } catch (error) {
      toaster.create({
        title: 'Add Liquidity Failed',
        description: error.message,
        status: 'error',
        duration: 5000,
      })
    }
  }

  const handleRemoveLiquidity = async () => {
    if (!lpAmount || !lpToken) {
      toaster.create({
        title: 'Error',
        description: 'Please enter all required fields',
        status: 'error',
        duration: 3000,
      })
      return
    }

    try {
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200) // 20 minutes
      const liquidity = parseUnits(lpAmount.toString(), 18)

      // Get the correct token addresses from the selected LP pair
      const selectedPair = LP_PAIRS.find(pair => pair.id === lpToken)
      if (!selectedPair) {
        throw new Error('Selected LP pair not found')
      }

      // Step 1: Approve LP token spending by the router
      toaster.create({
        title: 'Approval Required',
        description: 'Please approve LP token spending in your wallet, then confirm the remove liquidity transaction.',
        status: 'info',
        duration: 8000,
      })

      await writeContract({
        address: selectedPairAddress, // The LP pair contract address
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [contractAddresses.router, liquidity]
      })

      // Wait a bit for approval to be mined
      await new Promise(resolve => setTimeout(resolve, 3000))

      // Step 2: Remove liquidity
      await writeContract({
        address: contractAddresses.router,
        abi: ROUTER_ABI,
        functionName: 'removeLiquidity',
        args: [
          selectedPair.tokenAAddress, // Use correct token addresses from LP pair
          selectedPair.tokenBAddress, // Use correct token addresses from LP pair
          liquidity,
          0n, // amountAMin (could calculate with slippage)
          0n, // amountBMin (could calculate with slippage)
          address,
          deadline
        ]
      })

      // Success handling and balance refetching is now done via useEffect when transaction is confirmed
    } catch (error) {
      toaster.create({
        title: 'Remove Liquidity Failed',
        description: error.message,
        status: 'error',
        duration: 5000,
      })
    }
  }

  return (
    <Box
      maxW="md"
      mx="auto"
      p={6}
      borderRadius="xl"
      border="1px"
      borderColor="rgba(255, 215, 0, 0.2)"
      bg="#1A1A1A"
      shadow="0 20px 40px rgba(0, 0, 0, 0.1)"
    >
      {/* Navigation Tabs */}
      <HStack gap={1} bg="#1F1F1F" p={1} borderRadius="16px" w="fit-content" mx="auto" border="1px solid rgba(255, 215, 0, 0.2)" mb={6}>
        <Button
          px={6}
          py={3}
          borderRadius="12px"
          bg={activeTab === 'add' ? "#DC143C" : "transparent"}
          shadow={activeTab === 'add' ? "0 4px 12px rgba(220, 20, 60, 0.3)" : "none"}
          fontSize="16px"
          fontWeight={activeTab === 'add' ? "600" : "500"}
          color={activeTab === 'add' ? "white" : "#FFD700"}
          _hover={{
            bg: activeTab === 'add' ? "#B71C1C" : "#242424",
            transform: activeTab === 'add' ? "translateY(-1px)" : "none"
          }}
          transition="all 0.2s"
          onClick={() => setActiveTab('add')}
        >
          <HStack gap={2}>
            <FaPlus />
            <Text>Add Liquidity</Text>
          </HStack>
        </Button>
        <Button
          px={6}
          py={3}
          borderRadius="12px"
          bg={activeTab === 'remove' ? "#DC143C" : "transparent"}
          shadow={activeTab === 'remove' ? "0 4px 12px rgba(220, 20, 60, 0.3)" : "none"}
          fontSize="16px"
          fontWeight={activeTab === 'remove' ? "600" : "500"}
          color={activeTab === 'remove' ? "white" : "#FFD700"}
          _hover={{
            bg: activeTab === 'remove' ? "#B71C1C" : "#242424",
            transform: activeTab === 'remove' ? "translateY(-1px)" : "none"
          }}
          transition="all 0.2s"
          onClick={() => setActiveTab('remove')}
        >
          <HStack gap={2}>
            <FaMinus />
            <Text>Remove Liquidity</Text>
          </HStack>
        </Button>
      </HStack>

      {/* Add Liquidity Panel */}
      {activeTab === 'add' && (
            <VStack gap={4}>
              <Text fontSize="lg" fontWeight="bold" alignSelf="start" color="white">
                Add Liquidity
              </Text>

              {/* Token A Input */}
              <Box w="full" p={4} borderRadius="lg" bg="#242424" border="1px" borderColor="rgba(255, 215, 0, 0.2)">
                <VStack gap={3}>
                  <HStack justify="space-between" w="full">
                    <Text fontSize="sm" color="#FFD700">Token A</Text>
                    <Text fontSize="sm" color="rgba(255, 255, 255, 0.7)">Balance: {getTokenBalance(tokenA)}</Text>
                  </HStack>
                  <HStack w="full" gap={3}>
                    <Input
                      placeholder="0.0"
                      value={amountA}
                      onChange={(e) => setAmountA(e.target.value)}
                      fontSize="xl"
                      fontWeight="bold"
                      border="none"
                      bg="transparent"
                      color="white"
                      _placeholder={{ color: "rgba(255, 255, 255, 0.4)" }}
                      _focus={{ boxShadow: 'none' }}
                      flex={1}
                    />
                    <TokenSelector
                      selectedToken={tokenA}
                      onTokenSelect={setTokenA}
                      excludeToken={tokenB}
                      placeholder="Select token"
                    />
                  </HStack>
                </VStack>
              </Box>

              {/* Plus Icon */}
              <Box color="gray.400">
                <FaPlus />
              </Box>

              {/* Same Token Error Message */}
              {areTokensSame() && (
                <Box w="full" p={3} borderRadius="12px" bg="rgba(239, 68, 68, 0.15)" border="1px" borderColor="rgba(239, 68, 68, 0.3)">
                  <HStack gap={2}>
                    <FaExclamationTriangle color="rgb(239, 68, 68)" size="14px" />
                    <Text fontSize="14px" color="rgb(239, 68, 68)" fontWeight="500">
                      Token A and Token B cannot be the same. Please select different tokens.
                    </Text>
                  </HStack>
                </Box>
              )}

              {/* Token B Input */}
              <Box w="full" p={4} borderRadius="lg" bg="#242424" border="1px" borderColor="rgba(255, 215, 0, 0.2)">
                <VStack gap={3}>
                  <HStack justify="space-between" w="full">
                    <Text fontSize="sm" color="#FFD700">Token B</Text>
                    <Text fontSize="sm" color="rgba(255, 255, 255, 0.7)">Balance: {getTokenBalance(tokenB)}</Text>
                  </HStack>
                  <HStack w="full" gap={3}>
                    <Input
                      placeholder="0.0"
                      value={amountB}
                      onChange={(e) => setAmountB(e.target.value)}
                      fontSize="xl"
                      fontWeight="bold"
                      border="none"
                      bg="transparent"
                      color="white"
                      _placeholder={{ color: "rgba(255, 255, 255, 0.4)" }}
                      _focus={{ boxShadow: 'none' }}
                      flex={1}
                    />
                    <TokenSelector
                      selectedToken={tokenB}
                      onTokenSelect={setTokenB}
                      excludeToken={tokenA}
                      placeholder="Select token"
                    />
                  </HStack>
                </VStack>
              </Box>

              {/* Slippage Setting */}
              <HStack justify="space-between" w="full" fontSize="sm">
                <Text color="#FFD700">Slippage Tolerance</Text>
                <HStack>
                  <Input
                    value={slippage}
                    onChange={(e) => setSlippage(e.target.value)}
                    w="60px"
                    size="sm"
                    textAlign="center"
                    bg="#242424"
                    color="white"
                    border="1px"
                    borderColor="rgba(255, 215, 0, 0.2)"
                    _focus={{ borderColor: "#DC143C" }}
                  />
                  <Text color="rgba(255, 255, 255, 0.7)">%</Text>
                </HStack>
              </HStack>

              {/* Current LP Balance Info */}
              {pairAddress && pairAddress !== '0x0000000000000000000000000000000000000000' && (
                <Box w="full" p={3} borderRadius="12px" bg="rgba(255, 215, 0, 0.1)" border="1px" borderColor="rgba(255, 215, 0, 0.2)">
                  <HStack justify="space-between">
                    <Text fontSize="sm" color="#FFD700" fontWeight="500">
                      Your LP Tokens for this pair:
                    </Text>
                    <Text fontSize="sm" color="white" fontWeight="600">
                      {getCurrentLpBalance()}
                    </Text>
                  </HStack>
                </Box>
              )}

              {!address && (
                <Box bg="orange.50" border="1px" borderColor="orange.200" p={4} borderRadius="md">
                  <HStack>
                    <FaExclamationTriangle style={{ color: "orange" }} />
                    <Text color="orange.700">Please connect your wallet to add liquidity</Text>
                  </HStack>
                </Box>
              )}

              <Button
                w="full"
                size="lg"
                colorPalette={approvalNeeded ? "blue" : "green"}
                border="1px solid"
                borderColor="rgba(255, 215, 0, 0.3)"
                _hover={{ 
                  borderColor: "#FFD700"
                }}
                onClick={handleAddLiquidity}
                disabled={!address || !amountA || !amountB || areTokensSame() || isPending || isConfirming}
              >
                {isPending || isConfirming 
                  ? (approvalNeeded ? 'Approving...' : 'Adding Liquidity...') 
                  : (approvalNeeded ? 'Approve PROTO Tokens' : 'Add Liquidity')}
              </Button>
            </VStack>
      )}

        {/* Remove Liquidity Panel */}
        {activeTab === 'remove' && (
            <VStack gap={4}>
              <Text fontSize="lg" fontWeight="bold" alignSelf="start" color="white">
                Remove Liquidity
              </Text>

              {/* LP Token Input */}
              <Box w="full" p={4} borderRadius="lg" bg="#242424" border="1px" borderColor="rgba(255, 215, 0, 0.2)">
                <VStack gap={3}>
                  <HStack justify="space-between" w="full">
                    <Text fontSize="sm" color="#FFD700">LP Token Amount</Text>
                    <Text fontSize="sm" color="rgba(255, 255, 255, 0.7)">LP Balance: {getRemoveLpBalance()}</Text>
                  </HStack>
                  <HStack w="full" gap={3}>
                    <Input
                      placeholder="0.0"
                      value={lpAmount}
                      onChange={(e) => setLpAmount(e.target.value)}
                      fontSize="xl"
                      fontWeight="bold"
                      border="none"
                      bg="transparent"
                      color="white"
                      _placeholder={{ color: "rgba(255, 255, 255, 0.4)" }}
                      _focus={{ boxShadow: 'none' }}
                      flex={1}
                    />
                    <LpSelector
                      selectedLp={lpToken}
                      onLpSelect={setLpToken}
                    />
                  </HStack>
                </VStack>
              </Box>

              {/* Helper to use current Add Liquidity pair */}
              {currentAddPairHasLp && (
                <Box w="full" p={3} borderRadius="12px" bg="rgba(255, 215, 0, 0.1)" border="1px" borderColor="rgba(255, 215, 0, 0.2)">
                  <HStack justify="space-between">
                    <VStack align="start" gap={1}>
                      <Text fontSize="sm" color="#FFD700" fontWeight="500">
                        You have LP tokens for {tokenA === 'ETH' ? 'ETH' : (typeof tokenA === 'object' ? tokenA.symbol : tokenA)}-{tokenB === 'ETH' ? 'ETH' : (typeof tokenB === 'object' ? tokenB.symbol : tokenB)}
                      </Text>
                      <Text fontSize="xs" color="rgba(255, 255, 255, 0.7)">
                        Balance: {getCurrentLpBalance()}
                      </Text>
                    </VStack>
                    <Button
                      size="sm"
                      px={3}
                      py={1}
                      bg="#DC143C"
                      color="white"
                      fontSize="12px"
                      _hover={{ bg: "#B71C1C" }}
                      onClick={() => {
                        const tokenASymbol = tokenA === 'ETH' ? 'ETH' : 'PROTO'
                        const tokenBSymbol = tokenB === 'ETH' ? 'ETH' : 'PROTO'
                        const pairId = `${tokenASymbol.toLowerCase()}-${tokenBSymbol.toLowerCase()}`
                        const existingPair = LP_PAIRS.find(pair => pair.id === pairId || pair.id === `${tokenBSymbol.toLowerCase()}-${tokenASymbol.toLowerCase()}`)
                        if (existingPair) {
                          setLpToken(existingPair.id)
                        }
                      }}
                    >
                      Use This Pair
                    </Button>
                  </HStack>
                </Box>
              )}

              {!address && (
                <Box bg="orange.50" border="1px" borderColor="orange.200" p={4} borderRadius="md">
                  <HStack>
                    <FaExclamationTriangle style={{ color: "orange" }} />
                    <Text color="orange.700">Please connect your wallet to remove liquidity</Text>
                  </HStack>
                </Box>
              )}

              <Button
                w="full"
                size="lg"
                colorPalette="red"
                border="1px solid"
                borderColor="rgba(255, 215, 0, 0.3)"
                _hover={{ 
                  borderColor: "#FFD700"
                }}
                onClick={handleRemoveLiquidity}
                disabled={!address || !lpAmount || isPending || isConfirming}
              >
                {isPending || isConfirming ? 'Removing...' : 'Remove Liquidity'}
              </Button>
            </VStack>
      )}

      {/* Transaction Status */}
      {hash && transactionTab === activeTab && (
        <Box bg="green.50" border="1px" borderColor="green.200" p={4} borderRadius="md" mt={4}>
          <HStack align="start" gap={3}>
            <FaCheckCircle style={{ color: 'green' }} />
            <VStack align="start" gap={1}>
              <Text fontSize="sm" color="green.700">Transaction submitted!</Text>
              <Text fontSize="xs" color="gray.600">
                Hash: {hash.slice(0, 10)}...{hash.slice(-8)}
              </Text>
            </VStack>
          </HStack>
        </Box>
      )}
    </Box>
  )
}
