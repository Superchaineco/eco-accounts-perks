// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {EcoAccountsPerks} from "../src/EcoAccountsPerks.sol";
import {
    Upgrades,
    UnsafeUpgrades
} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployEcoAccountsPerks is Script {
    function run() external {
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        address ecoAccountsBadgesAddress = vm.envAddress(
            "ECO_ACCOUNTS_BADGES_ADDRESS"
        );

        address proxy = Upgrades.deployUUPSProxy(
            "EcoAccountsPerks.sol",
            abi.encodeCall(
                EcoAccountsPerks.initialize,
                (initialOwner, ecoAccountsBadgesAddress)
            )
        );
        // vm.startBroadcast();

        // EcoAccountsPerks perks = new EcoAccountsPerks(
        //     initialOwner,
        //     ecoAccountsBadgesAddress
        // );

        // vm.stopBroadcast();

        // console.log("EcoAccountsPerks deployed on: ", address(perks));
        console.log("EcoAccountsPerks deployed on: ", proxy);
    }

    function deployForTest(
        address initialOwner,
        address ecoAccountsBadgesAddress
    ) external returns (address) {
        EcoAccountsPerks implementation = new EcoAccountsPerks();
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            address(implementation),
            abi.encodeCall(
                EcoAccountsPerks.initialize,
                (initialOwner, ecoAccountsBadgesAddress)
            )
        );

        return proxy;
    }
}
