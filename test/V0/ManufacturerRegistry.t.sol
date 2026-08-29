// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ManufacturerRegistry} from "../../src/V0/ManufacturerRegistry.sol";

contract ManufacturerRegistryTest is Test {
    ManufacturerRegistry public registry;

    address public admin = makeAddr("admin");
    address public signer = makeAddr("signer");
    address public stranger = makeAddr("stranger");

    bytes32 constant MANUFACTURER_ID = keccak256("apple");

    event ManufacturerRegistered(bytes32 indexed manufacturerId, address signer);
    event ManufacturerSignerUpdated(bytes32 indexed manufacturerId, address oldSigner, address newSigner);
    event ManufacturerDeactivated(bytes32 indexed manufacturerId);

    function setUp() public {
        registry = new ManufacturerRegistry(admin);
    }

    // ---------------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------------

    function test_Constructor_GrantsBothRolesToAdmin() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.ADMIN_ROLE(), admin));
    }

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(ManufacturerRegistry.ZeroAddress.selector);
        new ManufacturerRegistry(address(0));
    }

    // ---------------------------------------------------------------------
    // registerManufacturer
    // ---------------------------------------------------------------------

    function test_RegisterManufacturer_StoresSignerAndActivatesManufacturer() public {
        vm.prank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);

        assertEq(registry.getSigner(MANUFACTURER_ID), signer);
        assertTrue(registry.isActive(MANUFACTURER_ID));
    }

    function test_RegisterManufacturer_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ManufacturerRegistered(MANUFACTURER_ID, signer);

        vm.prank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);
    }

    function test_RegisterManufacturer_RevertsWhenNotAdmin() public {
        bytes32 role = registry.ADMIN_ROLE();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, role));
        registry.registerManufacturer(MANUFACTURER_ID, signer);
    }

    function test_RegisterManufacturer_RevertsOnZeroSigner() public {
        vm.prank(admin);
        vm.expectRevert(ManufacturerRegistry.ZeroAddress.selector);
        registry.registerManufacturer(MANUFACTURER_ID, address(0));
    }

    function test_RegisterManufacturer_RevertsWhenAlreadyRegistered() public {
        vm.startPrank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);

        vm.expectRevert(abi.encodeWithSelector(ManufacturerRegistry.AlreadyRegistered.selector, MANUFACTURER_ID));
        registry.registerManufacturer(MANUFACTURER_ID, makeAddr("otherSigner"));
        vm.stopPrank();
    }

    function test_RegisterManufacturer_RevertsWhenReRegisteringAfterDeactivation() public {
        vm.startPrank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);
        registry.deactivateManufacturer(MANUFACTURER_ID);

        vm.expectRevert(abi.encodeWithSelector(ManufacturerRegistry.AlreadyRegistered.selector, MANUFACTURER_ID));
        registry.registerManufacturer(MANUFACTURER_ID, makeAddr("otherSigner"));
        vm.stopPrank();
    }

    function test_MultipleManufacturerIds_AreScopedIndependently() public {
        bytes32 idA = keccak256("apple");
        bytes32 idB = keccak256("samsung");
        address signerA = makeAddr("signerA");
        address signerB = makeAddr("signerB");

        vm.startPrank(admin);
        registry.registerManufacturer(idA, signerA);
        registry.registerManufacturer(idB, signerB);
        registry.deactivateManufacturer(idA);
        vm.stopPrank();

        assertFalse(registry.isActive(idA));
        assertTrue(registry.isActive(idB));
        assertEq(registry.getSigner(idA), signerA);
        assertEq(registry.getSigner(idB), signerB);
    }

    // ---------------------------------------------------------------------
    // updateSigner
    // ---------------------------------------------------------------------

    function test_UpdateSigner_UpdatesSignerAddress() public {
        address newSigner = makeAddr("newSigner");

        vm.startPrank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);
        registry.updateSigner(MANUFACTURER_ID, newSigner);
        vm.stopPrank();

        assertEq(registry.getSigner(MANUFACTURER_ID), newSigner);
    }

    function test_UpdateSigner_EmitsEvent() public {
        address newSigner = makeAddr("newSigner");

        vm.startPrank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);

        vm.expectEmit(true, false, false, true);
        emit ManufacturerSignerUpdated(MANUFACTURER_ID, signer, newSigner);
        registry.updateSigner(MANUFACTURER_ID, newSigner);
        vm.stopPrank();
    }

    function test_UpdateSigner_RevertsWhenNotAdmin() public {
        bytes32 role = registry.ADMIN_ROLE();
        vm.prank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, role));
        registry.updateSigner(MANUFACTURER_ID, makeAddr("newSigner"));
    }

    function test_UpdateSigner_RevertsWhenNotRegistered() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ManufacturerRegistry.NotRegistered.selector, MANUFACTURER_ID));
        registry.updateSigner(MANUFACTURER_ID, signer);
    }

    function test_UpdateSigner_RevertsOnZeroAddress() public {
        vm.startPrank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);

        vm.expectRevert(ManufacturerRegistry.ZeroAddress.selector);
        registry.updateSigner(MANUFACTURER_ID, address(0));
        vm.stopPrank();
    }

    function test_UpdateSigner_DoesNotChangeActiveStatus() public {
        vm.startPrank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);
        registry.updateSigner(MANUFACTURER_ID, makeAddr("newSigner"));
        vm.stopPrank();

        assertTrue(registry.isActive(MANUFACTURER_ID));
    }

    function test_UpdateSigner_WorksWhileDeactivated() public {
        address newSigner = makeAddr("newSigner");

        vm.startPrank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);
        registry.deactivateManufacturer(MANUFACTURER_ID);
        registry.updateSigner(MANUFACTURER_ID, newSigner);
        vm.stopPrank();

        assertEq(registry.getSigner(MANUFACTURER_ID), newSigner);
        assertFalse(registry.isActive(MANUFACTURER_ID));
    }

    // ---------------------------------------------------------------------
    // deactivateManufacturer
    // ---------------------------------------------------------------------

    function test_DeactivateManufacturer_TogglesActiveFlagWithoutErasingSigner() public {
        vm.startPrank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);
        registry.deactivateManufacturer(MANUFACTURER_ID);
        vm.stopPrank();

        assertFalse(registry.isActive(MANUFACTURER_ID));
        assertEq(registry.getSigner(MANUFACTURER_ID), signer);
    }

    function test_DeactivateManufacturer_EmitsEvent() public {
        vm.startPrank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);

        vm.expectEmit(true, false, false, true);
        emit ManufacturerDeactivated(MANUFACTURER_ID);
        registry.deactivateManufacturer(MANUFACTURER_ID);
        vm.stopPrank();
    }

    function test_DeactivateManufacturer_RevertsWhenNotAdmin() public {
        bytes32 role = registry.ADMIN_ROLE();
        vm.prank(admin);
        registry.registerManufacturer(MANUFACTURER_ID, signer);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, role));
        registry.deactivateManufacturer(MANUFACTURER_ID);
    }

    function test_DeactivateManufacturer_RevertsWhenNotRegistered() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ManufacturerRegistry.NotRegistered.selector, MANUFACTURER_ID));
        registry.deactivateManufacturer(MANUFACTURER_ID);
    }

    // ---------------------------------------------------------------------
    // views on unregistered manufacturerId
    // ---------------------------------------------------------------------

    function test_Views_ReturnDefaultsForUnregisteredManufacturer() public view {
        assertEq(registry.getSigner(MANUFACTURER_ID), address(0));
        assertFalse(registry.isActive(MANUFACTURER_ID));
    }
}
