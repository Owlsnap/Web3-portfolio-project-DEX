// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Router} from "../src/Router.sol";
import {Factory} from "../src/Factory.sol";
import {Pair} from "../src/Pair.sol";

/**
 * @dev Deepens the live Base Sepolia pools so visitors' swaps don't swing the price.
 *      Token amounts are derived from current reserves, so pool prices are preserved.
 *
 *      Required env: ROUTER (current deployment). Optional (in wei): ETH_AMOUNT, USDC_POOL_PROTO
 *      forge script script/TopUpLiquidity.s.sol --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
 */
contract TopUpLiquidity is Script {
    address constant WETH = 0xb0F800aa76233B5d89e31bFE37cDc2CBcC32ad39;
    address constant PROTO = 0x599C2c44aAB318D6537A5C873aBa4654A4f87db4;
    address constant USDC = 0x7DD41ED04666FFE286f288AB1393bc261c2E0794;

    function run() external {
        Router router = Router(payable(vm.envAddress("ROUTER")));
        Factory factory = Factory(router.factory());
        uint256 ethAmount = vm.envOr("ETH_AMOUNT", uint256(0.008 ether));
        uint256 usdcPoolProto = vm.envOr("USDC_POOL_PROTO", uint256(792 ether));
        uint256 deadline = block.timestamp + 1200;

        uint256 protoForEth = _matching(factory, WETH, PROTO, ethAmount);
        uint256 usdcForProto = _matching(factory, PROTO, USDC, usdcPoolProto);

        vm.startBroadcast();
        (, address deployer,) = vm.readCallers();

        console.log("Deployer:", deployer);
        console.log("ETH/PROTO  add (wei ETH, wei PROTO):", ethAmount, protoForEth);
        console.log("PROTO/USDC add (wei PROTO, USDC units):", usdcPoolProto, usdcForProto);

        IERC20(PROTO).approve(address(router), protoForEth + usdcPoolProto);
        IERC20(USDC).approve(address(router), usdcForProto);

        router.addLiquidityETH{value: ethAmount}(
            PROTO, protoForEth, (protoForEth * 99) / 100, (ethAmount * 99) / 100, deployer, deadline
        );
        router.addLiquidity(
            PROTO, USDC, usdcPoolProto, usdcForProto,
            (usdcPoolProto * 99) / 100, (usdcForProto * 99) / 100, deployer, deadline
        );

        vm.stopBroadcast();
    }

    /// Amount of `tokenB` that matches `amountA` of `tokenA` at the pool's current price.
    function _matching(Factory factory, address tokenA, address tokenB, uint256 amountA)
        internal
        view
        returns (uint256)
    {
        Pair pair = Pair(factory.getPair(tokenA, tokenB));
        (uint256 r0, uint256 r1,) = pair.getReserves();
        (uint256 reserveA, uint256 reserveB) = pair.token0() == tokenA ? (r0, r1) : (r1, r0);
        return (amountA * reserveB) / reserveA;
    }
}
