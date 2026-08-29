// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Prevents double registration of the same physical device.
/// Nullifiers are scoped by identifier type to avoid cross-manufacturer serial collisions.
contract NullifierRegistry {
    address public immutable passportFactory;

    // registered + registeredAt packed into one 32-byte slot, so register() costs
    // one SSTORE instead of two.
    struct Registration {
        bool registered;
        uint96 registeredAt;
    }

    // typeId => nullifier => registration
    mapping(uint8 => mapping(bytes32 => Registration)) private _registrations;

    event NullifierRegistered(uint8 indexed typeId, bytes32 indexed nullifier, uint256 timestamp);

    error AlreadyRegistered(uint8 typeId, bytes32 nullifier);
    error Unauthorized();
    error ZeroAddress();

    modifier onlyFactory() {
        if (msg.sender != passportFactory) revert Unauthorized();
        _;
    }

    constructor(address _passportFactory) {
        if (_passportFactory == address(0)) revert ZeroAddress();
        passportFactory = _passportFactory;
    }

    /// @notice Register a nullifier for a given identifier type. Only callable by PassportFactory.
    function register(uint8 typeId, bytes32 nullifier) external onlyFactory {
        if (_registrations[typeId][nullifier].registered) revert AlreadyRegistered(typeId, nullifier);
        _registrations[typeId][nullifier] = Registration({registered: true, registeredAt: uint96(block.timestamp)});
        emit NullifierRegistered(typeId, nullifier, block.timestamp);
    }

    /// @notice Returns true if the nullifier has already been registered for this identifier type.
    function isRegistered(uint8 typeId, bytes32 nullifier) external view returns (bool) {
        return _registrations[typeId][nullifier].registered;
    }

    /// @notice Returns the timestamp at which the nullifier was registered (0 if not registered).
    function registeredAt(uint8 typeId, bytes32 nullifier) external view returns (uint256) {
        return _registrations[typeId][nullifier].registeredAt;
    }
}
