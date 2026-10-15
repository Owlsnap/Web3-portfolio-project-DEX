// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {Router} from "../src/Router.sol";
import {Pair} from "../src/Pair.sol";
import {WETH} from "../src/WETH.sol";
import {DEXToken} from "../src/DEXToken.sol";
import {DEXTimelock} from "../src/DEXTimelock.sol";
import {DEXGovernor} from "../src/DEXGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {TokenFaucet} from "../src/TokenFaucet.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Deploys ProtoSwap with governance to Base Sepolia.
 *
 * Fresh deploy:
 *   forge script script/DeployBaseSepolia.s.sol --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
 *
 * Optional env vars:
 *   WETH, PROTO, USDC   reuse existing token contracts instead of deploying new ones
 *   OLD_ROUTER          withdraw the deployer's liquidity from a previous deployment first
 *                       (recovers its ETH to seed the new pools)
 *   ETH_SEED            ETH for the ETH/PROTO pool (default: balance minus GAS_RESERVE)
 *
 * Governance settings are tuned for a live demo: a visitor can claim PROTO from the faucet,
 * propose, vote and execute within about an hour. Mainnet values would be days, not minutes.
 */
contract DeployBaseSepolia is Script {
    // ── Governance (demo settings) ───────────────────────────────────────
    uint48  constant VOTING_DELAY       = 1 minutes;
    uint32  constant VOTING_PERIOD      = 1 hours;
    uint256 constant TIMELOCK_DELAY     = 5 minutes;
    uint256 constant PROPOSAL_THRESHOLD = 1_000 ether;    // 1,000 PROTO
    uint256 constant QUORUM_NUMERATOR   = 1;              // 1 / 100,000 = 0.001% of supply = 10,000 PROTO

    // ── PROTO faucet ─────────────────────────────────────────────────────
    uint256 constant FAUCET_DRIP    = 10_000 ether;       // one claim is enough to reach quorum
    uint256 constant FAUCET_FUNDING = 10_000_000 ether;   // 1,000 claims
    uint256 constant FAUCET_COOLDOWN = 1 days;

    // ── Pools ────────────────────────────────────────────────────────────
    uint256 constant PROTO_PER_ETH    = 100_000;          // 1 ETH = 100,000 PROTO
    uint256 constant PROTO_USDC_PROTO = 800 ether;
    uint256 constant PROTO_USDC_USDC  = 8_000_000e6;      // 1 PROTO = 10,000 USDC
    uint256 constant GAS_RESERVE      = 0.001 ether;

    struct Deployment {
        WETH weth;
        DEXToken proto;
        MockERC20 usdc;
        Factory factory;
        Router router;
        DEXTimelock timelock;
        DEXGovernor governor;
        Treasury treasury;
        TokenFaucet faucet;
    }

    function run() external {
        vm.startBroadcast();
        (, address deployer,) = vm.readCallers();

        console.log("=== ProtoSwap Deploy - Base Sepolia ===");
        console.log("Deployer:", deployer);

        Deployment memory d;

        // ── Tokens (reused if provided) ─────────────────────────────────
        address wethAddr  = vm.envOr("WETH", address(0));
        address protoAddr = vm.envOr("PROTO", address(0));
        address usdcAddr  = vm.envOr("USDC", address(0));
        d.weth  = wethAddr  != address(0) ? WETH(payable(wethAddr)) : new WETH();
        d.proto = protoAddr != address(0) ? DEXToken(protoAddr) : new DEXToken(deployer);
        d.usdc  = usdcAddr  != address(0)
            ? MockERC20(usdcAddr)
            : new MockERC20("Mock USDC", "USDC", 6, 100_000_000e6);

        // ── Withdraw liquidity from a previous deployment ───────────────
        address oldRouter = vm.envOr("OLD_ROUTER", address(0));
        if (oldRouter != address(0)) {
            _withdrawAll(Router(payable(oldRouter)), deployer, address(d.proto), address(d.weth), true);
            _withdrawAll(Router(payable(oldRouter)), deployer, address(d.proto), address(d.usdc), false);
        }
        console.log("ETH balance:", deployer.balance);

        // ── Core DEX (owned by the deployer until governance is wired) ─
        d.factory = new Factory(deployer);
        d.router  = new Router(address(d.factory), address(d.weth));

        _seedPools(d, deployer);
        _deployGovernance(d, deployer);

        // ── PROTO faucet ────────────────────────────────────────────────
        d.faucet = new TokenFaucet(IERC20(address(d.proto)), FAUCET_DRIP, FAUCET_COOLDOWN);
        IERC20(address(d.proto)).transfer(address(d.faucet), FAUCET_FUNDING);

        vm.stopBroadcast();

        _logSummary(d);
    }

    function _seedPools(Deployment memory d, address deployer) internal {
        uint256 ethSeed = vm.envOr("ETH_SEED", uint256(0));
        if (ethSeed == 0) {
            require(deployer.balance > GAS_RESERVE, "Not enough ETH to seed the ETH/PROTO pool");
            ethSeed = deployer.balance - GAS_RESERVE;
        }
        uint256 protoForEth = ethSeed * PROTO_PER_ETH;
        uint256 deadline = block.timestamp + 1200;

        IERC20(address(d.proto)).approve(address(d.router), protoForEth + PROTO_USDC_PROTO);
        IERC20(address(d.usdc)).approve(address(d.router), PROTO_USDC_USDC);

        d.router.addLiquidityETH{value: ethSeed}(
            address(d.proto), protoForEth, protoForEth, ethSeed, deployer, deadline
        );
        d.router.addLiquidity(
            address(d.proto), address(d.usdc), PROTO_USDC_PROTO, PROTO_USDC_USDC,
            PROTO_USDC_PROTO, PROTO_USDC_USDC, deployer, deadline
        );
        console.log("ETH/PROTO seeded with ETH (wei):", ethSeed);
    }

    function _deployGovernance(Deployment memory d, address deployer) internal {
        // Timelock starts with the deployer as admin so roles can be wired, then the admin role is renounced
        d.timelock = new DEXTimelock(TIMELOCK_DELAY, new address[](0), new address[](0), deployer);
        d.governor = new DEXGovernor(
            d.proto, d.timelock, VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD, QUORUM_NUMERATOR
        );
        d.timelock.grantRole(d.timelock.PROPOSER_ROLE(), address(d.governor));
        d.timelock.grantRole(d.timelock.CANCELLER_ROLE(), address(d.governor));
        d.timelock.grantRole(d.timelock.EXECUTOR_ROLE(), address(0)); // anyone can execute once the delay passes

        // Treasury owned by governance, and protocol fees routed to it
        d.treasury = new Treasury(address(d.timelock), "ProtoSwap community treasury");
        d.factory.setTreasury(address(d.treasury));
        d.factory.setFeeTo(address(d.treasury));

        // Hand the DEX to governance
        d.factory.transferOwnership(address(d.timelock));
        d.timelock.renounceRole(d.timelock.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _withdrawAll(Router oldRouter, address deployer, address token, address other, bool isEth) internal {
        Factory oldFactory = Factory(oldRouter.factory());
        address pair = oldFactory.getPair(token, other);
        if (pair == address(0)) return;
        uint256 liquidity = Pair(pair).balanceOf(deployer);
        if (liquidity == 0) return;

        Pair(pair).approve(address(oldRouter), liquidity);
        if (isEth) {
            oldRouter.removeLiquidityETH(token, liquidity, 0, 0, deployer, block.timestamp + 1200);
        } else {
            oldRouter.removeLiquidity(token, other, liquidity, 0, 0, deployer, block.timestamp + 1200);
        }
        console.log("Withdrew liquidity from old pair:", pair);
    }

    function _logSummary(Deployment memory d) internal view {
        console.log("\n=== Deployed Addresses (paste into frontend/src/config/wagmi.js) ===");
        console.log("factory:  ", address(d.factory));
        console.log("router:   ", address(d.router));
        console.log("weth:     ", address(d.weth));
        console.log("dexToken: ", address(d.proto));
        console.log("mockUsdc: ", address(d.usdc));
        console.log("governor: ", address(d.governor));
        console.log("timelock: ", address(d.timelock));
        console.log("treasury: ", address(d.treasury));
        console.log("protoFaucet:", address(d.faucet));
        console.log("\nPairs:");
        console.log(" ETH/PROTO: ", d.factory.getPair(address(d.weth), address(d.proto)));
        console.log(" PROTO/USDC:", d.factory.getPair(address(d.proto), address(d.usdc)));
    }
}
