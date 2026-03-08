// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/MockERC20.sol";

contract MockERC20Test is Test {
    MockERC20 public token;

    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    /**
     * @dev Setup function called before each test
     * Creates a fresh MockERC20 instance with standard parameters
     */
    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 18, INITIAL_SUPPLY);
    }

    /**
     * @dev Test that the token is deployed with correct initial parameters
     * Verifies: name, symbol, decimals, total supply, owner balance, and ownership
     */
    function testInitialState() public view {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.owner(), owner);
    }

    /**
     * @dev Test that owner can successfully mint tokens to any address
     * Verifies: recipient balance increases, total supply increases
     */
    function testMint() public {
        uint256 mintAmount = 1000e18;
        
        token.mint(alice, mintAmount);
        
        assertEq(token.balanceOf(alice), mintAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + mintAmount);
    }

    /**
     * @dev Test that only the owner can mint tokens (access control)
     * Verifies: non-owner calls to mint() revert with proper error
     */
    function testMintOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1000e18);
    }

    /**
     * @dev Test that tokens can be burned successfully
     * Verifies: caller's balance decreases, total supply decreases
     */
    function testBurn() public {
        uint256 burnAmount = 1000e18;
        
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    /**
     * @dev Test that burning tokens fails when user has insufficient balance
     * Verifies: calling burn() with more tokens than owned reverts
     */
    function testBurnInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert();
        token.burn(1e18);
    }

    /**
     * @dev Test basic token transfer functionality
     * Verifies: sender balance decreases, recipient balance increases
     */
    function testTransfer() public {
        uint256 transferAmount = 1000e18;
        
        token.transfer(alice, transferAmount);
        
        assertEq(token.balanceOf(alice), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
    }

    /**
     * @dev Test that transfer fails when sender has insufficient balance
     * Verifies: transferring more tokens than owned reverts
     */
    function testTransferInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1e18);  // Alice has 0 tokens, can't transfer to bob
    }

    /**
     * @dev Test the approve + transferFrom mechanism (ERC-20 standard)
     * Verifies: approved spender can transfer owner's tokens, allowances update correctly
     */
    function testApproveAndTransferFrom() public {
        uint256 approveAmount = 1000e18;
        uint256 transferAmount = 500e18;
        
        // Owner approves alice to spend tokens
        token.approve(alice, approveAmount);
        
        // Alice transfers owner's tokens to bob
        vm.prank(alice);
        token.transferFrom(owner, bob, transferAmount);
        
        assertEq(token.balanceOf(bob), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.allowance(owner, alice), approveAmount - transferAmount);
    }

    /**
     * @dev Test that transferFrom fails without proper allowance
     * Verifies: calling transferFrom without approval reverts
     */
    function testTransferFromInsufficientAllowance() public {
        // No approval given
        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(owner, bob, 1e18);
    }

    /**
     * @dev Fuzz test for mint function with random amounts
     * Verifies: minting works correctly with any valid amount (prevents overflow)
     * Note: vm.assume() filters out amounts that would cause overflow
     */
    function testFuzzMint(uint256 amount) public {
        vm.assume(amount <= type(uint256).max - INITIAL_SUPPLY);
        
        token.mint(alice, amount);
        
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
    }
}