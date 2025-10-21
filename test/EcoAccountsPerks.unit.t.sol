// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EcoAccountsPerks} from "../src/EcoAccountsPerks.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EcoAccountsPerksUnit is Test {
    EcoAccountsPerks public ecoAccountsPerks;
    DummyToken public dummyToken;

    uint256 internal signerPk = 0xBEEF;
    address internal signer = vm.addr(signerPk);

    function setUp() public {
        
        ecoAccountsPerks = new EcoAccountsPerks(address(this));
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

    function test_redemPerk() public createPerk(address(dummyToken), 100, 10) {
        ecoAccountsPerks.grantRole(ecoAccountsPerks.SIGNER_ROLE(), signer);
        uint256 perkId = 0;
        uint256 nullifier = 1;
        bytes memory signature = _getSignature(perkId, nullifier);
        ecoAccountsPerks.redeemPerk(
            perkId,
            signature,
            signer,
            nullifier
        );
    }

    function _getSignature(
        uint256 perkId,
        uint256 nullifier
    ) internal returns (bytes memory signature) {
        bytes32 structHash = keccak256(
            abi.encode(
                ecoAccountsPerks.PERKS_REDEMPTION_TYPEHASH(),
                perkId,
                nullifier
            )
        );

        bytes32 domain = ecoAccountsPerks.domainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domain, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        signature = abi.encodePacked(r, s, v);
    }
}


contract DummyToken is ERC20 {
    constructor() ERC20("DummyToken", "DUMMY") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}