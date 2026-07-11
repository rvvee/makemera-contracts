// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Prevents double registration of the same physical device.
/// Nullifiers are scoped by identifier type to avoid cross-manufacturer serial collisions.
contract NullifierRegistry {
    address public immutable passportFactory;

    // typeId => nullifier => registered
    mapping(uint8 => mapping(bytes32 => bool)) private _nullifiers;

    // typeId => nullifier => block timestamp of registration
    mapping(uint8 => mapping(bytes32 => uint256)) private _registeredAt;

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
        if (_nullifiers[typeId][nullifier]) revert AlreadyRegistered(typeId, nullifier);
        _nullifiers[typeId][nullifier] = true;
        _registeredAt[typeId][nullifier] = block.timestamp;
        emit NullifierRegistered(typeId, nullifier, block.timestamp);
    }

    /// @notice Returns true if the nullifier has already been registered for this identifier type.
    function isRegistered(uint8 typeId, bytes32 nullifier) external view returns (bool) {
        return _nullifiers[typeId][nullifier];
    }

    /// @notice Returns the timestamp at which the nullifier was registered (0 if not registered).
    function registeredAt(uint8 typeId, bytes32 nullifier) external view returns (uint256) {
        return _registeredAt[typeId][nullifier];
    }
}
