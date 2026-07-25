// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Calling surface PassportFactory needs from VerifierRouter.
/// @dev Not yet implemented. VerifierRouter is expected to route by typeId to either a
/// ZK verifier (ZKVerifier*.sol, SnarkJS-generated) or a manufacturer signature check.
interface IVerifierRouter {
    function verify(uint8 typeId, bytes32 nullifier, bytes calldata proof, bytes calldata publicInputs)
        external
        view
        returns (bool);
}
