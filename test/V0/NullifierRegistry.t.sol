// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NullifierRegistry} from "../../src/V0/NullifierRegistry.sol";

contract NullifierRegistryTest is Test {
    NullifierRegistry registry;
    address factory = address(0xF4C7024);
    uint8 constant TYPE_ID = 1;
    bytes32 constant NULLIFIER = keccak256("test-nullifier");

    function setUp() public {
        registry = new NullifierRegistry(factory);
    }

    function test_Register_StoresRegistrationAndEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit NullifierRegistry.NullifierRegistered(TYPE_ID, NULLIFIER, block.timestamp);

        vm.prank(factory);
        uint256 gasBefore = gasleft();
        registry.register(TYPE_ID, NULLIFIER);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("register() gas used", gasUsed);

        assertTrue(registry.isRegistered(TYPE_ID, NULLIFIER));
        assertEq(registry.registeredAt(TYPE_ID, NULLIFIER), block.timestamp);
    }

    function test_Register_RevertsWhenAlreadyRegistered() public {
        vm.prank(factory);
        registry.register(TYPE_ID, NULLIFIER);

        vm.prank(factory);
        vm.expectRevert(abi.encodeWithSelector(NullifierRegistry.AlreadyRegistered.selector, TYPE_ID, NULLIFIER));
        registry.register(TYPE_ID, NULLIFIER);
    }

    function test_Register_RevertsWhenNotFactory() public {
        vm.expectRevert(NullifierRegistry.Unauthorized.selector);
        registry.register(TYPE_ID, NULLIFIER);
    }

    function test_Register_ScopedByTypeId() public {
        vm.prank(factory);
        registry.register(TYPE_ID, NULLIFIER);

        assertFalse(registry.isRegistered(TYPE_ID + 1, NULLIFIER));
    }

    function test_Views_ReturnDefaultsForUnregistered() public view {
        assertFalse(registry.isRegistered(TYPE_ID, NULLIFIER));
        assertEq(registry.registeredAt(TYPE_ID, NULLIFIER), 0);
    }
}
