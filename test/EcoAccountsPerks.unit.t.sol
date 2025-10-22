// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EcoAccountsPerks} from "../src/EcoAccountsPerks.sol";
import {IEcoAccountsBadges} from "../src/interfaces/IEcoAccountsBadges.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EcoAccountsPerksUnit is Test {
    EcoAccountsPerks public ecoAccountsPerks;
    IEcoAccountsBadges public ecoAccountsBadges;
    DummyToken public dummyToken;

    uint256 internal signerPk = 0xBEEF;
    address internal signer = vm.addr(signerPk);

    function setUp() public {
        ecoAccountsBadges = new DummyEcoAccountsBadges();
        ecoAccountsPerks = new EcoAccountsPerks(
            address(this),
            address(ecoAccountsBadges)
        );
        dummyToken = new DummyToken();
        dummyToken.transfer(
            address(ecoAccountsPerks),
            1000000 * 10 ** dummyToken.decimals()
        );
    }

    modifier createPerk(
        address token,
        uint256 amount,
        uint256 maxRedemptions
    ) {
        ecoAccountsPerks.addPerk(1, 1, token, amount, maxRedemptions);
        _;
    }

    modifier createPerkWithBadgeIdAndTier(
        address token,
        uint256 amount,
        uint256 maxRedemptions,
        uint256 badgeId,
        uint256 tier
    ) {
        ecoAccountsPerks.addPerk(badgeId, tier, token, amount, maxRedemptions);
        _;
    }

    function test_addPerk() public createPerk(address(0x123), 100, 10) {
        address token = address(0x123);
        uint256 amount = 100;
        uint256 maxRedemptions = 10;

        uint256 badgeId = 1;
        uint256 tier = 1;

        bytes32 perkId = keccak256(abi.encodePacked(badgeId, tier));

        (
            address perkToken,
            uint256 perkAmount,
            uint256 perkMaxRedemptions,
            uint256 perkRedemptions
        ) = ecoAccountsPerks.perks(perkId);
        assertEq(perkToken, token);
        assertEq(perkAmount, amount);
        assertEq(perkMaxRedemptions, maxRedemptions);
        assertEq(perkRedemptions, 0);
    }

    function test_setPerk() public createPerk(address(0x123), 100, 10) {
        address newToken = address(0x456);
        uint256 newAmount = 200;
        uint256 newMaxRedemptions = 20;

        uint256 badgeId = 1;
        uint256 tier = 1;

        bytes32 perkId = keccak256(abi.encodePacked(badgeId, tier));

        ecoAccountsPerks.setPerk(
            badgeId,
            tier,
            newToken,
            newAmount,
            newMaxRedemptions
        );
        (
            address perkToken,
            uint256 perkAmount,
            uint256 perkMaxRedemptions,
            uint256 perkRedemptions
        ) = ecoAccountsPerks.perks(perkId);
        assertEq(perkToken, newToken);
        assertEq(perkAmount, newAmount);
        assertEq(perkMaxRedemptions, newMaxRedemptions);
        assertEq(perkRedemptions, 0);
    }

    function test_redemPerk() public createPerk(address(dummyToken), 100, 10) {
        uint256 badgeId = 1;
        uint256 tier = 1;
        ecoAccountsPerks.grantRole(ecoAccountsPerks.SIGNER_ROLE(), signer);
        vm.prank(signer);
        ecoAccountsPerks.redeemPerk(badgeId, tier, address(0xABC));
        uint256 userBalance = dummyToken.balanceOf(address(0xABC));
        assertEq(userBalance, 100);
    }

    function test_redemPerks()
        public
        createPerkWithBadgeIdAndTier(address(dummyToken), 100, 1, 1, 1)
        createPerkWithBadgeIdAndTier(address(dummyToken), 100, 1, 1, 2)
    {
        uint256 badgeId1 = 1;
        uint256 tier1 = 1;

        uint256 badgeId2 = 1;
        uint256 tier2 = 2;

        uint256[] memory badgeIds = new uint256[](2);
        badgeIds[0] = badgeId1;
        badgeIds[1] = badgeId2;

        uint256[] memory tiers = new uint256[](2);
        tiers[0] = tier1;
        tiers[1] = tier2;

        ecoAccountsPerks.grantRole(ecoAccountsPerks.SIGNER_ROLE(), signer);
        vm.prank(signer);
        ecoAccountsPerks.redeemPerks(
            badgeIds,
            tiers,
            address(0xABC)
        );

        uint256 userBalance = dummyToken.balanceOf(address(0xABC));
        assertEq(userBalance, 200);
    }
}

contract DummyToken is ERC20 {
    constructor() ERC20("DummyToken", "DUMMY") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract DummyEcoAccountsBadges is IEcoAccountsBadges {

    function getUserBadgeTier(address user, uint256 badgeId) external view override returns (uint256) {
        return 2;
    }
}
