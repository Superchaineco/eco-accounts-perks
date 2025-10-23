// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IEcoAccountsBadges} from "./interfaces/IEcoAccountsBadges.sol";

contract EcoAccountsPerks is AccessControl, Ownable, Pausable {
    /*///////////////////////////////////////////////////////////////
                        State, Constants & Structs
    //////////////////////////////////////////////////////////////*/
    struct Perk {
        address token;
        uint256 amount;
        uint256 maxRedemptions;
        uint256 redemptions;
    }

    IEcoAccountsBadges public ecoAccountsBadges;

    mapping(bytes32 => Perk) public perks;
    mapping(bytes32 => mapping(address => bool)) public redeemedPerks;

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /*/////////////////////////////////////////////////////////////
                                Errors
    //////////////////////////////////////////////////////////////*/

    error InvalidPerk(bytes32 perkId);
    error PerkMaxRedemptionsReached(bytes32 perkId);
    error PerkAlreadyClaimed(bytes32 perkId, address user);
    error UserDoesNotHaveBadge(address user, uint256 badgeId, uint256 tier);

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event PerkAdded(
        uint256 indexed badgeId,
        uint256 indexed tier,
        address indexed token,
        uint256 amount,
        uint256 maxRedemptions
    );

    event PerkSet(
        uint256 indexed badgeId,
        uint256 indexed tier,
        address indexed token,
        uint256 amount,
        uint256 maxRedemptions
    );

    event PerkRedeemed(
        bytes32 indexed perkId,
        address indexed redeemer,
        address indexed token,
        uint256 amount
    );

    event PerkCompleted(uint256 indexed badgeId, uint256 indexed tier);

    /*///////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////*/
    constructor(
        address initialOwner,
        address ecoAccountsBadgesAddress
    ) Ownable(initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        ecoAccountsBadges = IEcoAccountsBadges(ecoAccountsBadgesAddress);
    }

    /*///////////////////////////////////////////////////////////////
                        Perk Redemption
    //////////////////////////////////////////////////////////////*/

    function redeemPerk(
        uint256 badgeId,
        uint256 tier,
        address user
    ) public onlyRole(SIGNER_ROLE) whenNotPaused {
        bytes32 perkId = keccak256(abi.encodePacked(badgeId, tier));
        require(_checkPerkValid(perkId), InvalidPerk(perkId));
        require(
            _checkUserNotClaimedPerk(perkId, user),
            PerkAlreadyClaimed(perkId, user)
        );
        require(
            _checkUserHasBadge(user, badgeId, tier),
            UserDoesNotHaveBadge(user, badgeId, tier)
        );

        Perk storage perk = perks[perkId];

        if (perk.maxRedemptions != type(uint256).max) {
            perk.redemptions += 1;
        }
        redeemedPerks[perkId][user] = true;

        IERC20(perk.token).transfer(user, perk.amount);
        emit PerkRedeemed(perkId, user, perk.token, perk.amount);

        if (perk.redemptions >= perk.maxRedemptions) {
            emit PerkCompleted(badgeId, tier);
        }
    }

    function redeemPerks(
        uint256[] calldata badgeIds,
        uint256[] calldata tiers,
        address user
    ) external onlyRole(SIGNER_ROLE) {
        require(
            badgeIds.length == tiers.length,
            "Badge IDs and tiers length mismatch"
        );

        for (uint256 i = 0; i < badgeIds.length; i++) {
            redeemPerk(badgeIds[i], tiers[i], user);
        }
    }

    /*///////////////////////////////////////////////////////////////
                        Setter Functions
    //////////////////////////////////////////////////////////////*/

    function addPerk(
        uint256 badgeId,
        uint256 tier,
        address token,
        uint256 amount,
        uint256 maxRedemptions
    ) public onlyOwner {
        Perk memory newPerk = Perk({
            token: token,
            amount: amount,
            maxRedemptions: maxRedemptions,
            redemptions: 0
        });

        bytes32 key = keccak256(abi.encodePacked(badgeId, tier));

        perks[key] = newPerk;
        emit PerkAdded(badgeId, tier, token, amount, maxRedemptions);
    }

    function setPerk(
        uint256 badgeId,
        uint256 tier,
        address token,
        uint256 amount,
        uint256 maxRedemptions
    ) public onlyOwner {
        bytes32 key = keccak256(abi.encodePacked(badgeId, tier));
        Perk storage perk = perks[key];
        perk.token = token;
        perk.amount = amount;
        perk.maxRedemptions = maxRedemptions;

        emit PerkSet(badgeId, tier, token, amount, maxRedemptions);
    }

    function setEcoAccountsBadgesAddress(
        address ecoAccountsBadgesAddress
    ) public onlyOwner {
        ecoAccountsBadges = IEcoAccountsBadges(ecoAccountsBadgesAddress);
    }

    /*///////////////////////////////////////////////////////////////
                        Getter Functions
    //////////////////////////////////////////////////////////////*/

    function canClaimPerk(
        uint256 badgeId,
        uint256 tier,
        address user
    ) public view returns (bool canClaim) {
        bytes32 perkId = keccak256(abi.encodePacked(badgeId, tier));
        return
            _checkPerkValid(perkId) &&
            _checkUserNotClaimedPerk(perkId, user) &&
            _checkUserHasBadge(user, badgeId, tier);
    }

    function perkIsClaimed(
        uint256 badgeId,
        uint256 tier,
        address user
    ) public view returns (bool isClaimed) {
        bytes32 perkId = keccak256(abi.encodePacked(badgeId, tier));
        return redeemedPerks[perkId][user];
    }

    /*///////////////////////////////////////////////////////////////
                        Admin Functions
    //////////////////////////////////////////////////////////////*/

    function depositTokens(address token, uint256 amount) public onlyOwner {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdrawTokens(address token, uint256 amount) public onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }

    /*///////////////////////////////////////////////////////////////
                        Helper Functions
    //////////////////////////////////////////////////////////////*/

    function _checkPerkValid(
        bytes32 perkId
    ) internal view returns (bool isValid) {
        Perk memory perk = perks[perkId];
        if (perk.redemptions < perk.maxRedemptions) {
            return true;
        } else {
            return false;
        }
    }

    function _checkUserNotClaimedPerk(
        bytes32 perkId,
        address user
    ) internal view returns (bool notClaimed) {
        return !redeemedPerks[perkId][user];
    }

    function _checkUserHasBadge(
        address user,
        uint256 badgeId,
        uint256 tier
    ) internal view returns (bool hasBadge) {
        uint256 userTier = ecoAccountsBadges.getUserBadgeTier(user, badgeId);
        return userTier >= tier;
    }
}
