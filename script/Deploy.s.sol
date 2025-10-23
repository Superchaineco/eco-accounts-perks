// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {EcoAccountsPerks} from "../src/EcoAccountsPerks.sol";

contract DeployEcoAccountsPerks is Script {
    function run() external {
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        address ecoAccountsBadgesAddress = vm.envAddress("ECO_ACCOUNTS_BADGES_ADDRESS");

        vm.startBroadcast();

        EcoAccountsPerks perks = new EcoAccountsPerks(initialOwner, ecoAccountsBadgesAddress);

        vm.stopBroadcast();

        console.log("EcoAccountsPerks deployed on: ", address(perks));
    }
}
