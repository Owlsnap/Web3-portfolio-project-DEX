// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Pair.sol";
import "./Treasury.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Factory
 * @dev Factory contract for creating and managing trading pairs
 * Based on Uniswap V2 Factory pattern with governance integration
 * 
 * Key responsibilities:
 * - Create new trading pairs between two tokens
 * - Prevent duplicate pairs (only one pair per token combination)
 * - Track all created pairs in a registry
 * - Manage fee collection settings (now controlled by governance)
 * - Allow governance to control protocol parameters
 */
contract Factory is Ownable {
    using SafeERC20 for IERC20;
    
    // ============ STATE VARIABLES ============
    
    /**
     * @dev Address that receives protocol fees (if enabled)
     * If address(0), no fees are taken
     */
    address public feeTo;
    
    /**
     * @dev Treasury contract for automated fee collection
     * When set, fees can be automatically sent to treasury
     */
    Treasury public treasury;
    
    /**
     * @dev Trading fee percentage (in basis points)
     * Default: 30 basis points = 0.3% (same as Uniswap V2)
     * Governance can adjust this from 0.05% to 1.0%
     */
    uint256 public tradingFee = 30; // 0.3% default
    
    /**
     * @dev Flash loan fee percentage (in basis points) 
     * Default: 9 basis points = 0.09% (30% of trading fee)
     * Governance can adjust this independently
     */
    uint256 public flashLoanFee = 9; // 0.09% default

    /**
     * @dev Nested mapping to get pair address from two tokens
     * getPair[tokenA][tokenB] = pair address
     * Works both ways: getPair[tokenA][tokenB] == getPair[tokenB][tokenA]
     */
    mapping(address => mapping(address => address)) public getPair;
    
    /**
     * @dev Array of all created pair addresses
     * Used to iterate through all pairs
     */
    address[] public allPairs;

    // ============ EVENTS ============
    
    /**
     * @dev Emitted when a new pair is created
     * @param token0 First token address (lexicographically smaller)
     * @param token1 Second token address (lexicographically larger)  
     * @param pair Address of the newly created pair contract
     * @param pairLength Total number of pairs after creation
     */
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256 pairLength
    );

    // ============ CONSTRUCTOR ============
    
    // ============ EVENTS ============
    
    /**
     * @dev Emitted when trading fee is changed by governance
     */
    event TradingFeeChanged(uint256 oldFee, uint256 newFee);
    
    /**
     * @dev Emitted when flash loan fee is changed by governance
     */
    event FlashLoanFeeChanged(uint256 oldFee, uint256 newFee);
    
    /**
     * @dev Emitted when fee recipient is changed by governance
     */
    event FeeToChanged(address oldFeeTo, address newFeeTo);
    
    /**
     * @dev Emitted when treasury is updated by governance
     */
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    
    /**
     * @dev Emitted when fees are collected to treasury
     */
    event FeesCollectedToTreasury(address indexed token, uint256 amount);

    /**
     * @dev Initialize the factory
     * @param initialOwner Address that will own the factory (should be governance timelock)
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        // Factory is owned by governance from deployment
        // No separate feeToSetter needed - governance controls everything
    }

    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Returns the total number of pairs created
     * @return Number of pairs in the allPairs array
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    // ============ PAIR CREATION ============
    
    /**
     * @dev Creates a new trading pair for tokenA and tokenB
     * @param tokenA Address of first token
     * @param tokenB Address of second token
     * @return pair Address of the newly created pair contract
     */
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair)
    {
        // Input validation
        require(tokenA != tokenB, "Factory: IDENTICAL_ADDRESSES");
        
        // Sort tokens (token0 < token1) for consistent pair addressing
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
            
        require(token0 != address(0), "Factory: ZERO_ADDRESS");
        require(
            getPair[token0][token1] == address(0),
            "Factory: PAIR_EXISTS"
        );

        // Deploy new pair contract using CREATE2 for deterministic addresses
        bytes memory bytecode = type(Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // Initialize the pair with token addresses
        Pair(pair).initialize(token0, token1);
        
        // Update mappings (both directions for easy lookup)
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        
        // Add to pairs array
        allPairs.push(pair);
        
        // Emit creation event
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    // ============ GOVERNANCE FUNCTIONS ============
    
    /**
     * @dev Set the address that receives protocol fees (governance only)
     * @param _feeTo New fee recipient address (address(0) to disable fees)
     */
    function setFeeTo(address _feeTo) external onlyOwner {
        address oldFeeTo = feeTo;
        feeTo = _feeTo;
        emit FeeToChanged(oldFeeTo, _feeTo);
    }

    /**
     * @dev Set the trading fee percentage (governance only)
     * @param _tradingFee New trading fee in basis points (5-100, i.e., 0.05%-1.0%)
     */
    function setTradingFee(uint256 _tradingFee) external onlyOwner {
        require(_tradingFee >= 5 && _tradingFee <= 100, "Factory: INVALID_FEE_RANGE");
        uint256 oldFee = tradingFee;
        tradingFee = _tradingFee;
        emit TradingFeeChanged(oldFee, _tradingFee);
    }

    /**
     * @dev Set the flash loan fee percentage (governance only)
     * @param _flashLoanFee New flash loan fee in basis points (1-50, i.e., 0.01%-0.5%)
     */
    function setFlashLoanFee(uint256 _flashLoanFee) external onlyOwner {
        require(_flashLoanFee >= 1 && _flashLoanFee <= 50, "Factory: INVALID_FLASH_FEE_RANGE");
        uint256 oldFee = flashLoanFee;
        flashLoanFee = _flashLoanFee;
        emit FlashLoanFeeChanged(oldFee, _flashLoanFee);
    }

    /**
     * @dev Set the treasury contract for automated fee collection (governance only)
     * @param _treasury New treasury contract address
     */
    function setTreasury(address _treasury) external onlyOwner {
        address oldTreasury = address(treasury);
        treasury = Treasury(payable(_treasury));
        emit TreasuryUpdated(oldTreasury, _treasury);
    }

    /**
     * @dev Collect fees from a specific pair to treasury (anyone can call)
     * @param pair Address of the pair to collect fees from
     * @param token Address of the token to collect fees for
     */
    function collectFeesToTreasury(address pair, address token) external {
        require(address(treasury) != address(0), "Factory: Treasury not set");
        require(pair != address(0), "Factory: Invalid pair");
        require(token != address(0), "Factory: Invalid token");
        
        uint256 balance = IERC20(token).balanceOf(pair);
        if (balance > 0) {
            // Transfer fees from pair directly to treasury
            IERC20(token).safeTransferFrom(pair, address(treasury), balance);
            
            // Notify treasury of the deposit to update internal tracking
            treasury.receiveTokenDeposit(token, balance, pair);
            
            emit FeesCollectedToTreasury(token, balance);
        }
    }

    /**
     * @dev Collect ETH fees to treasury (anyone can call)
     */
    function collectETHFeesToTreasury() external payable {
        require(address(treasury) != address(0), "Factory: Treasury not set");
        
        if (msg.value > 0) {
            // Send ETH to treasury
            (bool success, ) = payable(address(treasury)).call{value: msg.value}("");
            require(success, "Factory: ETH transfer failed");
            
            emit FeesCollectedToTreasury(address(0), msg.value);
        }
    }

    /**
     * @dev Get current fee information
     * @return _feeTo Fee recipient address
     * @return _tradingFee Trading fee in basis points
     * @return _flashLoanFee Flash loan fee in basis points
     */
    function getFeeInfo() external view returns (address _feeTo, uint256 _tradingFee, uint256 _flashLoanFee) {
        return (feeTo, tradingFee, flashLoanFee);
    }

    /**
     * @dev Get treasury information
     * @return treasuryAddress Address of the treasury contract
     * @return isSet Boolean indicating if treasury is set
     */
    function getTreasuryInfo() external view returns (address treasuryAddress, bool isSet) {
        return (address(treasury), address(treasury) != address(0));
    }
}
