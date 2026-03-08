// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title DEXTimelock
 * @dev Timelock controller for DEX governance - adds security delays
 * 
 * How it protects against malicious proposals:
 * 1. Proposal passes in governance
 * 2. Must wait minimum delay (e.g., 48 hours) before execution
 * 3. During delay period:
 *    - Community can review the actual code
 *    - Users can withdraw funds if suspicious
 *    - Governance can create counter-proposals
 *    - Emergency actions can be taken
 * 
 * Real-world example:
 * - Compound uses 48-hour timelock
 * - Uniswap uses 4-day timelock 
 * - MakerDAO uses even longer delays
 */
contract DEXTimelock is TimelockController {
    
    /**
     * @dev Constructor - Create the timelock with security parameters
     * @param minDelay Minimum delay in seconds (e.g., 48 hours = 172800 seconds)
     * @param proposers Addresses that can queue proposals (should be the Governor)
     * @param executors Addresses that can execute after delay (usually anyone = address(0))
     * @param admin Optional admin address (use address(0) for no admin)
     * 
     * Learning Note:
     * - minDelay: How long users have to react to proposals
     * - proposers: Only the Governor contract should queue proposals
     * - executors: Anyone can execute (decentralized) OR restrict to specific addresses
     * - admin: Emergency admin powers (dangerous, usually set to address(0))
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {
        // All logic is handled by OpenZeppelin's TimelockController
        // This ensures battle-tested security
    }
    
    // Note: TimelockController already provides all the functions we need:
    // - getMinDelay() - returns the minimum delay
    // - isOperationReady(bytes32 id) - checks if ready to execute  
    // - isOperationPending(bytes32 id) - checks if in delay period
    // - getTimestamp(bytes32 id) - returns execution timestamp
    //
    // We don't need to override these since the parent contract already implements them perfectly!
}