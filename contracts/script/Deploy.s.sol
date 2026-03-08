// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {Router} from "../src/Router.sol";
import {WETH} from "../src/WETH.sol";
import {DEXToken} from "../src/DEXToken.sol";
// import {DEXGovernor} from "../src/DEXGovernor.sol";
// import {DEXTimelock} from "../src/DEXTimelock.sol";  
// import {Treasury} from "../src/Treasury.sol";
// import {MockERC20} from "../src/MockERC20.sol";

contract DeployScript is Script {
    Factory public factory;
    Router public router;
    WETH public weth;
    DEXToken public dexToken;
    // DEXGovernor public governor;
    // DEXTimelock public timelock;
    // Treasury public treasury;

    function run() public {
        // Use Anvil's default private key directly
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil's first account
        vm.startBroadcast(deployerPrivateKey);

        // Deploy core contracts
        factory = new Factory(deployer);
        weth = new WETH();
        router = new Router(address(factory), address(weth));
        
        // Deploy governance token (tokens are minted to deployer in constructor)
        dexToken = new DEXToken(deployer);
        
        // Skip governance contracts for now to avoid contract size limits
        // timelock = new DEXTimelock(1 hours, new address[](0), new address[](0), deployer);
        // governor = new DEXGovernor(dexToken, timelock, 1, 50400, 100000 * 10**18);
        // treasury = new Treasury(deployer, "DEX Protocol Treasury");

        console.log("Factory deployed at:", address(factory));
        console.log("Router deployed at:", address(router));
        console.log("WETH deployed at:", address(weth));
        console.log("DEX Token deployed at:", address(dexToken));
        // console.log("Governor deployed at:", address(governor));
        // console.log("Timelock deployed at:", address(timelock));
        // console.log("Treasury deployed at:", address(treasury));

        // DEX tokens are already minted to deployer in constructor
        console.log("DEX Token balance of deployer:", dexToken.balanceOf(deployer));
        console.log("Deployer address:", deployer);
        console.log("msg.sender:", msg.sender);
        
        console.log("Deployment completed successfully!");
        console.log("You can add liquidity manually through the frontend.");

        vm.stopBroadcast();
    }
}
