// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEcoAccountsBadges {
    function getUserBadgeTier(
        address user,
        uint256 badgeId
    ) external view returns (uint256);
}
