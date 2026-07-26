// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Which trust path produced a passport - proof-of-knowledge (consumer) or a
/// brand-signed attestation (manufacturer). Recorded per-token so provenance is never left
/// to inference from typeId or which PassportFactory function was called.
enum IssuanceSource {
    Consumer,
    Manufacturer
}

/// @notice Calling surface PassportFactory needs from PassportNFT.
/// @dev Not yet implemented. PassportNFT owns only the ownership/sale lifecycle
/// (CREATED -> ACTIVE -> FOR_SALE -> TRANSFERRED -> ACTIVE) and must trust exactly one
/// minter: PassportFactory. It never writes theft state - that belongs to TheftRegistry.
interface IPassportNFT {
    function mint(
        address to,
        uint8 typeId,
        bytes32 nullifier,
        string calldata metadataURI,
        IssuanceSource issuedBy
    ) external returns (uint256 tokenId);
}
