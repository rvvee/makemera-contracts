// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Calling surface VerifierRouter needs from a SnarkJS-generated Groth16 verifier
/// (ZKVerifier*.sol). Matches the standard `snarkjs zkey export solidityverifier` output shape.
/// @dev Unconfirmed until packages/circuits exports a real verifier - see CLAUDE.md.
interface IZKVerifier {
    function verifyProof(uint256[2] calldata a, uint256[2][2] calldata b, uint256[2] calldata c, uint256[1] calldata publicSignals)
        external
        view
        returns (bool);
}
