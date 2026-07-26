// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IIdentifierRegistry} from "./interfaces/IIdentifierRegistry.sol";
import {IVerifierRouter} from "./interfaces/IVerifierRouter.sol";
import {IPassportNFT} from "./interfaces/IPassportNFT.sol";
import {NullifierRegistry} from "./NullifierRegistry.sol";

/// @notice Orchestrates passport creation. Holds no truth of its own - it reads
/// IdentifierRegistry, routes to VerifierRouter, writes NullifierRegistry, and mints via
/// PassportNFT. Theft state is never touched here; that lives solely in TheftRegistry.
/// @dev All dependency addresses are immutable, so PassportFactory, NullifierRegistry, and
/// PassportNFT must be deployed in an order that resolves their circular references (e.g.
/// a deploy script that predicts PassportFactory's address via nonce before deploying the
/// contracts that point back at it).
contract PassportFactory {
    IIdentifierRegistry public immutable identifierRegistry;
    IVerifierRouter public immutable verifierRouter;
    NullifierRegistry public immutable nullifierRegistry;
    IPassportNFT public immutable passportNFT;

    event PassportCreated(uint8 indexed typeId, bytes32 indexed nullifier, address indexed to, uint256 tokenId);

    error ZeroAddress();
    error IdentifierTypeInactive(uint8 typeId);
    error VerificationFailed(uint8 typeId);

    constructor(address _identifierRegistry, address _verifierRouter, address _nullifierRegistry, address _passportNFT) {
        if (
            _identifierRegistry == address(0) || _verifierRouter == address(0) || _nullifierRegistry == address(0)
                || _passportNFT == address(0)
        ) {
            revert ZeroAddress();
        }

        identifierRegistry = IIdentifierRegistry(_identifierRegistry);
        verifierRouter = IVerifierRouter(_verifierRouter);
        nullifierRegistry = NullifierRegistry(_nullifierRegistry);
        passportNFT = IPassportNFT(_passportNFT);
    }

    /// @notice Verifies a device proof, registers its nullifier, and mints the passport NFT.
    /// @dev The only path that writes to NullifierRegistry and the only minter PassportNFT
    /// should trust. Rejects types deactivated via IdentifierRegistry.setActive, so a
    /// compromised verifier can be shut off without touching this contract.
    function createPassport(
        uint8 typeId,
        bytes32 nullifier,
        bytes calldata proof,
        bytes calldata publicInputs,
        address to,
        string calldata metadataURI
    ) external returns (uint256 tokenId) {
        if (!identifierRegistry.statusOf(typeId)) revert IdentifierTypeInactive(typeId);

        if (!verifierRouter.verify(typeId, nullifier, proof, publicInputs)) revert VerificationFailed(typeId);
        nullifierRegistry.register(typeId, nullifier);

        tokenId = passportNFT.mint(to, typeId, nullifier, metadataURI);

        emit PassportCreated(typeId, nullifier, to, tokenId);
    }
}
