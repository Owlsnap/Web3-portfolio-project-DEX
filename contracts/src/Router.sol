// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Factory.sol";
import "./Pair.sol";
import {WETH as WrappedETH} from "./WETH.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Router
 * @dev User-friendly interface for DEX operations
 * Handles adding/removing liquidity and token swaps with safety checks
 */
contract Router {
    
    // ============ STATE VARIABLES ============
    
    address public immutable factory; // Factory contract address
    address public immutable WETH;    // WETH contract address
    
    // ============ CONSTRUCTOR ============
    
    /**
     * @dev Initialize router with factory and WETH addresses
     * @param _factory Address of the Factory contract
     * @param _WETH Address of the WETH contract
     */
    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }
    
    // ============ MODIFIERS ============
    
    /**
     * @dev Ensures transaction completes before deadline
     * Prevents transactions from being executed long after submission
     */
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "Router: EXPIRED");
        _;
    }
    
    /**
     * @dev Receive ETH (needed for WETH unwrapping)
     */
    receive() external payable {
        // Only accept ETH from WETH contract during unwrapping
        require(msg.sender == WETH, "Router: DIRECT_ETH_NOT_ALLOWED");
    }
    
    // ============ HELPER FUNCTIONS ============
    
    /**
     * @dev Get or create a pair for two tokens
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return pair Address of the pair contract
     */
    function _getPair(address tokenA, address tokenB) internal view returns (address pair) {
        pair = Factory(factory).getPair(tokenA, tokenB);
    }
    
    // ============ PUBLIC VIEW FUNCTIONS ============
    
    /**
     * @dev Check if a pair exists between two tokens
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return pair Address of pair contract (address(0) if doesn't exist)
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair) {
        return Factory(factory).getPair(tokenA, tokenB);
    }
    
    /**
     * @dev Check if a pair exists (returns boolean for convenience)
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return exists True if pair exists, false otherwise
     */
    function pairExists(address tokenA, address tokenB) external view returns (bool exists) {
        return Factory(factory).getPair(tokenA, tokenB) != address(0);
    }
    
    /**
     * @dev Create a new trading pair (if it doesn't exist)
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return pair Address of the created pair contract
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        return Factory(factory).createPair(tokenA, tokenB);
    }
    
    /**
     * @dev Get the total number of pairs created
     * @return count Total number of pairs
     */
    function allPairsLength() external view returns (uint256 count) {
        return Factory(factory).allPairsLength();
    }
    
    /**
     * @dev Get pair address by index
     * @param index Index in the pairs array
     * @return pair Address of the pair at given index
     */
    function allPairs(uint256 index) external view returns (address pair) {
        return Factory(factory).allPairs(index);
    }
    
    /**
     * @dev Calculate optimal amounts for adding liquidity
     * @param tokenA Address of first token
     * @param tokenB Address of second token
     * @param amountADesired Amount of tokenA user wants to add
     * @param amountBDesired Amount of tokenB user wants to add
     * @param amountAMin Minimum amount of tokenA (slippage protection)
     * @param amountBMin Minimum amount of tokenB (slippage protection)
     * @return amountA Actual amount of tokenA to add
     * @return amountB Actual amount of tokenB to add
     */
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        // Get current reserves from the pair
        (uint256 reserveA, uint256 reserveB) = _getReserves(tokenA, tokenB);
        
        if (reserveA == 0 && reserveB == 0) {
            // First time adding liquidity - use exactly what user wants
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // Calculate optimal amounts based on current ratio
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Router: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Router: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    
    /**
     * @dev Get reserves for a token pair
     * @param tokenA First token address  
     * @param tokenB Second token address
     * @return reserveA Reserve of tokenA
     * @return reserveB Reserve of tokenB
     */
    function _getReserves(address tokenA, address tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        address pair = _getPair(tokenA, tokenB);
        if (pair == address(0)) {
            return (0, 0);
        }
        
        (uint256 reserve0, uint256 reserve1,) = Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA < tokenB ? (reserve0, reserve1) : (reserve1, reserve0);
    }
    
    // ============ LIQUIDITY FUNCTIONS ============
    
    /**
     * @dev Add liquidity to a token pair
     * @param tokenA Address of first token
     * @param tokenB Address of second token  
     * @param amountADesired Amount of tokenA user wants to add
     * @param amountBDesired Amount of tokenB user wants to add
     * @param amountAMin Minimum amount of tokenA (slippage protection)
     * @param amountBMin Minimum amount of tokenB (slippage protection)
     * @param to Address to receive LP tokens
     * @param deadline Transaction must complete before this time
     * @return amountA Actual amount of tokenA added
     * @return amountB Actual amount of tokenB added  
     * @return liquidity Amount of LP tokens minted
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // Calculate optimal amounts to add
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        
        // Get or create the pair
        address pair = _getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = Factory(factory).createPair(tokenA, tokenB);
        }
        
        // Transfer tokens from user to pair contract
        IERC20(tokenA).transferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).transferFrom(msg.sender, pair, amountB);
        
        // Mint LP tokens to specified address
        liquidity = Pair(pair).mint(to);
    }
    
    /**
     * @dev Remove liquidity from a token pair
     * @param tokenA Address of first token
     * @param tokenB Address of second token
     * @param liquidity Amount of LP tokens to burn
     * @param amountAMin Minimum amount of tokenA to receive (slippage protection)
     * @param amountBMin Minimum amount of tokenB to receive (slippage protection)
     * @param to Address to receive tokens
     * @param deadline Transaction must complete before this time
     * @return amountA Amount of tokenA received
     * @return amountB Amount of tokenB received
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        // Get the pair address
        address pair = _getPair(tokenA, tokenB);
        require(pair != address(0), "Router: PAIR_NOT_EXISTS");
        
        // Transfer LP tokens from user to pair contract
        IERC20(pair).transferFrom(msg.sender, pair, liquidity);
        
        // Burn LP tokens and get underlying tokens back
        (uint256 amount0, uint256 amount1) = Pair(pair).burn(to);
        
        // Sort amounts to match tokenA/tokenB order
        (amountA, amountB) = tokenA < tokenB ? (amount0, amount1) : (amount1, amount0);
        
        // Check slippage protection
        require(amountA >= amountAMin, "Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "Router: INSUFFICIENT_B_AMOUNT");
    }
    
    // ============ ETH LIQUIDITY FUNCTIONS ============
    
    /**
     * @dev Add liquidity with ETH (automatically wrapped to WETH)
     * @param token Address of the token to pair with ETH
     * @param amountTokenDesired Amount of token user wants to add
     * @param amountTokenMin Minimum amount of token (slippage protection)
     * @param amountETHMin Minimum amount of ETH (slippage protection)
     * @param to Address to receive LP tokens
     * @param deadline Transaction must complete before this time
     * @return amountToken Actual amount of token added
     * @return amountETH Actual amount of ETH added
     * @return liquidity Amount of LP tokens minted
     */
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        // Calculate optimal amounts to add
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        
        // Get or create the pair
        address pair = _getPair(token, WETH);
        if (pair == address(0)) {
            pair = Factory(factory).createPair(token, WETH);
        }
        
        // Transfer token from user to pair
        IERC20(token).transferFrom(msg.sender, pair, amountToken);
        
        // Wrap ETH and transfer to pair
        WrappedETH(payable(WETH)).deposit{value: amountETH}();
        IERC20(WETH).transfer(pair, amountETH);
        
        // Mint LP tokens to specified address
        liquidity = Pair(pair).mint(to);
        
        // Refund excess ETH
        if (msg.value > amountETH) {
            (bool success, ) = msg.sender.call{value: msg.value - amountETH}("");
            require(success, "Router: ETH_REFUND_FAILED");
        }
    }
    
    /**
     * @dev Remove liquidity and receive ETH (WETH automatically unwrapped)
     * @param token Address of the token paired with ETH
     * @param liquidity Amount of LP tokens to burn
     * @param amountTokenMin Minimum amount of token to receive (slippage protection)
     * @param amountETHMin Minimum amount of ETH to receive (slippage protection)
     * @param to Address to receive tokens and ETH
     * @param deadline Transaction must complete before this time
     * @return amountToken Amount of token received
     * @return amountETH Amount of ETH received
     */
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        // Get the pair address
        address pair = _getPair(token, WETH);
        require(pair != address(0), "Router: PAIR_NOT_EXISTS");
        
        // Transfer LP tokens from user to pair contract
        IERC20(pair).transferFrom(msg.sender, pair, liquidity);
        
        // Burn LP tokens and get underlying tokens back to this contract
        (uint256 amount0, uint256 amount1) = Pair(pair).burn(address(this));
        
        // Sort amounts to match token/WETH order
        (amountToken, amountETH) = token < WETH ? (amount0, amount1) : (amount1, amount0);
        
        // Check slippage protection
        require(amountToken >= amountTokenMin, "Router: INSUFFICIENT_TOKEN_AMOUNT");
        require(amountETH >= amountETHMin, "Router: INSUFFICIENT_ETH_AMOUNT");
        
        // Send token to recipient
        IERC20(token).transfer(to, amountToken);
        
        // Unwrap WETH and send ETH to recipient
        WrappedETH(payable(WETH)).withdraw(amountETH);
        (bool success, ) = to.call{value: amountETH}("");
        require(success, "Router: ETH_TRANSFER_FAILED");
    }
    
    // ============ SWAP FUNCTIONS ============
    
    /**
     * @dev Calculate amount out for a given amount in using the governance-controlled fee
     * @param amountIn Amount of input token
     * @param reserveIn Reserve of input token in pair
     * @param reserveOut Reserve of output token in pair
     * @return amountOut Amount of output token to receive
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        view
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Router: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "Router: INSUFFICIENT_LIQUIDITY");

        uint256 fee = Factory(factory).tradingFee(); // basis points, e.g. 30 = 0.3%
        uint256 amountInWithFee = amountIn * (10000 - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * @dev Calculate amount in needed for a given amount out using the governance-controlled fee
     * @param amountOut Desired amount of output token
     * @param reserveIn Reserve of input token in pair
     * @param reserveOut Reserve of output token in pair
     * @return amountIn Amount of input token needed
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        view
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "Router: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "Router: INSUFFICIENT_LIQUIDITY");

        uint256 fee = Factory(factory).tradingFee(); // basis points, e.g. 30 = 0.3%
        uint256 numerator = reserveIn * amountOut * 10000;
        uint256 denominator = (reserveOut - amountOut) * (10000 - fee);
        amountIn = (numerator / denominator) + 1; // +1 for rounding
    }
    
    /**
     * @dev Swap exact amount of tokens for as many output tokens as possible
     * @param amountIn Exact amount of input tokens to swap
     * @param amountOutMin Minimum amount of output tokens (slippage protection)
     * @param path Array of token addresses (trading route)
     * @param to Address to receive output tokens
     * @param deadline Transaction must complete before this time
     * @return amounts Array of input/output amounts for each step
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        // Calculate output amounts for entire path
        amounts = getAmountsOut(amountIn, path);
        
        // Check slippage protection
        require(amounts[amounts.length - 1] >= amountOutMin, "Router: INSUFFICIENT_OUTPUT_AMOUNT");
        
        // Transfer input tokens to first pair
        address firstPair = _getPair(path[0], path[1]);
        require(firstPair != address(0), "Router: PAIR_NOT_EXISTS");
        IERC20(path[0]).transferFrom(msg.sender, firstPair, amounts[0]);
        
        // Execute swaps along the path
        _swap(amounts, path, to);
    }
    
    /**
     * @dev Internal function to execute swaps along a path
     * @param amounts Array of amounts for each step
     * @param path Array of token addresses
     * @param _to Final recipient of tokens
     */
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal {
        for (uint256 i = 0; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = input < output ? (input, output) : (output, input);
            uint256 amountOut = amounts[i + 1];
            
            (uint256 amount0Out, uint256 amount1Out) = input == token0 
                ? (uint256(0), amountOut) 
                : (amountOut, uint256(0));
            
            address currentPair = _getPair(input, output);
            address nextRecipient = i < path.length - 2 
                ? _getPair(output, path[i + 2]) 
                : _to;
            
            Pair(currentPair).swap(amount0Out, amount1Out, nextRecipient, new bytes(0));
        }
    }
    
    /**
     * @dev Swap tokens for exact amount of output tokens
     * @param amountOut Exact amount of output tokens desired
     * @param amountInMax Maximum amount of input tokens (slippage protection)
     * @param path Array of token addresses (trading route)
     * @param to Address to receive output tokens
     * @param deadline Transaction must complete before this time
     * @return amounts Array of input/output amounts for each step
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        // Calculate input amounts needed for entire path
        amounts = getAmountsIn(amountOut, path);
        
        // Check slippage protection
        require(amounts[0] <= amountInMax, "Router: EXCESSIVE_INPUT_AMOUNT");
        
        // Transfer input tokens to first pair
        address firstPair = _getPair(path[0], path[1]);
        require(firstPair != address(0), "Router: PAIR_NOT_EXISTS");
        IERC20(path[0]).transferFrom(msg.sender, firstPair, amounts[0]);
        
        // Execute swaps along the path
        _swap(amounts, path, to);
    }
    
    // ============ ETH SWAP FUNCTIONS ============
    
    /**
     * @dev Swap exact ETH for tokens
     * ETH is automatically wrapped to WETH for the swap
     * @param amountOutMin Minimum amount of output tokens (slippage protection)
     * @param path Array of token addresses (must start with WETH)
     * @param to Address to receive output tokens
     * @param deadline Transaction must complete before this time
     * @return amounts Array of input/output amounts for each step
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WETH, "Router: INVALID_PATH");
        require(msg.value > 0, "Router: INSUFFICIENT_ETH");
        
        // Calculate output amounts for entire path
        amounts = getAmountsOut(msg.value, path);
        
        // Check slippage protection
        require(amounts[amounts.length - 1] >= amountOutMin, "Router: INSUFFICIENT_OUTPUT_AMOUNT");
        
        // Wrap ETH to WETH and send to first pair
        WrappedETH(payable(WETH)).deposit{value: amounts[0]}();
        address firstPair = _getPair(path[0], path[1]);
        require(firstPair != address(0), "Router: PAIR_NOT_EXISTS");
        IERC20(WETH).transfer(firstPair, amounts[0]);
        
        // Execute swaps along the path
        _swap(amounts, path, to);
    }
    
    /**
     * @dev Swap tokens for exact ETH
     * Output WETH is automatically unwrapped to ETH
     * @param amountOut Exact amount of ETH desired
     * @param amountInMax Maximum amount of input tokens (slippage protection)
     * @param path Array of token addresses (must end with WETH)
     * @param to Address to receive ETH
     * @param deadline Transaction must complete before this time
     * @return amounts Array of input/output amounts for each step
     */
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "Router: INVALID_PATH");
        
        // Calculate input amounts needed for entire path
        amounts = getAmountsIn(amountOut, path);
        
        // Check slippage protection
        require(amounts[0] <= amountInMax, "Router: EXCESSIVE_INPUT_AMOUNT");
        
        // Transfer input tokens to first pair
        address firstPair = _getPair(path[0], path[1]);
        require(firstPair != address(0), "Router: PAIR_NOT_EXISTS");
        IERC20(path[0]).transferFrom(msg.sender, firstPair, amounts[0]);
        
        // Execute swaps along the path (WETH comes to this contract)
        _swap(amounts, path, address(this));
        
        // Unwrap WETH to ETH and send to recipient
        WrappedETH(payable(WETH)).withdraw(amounts[amounts.length - 1]);
        (bool success, ) = to.call{value: amounts[amounts.length - 1]}("");
        require(success, "Router: ETH_TRANSFER_FAILED");
    }
    
    /**
     * @dev Swap exact tokens for ETH
     * Output WETH is automatically unwrapped to ETH
     * @param amountIn Exact amount of input tokens to swap
     * @param amountOutMin Minimum amount of ETH (slippage protection)
     * @param path Array of token addresses (must end with WETH)
     * @param to Address to receive ETH
     * @param deadline Transaction must complete before this time
     * @return amounts Array of input/output amounts for each step
     */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "Router: INVALID_PATH");
        
        // Calculate output amounts for entire path
        amounts = getAmountsOut(amountIn, path);
        
        // Check slippage protection
        require(amounts[amounts.length - 1] >= amountOutMin, "Router: INSUFFICIENT_OUTPUT_AMOUNT");
        
        // Transfer input tokens to first pair
        address firstPair = _getPair(path[0], path[1]);
        require(firstPair != address(0), "Router: PAIR_NOT_EXISTS");
        IERC20(path[0]).transferFrom(msg.sender, firstPair, amounts[0]);
        
        // Execute swaps along the path (WETH comes to this contract)
        _swap(amounts, path, address(this));
        
        // Unwrap WETH to ETH and send to recipient
        WrappedETH(payable(WETH)).withdraw(amounts[amounts.length - 1]);
        (bool success, ) = to.call{value: amounts[amounts.length - 1]}("");
        require(success, "Router: ETH_TRANSFER_FAILED");
    }
    
    /**
     * @dev Swap ETH for exact tokens
     * ETH is automatically wrapped to WETH for the swap
     * @param amountOut Exact amount of output tokens desired
     * @param path Array of token addresses (must start with WETH)
     * @param to Address to receive output tokens
     * @param deadline Transaction must complete before this time
     * @return amounts Array of input/output amounts for each step
     */
    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WETH, "Router: INVALID_PATH");
        
        // Calculate input amounts needed for entire path
        amounts = getAmountsIn(amountOut, path);
        
        // Check we have enough ETH
        require(amounts[0] <= msg.value, "Router: EXCESSIVE_INPUT_AMOUNT");
        
        // Wrap ETH to WETH and send to first pair
        WrappedETH(payable(WETH)).deposit{value: amounts[0]}();
        address firstPair = _getPair(path[0], path[1]);
        require(firstPair != address(0), "Router: PAIR_NOT_EXISTS");
        IERC20(WETH).transfer(firstPair, amounts[0]);
        
        // Execute swaps along the path
        _swap(amounts, path, to);
        
        // Refund excess ETH
        if (msg.value > amounts[0]) {
            (bool success, ) = msg.sender.call{value: msg.value - amounts[0]}("");
            require(success, "Router: ETH_REFUND_FAILED");
        }
    }
    
    /**
     * @dev Swap exact tokens for tokens supporting fee-on-transfer tokens
     * @param amountIn Exact amount of input tokens to swap
     * @param amountOutMin Minimum amount of output tokens (slippage protection)
     * @param path Array of token addresses (trading route)
     * @param to Address to receive output tokens
     * @param deadline Transaction must complete before this time
     */
    function swapExactTokensForTokensFeeOnTransfer(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        // Transfer input tokens to first pair
        address firstPair = _getPair(path[0], path[1]);
        require(firstPair != address(0), "Router: PAIR_NOT_EXISTS");
        
        // For fee-on-transfer tokens, we need to check actual received amount
        uint256 balanceBefore = IERC20(path[0]).balanceOf(firstPair);
        IERC20(path[0]).transferFrom(msg.sender, firstPair, amountIn);
        uint256 amountActuallyReceived = IERC20(path[0]).balanceOf(firstPair) - balanceBefore;
        
        // Calculate output amounts based on actual received amount
        uint256[] memory amounts = new uint256[](path.length);
        amounts[0] = amountActuallyReceived;
        
        // Execute swaps with actual amounts
        _swapSupportingFeeOnTransferTokens(path, to);
        
        // Check final output meets minimum requirement
        require(
            IERC20(path[path.length - 1]).balanceOf(to) >= amountOutMin,
            "Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }
    
    /**
     * @dev Internal swap function for fee-on-transfer tokens
     * @param path Array of token addresses
     * @param _to Final recipient of tokens
     */
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal {
        for (uint256 i = 0; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = input < output ? (input, output) : (output, input);
            
            address currentPair = _getPair(input, output);
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(input, output);
            
            // Calculate actual input amount (handling fee-on-transfer)
            uint256 amountInput = IERC20(input).balanceOf(currentPair) - reserveIn;
            uint256 amountOutput = getAmountOut(amountInput, reserveIn, reserveOut);
            
            (uint256 amount0Out, uint256 amount1Out) = input == token0 
                ? (uint256(0), amountOutput) 
                : (amountOutput, uint256(0));
            
            address nextRecipient = i < path.length - 2 
                ? _getPair(output, path[i + 2]) 
                : _to;
            
            Pair(currentPair).swap(amount0Out, amount1Out, nextRecipient, new bytes(0));
        }
    }

    /**
     * @dev Calculate output amounts for a multi-hop swap
     * @param amountIn Input amount
     * @param path Array of token addresses
     * @return amounts Array of amounts for each step
     */
    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "Router: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        
        for (uint256 i = 0; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
    
    /**
     * @dev Calculate input amounts needed for a multi-hop swap
     * @param amountOut Desired output amount
     * @param path Array of token addresses
     * @return amounts Array of amounts for each step
     */
    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "Router: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}