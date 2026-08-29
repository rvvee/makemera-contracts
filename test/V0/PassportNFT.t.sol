// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {PassportNFT} from "../../src/V0/PassportNFT.sol";
import {IssuanceSource} from "../../src/V0/interfaces/IPassportNFT.sol";

contract PassportNFTTest is Test {
    PassportNFT public passportNFT;

    address public factory = makeAddr("factory");
    address public owner = makeAddr("owner");
    address public stranger = makeAddr("stranger");

    uint8 constant TYPE_ID = 1;
    bytes32 constant NULLIFIER = keccak256("nullifier");
    string constant METADATA_URI = "ipfs://metadata";

    event PassportListedForSale(uint256 indexed tokenId);
    event PassportDelisted(uint256 indexed tokenId);

    function setUp() public {
        passportNFT = new PassportNFT(factory);
    }

    function _mint(address to) internal returns (uint256 tokenId) {
        vm.prank(factory);
        tokenId = passportNFT.mint(to, TYPE_ID, NULLIFIER, METADATA_URI, IssuanceSource.Consumer);
    }

    // ---------------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------------

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(PassportNFT.ZeroAddress.selector);
        new PassportNFT(address(0));
    }

    // ---------------------------------------------------------------------
    // mint
    // ---------------------------------------------------------------------

    function test_Mint_RevertsWhenNotFactory() public {
        vm.prank(stranger);
        vm.expectRevert(PassportNFT.Unauthorized.selector);
        passportNFT.mint(owner, TYPE_ID, NULLIFIER, METADATA_URI, IssuanceSource.Consumer);
    }

    function test_Mint_MintsTokenAndStoresPassportData() public {
        uint256 tokenId = _mint(owner);

        assertEq(passportNFT.ownerOf(tokenId), owner);
        assertEq(uint8(passportNFT.statusOf(tokenId)), uint8(PassportNFT.PassportStatus.ACTIVE));
        assertEq(passportNFT.typeIdOf(tokenId), TYPE_ID);
        assertEq(passportNFT.nullifierOf(tokenId), NULLIFIER);
        assertEq(passportNFT.tokenURI(tokenId), METADATA_URI);
        assertEq(uint8(passportNFT.issuedByOf(tokenId)), uint8(IssuanceSource.Consumer));
    }

    function test_Mint_TokenIdsIncrementSequentially() public {
        uint256 tokenId1 = _mint(owner);
        uint256 tokenId2 = _mint(owner);

        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
    }

    // ---------------------------------------------------------------------
    // listForSale
    // ---------------------------------------------------------------------

    function test_ListForSale_RevertsWhenNotOwner() public {
        uint256 tokenId = _mint(owner);

        vm.prank(stranger);
        vm.expectRevert(PassportNFT.Unauthorized.selector);
        passportNFT.listForSale(tokenId);
    }

    function test_ListForSale_RevertsWhenNotActive() public {
        uint256 tokenId = _mint(owner);

        vm.startPrank(owner);
        passportNFT.listForSale(tokenId);

        vm.expectRevert(abi.encodeWithSelector(PassportNFT.NotActive.selector, tokenId));
        passportNFT.listForSale(tokenId);
        vm.stopPrank();
    }

    function test_ListForSale_SetsStatusAndEmitsEvent() public {
        uint256 tokenId = _mint(owner);

        vm.expectEmit(true, false, false, true);
        emit PassportListedForSale(tokenId);

        vm.prank(owner);
        passportNFT.listForSale(tokenId);

        assertEq(uint8(passportNFT.statusOf(tokenId)), uint8(PassportNFT.PassportStatus.FOR_SALE));
    }

    // ---------------------------------------------------------------------
    // delist
    // ---------------------------------------------------------------------

    function test_Delist_RevertsWhenNotOwner() public {
        uint256 tokenId = _mint(owner);
        vm.prank(owner);
        passportNFT.listForSale(tokenId);

        vm.prank(stranger);
        vm.expectRevert(PassportNFT.Unauthorized.selector);
        passportNFT.delist(tokenId);
    }

    function test_Delist_RevertsWhenNotForSale() public {
        uint256 tokenId = _mint(owner);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(PassportNFT.NotForSale.selector, tokenId));
        passportNFT.delist(tokenId);
    }

    function test_Delist_SetsStatusAndEmitsEvent() public {
        uint256 tokenId = _mint(owner);
        vm.prank(owner);
        passportNFT.listForSale(tokenId);

        vm.expectEmit(true, false, false, true);
        emit PassportDelisted(tokenId);

        vm.prank(owner);
        passportNFT.delist(tokenId);

        assertEq(uint8(passportNFT.statusOf(tokenId)), uint8(PassportNFT.PassportStatus.ACTIVE));
    }

    // ---------------------------------------------------------------------
    // transfer / history (_update override)
    // ---------------------------------------------------------------------

    function test_Transfer_AppendsTransferRecordWithFromToTimestamp() public {
        uint256 tokenId = _mint(owner);

        vm.warp(12345);
        vm.prank(owner);
        passportNFT.transferFrom(owner, stranger, tokenId);

        PassportNFT.TransferRecord[] memory history = passportNFT.transferHistoryOf(tokenId);
        assertEq(history.length, 1);
        assertEq(history[0].from, owner);
        assertEq(history[0].to, stranger);
        assertEq(history[0].timestamp, 12345);
        assertEq(history[0].price, 0);
    }

    function test_Transfer_ResetsStatusToActiveRegardlessOfPriorStatus() public {
        uint256 tokenId = _mint(owner);
        vm.prank(owner);
        passportNFT.listForSale(tokenId);

        vm.prank(owner);
        passportNFT.transferFrom(owner, stranger, tokenId);

        assertEq(uint8(passportNFT.statusOf(tokenId)), uint8(PassportNFT.PassportStatus.ACTIVE));
    }

    // ---------------------------------------------------------------------
    // tokenURI
    // ---------------------------------------------------------------------

    function test_TokenURI_ReturnsStoredMetadataURI() public {
        uint256 tokenId = _mint(owner);
        assertEq(passportNFT.tokenURI(tokenId), METADATA_URI);
    }

    function test_TokenURI_RevertsForNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 999));
        passportNFT.tokenURI(999);
    }

    // ---------------------------------------------------------------------
    // transferHistoryOf
    // ---------------------------------------------------------------------

    function test_TransferHistoryOf_ReturnsEmptyArrayBeforeAnyTransfer() public {
        uint256 tokenId = _mint(owner);
        assertEq(passportNFT.transferHistoryOf(tokenId).length, 0);
    }

    function test_TransferHistoryOf_ReturnsAllRecordsAcrossMultipleTransfers() public {
        uint256 tokenId = _mint(owner);
        address buyer2 = makeAddr("buyer2");

        vm.prank(owner);
        passportNFT.transferFrom(owner, stranger, tokenId);

        vm.prank(stranger);
        passportNFT.transferFrom(stranger, buyer2, tokenId);

        PassportNFT.TransferRecord[] memory history = passportNFT.transferHistoryOf(tokenId);
        assertEq(history.length, 2);
        assertEq(history[0].from, owner);
        assertEq(history[0].to, stranger);
        assertEq(history[1].from, stranger);
        assertEq(history[1].to, buyer2);
    }
}
