// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEcoAccountsBadges} from "./interfaces/IEcoAccountsBadges.sol";

contract EcoAccountsPerks is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    /*///////////////////////////////////////////////////////////////
                        State, Constants & Structs
    //////////////////////////////////////////////////////////////*/
    struct Perk {
        address token;
        uint256 amount;
        uint256 maxRedemptions;
        uint256 redemptions;
    }

    struct PerkClaim {
        uint256 badgeId;
        uint256 tier;
    }

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    struct EcoAccountsPerksStorage {
        IEcoAccountsBadges ecoAccountsBadges;
        mapping(bytes32 => Perk) perks;
        mapping(bytes32 => mapping(address => bool)) redeemedPerks;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ecoaccounts_perks")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant ECO_ACCOUNTS_PERKS_STORAGE_LOCATION =
        0xe504a388e8ea4f7c1f9df3ff68b4eccc72e41810b0d1e54d07a638f146f63100;

    function ecoAccountsPerksStorage()
        private
        pure
        returns (EcoAccountsPerksStorage storage $)
    {
        assembly {
            $.slot := ECO_ACCOUNTS_PERKS_STORAGE_LOCATION
        }
    }

    /*/////////////////////////////////////////////////////////////
                                Errors
    //////////////////////////////////////////////////////////////*/

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
        uint256 badgeId,
        uint256 tier,
        uint256 amount
    );

    event PerkCompleted(uint256 indexed badgeId, uint256 indexed tier);

    /*///////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////*/
    function initialize(
        address initialOwner,
        address ecoAccountsBadgesAddress
    ) public initializer {
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        __Ownable_init(initialOwner);
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        $.ecoAccountsBadges = IEcoAccountsBadges(ecoAccountsBadgesAddress);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*///////////////////////////////////////////////////////////////
                        Perk Redemption
    //////////////////////////////////////////////////////////////*/

    function redeemPerk(
        uint256 badgeId,
        uint256 tier,
        address user
    ) public onlyRole(SIGNER_ROLE) whenNotPaused {
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        bytes32 perkId = keccak256(abi.encodePacked(badgeId, tier));
        if (_checkPerkValid(perkId)) {
            require(
                _checkUserNotClaimedPerk(perkId, user),
                PerkAlreadyClaimed(perkId, user)
            );
            require(
                _checkUserHasBadge(user, badgeId, tier),
                UserDoesNotHaveBadge(user, badgeId, tier)
            );

            Perk storage perk = $.perks[perkId];

            if (perk.maxRedemptions != 0) {
                perk.redemptions += 1;
            }
            $.redeemedPerks[perkId][user] = true;

            IERC20(perk.token).transfer(user, perk.amount);
            emit PerkRedeemed(
                perkId,
                user,
                perk.token,
                badgeId,
                tier,
                perk.amount
            );

            if (perk.redemptions >= perk.maxRedemptions) {
                emit PerkCompleted(badgeId, tier);
            }
        }
    }

    function redeemPerks(
        PerkClaim[] calldata claims,
        address user
    ) external onlyRole(SIGNER_ROLE) {
        for (uint256 i = 0; i < claims.length; i++) {
            redeemPerk(claims[i].badgeId, claims[i].tier, user);
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
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        Perk memory newPerk = Perk({
            token: token,
            amount: amount,
            maxRedemptions: maxRedemptions,
            redemptions: 0
        });

        bytes32 key = keccak256(abi.encodePacked(badgeId, tier));

        $.perks[key] = newPerk;
        emit PerkAdded(badgeId, tier, token, amount, maxRedemptions);
    }

    function setPerk(
        uint256 badgeId,
        uint256 tier,
        address token,
        uint256 amount,
        uint256 maxRedemptions
    ) public onlyOwner {
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        bytes32 key = keccak256(abi.encodePacked(badgeId, tier));
        Perk storage perk = $.perks[key];
        perk.token = token;
        perk.amount = amount;
        perk.maxRedemptions = maxRedemptions;

        emit PerkSet(badgeId, tier, token, amount, maxRedemptions);
    }

    function setEcoAccountsBadgesAddress(
        address ecoAccountsBadgesAddress
    ) public onlyOwner {
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        $.ecoAccountsBadges = IEcoAccountsBadges(ecoAccountsBadgesAddress);
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
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        bytes32 perkId = keccak256(abi.encodePacked(badgeId, tier));
        return $.redeemedPerks[perkId][user];
    }

    function perks(bytes32 perkId) public view returns (Perk memory) {
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        return $.perks[perkId];
    }

    function perks(
        uint256 badgeId,
        uint256 tier
    ) public view returns (Perk memory) {
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        bytes32 perkId = keccak256(abi.encodePacked(badgeId, tier));
        return $.perks[perkId];
    }

    function redeemedPerks(
        uint256 badgeId,
        uint256 tier,
        address user
    ) public view returns (bool hasRedeemed) {
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        bytes32 perkId = keccak256(abi.encodePacked(badgeId, tier));
        return $.redeemedPerks[perkId][user];
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

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /*///////////////////////////////////////////////////////////////
                        Helper Functions
    //////////////////////////////////////////////////////////////*/

    function calculatePerkId(
        uint256 badgeId,
        uint256 tier
    ) public pure returns (bytes32 perkId) {
        return keccak256(abi.encodePacked(badgeId, tier));
    }

    function _checkPerkValid(
        bytes32 perkId
    ) internal view returns (bool isValid) {
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        Perk memory perk = $.perks[perkId];
        if (
            (perk.redemptions < perk.maxRedemptions) ||
            (perk.maxRedemptions == 0)
        ) {
            return true;
        } else {
            return false;
        }
    }

    function _checkUserNotClaimedPerk(
        bytes32 perkId,
        address user
    ) internal view returns (bool notClaimed) {
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        return !$.redeemedPerks[perkId][user];
    }

    function _checkUserHasBadge(
        address user,
        uint256 badgeId,
        uint256 tier
    ) internal view returns (bool hasBadge) {
        EcoAccountsPerksStorage storage $ = ecoAccountsPerksStorage();
        uint256 userTier = $.ecoAccountsBadges.getUserBadgeTier(user, badgeId);
        if (tier == 0) {
            uint256 highestTier = $.ecoAccountsBadges.getHighestBadgeTier(
                badgeId
            );
            return userTier >= highestTier;
        }

        return userTier >= tier;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
