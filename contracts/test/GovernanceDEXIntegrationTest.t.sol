// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/DEXToken.sol";
import "../src/DEXGovernor.sol";
import "../src/DEXTimelock.sol";
import "../src/Factory.sol";
import "../src/FlashLoanExample.sol";
import "../src/MockERC20.sol";

/**
 * @title GovernanceDEXIntegrationTest
 * @dev Tests integration between governance system and DEX protocol
 * 
 * Test Coverage:
 * 1. Governance controlling Factory parameters
 * 2. Governance changing trading fees
 * 3. Governance changing flash loan fees
 * 4. Governance setting fee recipient
 * 5. Full proposal workflow for DEX parameter changes
 */
contract GovernanceDEXIntegrationTest is Test {
    // Governance contracts
    DEXToken public dexToken;
    DEXGovernor public governor;
    DEXTimelock public timelock;
    
    // DEX contracts
    Factory public factory;
    FlashLoanExample public flashLoan;
    
    // Test tokens
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    
    // Test accounts
    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public proposer = makeAddr("proposer");
    address public treasury = makeAddr("treasury");
    
    // Governance parameters
    uint48 public constant VOTING_DELAY = 1 days;
    uint32 public constant VOTING_PERIOD = 1 weeks;
    uint256 public constant PROPOSAL_THRESHOLD = 10_000_000e18; // 10M DEX tokens
    uint48 public constant TIMELOCK_DELAY = 2 days;
    
    // Token amounts
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 1e18; // 1B DEX tokens
    uint256 public constant PROPOSER_AMOUNT = 50_000_000e18; // 50M DEX (above 4% quorum)
    uint256 public constant VOTER_AMOUNT = 50_000e18; // 50k DEX each
    
    function setUp() public {
        console.log("=== Setting up Governance + DEX Integration Test ===");
        
        // 1. Deploy governance system
        _deployGovernance();
        
        // 2. Deploy DEX system (owned by timelock)
        _deployDEX();
        
        // 3. Deploy test tokens
        _deployTestTokens();
        
        // 4. Distribute DEX tokens for governance
        _distributeTokens();
        
        console.log("=== Integration Setup Complete ===\n");
    }
    
    function _deployGovernance() internal {
        // Deploy governance token
        dexToken = new DEXToken(owner);
        
        // Deploy timelock
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(0); // Will be set to governor
        executors[0] = address(0); // Anyone can execute after delay
        
        timelock = new DEXTimelock(TIMELOCK_DELAY, proposers, executors, owner);
        
        // Deploy governor
        governor = new DEXGovernor(dexToken, timelock, VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD);
        
        // Grant governor proposer role on timelock
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        timelock.grantRole(proposerRole, address(governor));
        
        console.log("Governance system deployed");
    }
    
    function _deployDEX() internal {
        // Deploy factory with timelock as owner (governance controlled)
        factory = new Factory(address(timelock));
        
        // Deploy flash loan contract
        flashLoan = new FlashLoanExample(address(factory));
        
        console.log("DEX system deployed with governance control");
        console.log("Factory owner:", factory.owner());
        console.log("Timelock address:", address(timelock));
    }
    
    function _deployTestTokens() internal {
        tokenA = new MockERC20("Token A", "TKA", 18, 1_000_000e18);
        tokenB = new MockERC20("Token B", "TKB", 18, 1_000_000e18);
        
        console.log("Test tokens deployed");
    }
    
    function _distributeTokens() internal {
        // Give proposer enough tokens to create proposals
        dexToken.transfer(proposer, PROPOSER_AMOUNT);
        
        // Give voters some tokens
        dexToken.transfer(alice, VOTER_AMOUNT);
        dexToken.transfer(bob, VOTER_AMOUNT);
        
        // Delegate voting power
        vm.prank(proposer);
        dexToken.delegate(proposer);
        
        vm.prank(alice);
        dexToken.delegate(alice);
        
        vm.prank(bob);
        dexToken.delegate(bob);
        
        // CRITICAL: Advance block AND time for ERC20Votes checkpoints
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
        
        console.log("DEX tokens distributed and voting power delegated");
    }
    
    // ========== BASIC INTEGRATION TESTS ==========
    
    function testFactoryOwnership() public { //restrict to view before deployment
        console.log("\n=== Testing Factory Ownership ===");
        
        // Factory should be owned by timelock
        assertEq(factory.owner(), address(timelock));
        
        // Check initial fee settings
        (address feeTo, uint256 tradingFee, uint256 flashLoanFee) = factory.getFeeInfo();
        assertEq(feeTo, address(0)); // No fee recipient initially
        assertEq(tradingFee, 30); // 0.3% default
        assertEq(flashLoanFee, 9); // 0.09% default
        
        console.log("Factory owned by timelock:");
        console.log("- Trading fee:", tradingFee, "basis points (0.3%)");
        console.log("- Flash loan fee:", flashLoanFee, "basis points (0.09%)");
        console.log("- Fee recipient:", feeTo == address(0) ? "None" : "Set");
    }
    
    function testDirectCallsFail() public {
        console.log("\n=== Testing Direct Calls Fail (Must Use Governance) ===");
        
        // Direct calls to factory admin functions should fail
        vm.expectRevert();
        factory.setTradingFee(25); // Should fail - not owner
        
        vm.expectRevert();
        factory.setFlashLoanFee(5); // Should fail - not owner
        
        vm.expectRevert();
        factory.setFeeTo(treasury); // Should fail - not owner
        
        console.log("Direct calls to factory properly blocked");
    }
    
    // ========== GOVERNANCE PROPOSAL TESTS ==========
    
    function testGovernanceChangeTradingFee() public {
        console.log("\n=== Testing Governance Change Trading Fee ===");
        
        // Create proposal to change trading fee from 30 to 25 basis points (0.3% to 0.25%)
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(factory);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setTradingFee(uint256)", 25);
        
        // Create proposal
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
        
        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Reduce trading fee to 0.25%");
        
        console.log("Proposal created to reduce trading fee");
        
        // Fast forward to voting period
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        // Vote with proposer (enough for quorum)
        vm.prank(proposer);
        governor.castVote(proposalId, 1); // Vote FOR
        
        console.log("Voted FOR the proposal");
        
        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        // Should succeed (quorum met)
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));
        
        // Queue the proposal
        governor.queue(targets, values, calldatas, keccak256(bytes("Reduce trading fee to 0.25%")));
        
        // Should be queued
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));
        
        console.log("Proposal queued in timelock");
        
        // Fast forward past timelock delay
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        
        // Execute the proposal
        governor.execute(targets, values, calldatas, keccak256(bytes("Reduce trading fee to 0.25%")));
        
        // Should be executed
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
        
        // Check that trading fee was changed
        (, uint256 newTradingFee, ) = factory.getFeeInfo();
        assertEq(newTradingFee, 25);
        
        console.log("Governance successfully changed trading fee to", newTradingFee, "basis points");
    }
    
    function testGovernanceSetTreasury() public {
        console.log("\n=== Testing Governance Set Treasury ===");
        
        // Create proposal to set treasury as fee recipient  
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(factory);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setFeeTo(address)", treasury);

        _executeGovernanceProposal(
            targets,
            values,
            calldatas,
            "Set treasury as fee recipient"
        );
        
        // Check that fee recipient was changed
        (address newFeeTo, , ) = factory.getFeeInfo();
        assertEq(newFeeTo, treasury);
        
        console.log("Governance successfully set treasury as fee recipient");
    }
    
    function testGovernanceChangeFlashLoanFee() public {
        console.log("\n=== Testing Governance Change Flash Loan Fee ===");
        
        // Create proposal to change flash loan fee from 9 to 15 basis points
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(factory);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setFlashLoanFee(uint256)", 15);
        
        _executeGovernanceProposal(
            targets, 
            values, 
            calldatas, 
            "Increase flash loan fee to 0.15%"
        );
        
        // Check that flash loan fee was changed
        (, , uint256 newFlashLoanFee) = factory.getFeeInfo();
        assertEq(newFlashLoanFee, 15);
        
        console.log("Governance successfully changed flash loan fee to", newFlashLoanFee, "basis points");
    }
    
    function testMultiActionProposal() public {
        console.log("\n=== Testing Multi-Action Governance Proposal ===");
        
        // Create proposal that changes multiple parameters at once
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory calldatas = new bytes[](3);
        
        // Action 1: Set trading fee to 20 basis points
        targets[0] = address(factory);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setTradingFee(uint256)", 20);
        
        // Action 2: Set flash loan fee to 10 basis points  
        targets[1] = address(factory);
        values[1] = 0;
        calldatas[1] = abi.encodeWithSignature("setFlashLoanFee(uint256)", 10);
        
        // Action 3: Set treasury as fee recipient
        targets[2] = address(factory);
        values[2] = 0;
        calldatas[2] = abi.encodeWithSignature("setFeeTo(address)", treasury);
        
        _executeGovernanceProposal(
            targets, 
            values, 
            calldatas, 
            "Update all DEX parameters: reduce fees and set treasury"
        );
        
        // Check all changes were applied
        (address feeTo, uint256 tradingFee, uint256 flashLoanFee) = factory.getFeeInfo();
        assertEq(feeTo, treasury);
        assertEq(tradingFee, 20);
        assertEq(flashLoanFee, 10);
        
        console.log("Multi-action proposal executed successfully:");
        console.log("- Trading fee:", tradingFee, "basis points");
        console.log("- Flash loan fee:", flashLoanFee, "basis points");
        console.log("- Fee recipient: Treasury set");
    }
    
    function testInvalidFeeProposalFails() public {
        console.log("\n=== Testing Invalid Fee Proposal Fails ===");
        
        // Try to set trading fee too high (over 100 basis points = 1%)
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(factory);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setTradingFee(uint256)", 150); // 1.5% - too high
        
        // Create and execute proposal
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
        
        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Try to set invalid high fee");
        
        // Fast forward and vote
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.prank(proposer);
        governor.castVote(proposalId, 1);
        
        // Fast forward and queue
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        governor.queue(targets, values, calldatas, keccak256(bytes("Try to set invalid high fee")));
        
        // Fast forward past timelock
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        
        // Execution should fail due to invalid fee range
        vm.expectRevert();
        governor.execute(targets, values, calldatas, keccak256(bytes("Try to set invalid high fee")));
        
        console.log("Invalid fee proposal correctly failed during execution");
    }
    
    // ========== HELPER FUNCTIONS ==========
    
    function _executeGovernanceProposal(
        address[] memory targets,
        uint256[] memory values, 
        bytes[] memory calldatas,
        string memory description
    ) internal returns (uint256 proposalId) {
        // Create proposal
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
        
        vm.prank(proposer);
        proposalId = governor.propose(targets, values, calldatas, description);
        
        // Fast forward to voting period
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        // Vote
        vm.prank(proposer);
        governor.castVote(proposalId, 1);
        
        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        // Queue
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        
        // Fast forward past timelock delay
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        
        // Execute
        governor.execute(targets, values, calldatas, descriptionHash);
        
        // Verify execution
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
        
        return proposalId;
    }
}