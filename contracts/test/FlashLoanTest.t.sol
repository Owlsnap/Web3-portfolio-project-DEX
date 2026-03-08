// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import "../src/Factory.sol";
import "../src/Router.sol";
import "../src/Pair.sol";
import "../src/MockERC20.sol";
import "../src/FlashLoanExample.sol";
import "../src/WETH.sol";

/**
 * @title FlashLoanTest
 * @dev Test flash loan functionality
 * Demonstrates how to borrow tokens without collateral and repay in same transaction
 */
contract FlashLoanTest is Test {
    Factory public factory;
    Router public router;
    FlashLoanExample public flashLoanContract;
    WETH public weth;
    
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    uint256 constant INITIAL_MINT = 1000000 * 1e18;
    uint256 constant LIQUIDITY_AMOUNT = 100000 * 1e18; // More liquidity for flash loans
    
    function setUp() public {
        // Deploy contracts
        factory = new Factory(address(this));
        weth = new WETH();
        router = new Router(address(factory), address(weth));
        flashLoanContract = new FlashLoanExample(address(factory));
        
        // Deploy test tokens
        tokenA = new MockERC20("TokenA", "TKA", 18, 0);
        tokenB = new MockERC20("TokenB", "TKB", 18, 0);
        
        // Mint tokens
        tokenA.mint(alice, INITIAL_MINT);
        tokenB.mint(alice, INITIAL_MINT);
        // Give contract enough tokens to cover flash loan fees
        // For 10,000 token loan, fee = 30 tokens
        // For 50,000 token loan, fee = 150 tokens
        // Give 200 tokens to be safe for all tests
        tokenA.mint(address(flashLoanContract), 200 * 1e18);
        
        // Setup approvals
        vm.startPrank(alice);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        vm.stopPrank();
        
        // Create pair and add liquidity
        vm.startPrank(alice);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        vm.stopPrank();
    }
    
    /**
     * @dev Test basic flash loan functionality
     */
    function test_BasicFlashLoan() public {
        console.log("=== Testing Basic Flash Loan ===");
        
        uint256 flashLoanAmount = 1000 * 1e18; // Borrow smaller amount: 1,000 tokens
        
        // Check if flash loan is possible
        (bool possible, uint256 availableLiquidity) = flashLoanContract.canFlashLoan(
            address(tokenA),
            address(tokenB),
            flashLoanAmount
        );
        
        console.log("Flash loan possible:", possible);
        console.log("Available liquidity:", availableLiquidity / 1e18);
        assertTrue(possible, "Flash loan should be possible");
        
        // Calculate the correct fee based on the pair's fee system
        uint256 amountToRepay = (flashLoanAmount * 1000) / 997 + 1;
        uint256 fee = amountToRepay - flashLoanAmount;
        console.log("Flash loan amount:", flashLoanAmount / 1e18);
        console.log("Amount to repay:", amountToRepay / 1e18);
        console.log("Calculated fee:", fee / 1e18);
        
        // We only need to mint the fee amount since the flash loan will borrow and return the principal
        // Plus a little extra profit to make it realistic
        uint256 extraProfit = 10 * 1e18; // 10 tokens extra profit
        tokenA.mint(address(flashLoanContract), fee + extraProfit);
        
        // Get balances before
        uint256 contractBalanceBefore = tokenA.balanceOf(address(flashLoanContract));
        console.log("Contract balance before:", contractBalanceBefore / 1e18);
        console.log("Expected final balance:", (200 + fee / 1e18 + 10 - fee / 1e18));
        console.log("Which should be: 210 tokens");
        
        // Execute flash loan
        vm.prank(bob);
        flashLoanContract.executeFlashLoan(
            address(tokenA),
            address(tokenB),
            flashLoanAmount,
            abi.encode("test flash loan")
        );
        
        // Get balances after
        uint256 contractBalanceAfter = tokenA.balanceOf(address(flashLoanContract));
        console.log("Contract balance after:", contractBalanceAfter / 1e18);
        
        console.log("Expected fee paid:", fee / 1e18);
        
        console.log("Contract balance before (tokens):", contractBalanceBefore / 1e18);
        console.log("Contract balance after (tokens):", contractBalanceAfter / 1e18);
        
        // Calculate what actually happened
        // We started with: 200 (setup) + fee + 10 (extra profit) = contractBalanceBefore
        // We ended with: contractBalanceAfter  
        // So the cost of the flash loan was: contractBalanceBefore - contractBalanceAfter
        uint256 actualCost = contractBalanceBefore - contractBalanceAfter;
        console.log("Actual cost of flash loan (tokens):", actualCost / 1e18);
        console.log("Expected fee (tokens):", fee / 1e18);
        
        // The flash loan should cost exactly the fee (since we gave extra profit)
        // Final balance should be: 200 (setup) + 10 (extra profit) = 210 tokens
        console.log("Expected final balance: 210 tokens");
        console.log("Actual final balance:", contractBalanceAfter / 1e18);
        
        // Verify the flash loan worked correctly
        uint256 expectedFinalBalance = 200 * 1e18 + extraProfit; // 200 from setup + 10 extra = 210
        assertEq(contractBalanceAfter, expectedFinalBalance, "Final balance should match expected");
        
        console.log("=== Flash loan successful! ===\n");
    }
    
    /**
     * @dev Test flash loan with insufficient funds to repay (should fail)
     */
    function test_FlashLoanInsufficientFundsToRepay() public {
        console.log("=== Testing Flash Loan Failure (Insufficient Funds) ===");
        
        // Remove tokens from flash loan contract so it can't repay
        // Use the emergencyWithdraw function that the contract provides
        flashLoanContract.emergencyWithdraw(address(tokenA), alice);
        
        uint256 flashLoanAmount = 1000 * 1e18;
        
        // This should revert because contract can't repay
        vm.expectRevert("FlashLoan: INSUFFICIENT_FUNDS_TO_REPAY");
        vm.prank(bob);
        flashLoanContract.executeFlashLoan(
            address(tokenA),
            address(tokenB),
            flashLoanAmount,
            abi.encode("test insufficient funds")
        );
        
        console.log("Flash loan correctly failed when insufficient funds to repay");
    }
    
    /**
     * @dev Test flash loan exceeding available liquidity (should fail)
     */
    function test_FlashLoanExceedingLiquidity() public {
        console.log("=== Testing Flash Loan Failure (Exceeding Liquidity) ===");
        
        // Try to borrow more than available in the pool
        uint256 excessiveAmount = LIQUIDITY_AMOUNT + 1000 * 1e18;
        
        (bool possible,) = flashLoanContract.canFlashLoan(
            address(tokenA),
            address(tokenB),
            excessiveAmount
        );
        
        assertFalse(possible, "Flash loan should not be possible for excessive amount");
        
        // This should revert at the pair level (insufficient liquidity)
        vm.expectRevert("Pair: INSUFFICIENT_LIQUIDITY");
        vm.prank(bob);
        flashLoanContract.executeFlashLoan(
            address(tokenA),
            address(tokenB),
            excessiveAmount,
            abi.encode("test excessive amount")
        );
        
        console.log("Flash loan correctly failed when exceeding available liquidity");
    }
    
    /**
     * @dev Test flash loan fee calculation
     */
    function test_FlashLoanFeeCalculation() public {
        console.log("=== Testing Flash Loan Fee Calculation ===");
        
        uint256[] memory testAmounts = new uint256[](3);
        testAmounts[0] = 1000 * 1e18;   // 1,000 tokens
        testAmounts[1] = 10000 * 1e18;  // 10,000 tokens  
        testAmounts[2] = 50000 * 1e18;  // 50,000 tokens
        
        for (uint256 i = 0; i < testAmounts.length; i++) {
            uint256 amount = testAmounts[i];
            uint256 contractBalanceBefore = tokenA.balanceOf(address(flashLoanContract));
            
            // Add tokens to contract for this test (just fee + some profit)
            uint256 amountToRepay = (amount * 1000) / 997 + 1;
            uint256 expectedFee = amountToRepay - amount;
            tokenA.mint(address(flashLoanContract), expectedFee + 1 * 1e18); // fee + 1 token profit
            
            console.log("Testing flash loan amount:", amount / 1e18);
            
            // Execute flash loan
            vm.prank(bob);
            flashLoanContract.executeFlashLoan(
                address(tokenA),
                address(tokenB),
                amount,
                abi.encode("fee test")
            );
            
            uint256 contractBalanceAfter = tokenA.balanceOf(address(flashLoanContract));
            uint256 profit = 1 * 1e18; // We minted fee + 1 token profit
            uint256 actualFeePaid = contractBalanceBefore + expectedFee + profit - contractBalanceAfter;
            
            console.log("Expected fee:", expectedFee / 1e18);
            console.log("Actual fee paid:", actualFeePaid / 1e18);
            
            assertEq(actualFeePaid, expectedFee, "Fee should be exactly 0.3%");
        }
        
        console.log("=== All fee calculations correct! ===\n");
    }
    
    /**
     * @dev Demonstrate flash loan use case: arbitrage simulation
     */
    function test_FlashLoanArbitrageExample() public {
        console.log("=== Flash Loan Arbitrage Example ===");
        console.log("This simulates using flash loans for arbitrage opportunities");
        
        uint256 flashLoanAmount = 25000 * 1e18;
        
        // Calculate the fee first to determine how much profit we need
        uint256 amountToRepay = (flashLoanAmount * 1000) / 997 + 1;
        uint256 fee = amountToRepay - flashLoanAmount;
        
        // Give the contract enough tokens to cover fee + desired net profit
        uint256 desiredNetProfit = 25 * 1e18; // 25 tokens net profit
        uint256 totalProfitNeeded = fee + desiredNetProfit;
        tokenA.mint(address(flashLoanContract), totalProfitNeeded);
        
        uint256 contractBalanceBefore = tokenA.balanceOf(address(flashLoanContract));
        console.log("Contract balance before arbitrage:", contractBalanceBefore / 1e18);
        
        // Execute "arbitrage" flash loan
        vm.prank(bob);
        flashLoanContract.executeFlashLoan(
            address(tokenA),
            address(tokenB),
            flashLoanAmount,
            abi.encode("arbitrage opportunity")
        );
        
        uint256 contractBalanceAfter = tokenA.balanceOf(address(flashLoanContract));
        console.log("Contract balance after arbitrage:", contractBalanceAfter / 1e18);
        
        console.log("Flash loan amount:", flashLoanAmount / 1e18);
        console.log("Fee paid:", fee / 1e18);
        console.log("Total profit provided:", totalProfitNeeded / 1e18);
        console.log("Expected net gain:", desiredNetProfit / 1e18);
        
        // Contract should end up with: 200 (initial setup) + 25 (desired net profit) = 225 tokens
        uint256 expectedFinalBalance = 200 * 1e18 + desiredNetProfit;
        assertEq(
            contractBalanceAfter,
            expectedFinalBalance,
            "Should have net profit after arbitrage"
        );
        
        console.log("=== Arbitrage flash loan successful! ===\n");
    }
}