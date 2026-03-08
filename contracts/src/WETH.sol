// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title WETH - Wrapped Ether
 * @dev Implementation of Wrapped Ether for DEX compatibility
 * 
 * Purpose in DEX:
 * - Enables ETH to be traded as an ERC20 token
 * - Creates ETH/Token liquidity pairs 
 * - Allows users to deposit ETH and receive WETH tokens
 * - Users can withdraw ETH by burning WETH tokens
 * - Maintains 1:1 peg with ETH at all times
 * 
 * Key Features:
 * - Deposit: Send ETH, receive WETH
 * - Withdraw: Burn WETH, receive ETH
 * - ERC20 Compatible: Can be used in Router/Pair contracts
 * - 1:1 Backing: Every WETH is backed by 1 ETH in the contract
 */
contract WETH is ERC20 {
    
    // ============ EVENTS ============
    
    /**
     * @dev Emitted when ETH is deposited and WETH is minted
     * @param user Address that deposited ETH
     * @param amount Amount of ETH deposited and WETH minted
     */
    event Deposit(address indexed user, uint256 amount);
    
    /**
     * @dev Emitted when WETH is burned and ETH is withdrawn
     * @param user Address that withdrew ETH
     * @param amount Amount of WETH burned and ETH withdrawn
     */
    event Withdrawal(address indexed user, uint256 amount);
    
    // ============ CONSTRUCTOR ============
    
    /**
     * @dev Initialize WETH with standard ERC20 properties
     */
    constructor() ERC20("Wrapped Ether", "WETH") {
        // WETH has 18 decimals (same as ETH)
        // No initial supply - tokens are minted when ETH is deposited
    }
    
    // ============ CORE FUNCTIONS ============
    
    /**
     * @dev Deposit ETH and receive WETH tokens
     * Anyone can deposit ETH to get WETH tokens
     * Maintains 1:1 ratio with ETH
     */
    function deposit() public payable {
        require(msg.value > 0, "WETH: Cannot deposit 0 ETH");
        
        // Mint WETH tokens equal to ETH deposited
        _mint(msg.sender, msg.value);
        
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @dev Withdraw ETH by burning WETH tokens
     * @param amount Amount of WETH to burn and ETH to withdraw
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "WETH: Cannot withdraw 0");
        require(balanceOf(msg.sender) >= amount, "WETH: Insufficient WETH balance");
        require(address(this).balance >= amount, "WETH: Insufficient ETH in contract");
        
        // Burn WETH tokens
        _burn(msg.sender, amount);
        
        // Send ETH to user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "WETH: ETH transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }
    
    // ============ CONVENIENCE FUNCTIONS ============
    
    /**
     * @dev Fallback function - automatically deposit when ETH is sent
     * This allows users to send ETH directly to the contract
     */
    receive() external payable {
        deposit();
    }
    
    /**
     * @dev Get the total ETH backing this WETH supply
     * Should always equal totalSupply() for proper 1:1 backing
     */
    function totalETHBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // ============ ROUTER INTEGRATION HELPERS ============
    
    /**
     * @dev Deposit ETH for a specific user (used by Router)
     * @param user Address to mint WETH tokens to
     * This is useful when the Router needs to convert ETH to WETH on behalf of users
     */
    function depositFor(address user) external payable {
        require(msg.value > 0, "WETH: Cannot deposit 0 ETH");
        require(user != address(0), "WETH: Cannot deposit for zero address");
        
        // Mint WETH tokens to the specified user
        _mint(user, msg.value);
        
        emit Deposit(user, msg.value);
    }
    
    /**
     * @dev Withdraw ETH to a specific address (used by Router)
     * @param amount Amount of WETH to burn
     * @param to Address to send ETH to
     * This allows the Router to convert WETH to ETH and send to users
     */
    function withdrawTo(uint256 amount, address payable to) external {
        require(amount > 0, "WETH: Cannot withdraw 0");
        require(to != address(0), "WETH: Cannot withdraw to zero address");
        require(balanceOf(msg.sender) >= amount, "WETH: Insufficient WETH balance");
        require(address(this).balance >= amount, "WETH: Insufficient ETH in contract");
        
        // Burn WETH tokens from sender
        _burn(msg.sender, amount);
        
        // Send ETH to specified address
        (bool success, ) = to.call{value: amount}("");
        require(success, "WETH: ETH transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Check if the contract has sufficient ETH backing
     * @return true if contract balance >= total supply (proper backing)
     */
    function isProperlyBacked() external view returns (bool) {
        return address(this).balance >= totalSupply();
    }
    
    /**
     * @dev Get exchange rate (should always be 1 ETH = 1 WETH)
     * @return rate Exchange rate scaled by 1e18
     */
    function exchangeRate() external pure returns (uint256 rate) {
        return 1e18; // Always 1:1 ratio
    }
}