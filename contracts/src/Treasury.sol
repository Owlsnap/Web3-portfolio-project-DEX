// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Treasury
 * @dev Treasury contract for managing DEX protocol funds
 * Features:
 * - Collects trading fees from Factory
 * - Manages multiple token balances
 * - Governance-controlled withdrawals and distributions
 * - Support for staking rewards, grants, and operational expenses
 * - Emergency functions for fund recovery
 */
contract Treasury is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Events
    event FundsDeposited(address indexed token, uint256 amount, address indexed from);
    event FundsWithdrawn(address indexed token, uint256 amount, address indexed to, string purpose);
    event DistributionExecuted(address indexed token, address[] recipients, uint256[] amounts, string purpose);
    event EmergencyWithdraw(address indexed token, uint256 amount, address indexed to);
    event TreasuryPurposeUpdated(string oldPurpose, string newPurpose);

    // State variables
    mapping(address => uint256) public tokenBalances;
    address[] public supportedTokens;
    mapping(address => bool) public isSupportedToken;
    
    string public treasuryPurpose;
    uint256 public totalDistributed;
    uint256 public totalWithdrawn;
    
    // Constants
    uint256 public constant MAX_RECIPIENTS = 100; // Prevent gas limit issues
    
    modifier validToken(address token) {
        require(token != address(0), "Treasury: Invalid token address");
        _;
    }
    
    modifier validRecipients(address[] memory recipients, uint256[] memory amounts) {
        require(recipients.length == amounts.length, "Treasury: Arrays length mismatch");
        require(recipients.length <= MAX_RECIPIENTS, "Treasury: Too many recipients");
        require(recipients.length > 0, "Treasury: No recipients");
        _;
    }

    constructor(address initialOwner, string memory _purpose) Ownable(initialOwner) {
        treasuryPurpose = _purpose;
    }

    /**
     * @dev Receive ETH deposits
     */
    receive() external payable {
        _addTokenToSupported(address(0)); // ETH represented as address(0)
        tokenBalances[address(0)] += msg.value;
        emit FundsDeposited(address(0), msg.value, msg.sender);
    }

    /**
     * @dev Deposit ERC20 tokens to treasury
     * @param token Token contract address
     * @param amount Amount to deposit
     */
    function depositToken(address token, uint256 amount) 
        external 
        validToken(token) 
        nonReentrant 
    {
        require(amount > 0, "Treasury: Amount must be greater than 0");
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        _addTokenToSupported(token);
        tokenBalances[token] += amount;
        
        emit FundsDeposited(token, amount, msg.sender);
    }

    /**
     * @dev Receive tokens directly from external contracts (like Factory fee collection)
     * @param token Token contract address
     * @param amount Amount being received
     * @param from Address sending the tokens
     * @dev This function assumes tokens are already transferred to this contract
     */
    function receiveTokenDeposit(address token, uint256 amount, address from) 
        external 
        validToken(token)
        nonReentrant 
    {
        require(amount > 0, "Treasury: Amount must be greater than 0");
        require(from != address(0), "Treasury: Invalid sender");
        
        // Verify the tokens are actually in the treasury
        uint256 currentBalance = IERC20(token).balanceOf(address(this));
        uint256 expectedBalance = tokenBalances[token] + amount;
        require(currentBalance >= expectedBalance, "Treasury: Tokens not received");
        
        _addTokenToSupported(token);
        tokenBalances[token] += amount;
        
        emit FundsDeposited(token, amount, from);
    }

    /**
     * @dev Withdraw funds for specific purpose (governance controlled)
     * @param token Token to withdraw (address(0) for ETH)
     * @param amount Amount to withdraw
     * @param to Recipient address
     * @param purpose Purpose of withdrawal
     */
    function withdrawFunds(
        address token, 
        uint256 amount, 
        address payable to, 
        string memory purpose
    ) 
        external 
        onlyOwner 
        nonReentrant 
    {
        require(to != address(0), "Treasury: Invalid recipient");
        require(amount > 0, "Treasury: Amount must be greater than 0");
        require(tokenBalances[token] >= amount, "Treasury: Insufficient balance");
        require(bytes(purpose).length > 0, "Treasury: Purpose required");

        tokenBalances[token] -= amount;
        totalWithdrawn += amount;

        if (token == address(0)) {
            to.transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit FundsWithdrawn(token, amount, to, purpose);
    }

    /**
     * @dev Distribute funds to multiple recipients (governance controlled)
     * @param token Token to distribute
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts for each recipient
     * @param purpose Purpose of distribution
     */
    function distributeFunds(
        address token,
        address[] memory recipients,
        uint256[] memory amounts,
        string memory purpose
    )
        external
        onlyOwner
        nonReentrant
        validRecipients(recipients, amounts)
    {
        require(bytes(purpose).length > 0, "Treasury: Purpose required");
        
        uint256 totalAmount = 0;
        for (uint i = 0; i < amounts.length; i++) {
            require(recipients[i] != address(0), "Treasury: Invalid recipient");
            require(amounts[i] > 0, "Treasury: Invalid amount");
            totalAmount += amounts[i];
        }
        
        require(tokenBalances[token] >= totalAmount, "Treasury: Insufficient balance");
        
        tokenBalances[token] -= totalAmount;
        totalDistributed += totalAmount;

        for (uint i = 0; i < recipients.length; i++) {
            if (token == address(0)) {
                payable(recipients[i]).transfer(amounts[i]);
            } else {
                IERC20(token).safeTransfer(recipients[i], amounts[i]);
            }
        }

        emit DistributionExecuted(token, recipients, amounts, purpose);
    }

    /**
     * @dev Emergency withdraw function (governance controlled)
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     * @param to Emergency recipient
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address payable to
    )
        external
        onlyOwner
        nonReentrant
    {
        require(to != address(0), "Treasury: Invalid recipient");
        require(amount > 0, "Treasury: Amount must be greater than 0");

        if (token == address(0)) {
            require(address(this).balance >= amount, "Treasury: Insufficient ETH balance");
            to.transfer(amount);
        } else {
            uint256 tokenBalance = IERC20(token).balanceOf(address(this));
            require(tokenBalance >= amount, "Treasury: Insufficient token balance");
            IERC20(token).safeTransfer(to, amount);
        }

        // Update tracked balance if it exists
        if (tokenBalances[token] >= amount) {
            tokenBalances[token] -= amount;
        } else {
            tokenBalances[token] = 0;
        }

        emit EmergencyWithdraw(token, amount, to);
    }

    /**
     * @dev Update treasury purpose (governance controlled)
     * @param newPurpose New purpose description
     */
    function updateTreasuryPurpose(string memory newPurpose) 
        external 
        onlyOwner 
    {
        require(bytes(newPurpose).length > 0, "Treasury: Purpose cannot be empty");
        string memory oldPurpose = treasuryPurpose;
        treasuryPurpose = newPurpose;
        emit TreasuryPurposeUpdated(oldPurpose, newPurpose);
    }

    /**
     * @dev Get treasury balance for a specific token
     * @param token Token address (address(0) for ETH)
     * @return balance Token balance
     */
    function getBalance(address token) external view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev Get tracked balance for a token
     * @param token Token address
     * @return balance Tracked balance
     */
    function getTrackedBalance(address token) external view returns (uint256) {
        return tokenBalances[token];
    }

    /**
     * @dev Get all supported tokens
     * @return tokens Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @dev Get treasury statistics
     * @return totalSupportedTokens Number of supported tokens
     * @return totalDistributedAmount Total amount distributed
     * @return totalWithdrawnAmount Total amount withdrawn
     * @return purpose Current treasury purpose
     */
    function getTreasuryStats() 
        external 
        view 
        returns (
            uint256 totalSupportedTokens,
            uint256 totalDistributedAmount,
            uint256 totalWithdrawnAmount,
            string memory purpose
        ) 
    {
        return (
            supportedTokens.length,
            totalDistributed,
            totalWithdrawn,
            treasuryPurpose
        );
    }

    /**
     * @dev Internal function to add token to supported list
     * @param token Token address to add
     */
    function _addTokenToSupported(address token) internal {
        if (!isSupportedToken[token]) {
            supportedTokens.push(token);
            isSupportedToken[token] = true;
        }
    }

    /**
     * @dev Check if contract can receive tokens
     * @param token Token address
     * @return canReceive True if token can be received
     */
    function canReceiveToken(address token) external pure returns (bool) {
        return token != address(0); // Can receive any ERC20 token and ETH
    }
}