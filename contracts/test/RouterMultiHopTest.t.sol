// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import "../src/Factory.sol";
import "../src/Router.sol";
import "../src/Pair.sol";
import "../src/MockERC20.sol";
import "../src/WETH.sol";

/**
 * @title RouterMultiHopTest
 * @dev Test multi-hop routing functionality in the DEX
 * Shows how tokens can be swapped through intermediate pairs
 */
contract RouterMultiHopTest is Test {
    Factory public factory;
    Router public router;
    WETH public weth;
    
    // Test tokens
    MockERC20 public tokenA;  // Starting token
    MockERC20 public tokenB;  // Intermediate token (WETH-like)
    MockERC20 public tokenC;  // Intermediate token (USDC-like)
    MockERC20 public tokenD;  // Final token
    
    // Test accounts
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    
    // Initial amounts
    uint256 constant INITIAL_MINT = 1000000 * 1e18;
    uint256 constant LIQUIDITY_AMOUNT = 10000 * 1e18;
    
    function setUp() public {
        // Deploy contracts
        factory = new Factory(address(this)); // Factory needs feeToSetter address
        weth = new WETH();
        router = new Router(address(factory), address(weth));
        
        // Deploy test tokens (name, symbol, decimals, initialSupply)
        tokenA = new MockERC20("TokenA", "TKA", 18, 0); // 0 initial supply, we'll mint later
        tokenB = new MockERC20("TokenB", "TKB", 18, 0); // WETH-like hub token
        tokenC = new MockERC20("TokenC", "TKC", 18, 0); // USDC-like hub token  
        tokenD = new MockERC20("TokenD", "TKD", 18, 0);
        
        // Mint tokens to test accounts
        tokenA.mint(alice, INITIAL_MINT);
        tokenB.mint(alice, INITIAL_MINT);
        tokenC.mint(alice, INITIAL_MINT);
        tokenD.mint(alice, INITIAL_MINT);
        
        tokenA.mint(bob, INITIAL_MINT);
        tokenB.mint(bob, INITIAL_MINT);
        tokenC.mint(bob, INITIAL_MINT);
        tokenD.mint(bob, INITIAL_MINT);
        
        // Setup approvals
        vm.startPrank(alice);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);
        tokenD.approve(address(router), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(bob);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);
        tokenD.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }
    
    /**
     * @dev Setup liquidity pools to enable multi-hop routing
     * Creates: A-B, B-C, C-D pairs (but no direct A-D pair)
     */
    function test_SetupLiquidityPools() public {
        vm.startPrank(alice);
        
        console.log("=== Setting up liquidity pools ===");
        
        // Create and add liquidity to A-B pair
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,     // 10,000 TokenA
            LIQUIDITY_AMOUNT,     // 10,000 TokenB
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        // Create and add liquidity to B-C pair
        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            LIQUIDITY_AMOUNT,     // 10,000 TokenB
            LIQUIDITY_AMOUNT,     // 10,000 TokenC
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        // Create and add liquidity to C-D pair
        router.addLiquidity(
            address(tokenC),
            address(tokenD),
            LIQUIDITY_AMOUNT,     // 10,000 TokenC
            LIQUIDITY_AMOUNT,     // 10,000 TokenD
            0,
            0,
            alice,
            block.timestamp + 300
        );
        
        vm.stopPrank();
        
        // Verify pairs exist
        address pairAB = router.getPair(address(tokenA), address(tokenB));
        address pairBC = router.getPair(address(tokenB), address(tokenC));
        address pairCD = router.getPair(address(tokenC), address(tokenD));
        address pairAD = router.getPair(address(tokenA), address(tokenD));
        
        assertTrue(pairAB != address(0), "A-B pair should exist");
        assertTrue(pairBC != address(0), "B-C pair should exist");
        assertTrue(pairCD != address(0), "C-D pair should exist");
        assertTrue(pairAD == address(0), "A-D pair should NOT exist (forces multi-hop)");
        
        console.log("A-B Pair:", pairAB);
        console.log("B-C Pair:", pairBC);
        console.log("C-D Pair:", pairCD);
        console.log("A-D Pair:", pairAD, "(should be 0x0)");
        
        console.log("=== Liquidity pools setup complete! ===\n");
    }
    
    /**
     * @dev Test direct swap (single hop)
     */
    function test_DirectSwap() public {
        test_SetupLiquidityPools();
        
        vm.startPrank(bob);
        
        console.log("=== Testing Direct Swap (A -> B) ===");
        
        uint256 swapAmount = 1000 * 1e18; // 1,000 TokenA
        uint256 balanceABefore = tokenA.balanceOf(bob);
        uint256 balanceBBefore = tokenB.balanceOf(bob);
        
        console.log("Bob's TokenA before:", balanceABefore / 1e18);
        console.log("Bob's TokenB before:", balanceBBefore / 1e18);
        
        // Create path for direct swap
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // Calculate expected output
        uint256[] memory expectedAmounts = router.getAmountsOut(swapAmount, path);
        console.log("Expected TokenB output:", expectedAmounts[1] / 1e18);
        
        // Execute direct swap
        router.swapExactTokensForTokens(
            swapAmount,
            0, // Accept any amount (for testing)
            path,
            bob,
            block.timestamp + 300
        );
        
        uint256 balanceAAfter = tokenA.balanceOf(bob);
        uint256 balanceBAfter = tokenB.balanceOf(bob);
        
        console.log("Bob's TokenA after:", balanceAAfter / 1e18);
        console.log("Bob's TokenB after:", balanceBAfter / 1e18);
        console.log("Actual TokenB received:", (balanceBAfter - balanceBBefore) / 1e18);
        
        // Verify swap worked
        assertEq(balanceAAfter, balanceABefore - swapAmount, "TokenA should be deducted");
        assertTrue(balanceBAfter > balanceBBefore, "Should receive TokenB");
        
        vm.stopPrank();
        console.log("=== Direct swap successful! ===\n");
    }
    
    /**
     * @dev Test multi-hop swap (A -> B -> C -> D)
     */
    function test_MultiHopSwap() public {
        test_SetupLiquidityPools();
        
        vm.startPrank(bob);
        
        console.log("=== Testing Multi-Hop Swap (A -> B -> C -> D) ===");
        
        uint256 swapAmount = 1000 * 1e18; // 1,000 TokenA
        uint256 balanceABefore = tokenA.balanceOf(bob);
        uint256 balanceDBefore = tokenD.balanceOf(bob);
        
        console.log("Bob's TokenA before:", balanceABefore / 1e18);
        console.log("Bob's TokenD before:", balanceDBefore / 1e18);
        
        // Create path for multi-hop swap: A -> B -> C -> D
        address[] memory path = new address[](4);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        path[3] = address(tokenD);
        
        // Calculate expected outputs for each hop
        uint256[] memory expectedAmounts = router.getAmountsOut(swapAmount, path);
        console.log("=== Expected amounts for each hop ===");
        console.log("Input TokenA:", expectedAmounts[0] / 1e18);
        console.log("A->B TokenB:", expectedAmounts[1] / 1e18);
        console.log("B->C TokenC:", expectedAmounts[2] / 1e18);
        console.log("C->D TokenD:", expectedAmounts[3] / 1e18);
        
        // Execute multi-hop swap
        router.swapExactTokensForTokens(
            swapAmount,
            0, // Accept any amount (for testing)
            path,
            bob,
            block.timestamp + 300
        );
        
        uint256 balanceAAfter = tokenA.balanceOf(bob);
        uint256 balanceDAfter = tokenD.balanceOf(bob);
        
        console.log("=== Results ===");
        console.log("Bob's TokenA after:", balanceAAfter / 1e18);
        console.log("Bob's TokenD after:", balanceDAfter / 1e18);
        console.log("Actual TokenD received:", (balanceDAfter - balanceDBefore) / 1e18);
        
        // Verify multi-hop swap worked
        assertEq(balanceAAfter, balanceABefore - swapAmount, "TokenA should be deducted");
        assertTrue(balanceDAfter > balanceDBefore, "Should receive TokenD");
        
        // Should receive close to expected amount (accounting for small rounding differences)
        uint256 actualReceived = balanceDAfter - balanceDBefore;
        uint256 expectedReceived = expectedAmounts[3];
        assertTrue(
            actualReceived >= expectedReceived - 1e15, // Allow for small rounding errors
            "Should receive expected amount"
        );
        
        vm.stopPrank();
        console.log("=== Multi-hop swap successful! ===\n");
    }
    
    /**
     * @dev Compare direct vs multi-hop efficiency
     */
    function test_CompareDirectVsMultiHop() public {
        test_SetupLiquidityPools();
        
        console.log("=== Comparing Direct vs Multi-Hop Efficiency ===");
        
        // Add A-D direct pair for comparison
        vm.startPrank(alice);
        router.addLiquidity(
            address(tokenA),
            address(tokenD),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        vm.stopPrank();
        
        vm.startPrank(bob);
        
        uint256 swapAmount = 1000 * 1e18;
        
        // Direct path: A -> D
        address[] memory directPath = new address[](2);
        directPath[0] = address(tokenA);
        directPath[1] = address(tokenD);
        
        // Multi-hop path: A -> B -> C -> D
        address[] memory multiHopPath = new address[](4);
        multiHopPath[0] = address(tokenA);
        multiHopPath[1] = address(tokenB);
        multiHopPath[2] = address(tokenC);
        multiHopPath[3] = address(tokenD);
        
        // Calculate outputs
        uint256[] memory directAmounts = router.getAmountsOut(swapAmount, directPath);
        uint256[] memory multiHopAmounts = router.getAmountsOut(swapAmount, multiHopPath);
        
        console.log("=== Output comparison for 1000 TokenA ===");
        console.log("Direct swap (A->D):", directAmounts[1] / 1e18, "TokenD");
        console.log("Multi-hop (A->B->C->D):", multiHopAmounts[3] / 1e18, "TokenD");
        
        // Multi-hop should give less due to multiple fees
        assertTrue(
            directAmounts[1] > multiHopAmounts[3],
            "Direct swap should be more efficient than multi-hop"
        );
        
        uint256 efficiencyLoss = ((directAmounts[1] - multiHopAmounts[3]) * 100) / directAmounts[1];
        console.log("Efficiency loss from multi-hop:", efficiencyLoss, "%");
        
        vm.stopPrank();
        console.log("=== Comparison complete! ===\n");
    }
    
    /**
     * @dev Test that multi-hop fails if any pair doesn't exist
     */
    function test_MultiHopFailsWithMissingPair() public {
        // Only setup A-B pair, not B-C or C-D
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
        
        vm.startPrank(bob);
        
        console.log("=== Testing Multi-Hop with Missing Pair ===");
        
        // Try multi-hop path where B-C pair doesn't exist
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC); // B-C pair doesn't exist!
        
        uint256 swapAmount = 1000 * 1e18;
        
        // This should revert because B-C pair doesn't exist
        vm.expectRevert();
        router.getAmountsOut(swapAmount, path);
        
        console.log("Multi-hop correctly failed when pair is missing");
        
        vm.stopPrank();
    }
}