// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorStorage.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "./DEXToken.sol";
import "./DEXTimelock.sol";

/**
 * @title DEXGovernor
 * @dev Main governance contract for the DEX protocol
 * 
 * This contract handles:
 * - Creating proposals (change fees, set the protocol fee recipient, manage the treasury, etc.)
 * - Voting on proposals using DEX tokens
 * - Queueing passed proposals in the timelock and executing them after the delay
 *
 * GovernorStorage keeps every proposal's details on-chain, so a frontend can list proposals
 * (proposalCount / proposalDetailsAt) and queue/execute them by ID without indexing events.
 */
contract DEXGovernor is 
    Governor,
    GovernorSettings, 
    GovernorCountingSimple,
    GovernorStorage,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    // The DEX token used for voting
    DEXToken public immutable dexToken;
    
    // The timelock controller for security delays (renamed to avoid conflicts)
    DEXTimelock public immutable dexTimelock;

    // Human-readable description of each proposal, for display in the frontend
    mapping(uint256 => string) public proposalDescriptions;
    
    /**
     * @dev Constructor - Set up the governance contract with timelock
     * @param _dexToken The DEX token contract (for voting power)
     * @param _timelock The timelock controller (for execution delays)
     * @param _votingDelay How long after proposal creation before voting starts (in seconds)
     * @param _votingPeriod How long voting lasts (in seconds)  
     * @param _proposalThreshold Minimum tokens needed to create a proposal
     * @param _quorumNumerator Quorum as a fraction of total supply, out of quorumDenominator()
     *        (100_000), e.g. 4_000 = 4%, 1 = 0.001%
     */
    constructor(
        DEXToken _dexToken,
        DEXTimelock _timelock,
        uint48 _votingDelay,    // e.g., 1 day = 86400 seconds
        uint32 _votingPeriod,   // e.g., 1 week = 604800 seconds
        uint256 _proposalThreshold, // e.g., 100,000 DEX tokens
        uint256 _quorumNumerator    // e.g., 4_000 = 4%
    )
        Governor("DEX Governor")
        GovernorSettings(_votingDelay, _votingPeriod, _proposalThreshold)
        GovernorVotes(IVotes(address(_dexToken)))
        GovernorVotesQuorumFraction(_quorumNumerator)
        GovernorTimelockControl(TimelockController(payable(address(_timelock))))
    {
        dexToken = _dexToken;
        dexTimelock = _timelock;
    }

    /**
     * @dev Required override - returns the voting delay from GovernorSettings
     * This is how long after proposal creation before voting starts
     */
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    /**
     * @dev Required override - returns the voting period from GovernorSettings  
     * This is how long voting lasts
     */
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    /**
     * @dev Required override - returns the proposal threshold from GovernorSettings
     * This is minimum tokens needed to create a proposal
     */
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    /**
     * @dev Quorum precision: numerators are out of 100,000, so quorum can go as low as 0.001%
     * of total supply. Governance can change the numerator via updateQuorumNumerator().
     */
    function quorumDenominator() public pure override returns (uint256) {
        return 100_000;
    }

    /**
     * @dev Minimum number of votes (For + Abstain) needed for a proposal to pass,
     * measured against the token's total supply at the proposal's snapshot
     */
    function quorum(uint256 timepoint)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(timepoint);
    }

    // ========== MAIN GOVERNANCE FUNCTIONS ==========

    // Note: OpenZeppelin Governor already provides all the functions we need:
    // - propose() - creates proposals (with automatic threshold checking)
    // - castVote() - votes on proposals
    // - castVoteWithReason() - votes with explanation
    // - queue(proposalId) / execute(proposalId) - via GovernorStorage, no need to resend calldata
    //
    // Example usage:
    // To change trading fee: propose([factoryAddress], [0], [abi.encodeWithSignature("setTradingFee(uint256)", 25)], "Reduce fees")
    // To vote: castVote(proposalId, 1) where 1 = For, 0 = Against, 2 = Abstain

    /**
     * @dev Store the proposal (GovernorStorage) and its description for the frontend
     */
    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal override(Governor, GovernorStorage) returns (uint256 proposalId) {
        proposalId = super._propose(targets, values, calldatas, description, proposer);
        proposalDescriptions[proposalId] = description;
    }

    /**
     * @dev Required override for timelock integration
     * Determines when proposals are queued for execution
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev Required override for timelock integration
     * Handles the actual execution through timelock
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    // Required overrides for timelock integration (these are necessary)
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function proposalNeedsQueuing(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }
}