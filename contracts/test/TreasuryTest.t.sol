// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Treasury.sol";
import "../src/DEXToken.sol";
import "../src/DEXGovernor.sol";
import "../src/DEXTimelock.sol";
import "../src/Factory.sol";
import "../src/MockERC20.sol";

contract TreasuryTest is Test {
    // Contracts
    Treasury public treasury;
    DEXToken public dexToken;
    DEXGovernor public governor;
    DEXTimelock public timelock;
    Factory public factory;
    MockERC20 public testToken;
    MockERC20 public anotherToken;

    // Test accounts
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public deployer = makeAddr("deployer");
    address public emergencyRecipient = makeAddr("emergency");

    // Constants
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000e18; // 1B tokens
    uint256 public constant PROPOSAL_THRESHOLD = 10_000_000e18; // 1% of total supply
    uint256 public constant VOTING_DELAY = 1 days;
    uint256 public constant VOTING_PERIOD = 1 weeks;
    uint256 public constant TIMELOCK_DELAY = 2 days;

    event FundsDeposited(address indexed token, uint256 amount, address indexed from);
    event FundsWithdrawn(address indexed token, uint256 amount, address indexed to, string purpose);
    event DistributionExecuted(address indexed token, address[] recipients, uint256[] amounts, string purpose);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event FeesCollectedToTreasury(address indexed token, uint256 amount);

    function setUp() public {
        vm.startPrank(deployer);

        // Deploy governance tokens
        dexToken = new DEXToken(deployer);

        // Deploy timelock (with deployer as initial admin)
        address[] memory proposers = new address[](0); // Governor will be added later
        address[] memory executors = new address[](0); // Anyone can execute
        timelock = new DEXTimelock(TIMELOCK_DELAY, proposers, executors, deployer);

        // Deploy governor
        governor = new DEXGovernor(
            dexToken, 
            timelock,
            uint48(VOTING_DELAY),
            uint32(VOTING_PERIOD), 
            PROPOSAL_THRESHOLD
        );

        // Setup governance permissions
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0)); // Anyone can execute
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // Deploy treasury with timelock as owner
        treasury = new Treasury(address(timelock), "DEX Protocol Treasury for development and operations");

        // Deploy factory with timelock as owner
        factory = new Factory(address(timelock));

        // Deploy test tokens
        testToken = new MockERC20("Test Token", "TEST", 18, INITIAL_SUPPLY);
        anotherToken = new MockERC20("Another Token", "ANOTHER", 18, INITIAL_SUPPLY);

        // Give test accounts ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);

        // Mint test tokens for testing
        testToken.mint(alice, 1000e18);
        testToken.mint(bob, 1000e18);
        anotherToken.mint(alice, 500e18);

        // Setup DEX token delegation for governance
        // Alice needs enough tokens to both propose AND meet quorum (>4% of 1B = >40M tokens)
        dexToken.transfer(alice, 50_000_000e18); // Give Alice 50M tokens (above 4% quorum)
        dexToken.transfer(bob, 10_000_000e18); // Give Bob 10M tokens for additional votes

        vm.stopPrank();

        // Users delegate to themselves for voting power
        vm.prank(alice);
        dexToken.delegate(alice);

        vm.prank(bob);
        dexToken.delegate(bob);

        // Critical: Wait for delegations to be recorded in checkpoints
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }

    // ============ BASIC TREASURY TESTS ============

    function testTreasuryDeployment() public { //restrict to view before deployment
        assertEq(treasury.owner(), address(timelock));
        assertEq(treasury.treasuryPurpose(), "DEX Protocol Treasury for development and operations");
        assertEq(treasury.totalDistributed(), 0);
        assertEq(treasury.totalWithdrawn(), 0);
    }

    function testETHDeposit() public {
        uint256 depositAmount = 5 ether;
        
        vm.expectEmit(true, true, false, true);
        emit FundsDeposited(address(0), depositAmount, alice);
        
        vm.prank(alice);
        (bool success, ) = payable(address(treasury)).call{value: depositAmount}("");
        assertTrue(success);

        assertEq(treasury.getBalance(address(0)), depositAmount);
        assertEq(treasury.getTrackedBalance(address(0)), depositAmount);
        
        address[] memory supportedTokens = treasury.getSupportedTokens();
        assertEq(supportedTokens.length, 1);
        assertEq(supportedTokens[0], address(0));
    }

    function testTokenDeposit() public {
        uint256 depositAmount = 100e18;
        
        vm.startPrank(alice);
        testToken.approve(address(treasury), depositAmount);
        
        vm.expectEmit(true, true, false, true);
        emit FundsDeposited(address(testToken), depositAmount, alice);
        
        treasury.depositToken(address(testToken), depositAmount);
        vm.stopPrank();

        assertEq(treasury.getBalance(address(testToken)), depositAmount);
        assertEq(treasury.getTrackedBalance(address(testToken)), depositAmount);
        assertTrue(treasury.isSupportedToken(address(testToken)));
    }

    function testMultipleTokenDeposits() public {
        uint256 testAmount = 100e18;
        uint256 anotherAmount = 50e18;
        uint256 ethAmount = 2 ether;

        // Deposit TEST token
        vm.startPrank(alice);
        testToken.approve(address(treasury), testAmount);
        treasury.depositToken(address(testToken), testAmount);

        // Deposit ANOTHER token  
        anotherToken.approve(address(treasury), anotherAmount);
        treasury.depositToken(address(anotherToken), anotherAmount);

        // Deposit ETH
        (bool success, ) = payable(address(treasury)).call{value: ethAmount}("");
        assertTrue(success);
        vm.stopPrank();

        // Verify balances
        assertEq(treasury.getBalance(address(testToken)), testAmount);
        assertEq(treasury.getBalance(address(anotherToken)), anotherAmount);
        assertEq(treasury.getBalance(address(0)), ethAmount);

        // Verify supported tokens
        address[] memory supportedTokens = treasury.getSupportedTokens();
        assertEq(supportedTokens.length, 3);
    }

    // ============ GOVERNANCE CONTROLLED TREASURY OPERATIONS ============

    function testGovernanceWithdrawal() public {
        // Setup: Deposit tokens to treasury
        uint256 depositAmount = 100e18;
        vm.startPrank(alice);
        testToken.approve(address(treasury), depositAmount);
        treasury.depositToken(address(testToken), depositAmount);
        vm.stopPrank();

        // Create governance proposal for withdrawal
        uint256 withdrawAmount = 30e18;
        string memory purpose = "Development grant for Alice";
        
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawFunds(address,uint256,address,string)",
            address(testToken),
            withdrawAmount,
            alice,
            purpose
        );

        _createAndExecuteProposal(
            targets,
            values,
            calldatas,
            "Treasury Withdrawal: Development Grant"
        );

        // Verify withdrawal
        assertEq(treasury.getBalance(address(testToken)), depositAmount - withdrawAmount);
        assertEq(testToken.balanceOf(alice), 1000e18 - depositAmount + withdrawAmount); // Original + withdrawn - deposited
        assertGt(treasury.totalWithdrawn(), 0);
    }

    function testGovernanceDistribution() public {
        // Setup: Deposit tokens to treasury
        uint256 depositAmount = 300e18;
        vm.startPrank(alice);
        testToken.approve(address(treasury), depositAmount);
        treasury.depositToken(address(testToken), depositAmount);
        vm.stopPrank();

        // Prepare distribution
        address[] memory recipients = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = carol;
        amounts[0] = 100e18;
        amounts[1] = 80e18;
        amounts[2] = 50e18;

        // Create governance proposal for distribution
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "distributeFunds(address,address[],uint256[],string)",
            address(testToken),
            recipients,
            amounts,
            "Q4 Developer Rewards"
        );

        _createAndExecuteProposal(
            targets,
            values,
            calldatas,
            "Treasury Distribution: Q4 Rewards"
        );

        // Verify distribution
        uint256 totalDistributed = amounts[0] + amounts[1] + amounts[2];
        assertEq(treasury.getBalance(address(testToken)), depositAmount - totalDistributed);
        assertEq(testToken.balanceOf(alice), 1000e18 - depositAmount + amounts[0]);
        assertEq(testToken.balanceOf(bob), 1000e18 + amounts[1]);
        assertEq(testToken.balanceOf(carol), amounts[2]);
        assertEq(treasury.totalDistributed(), totalDistributed);
    }

    function testGovernanceETHDistribution() public {
        // Setup: Deposit ETH to treasury
        uint256 depositAmount = 10 ether;
        vm.prank(alice);
        (bool success, ) = payable(address(treasury)).call{value: depositAmount}("");
        assertTrue(success);

        // Record initial balances
        uint256 bobInitialBalance = bob.balance;
        uint256 carolInitialBalance = carol.balance;

        // Prepare ETH distribution
        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        recipients[0] = bob;
        recipients[1] = carol;
        amounts[0] = 3 ether;
        amounts[1] = 2 ether;

        // Create governance proposal for ETH distribution
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "distributeFunds(address,address[],uint256[],string)",
            address(0), // ETH
            recipients,
            amounts,
            "ETH Rewards Distribution"
        );

        _createAndExecuteProposal(
            targets,
            values,
            calldatas,
            "Treasury ETH Distribution"
        );

        // Verify ETH distribution
        assertEq(bob.balance, bobInitialBalance + amounts[0]);
        assertEq(carol.balance, carolInitialBalance + amounts[1]);
        assertEq(treasury.getBalance(address(0)), depositAmount - amounts[0] - amounts[1]);
    }

    // ============ FACTORY TREASURY INTEGRATION ============

    function testFactoryTreasuryIntegration() public {
        // Setup treasury in factory via governance
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(factory);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setTreasury(address)", address(treasury));

        _createAndExecuteProposal(
            targets,
            values,
            calldatas,
            "Set Treasury in Factory"
        );

        // Verify treasury is set
        (address treasuryAddress, bool isSet) = factory.getTreasuryInfo();
        assertEq(treasuryAddress, address(treasury));
        assertTrue(isSet);
    }

    function testFactoryFeeCollection() public {
        // First set up treasury in factory
        testFactoryTreasuryIntegration();

        // Simulate fee collection by minting tokens to a mock pair address
        address mockPair = makeAddr("mockPair");
        vm.prank(deployer);
        testToken.mint(mockPair, 50e18);

        // Approve factory to spend tokens from the pair (simulate pair allowing factory to collect)
        vm.prank(mockPair);  
        testToken.approve(address(factory), 50e18);

        // Collect fees to treasury
        vm.expectEmit(true, true, false, true);
        emit FeesCollectedToTreasury(address(testToken), 50e18);
        
        factory.collectFeesToTreasury(mockPair, address(testToken));

        // Verify fees were collected to treasury
        assertEq(treasury.getBalance(address(testToken)), 50e18);
        assertTrue(treasury.isSupportedToken(address(testToken)));
    }

    function testFactoryETHFeeCollection() public {
        // First set up treasury in factory
        testFactoryTreasuryIntegration();

        // Collect ETH fees to treasury
        uint256 ethAmount = 1 ether;
        
        vm.expectEmit(true, true, false, true);
        emit FeesCollectedToTreasury(address(0), ethAmount);
        
        vm.prank(alice);
        factory.collectETHFeesToTreasury{value: ethAmount}();

        // Verify ETH was collected to treasury
        assertEq(treasury.getBalance(address(0)), ethAmount);
        assertTrue(treasury.isSupportedToken(address(0)));
    }

    // ============ TREASURY PURPOSE AND STATS ============

    function testTreasuryPurposeUpdate() public {
        string memory newPurpose = "Updated DEX Treasury for community governance";
        
        // Create governance proposal to update purpose
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("updateTreasuryPurpose(string)", newPurpose);

        _createAndExecuteProposal(
            targets,
            values,
            calldatas,
            "Update Treasury Purpose"
        );

        assertEq(treasury.treasuryPurpose(), newPurpose);
    }

    function testTreasuryStats() public {
        // Add some deposits and perform operations to generate stats
        uint256 depositAmount = 100e18;
        vm.startPrank(alice);
        testToken.approve(address(treasury), depositAmount);
        treasury.depositToken(address(testToken), depositAmount);
        vm.stopPrank();

        // Get initial stats
        (uint256 supportedTokens, uint256 distributed, uint256 withdrawn, string memory purpose) = treasury.getTreasuryStats();
        
        assertEq(supportedTokens, 1);
        assertEq(distributed, 0);
        assertEq(withdrawn, 0);
        assertEq(purpose, "DEX Protocol Treasury for development and operations");
    }

    // ============ ERROR CASES ============

    function testUnauthorizedWithdrawal() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        
        vm.prank(alice);
        treasury.withdrawFunds(address(testToken), 100e18, payable(alice), "Unauthorized");
    }

    function testInvalidTokenDeposit() public {
        vm.expectRevert("Treasury: Invalid token address");
        
        vm.prank(alice);
        treasury.depositToken(address(0), 100e18);
    }

    function testWithdrawInsufficientBalance() public {
        // Try to withdraw more than available through governance
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawFunds(address,uint256,address,string)",
            address(testToken),
            1000e18, // More than available
            alice,
            "Test withdrawal"
        );

        // Create proposal but it will fail during execution
        uint256 proposalId = _createProposal(targets, values, calldatas, "Failed Withdrawal Test");
        _voteAndQueue(proposalId, targets, values, calldatas, "Failed Withdrawal Test");
        
        // Skip timelock delay
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        
        // This execution should fail
        vm.expectRevert("Treasury: Insufficient balance");
        governor.execute(targets, values, calldatas, keccak256(bytes("Failed Withdrawal Test")));
    }

    // ============ HELPER FUNCTIONS ============

    function _createAndExecuteProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal returns (uint256 proposalId) {
        proposalId = _createProposal(targets, values, calldatas, description);
        _voteAndQueue(proposalId, targets, values, calldatas, description);
        _executeProposal(targets, values, calldatas, description);
        return proposalId;
    }

    function _createProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal returns (uint256 proposalId) {
        // Ensure we're in a new block for proposal creation (required for ERC20Votes snapshots)
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
        
        vm.prank(alice);
        proposalId = governor.propose(targets, values, calldatas, description);
        return proposalId;
    }

    function _voteAndQueue(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal {
        // Wait for voting delay
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        
        // Vote (Alice votes FOR, Bob votes FOR to reach quorum)
        vm.prank(alice);
        governor.castVote(proposalId, 1); // Vote FOR
        
        vm.prank(bob);
        governor.castVote(proposalId, 1); // Vote FOR
        
        // Wait for voting period to end
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        // Queue the proposal
        vm.prank(alice);
        governor.queue(targets, values, calldatas, keccak256(bytes(description)));
    }

    function _executeProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal {
        // Wait for timelock delay
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        
        // Execute the proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.execute(targets, values, calldatas, descriptionHash);
    }
}