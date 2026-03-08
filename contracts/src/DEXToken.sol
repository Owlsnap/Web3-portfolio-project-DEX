// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DEXToken
 * @dev Governance token for the DEX protocol, similar to UNI token
 * 
 * Key Features:
 * - ERC20 standard token with voting capabilities
 * - Delegation support (delegate voting power to others)
 * - Historical voting power tracking (required for governance)
 * - Permit functionality (gasless approvals)
 * 
 * Learning Notes:
 * - ERC20Votes: Adds voting power and delegation features
 * - ERC20Permit: Allows gasless token approvals using signatures
 * - Checkpoints: Track voting power changes over time for fair governance
 */
contract DEXToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    
    // Total supply: 1 billion tokens (similar to UNI's 1B supply)
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 1e18;
    
    // Events for governance actions
    event TokensDistributed(address indexed recipient, uint256 amount, string reason);
    event DelegationChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    
    /**
     * @dev Constructor - Deploy the governance token
     * @param initialOwner Address that will own the contract initially
     */
    constructor(address initialOwner) 
        ERC20("DEX Token", "DEX") 
        ERC20Permit("DEX Token")
        Ownable(initialOwner)
    {
        // Mint total supply to the contract owner initially
        // In practice, this would be distributed through various mechanisms
        _mint(initialOwner, TOTAL_SUPPLY);
        
        emit TokensDistributed(initialOwner, TOTAL_SUPPLY, "Initial mint to contract owner");
    }
    
    /**
     * @dev Distribute tokens to specific addresses (only owner can call)
     * Used for initial distribution, airdrops, liquidity mining rewards, etc.
     * @param recipients Array of addresses to receive tokens
     * @param amounts Array of amounts for each recipient
     * @param reason Description of why tokens are being distributed
     */
    function distributeTokens(
        address[] calldata recipients, 
        uint256[] calldata amounts,
        string calldata reason
    ) external onlyOwner {
        require(recipients.length == amounts.length, "DEXToken: Arrays length mismatch");
        require(recipients.length > 0, "DEXToken: No recipients provided");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "DEXToken: Cannot send to zero address");
            require(amounts[i] > 0, "DEXToken: Amount must be greater than 0");
            
            _transfer(owner(), recipients[i], amounts[i]);
            emit TokensDistributed(recipients[i], amounts[i], reason);
        }
    }
    
    /**
     * @dev Delegate voting power to another address
     * This is a wrapper around the internal _delegate function for better UX
     * @param delegatee Address to delegate voting power to
     */
    function delegateVotingPower(address delegatee) external {
        _delegate(_msgSender(), delegatee);
    }
    
    /**
     * @dev Get current voting power of an address
     * @param account Address to check voting power for
     * @return Current voting power (includes delegated power)
     */
    function getVotingPower(address account) external view returns (uint256) {
        return getVotes(account);
    }
    
    /**
     * @dev Get historical voting power at a specific block
     * This is crucial for governance - prevents people from buying tokens just to vote
     * @param account Address to check
     * @param blockNumber Block number to check at
     * @return Voting power at that specific block
     */
    function getHistoricalVotingPower(address account, uint256 blockNumber) external view returns (uint256) {
        return getPastVotes(account, blockNumber);
    }
    
    // Required override for ERC20Votes - this is the modern OpenZeppelin way
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    // Required override for nonces() conflict between ERC20Permit and ERC20Votes
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
    
    /**
     * @dev Required override - returns the current block timestamp
     * Used by ERC20Votes for checkpoint timing
     */
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }
    
    /**
     * @dev Required override - specifies the clock mode
     * We use timestamp instead of block number for better cross-chain compatibility
     */
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }
    
    /**
     * @dev View function to get token information
     * Useful for frontends and tools
     */
    function getTokenInfo() external view returns (
        string memory, //token name
        string memory, //token symbol
        uint8, //token decimals
        uint256, //total supply
        uint256, //current block
        uint256 //current timestamp
    ) {
        return (
            name(),
            symbol(),
            decimals(),
            totalSupply(),
            block.number,
            block.timestamp
        );
    }
}