// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @notice Sole writer of theft truth. Independent state machine from PassportNFT's
/// ownership/sale lifecycle - single-writer rule (see CLAUDE.md). PassportNFT never stores a
/// stolen/disputed value; the two are merged only at read time by getDisplayStatus(passport,
/// theftStatus) in packages/core, never duplicated here or per app.
/// @dev Critical security property: reportStolen, resolveDispute, and markRecovered all check
/// PassportNFT.ownerOf first. Only the current holder can act, and that ability is lost the
/// moment the passport transfers - a thief who has the device but not the wallet can never
/// flag, resolve, or clear anything.
contract TheftRegistry {
    enum TheftStatus {
        CLEAN,
        STOLEN,
        DISPUTED,
        RECOVERED
    }

    struct Flag {
        TheftStatus status;
        address reportedBy;
        uint256 reportedAt;
        address disputedBy;
        uint256 disputedAt;
    }

    IERC721 public immutable passportNFT;

    mapping(uint256 => Flag) private _flags;

    event ReportedStolen(uint256 indexed tokenId, address indexed reportedBy, uint256 timestamp);
    event Disputed(uint256 indexed tokenId, address indexed disputedBy, uint256 timestamp);
    event DisputeResolved(uint256 indexed tokenId, address indexed resolvedBy, bool upheld);
    event Recovered(uint256 indexed tokenId, address indexed recoveredBy);

    error ZeroAddress();
    error NotPassportHolder(uint256 tokenId);
    error NotClean(uint256 tokenId);
    error NotStolen(uint256 tokenId);
    error NotDisputed(uint256 tokenId);

    modifier onlyPassportHolder(uint256 tokenId) {
        if (passportNFT.ownerOf(tokenId) != msg.sender) revert NotPassportHolder(tokenId);
        _;
    }

    constructor(address _passportNFT) {
        if (_passportNFT == address(0)) revert ZeroAddress();
        passportNFT = IERC721(_passportNFT);
    }

    /// @notice Flags a passport as stolen. Only the current holder - see contract-level dev
    /// note on why this is the property that makes the flag meaningful.
    function reportStolen(uint256 tokenId) external onlyPassportHolder(tokenId) {
        if (_flags[tokenId].status != TheftStatus.CLEAN) revert NotClean(tokenId);

        _flags[tokenId].status = TheftStatus.STOLEN;
        _flags[tokenId].reportedBy = msg.sender;
        _flags[tokenId].reportedAt = block.timestamp;

        emit ReportedStolen(tokenId, msg.sender, block.timestamp);
    }

    /// @notice Challenges a stolen flag. Anyone can dispute - typically a prospective buyer
    /// who believes the flag is wrong. Mandatory legal safeguard against stolen-flag
    /// liability (see About.md); UI must surface this state, never hide it.
    function disputeFlag(uint256 tokenId) external {
        if (_flags[tokenId].status != TheftStatus.STOLEN) revert NotStolen(tokenId);

        _flags[tokenId].status = TheftStatus.DISPUTED;
        _flags[tokenId].disputedBy = msg.sender;
        _flags[tokenId].disputedAt = block.timestamp;

        emit Disputed(tokenId, msg.sender, block.timestamp);
    }

    /// @notice Resolves a dispute. Only the passport holder (the original reporter, since
    /// reporting is holder-gated). uphold=true returns to STOLEN, uphold=false clears to
    /// CLEAN. A time-based fallback for a holder who never resolves is an apps/api concern
    /// (disputeResolution.ts), not yet reflected here - open design question.
    function resolveDispute(uint256 tokenId, bool uphold) external onlyPassportHolder(tokenId) {
        if (_flags[tokenId].status != TheftStatus.DISPUTED) revert NotDisputed(tokenId);

        _flags[tokenId].status = uphold ? TheftStatus.STOLEN : TheftStatus.CLEAN;
        emit DisputeResolved(tokenId, msg.sender, uphold);
    }

    /// @notice Clears a stolen flag once the device is recovered. Only the passport holder.
    function markRecovered(uint256 tokenId) external onlyPassportHolder(tokenId) {
        if (_flags[tokenId].status != TheftStatus.STOLEN) revert NotStolen(tokenId);

        _flags[tokenId].status = TheftStatus.RECOVERED;
        emit Recovered(tokenId, msg.sender);
    }

    function statusOf(uint256 tokenId) external view returns (TheftStatus) {
        return _flags[tokenId].status;
    }

    function reportedByOf(uint256 tokenId) external view returns (address) {
        return _flags[tokenId].reportedBy;
    }

    function reportedAtOf(uint256 tokenId) external view returns (uint256) {
        return _flags[tokenId].reportedAt;
    }

    function disputedByOf(uint256 tokenId) external view returns (address) {
        return _flags[tokenId].disputedBy;
    }

    function disputedAtOf(uint256 tokenId) external view returns (uint256) {
        return _flags[tokenId].disputedAt;
    }
}
