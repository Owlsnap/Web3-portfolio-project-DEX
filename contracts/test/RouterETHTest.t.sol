// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import "../src/Factory.sol";
import "../src/Router.sol";
import "../src/Pair.sol";
import "../src/MockERC20.sol";
import "../src/WETH.sol";

/**
 * @title RouterETHTest
 * @dev Comprehensive tests for Router ETH integration functionality
 * Tests automatic ETH wrapping/unwrapping for seamless user experience
 */
contract RouterETHTest is Test {
    Factory public factory;
    Router public router;
    WETH public weth;
    MockERC20 public tokenA;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    uint256 constant INITIAL_SUPPLY = 1_000_000 * 1e18;
    uint256 constant LIQUIDITY_AMOUNT = 10_000 * 1e18;
    uint256 constant SWAP_AMOUNT = 1_000 * 1e18;
    
    event ETHReceived(address indexed from, uint256 amount);
    
    // Track ETH received for testing
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }
    
    function setUp() public {
        // Deploy contracts
        factory = new Factory(address(this));
        weth = new WETH();
        router = new Router(address(factory), address(weth));
        
        // Deploy test token
        tokenA = new MockERC20("Token A", "TKNA", 18, INITIAL_SUPPLY);
        
        // Give test accounts ETH and tokens
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        tokenA.transfer(alice, 500_000 * 1e18);
        tokenA.transfer(bob, 500_000 * 1e18);
        
        // Setup approvals
        vm.prank(alice);
        tokenA.approve(address(router), type(uint256).max);
    }
    
    /**
     * @dev Test adding liquidity with ETH
     */
    function test_AddLiquidityETH() public {
        console.log("=== Testing Add Liquidity ETH ===");
        
        uint256 tokenAmount = LIQUIDITY_AMOUNT;
        uint256 ethAmount = 5 ether;
        
        uint256 aliceTokenBefore = tokenA.balanceOf(alice);
        uint256 aliceETHBefore = alice.balance;
        
        console.log("Alice token balance before:", aliceTokenBefore / 1e18);
        console.log("Alice ETH balance before:", aliceETHBefore / 1e18);
        
        // Add liquidity with ETH
        vm.prank(alice);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: ethAmount}(
            address(tokenA),
            tokenAmount,
            tokenAmount * 95 / 100, // 5% slippage
            ethAmount * 95 / 100,   // 5% slippage
            alice,
            block.timestamp + 300
        );
        
        console.log("Amount token added:", amountToken / 1e18);
        console.log("Amount ETH added:", amountETH / 1e18);
        console.log("Liquidity received:", liquidity / 1e18);
        
        // Verify balances changed correctly
        uint256 aliceTokenAfter = tokenA.balanceOf(alice);
        uint256 aliceETHAfter = alice.balance;
        
        console.log("Alice token balance after:", aliceTokenAfter / 1e18);
        console.log("Alice ETH balance after:", aliceETHAfter / 1e18);
        
        assertEq(aliceTokenBefore - aliceTokenAfter, amountToken, "Token amount should match");
        assertLt(aliceETHAfter, aliceETHBefore, "ETH balance should decrease");
        
        // Check pair was created and has liquidity
        address pair = factory.getPair(address(tokenA), address(weth));
        assertTrue(pair != address(0), "Pair should be created");
        
        uint256 pairWETHBalance = weth.balanceOf(pair);
        console.log("Pair WETH balance:", pairWETHBalance / 1e18);
        assertEq(pairWETHBalance, amountETH, "Pair should have WETH");
        
        console.log("=== Add Liquidity ETH successful! ===\n");
    }
    
    /**
     * @dev Test removing liquidity to ETH
     */
    function test_RemoveLiquidityETH() public {
        console.log("=== Testing Remove Liquidity ETH ===");
        
        // First add liquidity
        uint256 tokenAmount = LIQUIDITY_AMOUNT;
        uint256 ethAmount = 5 ether;
        
        vm.prank(alice);
        (,, uint256 liquidity) = router.addLiquidityETH{value: ethAmount}(
            address(tokenA),
            tokenAmount,
            0, 0, alice, block.timestamp + 300
        );
        
        console.log("Initial liquidity added:", liquidity / 1e18);
        
        // Get pair and approve router to spend LP tokens
        address pair = factory.getPair(address(tokenA), address(weth));
        vm.prank(alice);
        Pair(pair).approve(address(router), liquidity);
        
        uint256 aliceTokenBefore = tokenA.balanceOf(alice);
        uint256 aliceETHBefore = alice.balance;
        
        console.log("Alice token balance before removal:", aliceTokenBefore / 1e18);
        console.log("Alice ETH balance before removal:", aliceETHBefore / 1e18);
        
        // Remove half the liquidity
        uint256 liquidityToRemove = liquidity / 2;
        
        vm.prank(alice);
        (uint256 amountToken, uint256 amountETH) = router.removeLiquidityETH(
            address(tokenA),
            liquidityToRemove,
            0, 0, alice, block.timestamp + 300
        );
        
        console.log("Amount token removed:", amountToken / 1e18);
        console.log("Amount ETH removed:", amountETH / 1e18);
        
        uint256 aliceTokenAfter = tokenA.balanceOf(alice);
        uint256 aliceETHAfter = alice.balance;
        
        console.log("Alice token balance after removal:", aliceTokenAfter / 1e18);
        console.log("Alice ETH balance after removal:", aliceETHAfter / 1e18);
        
        // Verify balances increased
        assertEq(aliceTokenAfter - aliceTokenBefore, amountToken, "Token amount should match");
        assertGt(aliceETHAfter, aliceETHBefore, "ETH balance should increase");
        
        console.log("=== Remove Liquidity ETH successful! ===\n");
    }
    
    /**
     * @dev Test swapping exact ETH for tokens
     */
    function test_SwapExactETHForTokens() public {
        console.log("=== Testing Swap Exact ETH For Tokens ===");
        
        // First add liquidity to create a market
        vm.prank(alice);
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA), LIQUIDITY_AMOUNT, 0, 0, alice, block.timestamp + 300
        );
        
        uint256 ethToSwap = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        
        // Get expected output
        uint256[] memory amountsOut = router.getAmountsOut(ethToSwap, path);
        uint256 expectedTokens = amountsOut[1];
        
        console.log("ETH to swap:", ethToSwap / 1e18);
        console.log("Expected tokens out:", expectedTokens / 1e18);
        
        uint256 bobTokenBefore = tokenA.balanceOf(bob);
        uint256 bobETHBefore = bob.balance;
        
        // Execute swap
        vm.prank(bob);
        uint256[] memory amounts = router.swapExactETHForTokens{value: ethToSwap}(
            expectedTokens * 95 / 100, // 5% slippage
            path,
            bob,
            block.timestamp + 300
        );
        
        console.log("Actual ETH used:", amounts[0] / 1e18);
        console.log("Actual tokens received:", amounts[1] / 1e18);
        
        uint256 bobTokenAfter = tokenA.balanceOf(bob);
        uint256 bobETHAfter = bob.balance;
        
        assertEq(bobTokenAfter - bobTokenBefore, amounts[1], "Token amount should match");
        assertLt(bobETHAfter, bobETHBefore, "ETH balance should decrease");
        
        console.log("=== Swap Exact ETH For Tokens successful! ===\n");
    }
    
    /**
     * @dev Test swapping tokens for exact ETH
     */
    function test_SwapTokensForExactETH() public {
        console.log("=== Testing Swap Tokens For Exact ETH ===");
        
        // First add liquidity
        vm.prank(alice);
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA), LIQUIDITY_AMOUNT, 0, 0, alice, block.timestamp + 300
        );
        
        uint256 ethWanted = 1 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);
        
        // Get required input
        uint256[] memory amountsIn = router.getAmountsIn(ethWanted, path);
        uint256 tokensNeeded = amountsIn[0];
        
        console.log("ETH wanted:", ethWanted / 1e18);
        console.log("Tokens needed:", tokensNeeded / 1e18);
        
        // Setup bob with tokens and approval
        vm.startPrank(bob);
        tokenA.approve(address(router), type(uint256).max);
        
        uint256 bobTokenBefore = tokenA.balanceOf(bob);
        uint256 bobETHBefore = bob.balance;
        
        // Execute swap
        uint256[] memory amounts = router.swapTokensForExactETH(
            ethWanted,
            tokensNeeded * 105 / 100, // 5% slippage
            path,
            bob,
            block.timestamp + 300
        );
        
        vm.stopPrank();
        
        console.log("Actual tokens used:", amounts[0] / 1e18);
        console.log("Actual ETH received:", amounts[1] / 1e18);
        
        uint256 bobTokenAfter = tokenA.balanceOf(bob);
        uint256 bobETHAfter = bob.balance;
        
        assertEq(bobTokenBefore - bobTokenAfter, amounts[0], "Token amount should match");
        assertGt(bobETHAfter, bobETHBefore, "ETH balance should increase");
        assertEq(amounts[1], ethWanted, "Should receive exact ETH amount");
        
        console.log("=== Swap Tokens For Exact ETH successful! ===\n");
    }
    
    /**
     * @dev Test swapping exact tokens for ETH
     */
    function test_SwapExactTokensForETH() public {
        console.log("=== Testing Swap Exact Tokens For ETH ===");
        
        // First add liquidity
        vm.prank(alice);
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA), LIQUIDITY_AMOUNT, 0, 0, alice, block.timestamp + 300
        );
        
        uint256 tokensToSwap = SWAP_AMOUNT;
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);
        
        // Get expected output
        uint256[] memory amountsOut = router.getAmountsOut(tokensToSwap, path);
        uint256 expectedETH = amountsOut[1];
        
        console.log("Tokens to swap:", tokensToSwap / 1e18);
        console.log("Expected ETH out:", expectedETH / 1e18);
        
        // Setup bob with approval
        vm.startPrank(bob);
        tokenA.approve(address(router), type(uint256).max);
        
        uint256 bobTokenBefore = tokenA.balanceOf(bob);
        uint256 bobETHBefore = bob.balance;
        
        // Execute swap
        uint256[] memory amounts = router.swapExactTokensForETH(
            tokensToSwap,
            expectedETH * 95 / 100, // 5% slippage
            path,
            bob,
            block.timestamp + 300
        );
        
        vm.stopPrank();
        
        console.log("Actual tokens used:", amounts[0] / 1e18);
        console.log("Actual ETH received:", amounts[1] / 1e18);
        
        uint256 bobTokenAfter = tokenA.balanceOf(bob);
        uint256 bobETHAfter = bob.balance;
        
        assertEq(bobTokenBefore - bobTokenAfter, amounts[0], "Token amount should match");
        assertGt(bobETHAfter, bobETHBefore, "ETH balance should increase");
        assertEq(amounts[0], tokensToSwap, "Should use exact token amount");
        
        console.log("=== Swap Exact Tokens For ETH successful! ===\n");
    }
    
    /**
     * @dev Test swapping ETH for exact tokens
     */
    function test_SwapETHForExactTokens() public {
        console.log("=== Testing Swap ETH For Exact Tokens ===");
        
        // First add liquidity
        vm.prank(alice);
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA), LIQUIDITY_AMOUNT, 0, 0, alice, block.timestamp + 300
        );
        
        uint256 tokensWanted = SWAP_AMOUNT;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        
        // Get required input
        uint256[] memory amountsIn = router.getAmountsIn(tokensWanted, path);
        uint256 ethNeeded = amountsIn[0];
        
        console.log("Tokens wanted:", tokensWanted / 1e18);
        console.log("ETH needed:", ethNeeded / 1e18);
        
        uint256 bobTokenBefore = tokenA.balanceOf(bob);
        uint256 bobETHBefore = bob.balance;
        
        // Execute swap with some extra ETH (should refund excess)
        uint256 ethToSend = ethNeeded * 105 / 100; // 5% extra
        vm.prank(bob);
        uint256[] memory amounts = router.swapETHForExactTokens{value: ethToSend}(
            tokensWanted,
            path,
            bob,
            block.timestamp + 300
        );
        
        console.log("Actual ETH used:", amounts[0] / 1e18);
        console.log("Actual tokens received:", amounts[1] / 1e18);
        
        uint256 bobTokenAfter = tokenA.balanceOf(bob);
        uint256 bobETHAfter = bob.balance;
        
        assertEq(bobTokenAfter - bobTokenBefore, amounts[1], "Token amount should match");
        assertEq(amounts[1], tokensWanted, "Should receive exact token amount");
        assertLt(bobETHAfter, bobETHBefore, "ETH balance should decrease");
        
        // Should refund excess ETH
        uint256 ethUsed = bobETHBefore - bobETHAfter;
        assertLe(ethUsed, ethToSend, "Should not use more ETH than sent");
        
        console.log("=== Swap ETH For Exact Tokens successful! ===\n");
    }
    
    /**
     * @dev Test error cases for ETH functions
     */
    function test_ETHFunctionErrors() public {
        console.log("=== Testing ETH Function Error Cases ===");
        
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        
        // Test invalid path (not starting with WETH)
        address[] memory invalidPath = new address[](2);
        invalidPath[0] = address(tokenA);
        invalidPath[1] = address(weth);
        
        vm.expectRevert("Router: INVALID_PATH");
        vm.prank(bob);
        router.swapExactETHForTokens{value: 1 ether}(0, invalidPath, bob, block.timestamp + 300);
        
        // Test zero ETH
        vm.expectRevert("Router: INSUFFICIENT_ETH");
        vm.prank(bob);
        router.swapExactETHForTokens{value: 0}(0, path, bob, block.timestamp + 300);
        
        console.log("Error cases handled correctly");
    }
    
    /**
     * @dev Test WETH integration works correctly
     */
    function test_WETHIntegration() public {
        console.log("=== Testing WETH Integration ===");
        
        // Add liquidity to create WETH/Token pair
        vm.prank(alice);
        router.addLiquidityETH{value: 5 ether}(
            address(tokenA), LIQUIDITY_AMOUNT, 0, 0, alice, block.timestamp + 300
        );
        
        address pair = factory.getPair(address(tokenA), address(weth));
        assertTrue(pair != address(0), "WETH/Token pair should exist");
        
        // Check WETH balance in pair
        uint256 wethInPair = weth.balanceOf(pair);
        assertGt(wethInPair, 0, "Pair should have WETH balance");
        
        console.log("WETH in pair:", wethInPair / 1e18);
        console.log("WETH integration working correctly");
    }
}