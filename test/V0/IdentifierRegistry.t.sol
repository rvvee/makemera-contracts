// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IdentifierRegistry} from "../../src/V0/IdentifierRegistry.sol";

contract IdentifierRegistryTest is Test {
    IdentifierRegistry public registry;

    address public admin = makeAddr("admin");
    address public verifier = makeAddr("verifier");
    address public stranger = makeAddr("stranger");

    uint8 constant TYPE_ID = 1;
    uint8 constant TIER = 2;

    event IdentifierTypeRegistered(uint8 indexed typeId, uint8 tier, address verifier);
    event IdentifierTypeStatusChanged(uint8 indexed typeId, bool status);
    event IdentifierTypeVerifierUpdated(uint8 indexed typeId, address oldVerifier, address newVerifier);

    function setUp() public {
        registry = new IdentifierRegistry(admin);
    }

    // ---------------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------------

    function test_Constructor_GrantsBothRolesToAdmin() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.ADMIN_ROLE(), admin));
    }

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(IdentifierRegistry.ZeroAddress.selector);
        new IdentifierRegistry(address(0));
    }

    // ---------------------------------------------------------------------
    // registerType
    // ---------------------------------------------------------------------

    function test_RegisterType_StoresVerifierTierAndActivatesType() public {
        vm.prank(admin);
        registry.registerType(TYPE_ID, TIER, verifier);

        assertEq(registry.verifierOf(TYPE_ID), verifier);
        assertEq(registry.tierOf(TYPE_ID), TIER);
        assertTrue(registry.statusOf(TYPE_ID));
    }

    function test_RegisterType_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit IdentifierTypeRegistered(TYPE_ID, TIER, verifier);

        vm.prank(admin);
        registry.registerType(TYPE_ID, TIER, verifier);
    }

    function test_RegisterType_RevertsWhenNotAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, registry.ADMIN_ROLE()
            )
        );
        registry.registerType(TYPE_ID, TIER, verifier);
    }

    function test_RegisterType_RevertsWhenAlreadyRegistered() public {
        vm.startPrank(admin);
        registry.registerType(TYPE_ID, TIER, verifier);

        vm.expectRevert(abi.encodeWithSelector(IdentifierRegistry.AlreadyRegistered.selector, TYPE_ID));
        registry.registerType(TYPE_ID, TIER, verifier);
        vm.stopPrank();
    }

    function test_RegisterType_RevertsOnZeroVerifier() public {
        vm.prank(admin);
        vm.expectRevert(IdentifierRegistry.ZeroAddress.selector);
        registry.registerType(TYPE_ID, TIER, address(0));
    }

    // ---------------------------------------------------------------------
    // setStatus
    // ---------------------------------------------------------------------

    function test_SetStatus_TogglesActiveFlagWithoutErasingRecord() public {
        vm.startPrank(admin);
        registry.registerType(TYPE_ID, TIER, verifier);

        registry.setStatus(TYPE_ID, false);
        assertFalse(registry.statusOf(TYPE_ID));
        assertEq(registry.verifierOf(TYPE_ID), verifier);
        assertEq(registry.tierOf(TYPE_ID), TIER);

        registry.setStatus(TYPE_ID, true);
        assertTrue(registry.statusOf(TYPE_ID));
        vm.stopPrank();
    }

    function test_SetStatus_EmitsEvent() public {
        vm.startPrank(admin);
        registry.registerType(TYPE_ID, TIER, verifier);

        vm.expectEmit(true, false, false, true);
        emit IdentifierTypeStatusChanged(TYPE_ID, false);
        registry.setStatus(TYPE_ID, false);
        vm.stopPrank();
    }

    function test_SetStatus_RevertsWhenNotAdmin() public {
        vm.prank(admin);
        registry.registerType(TYPE_ID, TIER, verifier);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, registry.ADMIN_ROLE()
            )
        );
        registry.setStatus(TYPE_ID, false);
    }

    function test_SetStatus_RevertsWhenNotRegistered() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IdentifierRegistry.NotRegistered.selector, TYPE_ID));
        registry.setStatus(TYPE_ID, false);
    }

    // ---------------------------------------------------------------------
    // setVerifier
    // ---------------------------------------------------------------------

    function test_SetVerifier_UpdatesVerifierAddress() public {
        address newVerifier = makeAddr("newVerifier");

        vm.startPrank(admin);
        registry.registerType(TYPE_ID, TIER, verifier);
        registry.setVerifier(TYPE_ID, newVerifier);
        vm.stopPrank();

        assertEq(registry.verifierOf(TYPE_ID), newVerifier);
    }

    function test_SetVerifier_EmitsEvent() public {
        address newVerifier = makeAddr("newVerifier");

        vm.startPrank(admin);
        registry.registerType(TYPE_ID, TIER, verifier);

        vm.expectEmit(true, false, false, true);
        emit IdentifierTypeVerifierUpdated(TYPE_ID, verifier, newVerifier);
        registry.setVerifier(TYPE_ID, newVerifier);
        vm.stopPrank();
    }

    function test_SetVerifier_RevertsWhenNotAdmin() public {
        vm.prank(admin);
        registry.registerType(TYPE_ID, TIER, verifier);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, registry.ADMIN_ROLE()
            )
        );
        registry.setVerifier(TYPE_ID, makeAddr("newVerifier"));
    }

    function test_SetVerifier_RevertsWhenNotRegistered() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IdentifierRegistry.NotRegistered.selector, TYPE_ID));
        registry.setVerifier(TYPE_ID, verifier);
    }

    function test_SetVerifier_RevertsOnZeroAddress() public {
        vm.startPrank(admin);
        registry.registerType(TYPE_ID, TIER, verifier);

        vm.expectRevert(IdentifierRegistry.ZeroAddress.selector);
        registry.setVerifier(TYPE_ID, address(0));
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // views on unregistered typeId
    // ---------------------------------------------------------------------

    function test_Views_ReturnDefaultsForUnregisteredType() public view {
        assertEq(registry.verifierOf(TYPE_ID), address(0));
        assertEq(registry.tierOf(TYPE_ID), 0);
        assertFalse(registry.statusOf(TYPE_ID));
    }

    // ---------------------------------------------------------------------
    // typeId scoping (each typeId maintains independent state)
    // ---------------------------------------------------------------------

    function test_MultipleTypeIds_AreScopedIndependently() public {
        address verifierA = makeAddr("verifierA");
        address verifierB = makeAddr("verifierB");

        vm.startPrank(admin);
        registry.registerType(1, 1, verifierA);
        registry.registerType(2, 3, verifierB);
        registry.setStatus(1, false);
        vm.stopPrank();

        assertFalse(registry.statusOf(1));
        assertTrue(registry.statusOf(2));
        assertEq(registry.verifierOf(1), verifierA);
        assertEq(registry.verifierOf(2), verifierB);
        assertEq(registry.tierOf(1), 1);
        assertEq(registry.tierOf(2), 3);
    }
}
