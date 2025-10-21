// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EcoAccountsPerks} from "../src/EcoAccountsPerks.sol";

contract EcoAccountsPerksUnit is Test {
    EcoAccountsPerks public ecoAccountsPerks;

    function setUp() public {
        ecoAccountsPerks = new EcoAccountsPerks(address(this));
    }

    modifier createPerk(
        address token,
        uint256 amount,
        uint256 maxRedemptions
    ) {
        ecoAccountsPerks.addPerk(token, amount, maxRedemptions);
        _;
    }

    function test_addPerk() public createPerk(address(0x123), 100, 10) {
        address token = address(0x123);
        uint256 amount = 100;
        uint256 maxRedemptions = 10;

        (
            address perkToken,
            uint256 perkAmount,
            uint256 perkMaxRedemptions,
            uint256 perkRedemptions
        ) = ecoAccountsPerks.perks(0);
        assertEq(perkToken, token);
        assertEq(perkAmount, amount);
        assertEq(perkMaxRedemptions, maxRedemptions);
        assertEq(perkRedemptions, 0);
    }

    function test_setPerk() public createPerk(address(0x123), 100, 10) {
        address newToken = address(0x456);
        uint256 newAmount = 200;
        uint256 newMaxRedemptions = 20;

        ecoAccountsPerks.setPerk(0, newToken, newAmount, newMaxRedemptions);
        (
            address perkToken,
            uint256 perkAmount,
            uint256 perkMaxRedemptions,
            uint256 perkRedemptions
        ) = ecoAccountsPerks.perks(0);
        assertEq(perkToken, newToken);
        assertEq(perkAmount, newAmount);
        assertEq(perkMaxRedemptions, newMaxRedemptions);
        assertEq(perkRedemptions, 0);
    }

    function test_redemPerk() public createPerk(address(0x123), 100, 10) {
        uint256 perkId = 0;
        bytes memory signature = hex"abcdef";
        uint256 nullifier = 1;
        ecoAccountsPerks.redeemPerk(
            perkId,
            signature,
            address(this),
            nullifier
        );
    }
}
