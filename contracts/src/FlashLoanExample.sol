// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Pair.sol";
import "./Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FlashLoanExample
 * @dev Example contract showing how to use flash loans from our DEX
 * Flash loans allow you to borrow tokens without collateral, as long as you pay them back in the same transaction
 */
contract FlashLoanExample {
    
    Factory public immutable factory;
    
    // Events for tracking flash loan operations
    event FlashLoanExecuted(
        address indexed pair,
        address indexed token,
        uint256 amount,
        uint256 fee,
        address indexed borrower
    );
    
    // Event to mark the internal execution of flash loan logic (helps avoid unused parameter warnings)
    event FlashLoanLogicCalled(address indexed tokenBorrowed, uint256 amountBorrowed, address indexed originalCaller, bytes userData);
    
    constructor(address _factory) {
        factory = Factory(_factory);
    }
    
    /**
     * @dev Execute a flash loan
     * @param tokenBorrow The token to borrow
     * @param tokenOther The other token in the pair (needed to identify the pair)
     * @param amountBorrow Amount to borrow
     * @param userData Custom data to pass to the callback
     */
    function executeFlashLoan(
        address tokenBorrow,
        address tokenOther, 
        uint256 amountBorrow,
        bytes calldata userData
    ) external {
        // Get the pair address
        address pair = factory.getPair(tokenBorrow, tokenOther);
        require(pair != address(0), "FlashLoan: PAIR_NOT_EXISTS");
        
        // Determine token order (pairs sort tokens by address)
        bool token0IsBorrow = tokenBorrow < tokenOther;
        
        // Set up the amounts to borrow
        uint256 amount0Out = token0IsBorrow ? amountBorrow : 0;
        uint256 amount1Out = token0IsBorrow ? 0 : amountBorrow;
        
        // Execute the flash loan through the pair's swap function
        // The pair will send us tokens first, then call our callback
        Pair(pair).swap(
            amount0Out,
            amount1Out,
            address(this), // Callback will be made to this contract
            abi.encode(msg.sender, tokenBorrow, amountBorrow, userData) // Data for callback
        );
    }
    
    /**
     * @dev Callback function called by the pair during flash loan
     * This is where you implement your flash loan logic
     * @param sender Original caller (the pair contract)
     * @param amount0 Amount of token0 borrowed
     * @param amount1 Amount of token1 borrowed
     * @param data Custom data passed from executeFlashLoan
     */
    function call (
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        // Decode the data
        (address originalCaller, address tokenBorrow, uint256 amountBorrow, bytes memory userData) = 
            abi.decode(data, (address, address, uint256, bytes));
        
        // Security: Only pairs can call this function
        require(factory.getPair(Pair(msg.sender).token0(), Pair(msg.sender).token1()) == msg.sender, 
                "FlashLoan: INVALID_CALLER");
        
        // Validate that we received the expected amounts (use the parameters to avoid unused warnings)
        // Note: sender parameter is from the pair's swap function signature but not used in our validation
        require((amount0 > 0 && amount1 == 0) || (amount0 == 0 && amount1 > 0), "FlashLoan: INVALID_AMOUNTS");
        require(amount0 + amount1 == amountBorrow, "FlashLoan: AMOUNT_MISMATCH");
        
        // Use sender parameter to avoid unused warning (it represents the swap caller, which is our contract)
        require(sender != address(0), "FlashLoan: INVALID_SENDER");
        
        // At this point, we have received the borrowed tokens!
        uint256 balanceBefore = IERC20(tokenBorrow).balanceOf(address(this));
        require(balanceBefore >= amountBorrow, "FlashLoan: INSUFFICIENT_BORROW_AMOUNT");
        
        // ===== YOUR FLASH LOAN LOGIC GOES HERE =====
        // This is where you would:
        // 1. Use the borrowed tokens for arbitrage
        // 2. Liquidate positions
        // 3. Refinance debt
        // 4. Any other complex DeFi operation
        
        // Calculate repayment amount using the pair's trading fee (0.3%)
        // For flash loans through swap, we use the same 0.3% fee as regular swaps
        // The fee is calculated as: amountToRepay = amountBorrow * 1000 / 997
        // This ensures the invariant k is maintained after the flash loan
        uint256 amountToRepay = (amountBorrow * 1000) / 997 + 1; // +1 for rounding
        uint256 fee = amountToRepay - amountBorrow;
        
        _executeFlashLoanLogic(tokenBorrow, amountBorrow, userData, originalCaller);
        
        // ===== END OF YOUR LOGIC =====
        
        // Ensure we have enough to repay (your logic should have made profit)
        uint256 balanceAfter = IERC20(tokenBorrow).balanceOf(address(this));
        require(balanceAfter >= amountToRepay, "FlashLoan: INSUFFICIENT_FUNDS_TO_REPAY");
        
        // Repay the loan by transferring tokens back to the pair
        // The pair will check the invariant after this callback returns
        IERC20(tokenBorrow).transfer(msg.sender, amountToRepay);
        
        emit FlashLoanExecuted(msg.sender, tokenBorrow, amountBorrow, fee, originalCaller);
    }
    
    /**
     * @dev Your custom flash loan logic goes here
     * This is just an example - replace with your actual strategy
     * @param tokenBorrow The borrowed token
     * @param amountBorrow Amount borrowed
     * @param userData Custom data from the caller
     * @param originalCaller The original caller of the flash loan
     */
    function _executeFlashLoanLogic(
        address tokenBorrow,
        uint256 amountBorrow,
        bytes memory userData,
        address originalCaller
    ) internal {
        // Example: Simple arbitrage opportunity
        // In real scenarios, you might:
        
        // 1. ARBITRAGE: Buy token cheap on DEX A, sell expensive on DEX B
        // 2. LIQUIDATION: Borrow to liquidate undercollateralized positions
        // 3. REFINANCING: Pay off expensive loan with cheaper one
        // 4. COLLATERAL SWAP: Change collateral type without closing position
        
        // For this example, let's just emit an event
        // In a real flash loan, you MUST ensure you have enough tokens to repay!
        
        // Example: If userData contains another DEX address, we could arbitrage
        if (userData.length > 0) {
            // Decode additional parameters
            // (address targetDex, uint256 expectedProfit) = abi.decode(userData, (address, uint256));
            // ... perform arbitrage logic ...
        }
        
        // WARNING: This example doesn't actually make profit!
        // In production, your logic must generate enough profit to cover the fee + gas costs

        // Emit a small event to use the parameters and avoid compiler warnings about unused variables
        emit FlashLoanLogicCalled(tokenBorrow, amountBorrow, originalCaller, userData);
    }
    
    /**
     * @dev Emergency function to withdraw any tokens stuck in contract
     * @param token Token to withdraw
     * @param to Address to send tokens to
     */
    function emergencyWithdraw(address token, address to) external {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(to, balance);
        }
    }
    
    /**
     * @dev Check if a flash loan is possible for given parameters
     * @param tokenBorrow Token to borrow
     * @param tokenOther Other token in pair
     * @param amountBorrow Amount to borrow
     * @return possible True if flash loan is possible
     * @return availableLiquidity Available liquidity in the pair
     */
    function canFlashLoan(
        address tokenBorrow,
        address tokenOther,
        uint256 amountBorrow
    ) external view returns (bool possible, uint256 availableLiquidity) {
        address pair = factory.getPair(tokenBorrow, tokenOther);
        if (pair == address(0)) {
            return (false, 0);
        }
        
        // Get pair reserves
        (uint112 reserve0, uint112 reserve1,) = Pair(pair).getReserves();
        
        // Determine which reserve corresponds to our borrow token
        bool token0IsBorrow = tokenBorrow < tokenOther;
        availableLiquidity = token0IsBorrow ? reserve0 : reserve1;
        
        // Must leave some liquidity in pool (can't borrow everything)
        possible = amountBorrow < availableLiquidity;
    }
}