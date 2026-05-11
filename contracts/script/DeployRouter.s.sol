// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Router} from "../src/Router.sol";

contract DeployRouter is Script {
    // Existing Base Sepolia deployments — only Router is being replaced
    address constant FACTORY = 0x43F2994dAF377A52F31ddBDD8D47D80865375a59;
    address constant WETH    = 0xb0F800aa76233B5d89e31bFE37cDc2CBcC32ad39;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        console.log("=== Router Redeploy - Base Sepolia ===");
        console.log("Deployer:", deployer);
        console.log("Factory: ", FACTORY);
        console.log("WETH:    ", WETH);

        vm.startBroadcast(deployerKey);
        Router router = new Router(FACTORY, WETH);
        vm.stopBroadcast();

        console.log("\n=== Update wagmi.js ===");
        console.log("router:", address(router));
    }
}
