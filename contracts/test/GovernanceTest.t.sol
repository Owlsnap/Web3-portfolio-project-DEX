// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/DEXToken.sol";
import "../src/DEXGovernor.sol";
import "../src/DEXTimelock.sol";
import "../src/MockERC20.sol";

/**
 * @title GovernanceTest
 * @dev Comprehensive tests for the DEX governance system
 * 
 * Test Coverage:
 * 1. Token deployment and basic functionality
 * 2. Voting power delegation and tracking
 * 3. Proposal creation and voting
 * 4. Timelock integration and execution
 * 5. Security scenarios and edge cases
 */
contract GovernanceTest is Test {
    // Main contracts
    DEXToken public dexToken;
    DEXGovernor public governor;
    DEXTimelock public timelock;
    
    // Test target contract (we'll use MockERC20 as a governance target)
    MockERC20 public targetContract;
    
    // Test accounts
    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public proposer = makeAddr("proposer");
    
    // Governance parameters
    uint48 public constant VOTING_DELAY = 1 days;        // 1 day
    uint32 public constant VOTING_PERIOD = 1 weeks;      // 1 week
    uint256 public constant PROPOSAL_THRESHOLD = 10_000_000e18; // 10M DEX tokens (1% of supply)
    uint48 public constant TIMELOCK_DELAY = 2 days;      // 2 days
    
    // Token amounts
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 1e18; // 1B DEX tokens (matches DEXToken contract)
    // Make proposer hold >4% of TOTAL_SUPPLY so single-proposer quorum tests pass
    // 4% of 1_000_000_000 = 40_000_000 => give proposer 50_000_000
    uint256 public constant PROPOSER_AMOUNT = 50_000_000e18; // 50M DEX (above 4% quorum)
    uint256 public constant VOTER_AMOUNT = 50_000e18;     // 50k DEX each
    
    function setUp() public {
        console.log("=== Setting up Governance Test Environment ===");
        
        // 1. Deploy DEX governance token
        dexToken = new DEXToken(owner);
        console.log("DEXToken deployed with supply:", TOTAL_SUPPLY / 1e18);
        
        // 2. Deploy timelock controller
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(0); // Will be set to governor after deployment
        executors[0] = address(0); // Anyone can execute after delay
        
        timelock = new DEXTimelock(
            TIMELOCK_DELAY,
            proposers,
            executors,
            owner // admin (temporary)
        );
        console.log("DEXTimelock deployed with delay:", TIMELOCK_DELAY / 1 days, "days");
        
        // 3. Deploy governor
        governor = new DEXGovernor(
            dexToken,
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD
        );
        console.log("DEXGovernor deployed");
        
        // 4. Grant governor proposer role on timelock
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        timelock.grantRole(proposerRole, address(governor));
        console.log("Governor granted proposer role on timelock");
        
        // 5. Deploy a target contract for governance to control
        targetContract = new MockERC20("Target Token", "TGT", 18, 0);
        console.log("Target contract deployed for governance testing");
        
        // 6. Transfer ownership of target contract to timelock
        // This allows governance to control the target contract
        targetContract.transferOwnership(address(timelock));
        console.log("Target contract ownership transferred to timelock");
        
        // 7. Distribute tokens for testing
        _distributeTokens();
        
        console.log("=== Setup Complete ===\n");
    }
    
    function _distributeTokens() internal {
        // Give proposer enough tokens to create proposals
        dexToken.transfer(proposer, PROPOSER_AMOUNT);
        
        // Give voters some tokens
        dexToken.transfer(alice, VOTER_AMOUNT);
        dexToken.transfer(bob, VOTER_AMOUNT);
        dexToken.transfer(charlie, VOTER_AMOUNT);
        
        // IMPORTANT: Delegate voting power to themselves
        // In ERC20Votes, having tokens ≠ having voting power
        // You must delegate to activate voting power
        vm.prank(proposer);
        dexToken.delegate(proposer);
        
        vm.prank(alice);
        dexToken.delegate(alice);
        
        vm.prank(bob);
        dexToken.delegate(bob);
        
        vm.prank(charlie);
        dexToken.delegate(charlie);
        
        // CRITICAL: Advance block AND time so ERC20Votes checkpoints are written
        // Without both vm.roll() and vm.warp(), getPastVotes will return 0
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        console.log("Tokens distributed and voting power delegated to test accounts");
    }
    
    // ========== TOKEN TESTS ==========
    
    function testTokenBasicFunctionality() public { //restrict to view before deployment
        console.log("\n=== Testing Token Basic Functionality ===");
        
        // Check initial balances
        assertEq(dexToken.balanceOf(proposer), PROPOSER_AMOUNT);
        assertEq(dexToken.balanceOf(alice), VOTER_AMOUNT);
        
        // Check total supply
        assertEq(dexToken.totalSupply(), TOTAL_SUPPLY);
        
        console.log("Token balances and supply correct");
    }
    
    function testVotingPowerDelegation() public { //restrict to view before deployment
        console.log("\n=== Testing Voting Power Delegation ===");
        
    // Voting power should already be delegated in setup
    assertEq(dexToken.getVotes(alice), VOTER_AMOUNT);
    assertEq(dexToken.getVotes(proposer), PROPOSER_AMOUNT);

    console.log("Voting power delegation working correctly");
    }
    
    // ========== GOVERNOR TESTS ==========
    
    function testGovernorParameters() public { //restrict to view before deployment
        console.log("\n=== Testing Governor Parameters ===");
        
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), PROPOSAL_THRESHOLD);
        
        console.log("Governor parameters set correctly");
        console.log("Proposal threshold:", PROPOSAL_THRESHOLD / 1e18, "DEX tokens (1% of supply)");
    }
    
    function testProposalCreation() public {
        console.log("\n=== Testing Proposal Creation ===");
        
        // Use helper function that properly handles snapshots
        uint256 proposalId = _createTestProposal();
        
        // Check proposal state
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
        
        console.log("Proposal created successfully with ID:", proposalId);
    }
    
    function testProposalVoting() public {
        console.log("\n=== Testing Proposal Voting ===");
        
        // Create proposal
        uint256 proposalId = _createTestProposal();
        
        // Fast forward past voting delay
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        // Check proposal is now active
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));
        
        // Vote FOR the proposal
        vm.prank(alice);
        governor.castVoteWithReason(proposalId, 1, "I support this proposal");
        
        vm.prank(bob); 
        governor.castVote(proposalId, 1); // Vote FOR
        
        console.log("Votes cast successfully");
        
        // Check voting results
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        
        assertEq(forVotes, VOTER_AMOUNT * 2); // Alice + Bob
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
        
        console.log("Vote counting correct - For:", forVotes / 1e18);
        console.log("Against:", againstVotes, "Abstain:", abstainVotes);
    }
    
    function testQuorumRequirement() public {
        console.log("\n=== Testing Quorum Requirement ===");
        
        // Create proposal
        uint256 proposalId = _createTestProposal();
        
        // Check quorum requirement (4% of total supply)
        uint256 quorumRequired = governor.quorum(block.timestamp - 1);
        uint256 expectedQuorum = (TOTAL_SUPPLY * 4) / 100;
        
        assertEq(quorumRequired, expectedQuorum);
        
        console.log("Quorum requirement:", quorumRequired / 1e18, "DEX tokens (4% of supply)");
        
        // Fast forward to voting period
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        // Vote with proposer (200k tokens) - should meet quorum
        vm.prank(proposer);
        governor.castVote(proposalId, 1);
        
        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        // Should succeed (quorum met)
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));
        
        console.log("Proposal succeeded with sufficient quorum");
    }
    
    // ========== TIMELOCK TESTS ==========
    
    function testTimelockIntegration() public {
        console.log("\n=== Testing Timelock Integration ===");
        
        // Setup and create a successful proposal
        uint256 proposalId = _createSuccessfulProposal();
        
        // After proposal succeeds, it should be queued in timelock
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));
        console.log("Proposal automatically queued in timelock after success");
        
        // Try to execute immediately (should fail - timelock delay not passed)
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(targetContract);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("mint(address,uint256)", alice, 1000e18);
        
        bytes32 descriptionHash = keccak256(bytes("Test governance proposal"));
        
        vm.expectRevert(); // Should revert due to timelock delay
        governor.execute(targets, values, calldatas, descriptionHash);
        
        console.log("Execution blocked during timelock delay");
        
        // Fast forward past timelock delay
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        
        // Now execution should work
        uint256 balanceBefore = targetContract.balanceOf(alice);
        governor.execute(targets, values, calldatas, descriptionHash);
        uint256 balanceAfter = targetContract.balanceOf(alice);
        
        assertEq(balanceAfter - balanceBefore, 1000e18);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
        
        console.log("Proposal executed successfully after timelock delay");
        console.log("Alice received 1000 tokens from governance action");
    }
    
    // ========== SECURITY TESTS ==========
    
    function testProposalThresholdEnforcement() public {
        console.log("\n=== Testing Proposal Threshold Enforcement ===");
        
        // Alice has only 50k tokens (below 10M threshold)
        // She should NOT be able to create proposals
        
        // Advance block to ensure snapshot is available
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
        
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(targetContract);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("mint(address,uint256)", alice, 1000e18);
        
        // Should fail - Alice is below proposal threshold
        vm.prank(alice);
        vm.expectRevert(); // Expect any revert (OpenZeppelin uses custom errors)
        governor.propose(targets, values, calldatas, "Alice's proposal should fail");
        
        // But proposer (with 50M tokens) should be able to create proposals
        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Proposer's valid proposal");
        assertGt(proposalId, 0);
        
        console.log("Proposal threshold (10M DEX) properly enforced");
        console.log("Alice (50k DEX): BLOCKED");
        console.log("Proposer (50M DEX): ALLOWED");
    }
    
    function testVotingPowerSnapshot() public {
        console.log("\n=== Testing Voting Power Snapshot ===");
        
        // Create proposal (voting power already delegated in setup)
        // At snapshot time: Alice has VOTER_AMOUNT, Bob has VOTER_AMOUNT
        uint256 proposalId = _createTestProposal();
        
        // Alice transfers tokens after proposal creation
        vm.prank(alice);
        dexToken.transfer(bob, VOTER_AMOUNT / 2);
        
        // Fast forward to voting period
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        // Both Alice and Bob vote FOR
        // Alice's voting power at snapshot: VOTER_AMOUNT (before transfer)
        // Bob's voting power at snapshot: VOTER_AMOUNT (he already had tokens and delegation)
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        // Check that votes counted match snapshot expectations
        // Alice: VOTER_AMOUNT (her balance at snapshot time)
        // Bob: VOTER_AMOUNT (his balance at snapshot time)
        // Total: VOTER_AMOUNT * 2
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        
        assertEq(forVotes, VOTER_AMOUNT * 2, "Both Alice and Bob should vote with their snapshot power");
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);

        console.log("Voting power uses historical snapshot correctly");
        console.log("Alice votes counted:", VOTER_AMOUNT / 1e18, "DEX (snapshot power)");
        console.log("Bob votes counted:", VOTER_AMOUNT / 1e18, "DEX (snapshot power)");
        console.log("Total votes:", forVotes / 1e18, "DEX");
        
        // The key insight: voting power is determined at proposal creation time,
        // not at voting time. Token transfers after proposal creation don't affect voting power.
    }
    
    // ========== HELPER FUNCTIONS ==========
    
    function _createTestProposal() internal returns (uint256) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(targetContract);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("mint(address,uint256)", alice, 1000e18);
        
        // Ensure we're in a new block for proposal creation (required for ERC20Votes snapshots)
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
        
        vm.prank(proposer);
        return governor.propose(targets, values, calldatas, "Test governance proposal");
    }
    
    function _createSuccessfulProposal() internal returns (uint256) {
        // Create proposal (proposer already has voting power from setup)
        uint256 proposalId = _createTestProposal();
        
        // Fast forward to voting period
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        // Vote with proposer (enough for quorum)
        vm.prank(proposer);
        governor.castVote(proposalId, 1);
        
        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        // Queue the proposal in timelock (required step after success)
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(targetContract);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("mint(address,uint256)", alice, 1000e18);
        
        bytes32 descriptionHash = keccak256(bytes("Test governance proposal"));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        return proposalId;
    }
}