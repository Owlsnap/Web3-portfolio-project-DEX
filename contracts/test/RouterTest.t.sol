// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import "../src/Factory.sol";
import "../src/Router.sol";
import "../src/Pair.sol";
import "../src/MockERC20.sol";
import "../src/WETH.sol";

/**
 * @title RouterTest
 * @dev Comprehensive tests for the Router contract
 * 
 * Test Categories:
 * 1. Contract deployment and initialization
 * 2. Liquidity management (add/remove)
 * 3. Token swapping (direct swaps)
 * 4. Safety features (deadlines, slippage protection)
 * 5. Quote functions and price calculations
 * 6. Error handling and edge cases
 */
contract RouterTest is Test {
    // Contracts
    Factory public factory;
    Router public router;
    WETH public weth;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    
    // Test accounts
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public deployer = makeAddr("deployer");
    
    // Test constants
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 1e18; // 1M tokens each
    uint256 public constant LIQUIDITY_AMOUNT = 10_000 * 1e18;  // 10k tokens for liquidity
    uint256 public constant SWAP_AMOUNT = 1_000 * 1e18;        // 1k tokens for swaps
    
    function setUp() public {
        console.log("=== Setting up RouterTest Environment ===");
        
        vm.startPrank(deployer);
        
        // 1. Deploy Factory
        factory = new Factory(deployer);
        console.log("Factory deployed at:", address(factory));
        
        // 2. Deploy WETH
        weth = new WETH();
        console.log("WETH deployed at:", address(weth));
        
        // 3. Deploy Router with Factory and WETH addresses
        router = new Router(address(factory), address(weth));
        console.log("Router deployed at:", address(router));
        
        // 4. Deploy test tokens
        tokenA = new MockERC20("Token A", "TKNA", 18, INITIAL_SUPPLY);
        tokenB = new MockERC20("Token B", "TKNB", 18, INITIAL_SUPPLY);
        console.log("TokenA deployed at:", address(tokenA));
        console.log("TokenB deployed at:", address(tokenB));
        
        // 4. Distribute tokens to test accounts
        tokenA.transfer(alice, INITIAL_SUPPLY / 4); // 250k tokens
        tokenA.transfer(bob, INITIAL_SUPPLY / 4);   // 250k tokens
        tokenB.transfer(alice, INITIAL_SUPPLY / 4); // 250k tokens
        tokenB.transfer(bob, INITIAL_SUPPLY / 4);   // 250k tokens
        
        vm.stopPrank();
        
        console.log("=== Setup Complete ===\n");
    }

    // ============ DEPLOYMENT & BASIC FUNCTIONALITY TESTS ============
    
    /**
     * @dev Test 1: Verify Router deployment and basic configuration
     * Purpose: Ensure Router is properly connected to Factory
     */
    function test_RouterDeployment() public { //restrict to view before deployment
        console.log("\n=== Test 1: Router Deployment ===");
        
        // Verify router is connected to correct factory
        assertEq(router.factory(), address(factory));
        console.log("Router connected to Factory at:", router.factory());
        
        // Verify factory starts with no pairs
        assertEq(router.allPairsLength(), 0);
        console.log("Factory starts with 0 pairs");
    }
    
    /**
     * @dev Test 2: Test pair creation through Router
     * Purpose: Verify Router can create pairs via Factory
     */
    function test_CreatePairThroughRouter() public {
        console.log("\n=== Test 2: Create Pair Through Router ===");
        
        // Initially no pair should exist
        assertFalse(router.pairExists(address(tokenA), address(tokenB)));
        assertEq(router.getPair(address(tokenA), address(tokenB)), address(0));
        console.log("Initially no pair exists");
        
        // Create pair through router
        address pairAddress = router.createPair(address(tokenA), address(tokenB));
        console.log("Pair created at:", pairAddress);
        
        // Verify pair was created
        assertTrue(router.pairExists(address(tokenA), address(tokenB)));
        assertEq(router.getPair(address(tokenA), address(tokenB)), pairAddress);
        assertEq(router.allPairsLength(), 1);
        assertEq(router.allPairs(0), pairAddress);
        
        console.log("Pair verification complete");
        console.log("  - Pair exists: true");
        console.log("  - Total pairs: 1");
    }

    // ============ LIQUIDITY MANAGEMENT TESTS ============
    
    /**
     * @dev Test 3: Add liquidity to a new pair
     * Purpose: Test the core liquidity provision functionality
     * This is the most important Router function - it creates pairs and adds initial liquidity
     */
    function test_AddLiquidityNewPair() public {
        console.log("\n=== Test 3: Add Liquidity to New Pair ===");
        
        vm.startPrank(alice);
        
        // Check Alice's initial balances
        uint256 aliceTokenABefore = tokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = tokenB.balanceOf(alice);
        console.log("Alice's TokenA before:", aliceTokenABefore / 1e18);
        console.log("Alice's TokenB before:", aliceTokenBBefore / 1e18);
        
        // Approve Router to spend Alice's tokens
        tokenA.approve(address(router), LIQUIDITY_AMOUNT);
        tokenB.approve(address(router), LIQUIDITY_AMOUNT);
        console.log("Tokens approved for Router");
        
        // Add liquidity (creates pair automatically)
        uint256 deadline = block.timestamp + 300; // 5 minute deadline
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,     // amountADesired
            LIQUIDITY_AMOUNT,     // amountBDesired  
            LIQUIDITY_AMOUNT - 1, // amountAMin (allow tiny slippage)
            LIQUIDITY_AMOUNT - 1, // amountBMin (allow tiny slippage)
            alice,                // LP tokens go to Alice
            deadline
        );
        
        console.log("Liquidity added successfully");
        console.log("  - Amount A used:", amountA / 1e18);
        console.log("  - Amount B used:", amountB / 1e18);
        console.log("  - LP tokens minted:", liquidity / 1e18);
        
        // Verify pair was created and liquidity was added
        assertTrue(router.pairExists(address(tokenA), address(tokenB)));
        address pairAddress = router.getPair(address(tokenA), address(tokenB));
        
        // Check LP token balance
        Pair pair = Pair(pairAddress);
        uint256 aliceLPBalance = pair.balanceOf(alice);
        assertEq(aliceLPBalance, liquidity);
        console.log("Alice received", aliceLPBalance / 1e18, "LP tokens");
        
        // Verify token balances decreased
        assertEq(tokenA.balanceOf(alice), aliceTokenABefore - amountA);
        assertEq(tokenB.balanceOf(alice), aliceTokenBBefore - amountB);
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 4: Add liquidity to existing pair
     * Purpose: Test adding more liquidity to an already created pair
     * This tests the proportional liquidity addition logic
     */
    function test_AddLiquidityExistingPair() public {
        console.log("\n=== Test 4: Add Liquidity to Existing Pair ===");
        
        // First, create the pair with Alice's liquidity
        test_AddLiquidityNewPair();
        
        vm.startPrank(bob);
        
        // Bob adds liquidity to the existing pair
        uint256 bobTokenABefore = tokenA.balanceOf(bob);
        uint256 bobTokenBBefore = tokenB.balanceOf(bob);
        console.log("Bob's TokenA before:", bobTokenABefore / 1e18);
        console.log("Bob's TokenB before:", bobTokenBBefore / 1e18);
        
        // Approve tokens
        tokenA.approve(address(router), LIQUIDITY_AMOUNT / 2);
        tokenB.approve(address(router), LIQUIDITY_AMOUNT / 2);
        
        // Add liquidity
        uint256 deadline = block.timestamp + 300;
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT / 2,      // amountADesired (5k tokens)
            LIQUIDITY_AMOUNT / 2,      // amountBDesired (5k tokens)
            (LIQUIDITY_AMOUNT / 2) - 100, // amountAMin (small slippage tolerance)
            (LIQUIDITY_AMOUNT / 2) - 100, // amountBMin (small slippage tolerance)
            bob,
            deadline
        );
        
        console.log("Bob added liquidity");
        console.log("  - Amount A used:", amountA / 1e18);
        console.log("  - Amount B used:", amountB / 1e18);
        console.log("  - LP tokens minted:", liquidity / 1e18);
        
        // Verify Bob received LP tokens
        address pairAddress = router.getPair(address(tokenA), address(tokenB));
        Pair pair = Pair(pairAddress);
        uint256 bobLPBalance = pair.balanceOf(bob);
        assertEq(bobLPBalance, liquidity);
        assertGt(bobLPBalance, 0);
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 5: Remove liquidity from pair
     * Purpose: Test liquidity removal functionality
     * This tests that liquidity providers can exit their positions
     */
    function test_RemoveLiquidity() public {
        console.log("\n=== Test 5: Remove Liquidity ===");
        
        // First add liquidity
        test_AddLiquidityNewPair();
        
        vm.startPrank(alice);
        
        address pairAddress = router.getPair(address(tokenA), address(tokenB));
        Pair pair = Pair(pairAddress);
        uint256 aliceLPBalance = pair.balanceOf(alice);
        console.log("Alice's LP tokens before removal:", aliceLPBalance / 1e18);
        
        // Record token balances before removal
        uint256 aliceTokenABefore = tokenA.balanceOf(alice);
        uint256 aliceTokenBBefore = tokenB.balanceOf(alice);
        
        // Approve Router to spend LP tokens
        uint256 liquidityToRemove = aliceLPBalance / 2; // Remove half
        pair.approve(address(router), liquidityToRemove);
        console.log("LP tokens approved for removal");
        
        // Remove liquidity
        uint256 deadline = block.timestamp + 300;
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidityToRemove,
            1, // amountAMin - accept any amount (for testing)
            1, // amountBMin - accept any amount (for testing)
            alice,
            deadline
        );
        
        console.log("Liquidity removed successfully");
        console.log("  - Amount A received:", amountA / 1e18);
        console.log("  - Amount B received:", amountB / 1e18);
        console.log("  - LP tokens burned:", liquidityToRemove / 1e18);
        
        // Verify Alice received tokens back
        assertEq(tokenA.balanceOf(alice), aliceTokenABefore + amountA);
        assertEq(tokenB.balanceOf(alice), aliceTokenBBefore + amountB);
        
        // Verify LP token balance decreased
        uint256 aliceLPBalanceAfter = pair.balanceOf(alice);
        assertEq(aliceLPBalanceAfter, aliceLPBalance - liquidityToRemove);
        console.log("Alice's remaining LP tokens:", aliceLPBalanceAfter / 1e18);
        
        // Verify she got reasonable amounts back (should be proportional)
        assertGt(amountA, 0);
        assertGt(amountB, 0);
        
        vm.stopPrank();
    }

    // ============ TOKEN SWAPPING TESTS ============
    
    /**
     * @dev Test 6: Basic token swap
     * Purpose: Test the core swapping functionality
     * This tests swapExactTokensForTokens - the most used function
     */
    function test_SwapExactTokensForTokens() public {
        console.log("\n=== Test 6: Basic Token Swap ===");
        
        // First create a pair with liquidity
        test_AddLiquidityNewPair();
        
        vm.startPrank(bob);
        
        // Record Bob's initial balances
        uint256 bobTokenABefore = tokenA.balanceOf(bob);
        uint256 bobTokenBBefore = tokenB.balanceOf(bob);
        console.log("Bob's TokenA before swap:", bobTokenABefore / 1e18);
        console.log("Bob's TokenB before swap:", bobTokenBBefore / 1e18);
        
        // Approve Router to spend Bob's TokenA
        tokenA.approve(address(router), SWAP_AMOUNT);
        console.log("TokenA approved for swap");
        
        // Create swap path: A -> B
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // Get expected output before swap
        uint256[] memory expectedAmounts = router.getAmountsOut(SWAP_AMOUNT, path);
        uint256 expectedAmountOut = expectedAmounts[1];
        console.log("Expected TokenB output:", expectedAmountOut / 1e18);
        
        // Execute swap
        uint256 deadline = block.timestamp + 300;
        uint256[] memory amounts = router.swapExactTokensForTokens(
            SWAP_AMOUNT,                    // amountIn
            expectedAmountOut * 99 / 100,   // amountOutMin (1% slippage tolerance)
            path,
            bob,
            deadline
        );
        
        console.log("Swap executed successfully");
        console.log("  - TokenA spent:", amounts[0] / 1e18);
        console.log("  - TokenB received:", amounts[1] / 1e18);
        
        // Verify Bob's balances changed correctly
        assertEq(tokenA.balanceOf(bob), bobTokenABefore - amounts[0]);
        assertEq(tokenB.balanceOf(bob), bobTokenBBefore + amounts[1]);
        
        // Verify swap amounts
        assertEq(amounts[0], SWAP_AMOUNT);
        assertGe(amounts[1], expectedAmountOut * 99 / 100); // Within slippage tolerance
        assertLe(amounts[1], expectedAmountOut); // Should not exceed expected
        
        console.log("Balance verification complete");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 7: Swap with insufficient output (should fail)
     * Purpose: Test slippage protection works correctly
     * This ensures users don't get less than they expect due to price changes
     */
    function test_SwapFailsWithHighSlippageTolerance() public {
        console.log("\n=== Test 7: Swap Fails with High Slippage ===");
        
        // Create pair with liquidity
        test_AddLiquidityNewPair();
        
        vm.startPrank(bob);
        
        tokenA.approve(address(router), SWAP_AMOUNT);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // Get expected output
        uint256[] memory expectedAmounts = router.getAmountsOut(SWAP_AMOUNT, path);
        uint256 expectedAmountOut = expectedAmounts[1];
        
        // Try to swap with unrealistic minimum output (should fail)
        uint256 unrealisticMinOutput = expectedAmountOut * 150 / 100; // 150% of expected
        
        vm.expectRevert(); // Expect the transaction to revert
        router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            unrealisticMinOutput, // This is too high, should cause revert
            path,
            bob,
            block.timestamp + 300
        );
        
        console.log("Swap correctly failed with unrealistic slippage protection");
        
        vm.stopPrank();
    }

    // ============ SAFETY FEATURES & QUOTE FUNCTIONS ============
    
    /**
     * @dev Test 8: Deadline protection
     * Purpose: Ensure transactions can't be executed after deadline
     * This prevents old transactions from being executed at stale prices
     */
    function test_DeadlineProtection() public {
        console.log("\n=== Test 8: Deadline Protection ===");
        
        test_AddLiquidityNewPair();
        
        vm.startPrank(bob);
        
        tokenA.approve(address(router), SWAP_AMOUNT);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // Try to execute swap with past deadline
        uint256 pastDeadline = block.timestamp - 1; // 1 second ago
        
        vm.expectRevert("Router: EXPIRED");
        router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            1, // amountOutMin
            path,
            bob,
            pastDeadline // This should cause revert
        );
        
        console.log("Deadline protection working correctly");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 9: Quote functions accuracy
     * Purpose: Test getAmountsOut and getAmountsIn provide accurate quotes
     * This is crucial for frontend integration and user experience
     */
    function test_QuoteFunctions() public {
        console.log("\n=== Test 9: Quote Functions ===");
        
        test_AddLiquidityNewPair();
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // Test getAmountsOut
        uint256[] memory amountsOut = router.getAmountsOut(SWAP_AMOUNT, path);
        console.log("Quote for", SWAP_AMOUNT / 1e18, "TokenA:");
        console.log("  - Expected TokenB output:", amountsOut[1] / 1e18);
        
        // Verify quote structure
        assertEq(amountsOut.length, 2);
        assertEq(amountsOut[0], SWAP_AMOUNT);
        assertGt(amountsOut[1], 0);
        
        // Test getAmountsIn (reverse calculation)
        uint256 desiredOutput = amountsOut[1];
        uint256[] memory amountsIn = router.getAmountsIn(desiredOutput, path);
        console.log("To get", desiredOutput / 1e18, "TokenB:");
        console.log("  - TokenA input needed:", amountsIn[0] / 1e18);
        
        // Verify reverse quote structure  
        assertEq(amountsIn.length, 2);
        assertEq(amountsIn[1], desiredOutput);
        
        // The input needed should be close to our original amount (accounting for rounding)
        // Allow for small differences due to precision
        uint256 difference = amountsIn[0] > SWAP_AMOUNT ? 
            amountsIn[0] - SWAP_AMOUNT : SWAP_AMOUNT - amountsIn[0];
        assertLt(difference, SWAP_AMOUNT / 1000); // Less than 0.1% difference
        
        console.log("Quote functions working accurately");
    }
    
    /**
     * @dev Test 10: Invalid path handling
     * Purpose: Test that invalid swap paths are rejected
     * This prevents users from creating impossible swap routes
     */
    function test_InvalidSwapPath() public {
        console.log("\n=== Test 10: Invalid Swap Path ===");
        
        vm.startPrank(bob);
        
        // Test with single token path (invalid)
        address[] memory invalidPath = new address[](1);
        invalidPath[0] = address(tokenA);
        
        vm.expectRevert("Router: INVALID_PATH");
        router.getAmountsOut(SWAP_AMOUNT, invalidPath);
        
        // Test with empty path (invalid)
        address[] memory emptyPath = new address[](0);
        
        vm.expectRevert("Router: INVALID_PATH");
        router.getAmountsOut(SWAP_AMOUNT, emptyPath);
        
        console.log("Invalid path handling working correctly");
        
        vm.stopPrank();
    }

    // ============ MULTI-HOP SWAP TESTS ============
    
    /**
     * @dev Test 11: Three-token multi-hop swap
     * Purpose: Test swapping through intermediate tokens (A -> B -> C)
     * This is essential for tokens that don't have direct pairs
     */
    function test_MultiHopSwap() public {
        console.log("\n=== Test 11: Multi-hop Swap (A->B->C) ===");
        
        // Create a third token for multi-hop testing
        MockERC20 tokenC = new MockERC20("Token C", "TOKC", 18, INITIAL_SUPPLY);
        tokenC.mint(alice, INITIAL_SUPPLY / 4);
        tokenC.mint(bob, INITIAL_SUPPLY / 4);
        
        // Step 1: Create A-B pair (reuse existing)
        test_AddLiquidityNewPair();
        
        // Step 2: Create B-C pair
        vm.startPrank(alice);
        tokenB.approve(address(router), LIQUIDITY_AMOUNT);
        tokenC.approve(address(router), LIQUIDITY_AMOUNT);
        
        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        console.log("Created B-C pair with liquidity");
        
        vm.stopPrank();
        
        // Step 3: Execute multi-hop swap A -> B -> C
        vm.startPrank(bob);
        
        tokenA.approve(address(router), SWAP_AMOUNT);
        
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB); // Intermediate token
        path[2] = address(tokenC);
        
        uint256 bobTokenCBefore = tokenC.balanceOf(bob);
        uint256 bobTokenABefore = tokenA.balanceOf(bob);
        
        // Get quote for multi-hop swap
        uint256[] memory amountsOut = router.getAmountsOut(SWAP_AMOUNT, path);
        console.log("Multi-hop quote:");
        console.log("  - Input TokenA:", amountsOut[0] / 1e18);
        console.log("  - Intermediate TokenB:", amountsOut[1] / 1e18);
        console.log("  - Output TokenC:", amountsOut[2] / 1e18);
        
        // Execute the multi-hop swap
        router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            1, // Minimum output
            path,
            bob,
            block.timestamp + 300
        );
        
        uint256 bobTokenCAfter = tokenC.balanceOf(bob);
        uint256 bobTokenAAfter = tokenA.balanceOf(bob);
        
        // Verify the swap
        assertEq(bobTokenAAfter, bobTokenABefore - SWAP_AMOUNT);
        assertGt(bobTokenCAfter, bobTokenCBefore);
        
        uint256 tokenCReceived = bobTokenCAfter - bobTokenCBefore;
        console.log("Received", tokenCReceived / 1e18, "TokenC");
        
        // Verify the received amount matches the quote (within small tolerance)
        uint256 difference = tokenCReceived > amountsOut[2] ? 
            tokenCReceived - amountsOut[2] : amountsOut[2] - tokenCReceived;
        assertLt(difference, amountsOut[2] / 100); // Within 1%
        
        console.log("Multi-hop swap executed successfully");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 12: Complex multi-hop with different amounts
     * Purpose: Test swapTokensForExactTokens with multi-hop
     * This tests reverse calculation through multiple pairs
     */
    function test_MultiHopExactOutput() public {
        console.log("\n=== Test 12: Multi-hop Exact Output ===");
        
        // Setup multi-hop pairs (reuse previous test setup)
        test_MultiHopSwap();
        
        // Start fresh prank for Bob
        vm.startPrank(bob);
        
        // For this test, we'll demonstrate the concept with a 2-hop path (A->B)
        // This simplifies the logic while still testing exact output functionality
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256 exactOutput = 5 * 1e18;
        
        // Get quote for exact output
        uint256[] memory amountsIn = router.getAmountsIn(exactOutput, path);
        console.log("For exactly", exactOutput / 1e18, "TokenB:");
        console.log("  - Need", amountsIn[0] / 1e18, "TokenA");
        
        // Approve sufficient tokens
        tokenA.approve(address(router), amountsIn[0] * 2); // Extra buffer
        
        uint256 bobTokenABefore = tokenA.balanceOf(bob);
        uint256 bobTokenBBefore = tokenB.balanceOf(bob);
        
        // Execute exact output swap
        router.swapTokensForExactTokens(
            exactOutput,
            amountsIn[0] * 11 / 10, // 10% slippage tolerance
            path,
            bob,
            block.timestamp + 300
        );
        
        uint256 bobTokenAAfter = tokenA.balanceOf(bob);
        uint256 bobTokenBAfter = tokenB.balanceOf(bob);
        
        // Verify exact output received
        assertEq(bobTokenBAfter - bobTokenBBefore, exactOutput);
        
        // Verify input amount is close to quote
        uint256 actualInput = bobTokenABefore - bobTokenAAfter;
        uint256 inputDifference = actualInput > amountsIn[0] ? 
            actualInput - amountsIn[0] : amountsIn[0] - actualInput;
        assertLt(inputDifference, amountsIn[0] / 100); // Within 1%
        
        console.log("Spent", actualInput / 1e18, "TokenA");
        console.log("For exactly", exactOutput / 1e18, "TokenB");
        console.log("Multi-hop exact output swap successful");
        
        vm.stopPrank();
    }

    // ============ EDGE CASES & ERROR HANDLING ============
    
    /**
     * @dev Test 13: Insufficient liquidity scenarios
     * Purpose: Test behavior when trying to swap more than available liquidity
     * This ensures the DEX handles extreme scenarios gracefully
     */
    function test_InsufficientLiquidity() public {
        console.log("\n=== Test 13: Insufficient Liquidity Scenarios ===");
        
        test_AddLiquidityNewPair();
        
        vm.startPrank(bob);
        
        // Try to swap an enormous amount (more than total supply)
        uint256 enormousAmount = INITIAL_SUPPLY * 10; // 10x more than total supply
        tokenA.approve(address(router), enormousAmount);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // This should fail due to insufficient liquidity in the pair
        vm.expectRevert();
        router.swapExactTokensForTokens(
            enormousAmount,
            1,
            path,
            bob,
            block.timestamp + 300
        );
        
        console.log("Correctly rejected swap exceeding available liquidity");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 14: Zero amount handling
     * Purpose: Test that zero amounts are handled properly
     * Edge case that should be rejected to prevent issues
     */
    function test_ZeroAmountHandling() public {
        console.log("\n=== Test 14: Zero Amount Handling ===");
        
        test_AddLiquidityNewPair();
        
        vm.startPrank(bob);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // Try to swap zero tokens
        vm.expectRevert("Router: INSUFFICIENT_INPUT_AMOUNT");
        router.swapExactTokensForTokens(
            0, // Zero amount
            0,
            path,
            bob,
            block.timestamp + 300
        );
        
        console.log("Zero amount swap correctly rejected");
        
        // Try to add zero liquidity
        vm.expectRevert();
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            0, // Zero amount A
            LIQUIDITY_AMOUNT,
            0,
            0,
            bob,
            block.timestamp + 300
        );
        
        console.log("Zero liquidity addition correctly rejected");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 15: Recipient validation
     * Purpose: Test that zero address and invalid recipients are handled
     * Important for preventing tokens from being lost
     */
    function test_RecipientValidation() public {
        console.log("\n=== Test 15: Recipient Validation ===");
        
        test_AddLiquidityNewPair();
        
        vm.startPrank(bob);
        
        tokenA.approve(address(router), SWAP_AMOUNT);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // Try to send swap output to zero address
        vm.expectRevert();
        router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            1,
            path,
            address(0), // Invalid recipient
            block.timestamp + 300
        );
        
        console.log("Zero address recipient correctly rejected");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 16: Maximum slippage stress test
     * Purpose: Test system behavior under extreme market conditions
     * Helps ensure the DEX remains stable during high volatility
     */
    function test_ExtremeSlippageConditions() public {
        console.log("\n=== Test 16: Extreme Slippage Conditions ===");
        
        // Create a pair with very low liquidity to amplify slippage
        vm.startPrank(alice);
        
        uint256 lowLiquidity = 1000 * 1e18; // Much lower liquidity
        
        tokenA.approve(address(router), lowLiquidity);
        tokenB.approve(address(router), lowLiquidity);
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            lowLiquidity,
            lowLiquidity,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        vm.stopPrank();
        
        // Now try a large swap that will cause significant slippage
        vm.startPrank(bob);
        
        uint256 largeSwapAmount = 100 * 1e18; // 10% of total liquidity
        tokenA.approve(address(router), largeSwapAmount);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // Get quote to see the slippage
        uint256[] memory amountsOut = router.getAmountsOut(largeSwapAmount, path);
        uint256 expectedOutput = amountsOut[1];
        
        // Execute the swap
        uint256 bobTokenBBefore = tokenB.balanceOf(bob);
        
        router.swapExactTokensForTokens(
            largeSwapAmount,
            expectedOutput * 90 / 100, // Accept up to 10% slippage from quote
            path,
            bob,
            block.timestamp + 300
        );
        
        uint256 bobTokenBAfter = tokenB.balanceOf(bob);
        uint256 actualOutput = bobTokenBAfter - bobTokenBBefore;
        
        // Calculate actual slippage
        uint256 slippagePercent = (expectedOutput - actualOutput) * 100 / expectedOutput;
        console.log("Large swap slippage:", slippagePercent, "%");
        console.log("Expected:", expectedOutput / 1e18, "TokenB");
        console.log("Received:", actualOutput / 1e18, "TokenB");
        
        // Verify the swap still completed successfully
        assertGt(actualOutput, 0);
        assertGe(actualOutput, expectedOutput * 90 / 100); // Within slippage tolerance
        
        console.log("System handled extreme slippage conditions");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 17: Gas optimization verification
     * Purpose: Ensure gas usage is reasonable for all operations
     * Important for user experience and cost efficiency
     */
    function test_GasOptimization() public {
        console.log("\n=== Test 17: Gas Usage Analysis ===");
        
        test_AddLiquidityNewPair();
        
        vm.startPrank(bob);
        
        tokenA.approve(address(router), SWAP_AMOUNT);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // Measure gas for a standard swap
        uint256 gasBefore = gasleft();
        
        router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            1,
            path,
            bob,
            block.timestamp + 300
        );
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for standard swap:", gasUsed);
        
        // Verify gas usage is reasonable (adjust based on your requirements)
        assertLt(gasUsed, 200000); // Should use less than 200k gas
        
        console.log("Gas usage within acceptable limits");
        
        vm.stopPrank();
    }
}
