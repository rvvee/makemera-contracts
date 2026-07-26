// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IPassportNFT, IssuanceSource} from "./interfaces/IPassportNFT.sol";

/// @notice ERC-721 passport with full transfer history. Owns only the ownership/sale
/// lifecycle (CREATED -> ACTIVE -> FOR_SALE -> TRANSFERRED -> ACTIVE) - never theft state,
/// which is TheftRegistry's sole responsibility (single-writer rule, see CLAUDE.md).
contract PassportNFT is ERC721, IPassportNFT {
    enum PassportStatus {
        CREATED,
        ACTIVE,
        FOR_SALE,
        TRANSFERRED
    }

    struct TransferRecord {
        address from;
        address to;
        uint256 timestamp;
        uint256 price; // 0 for a plain transferFrom; a marketplace-aware sale flow can extend this later
    }

    struct Passport {
        uint8 typeId;
        bytes32 nullifier;
        string metadataURI;
        IssuanceSource issuedBy;
        PassportStatus status;
    }

    address public immutable passportFactory;

    uint256 private _nextTokenId = 1;

    mapping(uint256 => Passport) private _passports;
    mapping(uint256 => TransferRecord[]) private _transferHistory;

    event PassportListedForSale(uint256 indexed tokenId);
    event PassportDelisted(uint256 indexed tokenId);

    error ZeroAddress();
    error Unauthorized();
    error NotActive(uint256 tokenId);
    error NotForSale(uint256 tokenId);

    modifier onlyFactory() {
        if (msg.sender != passportFactory) revert Unauthorized();
        _;
    }

    constructor(address _passportFactory) ERC721("makemera Passport", "MMP") {
        if (_passportFactory == address(0)) revert ZeroAddress();
        passportFactory = _passportFactory;
    }

    /// @notice Mints a passport. Only callable by PassportFactory - the sole minter this
    /// contract trusts, per the single-writer rule for ownership/sale state.
    function mint(
        address to,
        uint8 typeId,
        bytes32 nullifier,
        string calldata metadataURI,
        IssuanceSource issuedBy
    ) external onlyFactory returns (uint256 tokenId) {
        tokenId = _nextTokenId++;

        _passports[tokenId] = Passport({
            typeId: typeId,
            nullifier: nullifier,
            metadataURI: metadataURI,
            issuedBy: issuedBy,
            status: PassportStatus.ACTIVE
        });

        _safeMint(to, tokenId);
    }

    /// @notice List an ACTIVE passport for sale. Only the current owner.
    function listForSale(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert Unauthorized();
        if (_passports[tokenId].status != PassportStatus.ACTIVE) revert NotActive(tokenId);

        _passports[tokenId].status = PassportStatus.FOR_SALE;
        emit PassportListedForSale(tokenId);
    }

    /// @notice Delist a FOR_SALE passport, returning it to ACTIVE. Only the current owner.
    function delist(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert Unauthorized();
        if (_passports[tokenId].status != PassportStatus.FOR_SALE) revert NotForSale(tokenId);

        _passports[tokenId].status = PassportStatus.ACTIVE;
        emit PassportDelisted(tokenId);
    }

    /// @dev Every real transfer (mint excluded, from == address(0)) appends a TransferRecord
    /// and cycles status through TRANSFERRED back to ACTIVE for the new owner, matching the
    /// documented state machine without a separate marketplace-only transfer function.
    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = super._update(to, tokenId, auth);

        if (from != address(0)) {
            _transferHistory[tokenId].push(TransferRecord({from: from, to: to, timestamp: block.timestamp, price: 0}));
            _passports[tokenId].status = PassportStatus.ACTIVE;
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _passports[tokenId].metadataURI;
    }

    function statusOf(uint256 tokenId) external view returns (PassportStatus) {
        return _passports[tokenId].status;
    }

    function typeIdOf(uint256 tokenId) external view returns (uint8) {
        return _passports[tokenId].typeId;
    }

    function nullifierOf(uint256 tokenId) external view returns (bytes32) {
        return _passports[tokenId].nullifier;
    }

    function issuedByOf(uint256 tokenId) external view returns (IssuanceSource) {
        return _passports[tokenId].issuedBy;
    }

    function transferHistoryOf(uint256 tokenId) external view returns (TransferRecord[] memory) {
        return _transferHistory[tokenId];
    }
}
