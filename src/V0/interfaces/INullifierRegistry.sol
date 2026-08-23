// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Calling surface PassportFactory needs from NullifierRegistry.
interface INullifierRegistry {
    function register(uint8 typeId, bytes32 nullifier) external;
}
