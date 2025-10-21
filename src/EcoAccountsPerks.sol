// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EcoAccountsPerks is EIP712, AccessControl, Ownable {
    using ECDSA for bytes32;
    using SignatureChecker for address;

    /*///////////////////////////////////////////////////////////////
                        State, Constants & Structs
    //////////////////////////////////////////////////////////////*/
    struct Perk {
        address token;
        uint256 amount;
        uint256 maxRedemptions;
        uint256 redemptions;
    }

    mapping(uint256 => Perk) public perks;
    mapping(uint256 => bool) public nullifiers;

    uint256 private perkCount;

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    bytes32 public constant PERKS_REDEMPTION_TYPEHASH =
        keccak256("PerkRedemption(uint256 perkId,uint256 nullifier)");

    /*/////////////////////////////////////////////////////////////
                                Errors
    //////////////////////////////////////////////////////////////*/

    error InvalidPerk(uint256 perkId);
    error PerkMaxRedemptionsReached(uint256 perkId);
    error InvalidSignature();
    error InvalidSigner(address actualSigner);
    error NullifierAlreadyUsed(uint256 nullifier);

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event PerkAdded(
        uint256 indexed perkId,
        address indexed token,
        uint256 amount,
        uint256 maxRedemptions
    );

    event PerkSet(
        uint256 indexed perkId,
        address indexed token,
        uint256 amount,
        uint256 maxRedemptions
    );

    event PerkRedeemed(
        uint256 indexed perkId,
        address indexed redeemer,
        address indexed token,
        uint256 amount
    );

    /*///////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////*/
    constructor(
        address initialOwner
    ) Ownable(initialOwner) EIP712("EcoAccountsPerks", "1") {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
    }

    /*///////////////////////////////////////////////////////////////
                        Perk Redemption
    //////////////////////////////////////////////////////////////*/

    function redeemPerk(
        uint256 perkId,
        bytes memory signature,
        address signer,
        uint256 nullifier
    ) external {
        require(_checkPerkValid(perkId), InvalidPerk(perkId));
        require(
            _checkSignature(perkId, signer, signature, nullifier),
            InvalidSignature()
        );
        require(!nullifiers[nullifier], NullifierAlreadyUsed(nullifier));

        Perk storage perk = perks[perkId];
        perk.redemptions += 1;
        nullifiers[nullifier] = true;

        IERC20(perk.token).transfer(msg.sender, perk.amount);
        emit PerkRedeemed(perkId, msg.sender, perk.token, perk.amount);
    }

    /*///////////////////////////////////////////////////////////////
                        Setter Functions
    //////////////////////////////////////////////////////////////*/

    function addPerk(
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

        perks[perkCount] = newPerk;
        perkCount++;
        emit PerkAdded(perkCount, token, amount, maxRedemptions);
    }

    function setPerk(
        uint256 perkId,
        address token,
        uint256 amount,
        uint256 maxRedemptions
    ) public onlyOwner {
        Perk storage perk = perks[perkId];
        perk.token = token;
        perk.amount = amount;
        perk.maxRedemptions = maxRedemptions;

        emit PerkSet(perkId, token, amount, maxRedemptions);
    }

    /*///////////////////////////////////////////////////////////////
                        Helper Functions
    //////////////////////////////////////////////////////////////*/

    function _checkPerkValid(
        uint256 perkId
    ) internal view returns (bool isValid) {
        Perk memory perk = perks[perkId];
        if (perk.redemptions < perk.maxRedemptions) {
            return true;
        } else {
            return false;
        }
    }

    function _checkSignature(
        uint256 perkId,
        address signer,
        bytes memory signature,
        uint256 nullifier
    ) internal view returns (bool isValid) {
        require(hasRole(SIGNER_ROLE, signer), InvalidSigner(signer));
        bytes32 data = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    PERKS_REDEMPTION_TYPEHASH,
                    perkId,
                    nullifier
                )
            )
        );
        return _verifySignature(signer, data, signature);
    }

    function _verifySignature(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        return SignatureChecker.isValidSignatureNow(signer, hash, signature);
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
