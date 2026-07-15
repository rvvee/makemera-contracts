// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Registry of supported device identifier types (IMEI, serial, MAC, manufacturer, custom).
/// Extensibility point: new identifier types are registered here, never hardcoded, so adding a
/// device category never requires redeploying PassportFactory or VerifierRouter.
contract IdentifierRegistry is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // typeId => verifier contract address (address(0) if unregistered)
    mapping(uint8 => address) private _verifiers;

    // typeId => verification tier (1-3)
    mapping(uint8 => uint8) private _tiers;

    // typeId => active status
    mapping(uint8 => bool) private _status;

    event IdentifierTypeRegistered(uint8 indexed typeId, uint8 tier, address verifier);
    event IdentifierTypeStatusChanged(uint8 indexed typeId, bool status);
    event IdentifierTypeVerifierUpdated(uint8 indexed typeId, address oldVerifier, address newVerifier);

    error AlreadyRegistered(uint8 typeId);
    error NotRegistered(uint8 typeId);
    error ZeroAddress();

    constructor(address _admin) {
        if (_admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    /// @notice Register a new identifier type. Only callable by an admin.
    function registerType(uint8 typeId, uint8 tier, address verifier) external onlyRole(ADMIN_ROLE) {
        if (_verifiers[typeId] != address(0)) revert AlreadyRegistered(typeId);
        if (verifier == address(0)) revert ZeroAddress();

        _verifiers[typeId] = verifier;
        _tiers[typeId] = tier;
        _status[typeId] = true;
        emit IdentifierTypeRegistered(typeId, tier, verifier);
    }

    /// @notice Enable or disable an identifier type without erasing its record. Only callable by an admin.
    function setStatus(uint8 typeId, bool status) external onlyRole(ADMIN_ROLE) {
        if (_verifiers[typeId] == address(0)) revert NotRegistered(typeId);
        _status[typeId] = status;
        emit IdentifierTypeStatusChanged(typeId, status);
    }

    /// @notice Point an identifier type at a new verifier contract. Only callable by an admin.
    function setVerifier(uint8 typeId, address verifier) external onlyRole(ADMIN_ROLE) {
        address old = _verifiers[typeId];
        if (old == address(0)) revert NotRegistered(typeId);
        if (verifier == address(0)) revert ZeroAddress();

        _verifiers[typeId] = verifier;
        emit IdentifierTypeVerifierUpdated(typeId, old, verifier);
    }

    /// @notice Returns true if the identifier type is registered and active.
    function statusOf(uint8 typeId) external view returns (bool) {
        return _status[typeId];
    }

    /// @notice Returns the verifier contract address for a given typeId (address(0) if unregistered).
    function verifierOf(uint8 typeId) external view returns (address) {
        return _verifiers[typeId];
    }

    /// @notice Returns the verification tier (1-3) for a given typeId.
    function tierOf(uint8 typeId) external view returns (uint8) {
        return _tiers[typeId];
    }
}
