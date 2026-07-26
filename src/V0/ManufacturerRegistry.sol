// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Per-manufacturer signer keys for manufacturer-issued passports (Apple, Samsung,
/// Google, ...). Split out from IdentifierRegistry because a single global signer per
/// identifier type doesn't scale across manufacturers - each brand needs its own key.
/// Signer addresses are public keys by design, not sensitive like protocolKey.
contract ManufacturerRegistry is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // manufacturerId => signer address (address(0) if unregistered)
    mapping(bytes32 => address) private _signers;

    // manufacturerId => active status
    mapping(bytes32 => bool) private _active;

    event ManufacturerRegistered(bytes32 indexed manufacturerId, address signer);
    event ManufacturerSignerUpdated(bytes32 indexed manufacturerId, address oldSigner, address newSigner);
    event ManufacturerDeactivated(bytes32 indexed manufacturerId);

    error AlreadyRegistered(bytes32 manufacturerId);
    error NotRegistered(bytes32 manufacturerId);
    error ZeroAddress();

    constructor(address _admin) {
        if (_admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    /// @notice Register a new manufacturer with its signer key. Only callable by an admin.
    function registerManufacturer(bytes32 manufacturerId, address signer) external onlyRole(ADMIN_ROLE) {
        if (_signers[manufacturerId] != address(0)) revert AlreadyRegistered(manufacturerId);
        if (signer == address(0)) revert ZeroAddress();

        _signers[manufacturerId] = signer;
        _active[manufacturerId] = true;
        emit ManufacturerRegistered(manufacturerId, signer);
    }

    /// @notice Rotate a manufacturer's signer key. Only callable by an admin.
    function updateSigner(bytes32 manufacturerId, address signer) external onlyRole(ADMIN_ROLE) {
        address old = _signers[manufacturerId];
        if (old == address(0)) revert NotRegistered(manufacturerId);
        if (signer == address(0)) revert ZeroAddress();

        _signers[manufacturerId] = signer;
        emit ManufacturerSignerUpdated(manufacturerId, old, signer);
    }

    /// @notice Deactivate a manufacturer without erasing its record. Only callable by an admin.
    function deactivateManufacturer(bytes32 manufacturerId) external onlyRole(ADMIN_ROLE) {
        if (_signers[manufacturerId] == address(0)) revert NotRegistered(manufacturerId);
        _active[manufacturerId] = false;
        emit ManufacturerDeactivated(manufacturerId);
    }

    /// @notice Returns the signer address for a given manufacturerId (address(0) if unregistered).
    function getSigner(bytes32 manufacturerId) external view returns (address) {
        return _signers[manufacturerId];
    }

    /// @notice Returns true if the manufacturer is registered and active.
    function isActive(bytes32 manufacturerId) external view returns (bool) {
        return _active[manufacturerId];
    }
}
