// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Factory.sol";
import "../src/Router.sol";
import "../src/Pair.sol";
import "../src/WETH.sol";
import "../src/MockERC20.sol";
import "../src/FlashLoanExample.sol";
import "../src/DEXToken.sol";
import "../src/DEXGovernor.sol";
import "../src/DEXTimelock.sol";
import "../src/Treasury.sol";
import "../src/TokenFaucet.sol";

/**
 * @title GovernedFeesTest
 * @dev Checks that governance-controlled parameters actually take effect in the pools:
 * 1. Swaps keep working (and match Router quotes) at any allowed trading fee
 * 2. Flash swaps are charged the flash loan fee
 * 3. Setting feeTo turns on the protocol fee
 * 4. The full governance flow with the testnet demo settings, from faucet claim to execution
 */
contract GovernedFeesTest is Test {
    Factory public factory;
    Router public router;
    WETH public weth;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    Pair public pair;

    address public alice = makeAddr("alice");
    address public lp = makeAddr("lp");

    uint256 constant LIQUIDITY = 100_000e18;

    function setUp() public {
        factory = new Factory(address(this));
        weth = new WETH();
        router = new Router(address(factory), address(weth));
        tokenA = new MockERC20("Token A", "TKA", 18, 10_000_000e18);
        tokenB = new MockERC20("Token B", "TKB", 18, 10_000_000e18);

        tokenA.transfer(lp, 1_000_000e18);
        tokenB.transfer(lp, 1_000_000e18);
        tokenA.transfer(alice, 1_000_000e18);

        _addLiquidity(lp, LIQUIDITY);
        pair = Pair(factory.getPair(address(tokenA), address(tokenB)));
    }

    // ============ HELPERS ============

    function _addLiquidity(address provider, uint256 amount) internal {
        vm.startPrank(provider);
        tokenA.approve(address(router), amount);
        tokenB.approve(address(router), amount);
        router.addLiquidity(address(tokenA), address(tokenB), amount, amount, 0, 0, provider, block.timestamp);
        vm.stopPrank();
    }

    function _path() internal view returns (address[] memory path) {
        path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
    }

    function _swap(address trader, uint256 amountIn) internal returns (uint256 amountOut) {
        vm.startPrank(trader);
        tokenA.approve(address(router), amountIn);
        uint256[] memory amounts = router.swapExactTokensForTokens(amountIn, 0, _path(), trader, block.timestamp);
        vm.stopPrank();
        return amounts[1];
    }

    // ============ TRADING FEE ============

    /**
     * @dev Regression: Pair used to hardcode 0.3% while Router quoted the governed fee,
     * so lowering the fee made every swap revert with "Pair: K"
     */
    function testSwapWorksAfterLoweringFee() public {
        factory.setTradingFee(5); // 0.05%, the minimum
        uint256 quoted = router.getAmountsOut(1_000e18, _path())[1];
        uint256 received = _swap(alice, 1_000e18);
        assertEq(received, quoted);
    }

    function testHigherFeeGivesLessOutput() public {
        uint256 atDefault = router.getAmountsOut(1_000e18, _path())[1];
        factory.setTradingFee(100); // 1%, the maximum
        uint256 quoted = router.getAmountsOut(1_000e18, _path())[1];
        uint256 received = _swap(alice, 1_000e18);
        assertEq(received, quoted);
        assertLt(received, atDefault);
    }

    function testFuzzSwapMatchesQuoteAtAnyFee(uint256 fee, uint256 amountIn) public {
        fee = bound(fee, 5, 100);
        amountIn = bound(amountIn, 1e15, 50_000e18);
        factory.setTradingFee(fee);
        uint256 quoted = router.getAmountsOut(amountIn, _path())[1];
        assertEq(_swap(alice, amountIn), quoted);
    }

    /**
     * @dev The pair must reject output above what the governed fee allows
     */
    function testPairEnforcesGovernedFee() public {
        factory.setTradingFee(100);
        uint256 amountIn = 1_000e18;
        (uint112 r0, uint112 r1,) = pair.getReserves();
        (uint256 reserveIn, uint256 reserveOut) = pair.token0() == address(tokenA) ? (r0, r1) : (r1, r0);

        // What a 0.3% fee would pay out: more than a 1% fee allows
        uint256 outAtDefaultFee = (amountIn * 9970 * reserveOut) / (reserveIn * 10000 + amountIn * 9970);

        vm.startPrank(alice);
        tokenA.transfer(address(pair), amountIn);
        (uint256 out0, uint256 out1) = pair.token0() == address(tokenA)
            ? (uint256(0), outAtDefaultFee)
            : (outAtDefaultFee, uint256(0));
        vm.expectRevert("Pair: K");
        pair.swap(out0, out1, alice, "");
        vm.stopPrank();
    }

    // ============ FLASH LOAN FEE ============

    function testFlashLoanPaysGovernedFlashFee() public {
        FlashLoanExample flash = new FlashLoanExample(address(factory));
        uint256 borrow = 10_000e18;

        // At the default 0.09% flash fee, repaying needs ~9 tokens on top of the loan
        uint256 fee = (borrow * 10000) / (10000 - factory.flashLoanFee()) + 1 - borrow;
        tokenA.transfer(address(flash), fee);
        flash.executeFlashLoan(address(tokenA), address(tokenB), borrow, "");
        assertEq(tokenA.balanceOf(address(flash)), 0);

        // After governance raises it to 0.5%, the old amount is no longer enough
        factory.setFlashLoanFee(50);
        tokenA.transfer(address(flash), fee);
        vm.expectRevert("FlashLoan: INSUFFICIENT_FUNDS_TO_REPAY");
        flash.executeFlashLoan(address(tokenA), address(tokenB), borrow, "");
    }

    // ============ PROTOCOL FEE ============

    function testNoProtocolFeeWhenFeeToUnset() public {
        _swap(alice, 10_000e18);
        _addLiquidity(lp, 1_000e18);
        assertEq(pair.kLast(), 0);
    }

    function testProtocolFeeMintsLpTokensToFeeTo() public {
        address feeRecipient = makeAddr("feeRecipient");
        factory.setFeeTo(feeRecipient);
        _addLiquidity(lp, 1_000e18); // records kLast
        assertGt(pair.kLast(), 0);

        for (uint256 i = 0; i < 10; i++) _swap(alice, 100e18); // small vs. the pool, so the price barely moves
        assertEq(pair.balanceOf(feeRecipient), 0); // fees are only minted on liquidity events

        _addLiquidity(lp, 1_000e18);
        uint256 feeLp = pair.balanceOf(feeRecipient);
        assertGt(feeLp, 0);

        // The minted LP tokens are worth about 1/6 of the 0.3% fees on 1k tokenA of volume
        uint256 valueInA = (feeLp * tokenA.balanceOf(address(pair))) / pair.totalSupply();
        uint256 expectedA = (1_000e18 * 30) / 10000 / 6 / 2; // half the value sits on the tokenB side
        assertApproxEqRel(valueInA, expectedA, 0.02e18);
    }

    // ============ END-TO-END GOVERNANCE (TESTNET DEMO SETTINGS) ============

    function testVisitorCanRunAProposalEndToEnd() public {
        // Same settings as script/DeployGovernance.s.sol
        DEXToken proto = new DEXToken(address(this));
        DEXTimelock timelock = new DEXTimelock(5 minutes, new address[](0), new address[](0), address(this));
        DEXGovernor governor = new DEXGovernor(proto, timelock, 1 minutes, 1 hours, 1_000e18, 1); // 0.001% quorum
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));
        factory.transferOwnership(address(timelock));

        TokenFaucet faucet = new TokenFaucet(proto, 10_000e18, 1 days);
        proto.transfer(address(faucet), 1_000_000e18);

        // A visitor claims PROTO and delegates to themselves
        address visitor = makeAddr("visitor");
        vm.startPrank(visitor);
        faucet.claim();
        proto.delegate(visitor);
        vm.stopPrank();
        assertGe(proto.balanceOf(visitor), governor.quorum(block.timestamp - 1)); // one claim reaches quorum
        vm.warp(block.timestamp + 1);

        // Propose lowering the trading fee
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(factory);
        calldatas[0] = abi.encodeCall(Factory.setTradingFee, (10));
        string memory description = "Lower the trading fee to 0.1%";

        vm.prank(visitor);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        assertEq(governor.proposalCount(), 1);
        assertEq(governor.proposalDescriptions(proposalId), description);

        vm.warp(block.timestamp + 1 minutes + 1);
        vm.prank(visitor);
        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + 1 hours);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // Queue and execute by ID only (GovernorStorage), as the frontend does
        governor.queue(proposalId);
        vm.warp(block.timestamp + 5 minutes);
        governor.execute(proposalId);
        assertEq(factory.tradingFee(), 10);

        // And swaps still work at the new fee
        uint256 quoted = router.getAmountsOut(1_000e18, _path())[1];
        assertEq(_swap(alice, 1_000e18), quoted);
    }

    // ============ TOKEN FAUCET ============

    function testTokenFaucetCooldownAndEmpty() public {
        TokenFaucet faucet = new TokenFaucet(tokenA, 100e18, 1 days);
        tokenA.transfer(address(faucet), 150e18);

        vm.prank(alice);
        faucet.claim();
        assertEq(faucet.nextClaimAt(alice), block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert("TokenFaucet: cooldown active");
        faucet.claim();

        vm.prank(lp);
        vm.expectRevert("TokenFaucet: empty");
        faucet.claim();

        vm.warp(block.timestamp + 1 days);
        assertEq(faucet.nextClaimAt(alice), 0);
    }
}
