// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {EcoAccountsPerks} from "../src/EcoAccountsPerks.sol";

contract AddPerkScript is Script {
    function run() external {
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        uint256 badgeId = vm.envUint("BADGE_ID");
        uint256 tier = vm.envUint("TIER");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        uint256 amount = vm.envUint("AMOUNT");
        uint256 maxRedemptions = vm.envUint("MAX_REDEMPTIONS");

        vm.startBroadcast();

        EcoAccountsPerks ecoAccountsPerks = EcoAccountsPerks(contractAddress);

        ecoAccountsPerks.addPerk(
            badgeId,
            tier,
            tokenAddress,
            amount,
            maxRedemptions
        );

        console.log("Perk added successfully");
        console.log("- BadgeId:", badgeId);
        console.log("- Tier:", tier);
        console.log("- Token:", tokenAddress);
        console.log("- Amount:", amount);
        console.log("- Max Redemptions:", maxRedemptions);

        vm.stopBroadcast();
    }
}
