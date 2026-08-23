// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IIdentifierRegistry} from "./interfaces/IIdentifierRegistry.sol";
import {IManufacturerRegistry} from "./interfaces/IManufacturerRegistry.sol";
import {IZKVerifier} from "./interfaces/IZKVerifier.sol";

/// @notice Routes proof verification to the correct verifier by typeId - a ZK verifier
/// (consumer path) or a manufacturer signature check (factory-issued path). Holds no truth of
/// its own: IdentifierRegistry owns which verifier/status a typeId has, ManufacturerRegistry
/// owns which signer a manufacturerId has. PassportFactory never sees a verifier address,
/// only a typeId - this contract resolves that internally.
/// @dev verify() and verifyManufacturer() are separate entry points with no internal branching
/// on typeId: the caller already knows which path it's on from which of its own functions was
/// invoked. Unknown/inactive typeId reverts with a custom error, never returns false silently -
/// a silent false is indistinguishable from "proof didn't verify" and would hide a
/// misconfiguration.
contract VerifierRouter {
    IIdentifierRegistry public immutable identifierRegistry;
    IManufacturerRegistry public immutable manufacturerRegistry;

    error ZeroAddress();
    error UnknownIdentifierType(uint8 typeId);
    error InactiveIdentifierType(uint8 typeId);
    error UnknownManufacturer(bytes32 manufacturerId);
    error InactiveManufacturer(bytes32 manufacturerId);
    error PublicInputMismatch(uint8 typeId, bytes32 nullifier);

    constructor(address _identifierRegistry, address _manufacturerRegistry) {
        if (_identifierRegistry == address(0) || _manufacturerRegistry == address(0)) revert ZeroAddress();

        identifierRegistry = IIdentifierRegistry(_identifierRegistry);
        manufacturerRegistry = IManufacturerRegistry(_manufacturerRegistry);
    }

    /// @notice Verifies a consumer ZK proof for a device identifier. Routes to the verifier
    /// contract IdentifierRegistry has on file for typeId - PassportFactory never passes or
    /// sees that address directly.
    /// @dev proof/publicInputs are abi-encoded to keep this interface identifier-type-agnostic;
    /// decoded here into the SnarkJS Groth16 verifyProof shape. The public signal is checked
    /// against the caller-supplied nullifier so a valid proof for one nullifier can't be
    /// replayed to register a different, unproven nullifier value.
    function verify(uint8 typeId, bytes32 nullifier, bytes calldata proof, bytes calldata publicInputs)
        external
        view
        returns (bool)
    {
        address verifier = identifierRegistry.verifierOf(typeId);
        if (verifier == address(0)) revert UnknownIdentifierType(typeId);
        if (!identifierRegistry.statusOf(typeId)) revert InactiveIdentifierType(typeId);

        (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) =
            abi.decode(proof, (uint256[2], uint256[2][2], uint256[2]));
        uint256[1] memory publicSignals = abi.decode(publicInputs, (uint256[1]));

        if (publicSignals[0] != uint256(nullifier)) revert PublicInputMismatch(typeId, nullifier);

        return IZKVerifier(verifier).verifyProof(a, b, c, publicSignals);
    }

    /// @notice Verifies a manufacturer-signed device attestation in place of a ZK proof.
    /// @dev IdentifierRegistry's typeId 4 (MANUFACTURER) verifier field is vestigial - the
    /// signer lives in ManufacturerRegistry, keyed by manufacturerId, not by typeId. typeId is
    /// still checked against IdentifierRegistry so an unknown/inactive type reverts the same
    /// way it does for verify(), and still included in the signed digest for domain separation
    /// across identifier types.
    function verifyManufacturer(uint8 typeId, bytes32 manufacturerId, bytes32 nullifier, bytes calldata sig)
        external
        view
        returns (bool)
    {
        if (identifierRegistry.verifierOf(typeId) == address(0)) revert UnknownIdentifierType(typeId);
        if (!identifierRegistry.statusOf(typeId)) revert InactiveIdentifierType(typeId);

        address signer = manufacturerRegistry.getSigner(manufacturerId);
        if (signer == address(0)) revert UnknownManufacturer(manufacturerId);
        if (!manufacturerRegistry.isActive(manufacturerId)) revert InactiveManufacturer(manufacturerId);

        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encodePacked(typeId, manufacturerId, nullifier)));

        return ECDSA.recoverCalldata(digest, sig) == signer;
    }
}
