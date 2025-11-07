// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EcoAccountsPerks} from "../src/EcoAccountsPerks.sol";
import {IEcoAccountsBadges} from "../src/interfaces/IEcoAccountsBadges.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DeployEcoAccountsPerks} from "../script/Deploy.s.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract EcoAccountsPerksUnit is Test {
    EcoAccountsPerks public ecoAccountsPerks;
    IEcoAccountsBadges public ecoAccountsBadges;
    DummyToken public dummyToken;

    uint256 internal signerPk = 0xBEEF;
    address internal signer = vm.addr(signerPk);
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    function setUp() public {
        DeployEcoAccountsPerks deployer = new DeployEcoAccountsPerks();
        address proxy = deployer.deployForTest(
            address(this),
            address(new DummyEcoAccountsBadges())
        );
        ecoAccountsBadges = new DummyEcoAccountsBadges();

        ecoAccountsPerks = EcoAccountsPerks(proxy);
        dummyToken = new DummyToken();
        dummyToken.transfer(
            address(ecoAccountsPerks),
            1000000 * 10 ** dummyToken.decimals()
        );
    }

    modifier createPerk(address token, uint256 amount, uint256 maxRedemptions) {
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

        EcoAccountsPerks.Perk memory perk = ecoAccountsPerks.perks(
            badgeId,
            tier
        );
        assertEq(perk.token, token);
        assertEq(perk.amount, amount);
        assertEq(perk.maxRedemptions, maxRedemptions);
        assertEq(perk.redemptions, 0);
    }

    function test_setPerk() public createPerk(address(0x123), 100, 10) {
        address newToken = address(0x456);
        uint256 newAmount = 200;
        uint256 newMaxRedemptions = 20;

        uint256 badgeId = 1;
        uint256 tier = 1;

        ecoAccountsPerks.setPerk(
            badgeId,
            tier,
            newToken,
            newAmount,
            newMaxRedemptions
        );

        EcoAccountsPerks.Perk memory perk = ecoAccountsPerks.perks(
            badgeId,
            tier
        );
        assertEq(perk.token, newToken);
        assertEq(perk.amount, newAmount);
        assertEq(perk.maxRedemptions, newMaxRedemptions);
        assertEq(perk.redemptions, 0);
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

        EcoAccountsPerks.PerkClaim[]
            memory claims = new EcoAccountsPerks.PerkClaim[](2);
        claims[0] = EcoAccountsPerks.PerkClaim({
            badgeId: badgeId1,
            tier: tier1
        });
        claims[1] = EcoAccountsPerks.PerkClaim({
            badgeId: badgeId2,
            tier: tier2
        });

        ecoAccountsPerks.grantRole(ecoAccountsPerks.SIGNER_ROLE(), signer);
        vm.prank(signer);
        ecoAccountsPerks.redeemPerks(claims, address(0xABC));

        uint256 userBalance = dummyToken.balanceOf(address(0xABC));
        assertEq(userBalance, 200);
    }

    function test_redemPerksWithoutMaxRedemptions()
        public
        createPerk(address(dummyToken), 100, 0)
    {
        uint256 badgeId1 = 1;
        uint256 tier1 = 1;

        EcoAccountsPerks.PerkClaim[]
            memory claims = new EcoAccountsPerks.PerkClaim[](1);
        claims[0] = EcoAccountsPerks.PerkClaim({
            badgeId: badgeId1,
            tier: tier1
        });

        ecoAccountsPerks.grantRole(ecoAccountsPerks.SIGNER_ROLE(), signer);
        vm.prank(signer);
        ecoAccountsPerks.redeemPerks(claims, address(0xABC));

        uint256 userBalance = dummyToken.balanceOf(address(0xABC));
        assertEq(userBalance, 100);
    }

    // Fuzz testing
    function testFuzz_addPerk(
        address token,
        uint256 amount,
        uint256 maxRedemptions,
        uint256 badgeId,
        uint256 tier
    ) public {
        vm.assume(amount > 0);
        vm.assume(badgeId > 0);
        vm.assume(tier > 0);

        ecoAccountsPerks.addPerk(badgeId, tier, token, amount, maxRedemptions);

        EcoAccountsPerks.Perk memory perk = ecoAccountsPerks.perks(
            badgeId,
            tier
        );
        assertEq(perk.token, token);
        assertEq(perk.amount, amount);
        assertEq(perk.maxRedemptions, maxRedemptions);
        assertEq(perk.redemptions, 0);
    }

    function testFuzz_setPerk(
        address token,
        uint256 amount,
        uint256 maxRedemptions,
        uint256 badgeId,
        uint256 tier
    ) public createPerk(address(0x123), 100, 10) {
        vm.assume(amount > 0);
        vm.assume(badgeId > 0);
        vm.assume(tier > 0);

        ecoAccountsPerks.setPerk(badgeId, tier, token, amount, maxRedemptions);

        EcoAccountsPerks.Perk memory perk = ecoAccountsPerks.perks(
            badgeId,
            tier
        );
        assertEq(perk.token, token);
        assertEq(perk.amount, amount);
        assertEq(perk.maxRedemptions, maxRedemptions);
    }

    // Error cases
    function test_RevertWhen_NonOwnerAddsPerk() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                address(0xBAD)
            )
        );
        ecoAccountsPerks.addPerk(1, 1, address(0x123), 100, 10);
    }

    function test_RevertWhen_NonSignerRedeemsPerk()
        public
        createPerk(address(dummyToken), 100, 10)
    {
        vm.prank(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(0xBAD),
                SIGNER_ROLE
            )
        );
        ecoAccountsPerks.redeemPerk(1, 1, address(0xABC));
    }

    function test_RevertWhen_PerkAlreadyClaimed()
        public
        createPerk(address(dummyToken), 100, 10)
    {
        ecoAccountsPerks.grantRole(ecoAccountsPerks.SIGNER_ROLE(), signer);
        vm.startPrank(signer);

        ecoAccountsPerks.redeemPerk(1, 1, address(0xABC));
        bytes32 perkId = keccak256(abi.encodePacked(uint256(1), uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(
                EcoAccountsPerks.PerkAlreadyClaimed.selector,
                perkId,
                address(0xABC)
            )
        );
        ecoAccountsPerks.redeemPerk(1, 1, address(0xABC));

        vm.stopPrank();
    }

    function test_notRevertWhen_MaxRedemptionsReached()
        public
        createPerk(address(dummyToken), 100, 1)
    {
        ecoAccountsPerks.grantRole(ecoAccountsPerks.SIGNER_ROLE(), signer);
        vm.startPrank(signer);

        // First redemption should succeed
        ecoAccountsPerks.redeemPerk(1, 1, address(0xABC));

        // Verify that only the first user received tokens
        assertEq(dummyToken.balanceOf(address(0xABC)), 100);
        assertEq(dummyToken.balanceOf(address(0xDEF)), 0);

        ecoAccountsPerks.redeemPerk(1, 1, address(0xDEF));

        EcoAccountsPerks.Perk memory perk = ecoAccountsPerks.perks(1, 1);
        assertEq(perk.redemptions, 1);

        vm.stopPrank();
    }

    // Pause/Unpause tests
    function test_PauseAndUnpause()
        public
        createPerk(address(dummyToken), 100, 10)
    {
        ecoAccountsPerks.grantRole(ecoAccountsPerks.SIGNER_ROLE(), signer);
        ecoAccountsPerks.pause();

        vm.startPrank(signer);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        ecoAccountsPerks.redeemPerk(1, 1, address(0xABC));
        vm.stopPrank();

        ecoAccountsPerks.unpause();
        vm.prank(signer);
        ecoAccountsPerks.redeemPerk(1, 1, address(0xABC));
    }

    // Helper functions tests
    function test_HelperFunctions() public {
        bytes32 perkId = ecoAccountsPerks.calculatePerkId(1, 1);
        assertEq(perkId, keccak256(abi.encodePacked(uint256(1), uint256(1))));
    }

    // Token management tests
    function test_TokenManagement() public {
        uint256 amount = 1000;
        // Mint tokens for the test
        dummyToken.mint(address(this), amount);
        dummyToken.approve(address(ecoAccountsPerks), amount);

        uint256 initialBalance = dummyToken.balanceOf(
            address(ecoAccountsPerks)
        );
        ecoAccountsPerks.depositTokens(address(dummyToken), amount);
        assertEq(
            dummyToken.balanceOf(address(ecoAccountsPerks)),
            initialBalance + amount
        );

        ecoAccountsPerks.withdrawTokens(address(dummyToken), amount);
        assertEq(
            dummyToken.balanceOf(address(ecoAccountsPerks)),
            initialBalance
        );
    }
}

contract DummyToken is ERC20 {
    constructor() ERC20("DummyToken", "DUMMY") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract DummyEcoAccountsBadges is IEcoAccountsBadges {
    function getUserBadgeTier(
        address user,
        uint256 badgeId
    ) external view override returns (uint256) {
        return 2;
    }
}
