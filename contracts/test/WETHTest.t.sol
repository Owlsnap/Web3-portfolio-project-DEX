// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import "../src/WETH.sol";

/**
 * @title WETHTest
 * @dev Comprehensive tests for the WETH contract
 * 
 * Test Categories:
 * 1. Basic deposit/withdraw functionality
 * 2. ERC20 compliance and transfers
 * 3. Router integration helpers
 * 4. Edge cases and error handling
 * 5. Backing verification
 */
contract WETHTest is Test {
    WETH public weth;
    
    // Test accounts
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    
    // Test constants
    uint256 public constant DEPOSIT_AMOUNT = 10 ether;
    uint256 public constant SMALL_AMOUNT = 0.1 ether;
    
    function setUp() public {
        console.log("=== Setting up WETH Test Environment ===");
        
        // Deploy WETH contract
        weth = new WETH();
        console.log("WETH deployed at:", address(weth));
        
        // Give test accounts some ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        
        console.log("Test accounts funded with ETH");
        console.log("=== Setup Complete ===\n");
    }
    
    // ============ BASIC FUNCTIONALITY TESTS ============
    
    /**
     * @dev Test 1: Basic deposit functionality
     * Purpose: Verify users can deposit ETH and receive WETH tokens
     */
    function test_BasicDeposit() public {
        console.log("\n=== Test 1: Basic Deposit ===");
        
        vm.startPrank(alice);
        
        // Check initial balances
        uint256 aliceETHBefore = alice.balance;
        uint256 aliceWETHBefore = weth.balanceOf(alice);
        uint256 contractETHBefore = address(weth).balance;
        
        console.log("Alice's ETH before:", aliceETHBefore / 1e18);
        console.log("Alice's WETH before:", aliceWETHBefore / 1e18);
        console.log("Contract ETH before:", contractETHBefore / 1e18);
        
        // Deposit ETH
        weth.deposit{value: DEPOSIT_AMOUNT}();
        
        // Check balances after deposit
        uint256 aliceETHAfter = alice.balance;
        uint256 aliceWETHAfter = weth.balanceOf(alice);
        uint256 contractETHAfter = address(weth).balance;
        
        console.log("Alice's ETH after:", aliceETHAfter / 1e18);
        console.log("Alice's WETH after:", aliceWETHAfter / 1e18);
        console.log("Contract ETH after:", contractETHAfter / 1e18);
        
        // Verify deposit worked correctly
        assertEq(aliceETHAfter, aliceETHBefore - DEPOSIT_AMOUNT);
        assertEq(aliceWETHAfter, aliceWETHBefore + DEPOSIT_AMOUNT);
        assertEq(contractETHAfter, contractETHBefore + DEPOSIT_AMOUNT);
        assertEq(weth.totalSupply(), DEPOSIT_AMOUNT);
        
        console.log("Basic deposit working correctly");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 2: Basic withdrawal functionality
     * Purpose: Verify users can withdraw ETH by burning WETH tokens
     */
    function test_BasicWithdraw() public {
        console.log("\n=== Test 2: Basic Withdrawal ===");
        
        // First deposit some WETH
        test_BasicDeposit();
        
        vm.startPrank(alice);
        
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2; // Withdraw half
        
        // Check balances before withdrawal
        uint256 aliceETHBefore = alice.balance;
        uint256 aliceWETHBefore = weth.balanceOf(alice);
        uint256 contractETHBefore = address(weth).balance;
        
        console.log("Withdrawing", withdrawAmount / 1e18, "ETH");
        
        // Withdraw ETH
        weth.withdraw(withdrawAmount);
        
        // Check balances after withdrawal
        uint256 aliceETHAfter = alice.balance;
        uint256 aliceWETHAfter = weth.balanceOf(alice);
        uint256 contractETHAfter = address(weth).balance;
        
        console.log("Alice's ETH after withdrawal:", aliceETHAfter / 1e18);
        console.log("Alice's WETH after withdrawal:", aliceWETHAfter / 1e18);
        console.log("Contract ETH after withdrawal:", contractETHAfter / 1e18);
        
        // Verify withdrawal worked correctly
        assertEq(aliceETHAfter, aliceETHBefore + withdrawAmount);
        assertEq(aliceWETHAfter, aliceWETHBefore - withdrawAmount);
        assertEq(contractETHAfter, contractETHBefore - withdrawAmount);
        
        console.log("Basic withdrawal working correctly");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 3: Fallback deposit (sending ETH directly)
     * Purpose: Verify the receive() function works for direct ETH transfers
     */
    function test_FallbackDeposit() public {
        console.log("\n=== Test 3: Fallback Deposit ===");
        
        vm.startPrank(alice);
        
        uint256 aliceWETHBefore = weth.balanceOf(alice);
        
        // Send ETH directly to contract (should trigger receive() function)
        (bool success, ) = payable(address(weth)).call{value: SMALL_AMOUNT}("");
        require(success, "Direct ETH transfer failed");
        
        uint256 aliceWETHAfter = weth.balanceOf(alice);
        
        console.log("WETH received from direct transfer:", (aliceWETHAfter - aliceWETHBefore) / 1e18);
        
        // Verify fallback deposit worked
        assertEq(aliceWETHAfter, aliceWETHBefore + SMALL_AMOUNT);
        assertEq(address(weth).balance, SMALL_AMOUNT);
        
        console.log("Fallback deposit working correctly");
        
        vm.stopPrank();
    }
    
    // ============ ERC20 FUNCTIONALITY TESTS ============
    
    /**
     * @dev Test 4: WETH transfers (ERC20 functionality)
     * Purpose: Verify WETH behaves as a proper ERC20 token
     */
    function test_WETHTransfers() public {
        console.log("\n=== Test 4: WETH Transfers ===");
        
        // Alice deposits WETH
        vm.prank(alice);
        weth.deposit{value: DEPOSIT_AMOUNT}();
        
        // Alice transfers WETH to Bob
        vm.startPrank(alice);
        
        uint256 transferAmount = DEPOSIT_AMOUNT / 3;
        uint256 bobWETHBefore = weth.balanceOf(bob);
        uint256 aliceWETHBefore = weth.balanceOf(alice);
        
        console.log("Transferring", transferAmount / 1e18, "WETH from Alice to Bob");
        
        weth.transfer(bob, transferAmount);
        
        uint256 bobWETHAfter = weth.balanceOf(bob);
        uint256 aliceWETHAfter = weth.balanceOf(alice);
        
        console.log("Bob's WETH after transfer:", bobWETHAfter / 1e18);
        console.log("Alice's WETH after transfer:", aliceWETHAfter / 1e18);
        
        // Verify transfer worked
        assertEq(bobWETHAfter, bobWETHBefore + transferAmount);
        assertEq(aliceWETHAfter, aliceWETHBefore - transferAmount);
        
        vm.stopPrank();
        
        // Bob can withdraw his WETH
        vm.startPrank(bob);
        uint256 bobETHBefore = bob.balance;
        
        weth.withdraw(transferAmount);
        
        uint256 bobETHAfter = bob.balance;
        assertEq(bobETHAfter, bobETHBefore + transferAmount);
        
        console.log("WETH transfers and withdrawals working correctly");
        
        vm.stopPrank();
    }
    
    // ============ ROUTER INTEGRATION TESTS ============
    
    /**
     * @dev Test 5: Deposit for another user
     * Purpose: Test Router integration helper functions
     */
    function test_DepositFor() public {
        console.log("\n=== Test 5: Deposit For Another User ===");
        
        vm.startPrank(alice);
        
        uint256 bobWETHBefore = weth.balanceOf(bob);
        
        // Alice deposits ETH but WETH goes to Bob
        weth.depositFor{value: DEPOSIT_AMOUNT}(bob);
        
        uint256 bobWETHAfter = weth.balanceOf(bob);
        uint256 aliceWETH = weth.balanceOf(alice);
        
        console.log("Bob's WETH after depositFor:", bobWETHAfter / 1e18);
        console.log("Alice's WETH (should be 0):", aliceWETH / 1e18);
        
        // Verify deposit worked for correct user
        assertEq(bobWETHAfter, bobWETHBefore + DEPOSIT_AMOUNT);
        assertEq(aliceWETH, 0); // Alice shouldn't have any WETH
        
        console.log("DepositFor functionality working correctly");
        
        vm.stopPrank();
    }
    
    /**
     * @dev Test 6: Withdraw to another address
     * Purpose: Test Router integration for withdrawing to specific addresses
     */
    function test_WithdrawTo() public {
        console.log("\n=== Test 6: Withdraw To Another Address ===");
        
        // Alice deposits WETH first
        vm.prank(alice);
        weth.deposit{value: DEPOSIT_AMOUNT}();
        
        vm.startPrank(alice);
        
        uint256 charlieETHBefore = charlie.balance;
        uint256 aliceWETHBefore = weth.balanceOf(alice);
        
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;
        
        // Alice withdraws WETH but ETH goes to Charlie
        weth.withdrawTo(withdrawAmount, payable(charlie));
        
        uint256 charlieETHAfter = charlie.balance;
        uint256 aliceWETHAfter = weth.balanceOf(alice);
        
        console.log("Charlie's ETH after withdrawTo:", charlieETHAfter / 1e18);
        console.log("Alice's remaining WETH:", aliceWETHAfter / 1e18);
        
        // Verify withdraw worked to correct address
        assertEq(charlieETHAfter, charlieETHBefore + withdrawAmount);
        assertEq(aliceWETHAfter, aliceWETHBefore - withdrawAmount);
        
        console.log("WithdrawTo functionality working correctly");
        
        vm.stopPrank();
    }
    
    // ============ ERROR HANDLING TESTS ============
    
    /**
     * @dev Test 7: Error conditions
     * Purpose: Verify proper error handling for edge cases
     */
    function test_ErrorConditions() public {
        console.log("\n=== Test 7: Error Conditions ===");
        
        vm.startPrank(alice);
        
        // Test 1: Cannot deposit 0 ETH
        vm.expectRevert("WETH: Cannot deposit 0 ETH");
        weth.deposit{value: 0}();
        
        // Test 2: Cannot withdraw 0 WETH
        vm.expectRevert("WETH: Cannot withdraw 0");
        weth.withdraw(0);
        
        // Test 3: Cannot withdraw more than balance
        vm.expectRevert("WETH: Insufficient WETH balance");
        weth.withdraw(1 ether);
        
        // Test 4: Cannot deposit for zero address
        vm.expectRevert("WETH: Cannot deposit for zero address");
        weth.depositFor{value: 1 ether}(address(0));
        
        // Test 5: Cannot withdraw to zero address
        weth.deposit{value: 1 ether}(); // First deposit some WETH
        vm.expectRevert("WETH: Cannot withdraw to zero address");
        weth.withdrawTo(0.5 ether, payable(address(0)));
        
        console.log("All error conditions handled correctly");
        
        vm.stopPrank();
    }
    
    // ============ BACKING VERIFICATION TESTS ============
    
    /**
     * @dev Test 8: Backing verification
     * Purpose: Ensure WETH is always properly backed by ETH
     */
    function test_BackingVerification() public {
        console.log("\n=== Test 8: Backing Verification ===");
        
        // Initially, contract should be properly backed (0 supply, 0 ETH)
        assertTrue(weth.isProperlyBacked());
        assertEq(weth.exchangeRate(), 1e18); // 1:1 ratio
        
        // After deposits, should still be properly backed
        vm.prank(alice);
        weth.deposit{value: DEPOSIT_AMOUNT}();
        
        assertTrue(weth.isProperlyBacked());
        assertEq(weth.totalETHBalance(), DEPOSIT_AMOUNT);
        assertEq(weth.totalSupply(), DEPOSIT_AMOUNT);
        
        console.log("Total WETH supply:", weth.totalSupply() / 1e18);
        console.log("Total ETH backing:", weth.totalETHBalance() / 1e18);
        console.log("Exchange rate (should be 1.0):", weth.exchangeRate() / 1e18);
        
        // Multiple users deposit
        vm.prank(bob);
        weth.deposit{value: DEPOSIT_AMOUNT / 2}();
        
        assertTrue(weth.isProperlyBacked());
        assertEq(weth.totalETHBalance(), DEPOSIT_AMOUNT + DEPOSIT_AMOUNT / 2);
        assertEq(weth.totalSupply(), DEPOSIT_AMOUNT + DEPOSIT_AMOUNT / 2);
        
        console.log("WETH maintains proper 1:1 backing at all times");
    }
    
    /**
     * @dev Test 9: Gas optimization
     * Purpose: Verify gas usage is reasonable
     */
    function test_GasOptimization() public {
        console.log("\n=== Test 9: Gas Usage Analysis ===");
        
        vm.startPrank(alice);
        
        // Measure gas for deposit
        uint256 gasBefore = gasleft();
        weth.deposit{value: 1 ether}();
        uint256 depositGas = gasBefore - gasleft();
        
        // Measure gas for withdrawal
        gasBefore = gasleft();
        weth.withdraw(0.5 ether);
        uint256 withdrawGas = gasBefore - gasleft();
        
        console.log("Gas used for deposit:", depositGas);
        console.log("Gas used for withdrawal:", withdrawGas);
        
        // Verify gas usage is reasonable (adjust based on requirements)
        // Based on observed ~60k gas usage, set reasonable threshold with buffer
        assertLt(depositGas, 100000);  // Should use less than 100k gas
        assertLt(withdrawGas, 100000); // Should use less than 100k gas
        
        console.log("Gas usage within acceptable limits");
        
        vm.stopPrank();
    }
}