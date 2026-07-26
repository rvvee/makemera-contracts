// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Calling surface PassportFactory needs from IdentifierRegistry.
interface IIdentifierRegistry {
    function statusOf(uint8 typeId) external view returns (bool);
    function verifierOf(uint8 typeId) external view returns (address);
    function tierOf(uint8 typeId) external view returns (uint8);
}
