// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Router} from "../src/Router.sol";

contract AddLiquidity is Script {
    // Deployed contract addresses (fresh deployment addresses)
    address constant ROUTER = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address constant DEX_TOKEN = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    address constant WETH = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        vm.startBroadcast(deployerPrivateKey);
        
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer:", deployer);
        console.log("Deployer ETH Balance:", deployer.balance);
        
        // Check PROTO token balance
        uint256 protoBalance = IERC20(DEX_TOKEN).balanceOf(deployer);
        console.log("Deployer PROTO Balance:", protoBalance);
        
        // Amounts to add as liquidity
        uint256 ethAmount = 1 ether;
        uint256 protoAmount = 1000 ether;
        
        // Approve PROTO tokens for router
        console.log("Approving PROTO tokens...");
        IERC20(DEX_TOKEN).approve(ROUTER, protoAmount);
        
        // Add ETH-PROTO liquidity
        console.log("Adding ETH-PROTO liquidity...");
        console.log("ETH Amount:", ethAmount);
        console.log("PROTO Amount:", protoAmount);
        
        Router router = Router(payable(ROUTER));
        
        // Calculate minimum amounts (5% slippage)
        uint256 ethAmountMin = (ethAmount * 95) / 100;
        uint256 protoAmountMin = (protoAmount * 95) / 100;
        
        // Add liquidity
        (, , uint256 liquidity) = router.addLiquidityETH{value: ethAmount}(
            DEX_TOKEN,
            protoAmount,
            protoAmountMin,
            ethAmountMin,
            deployer,
            block.timestamp + 1200
        );
        
        console.log("Liquidity tokens received:", liquidity);
        console.log("ETH-PROTO liquidity added successfully!");
        
        vm.stopBroadcast();
    }
}