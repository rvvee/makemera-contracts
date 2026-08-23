// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Calling surface VerifierRouter needs from ManufacturerRegistry.
interface IManufacturerRegistry {
    function getSigner(bytes32 manufacturerId) external view returns (address);
    function isActive(bytes32 manufacturerId) external view returns (bool);
}
