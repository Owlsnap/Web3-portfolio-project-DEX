// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {Router} from "../src/Router.sol";
import {WETH} from "../src/WETH.sol";
import {DEXToken} from "../src/DEXToken.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployBaseSepolia is Script {
    // Liquidity seeding amounts (kept small for testnet faucet constraints)
    uint256 constant ETH_PROTO_ETH    = 0.00008 ether;
    uint256 constant ETH_PROTO_PROTO  = 8 ether;        // 1 ETH = 100,000 PROTO
    uint256 constant PROTO_USDC_PROTO = 8 ether;
    uint256 constant PROTO_USDC_USDC  = 80_000e6;       // 1 PROTO = 10,000 USDC

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        console.log("=== ProtoSwap Deploy - Base Sepolia ===");
        console.log("Deployer:", deployer);
        console.log("ETH balance:", deployer.balance);

        vm.startBroadcast(deployerKey);

        // ── Core contracts ──────────────────────────────────────────────
        Factory  factory  = new Factory(deployer);
        WETH     weth     = new WETH();
        Router   router   = new Router(address(factory), address(weth));
        DEXToken proto    = new DEXToken(deployer);

        // ── Mock tokens ─────────────────────────────────────────────────
        MockERC20 mockUsdc = new MockERC20("Mock USDC", "USDC", 6, 100_000_000e6);

        // ── Seed ETH/PROTO pool ─────────────────────────────────────────
        IERC20(address(proto)).approve(address(router), ETH_PROTO_PROTO);
        router.addLiquidityETH{value: ETH_PROTO_ETH}(
            address(proto),
            ETH_PROTO_PROTO,
            (ETH_PROTO_PROTO * 95) / 100,
            (ETH_PROTO_ETH  * 95) / 100,
            deployer,
            block.timestamp + 1200
        );

        // ── Seed PROTO/USDC pool ────────────────────────────────────────
        IERC20(address(proto)).approve(address(router), PROTO_USDC_PROTO);
        IERC20(address(mockUsdc)).approve(address(router), PROTO_USDC_USDC);
        router.addLiquidity(
            address(proto),
            address(mockUsdc),
            PROTO_USDC_PROTO,
            PROTO_USDC_USDC,
            (PROTO_USDC_PROTO * 95) / 100,
            (PROTO_USDC_USDC * 95) / 100,
            deployer,
            block.timestamp + 1200
        );

        vm.stopBroadcast();

        // ── Summary ─────────────────────────────────────────────────────
        console.log("\n=== Deployed Addresses (paste into wagmi.js) ===");
        console.log("factory:  ", address(factory));
        console.log("router:   ", address(router));
        console.log("weth:     ", address(weth));
        console.log("dexToken: ", address(proto));
        console.log("mockUsdc: ", address(mockUsdc));
        console.log("\nPools seeded:");
        console.log(" ETH/PROTO  - 0.00008 ETH : 8 PROTO");
        console.log(" PROTO/USDC - 8 PROTO : 80,000 USDC");
    }
}
