// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PassportFactory} from "../../src/V0/PassportFactory.sol";
import {IssuanceSource} from "../../src/V0/interfaces/IPassportNFT.sol";

contract MockIdentifierRegistry {
    mapping(uint8 => bool) public statusOf;

    function setStatus(uint8 typeId, bool status) external {
        statusOf[typeId] = status;
    }

    function verifierOf(uint8) external pure returns (address) {
        return address(0);
    }

    function tierOf(uint8) external pure returns (uint8) {
        return 0;
    }
}

contract MockVerifierRouter {
    bool public verifyResult;
    bool public verifyManufacturerResult;

    function setVerifyResult(bool result) external {
        verifyResult = result;
    }

    function setVerifyManufacturerResult(bool result) external {
        verifyManufacturerResult = result;
    }

    function verify(uint8, bytes32, bytes calldata, bytes calldata) external view returns (bool) {
        return verifyResult;
    }

    function verifyManufacturer(uint8, bytes32, bytes32, bytes calldata) external view returns (bool) {
        return verifyManufacturerResult;
    }
}

contract MockNullifierRegistry {
    uint8 public lastTypeId;
    bytes32 public lastNullifier;
    uint256 public registerCallCount;

    function register(uint8 typeId, bytes32 nullifier) external {
        lastTypeId = typeId;
        lastNullifier = nullifier;
        registerCallCount++;
    }
}

contract MockPassportNFT {
    uint256 public nextTokenId = 1;

    address public lastTo;
    uint8 public lastTypeId;
    bytes32 public lastNullifier;
    string public lastMetadataURI;
    IssuanceSource public lastIssuedBy;
    uint256 public mintCallCount;

    function mint(address to, uint8 typeId, bytes32 nullifier, string calldata metadataURI, IssuanceSource issuedBy)
        external
        returns (uint256 tokenId)
    {
        tokenId = nextTokenId++;
        lastTo = to;
        lastTypeId = typeId;
        lastNullifier = nullifier;
        lastMetadataURI = metadataURI;
        lastIssuedBy = issuedBy;
        mintCallCount++;
    }
}

contract PassportFactoryTest is Test {
    PassportFactory public factory;
    MockIdentifierRegistry public identifierRegistry;
    MockVerifierRouter public verifierRouter;
    MockNullifierRegistry public nullifierRegistry;
    MockPassportNFT public passportNFT;

    address public to = makeAddr("to");

    uint8 constant TYPE_ID = 1;
    bytes32 constant NULLIFIER = keccak256("nullifier");
    bytes32 constant MANUFACTURER_ID = keccak256("apple");
    string constant METADATA_URI = "ipfs://metadata";
    bytes constant PROOF = "proof";
    bytes constant PUBLIC_INPUTS = "publicInputs";
    bytes constant SIG = "sig";

    event PassportCreated(
        uint8 indexed typeId, bytes32 indexed nullifier, address indexed to, uint256 tokenId, IssuanceSource issuedBy
    );

    function setUp() public {
        identifierRegistry = new MockIdentifierRegistry();
        verifierRouter = new MockVerifierRouter();
        nullifierRegistry = new MockNullifierRegistry();
        passportNFT = new MockPassportNFT();

        factory = new PassportFactory(
            address(identifierRegistry), address(verifierRouter), address(nullifierRegistry), address(passportNFT)
        );
    }

    // ---------------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------------

    function test_Constructor_RevertsOnZeroIdentifierRegistry() public {
        vm.expectRevert(PassportFactory.ZeroAddress.selector);
        new PassportFactory(address(0), address(verifierRouter), address(nullifierRegistry), address(passportNFT));
    }

    function test_Constructor_RevertsOnZeroVerifierRouter() public {
        vm.expectRevert(PassportFactory.ZeroAddress.selector);
        new PassportFactory(address(identifierRegistry), address(0), address(nullifierRegistry), address(passportNFT));
    }

    function test_Constructor_RevertsOnZeroNullifierRegistry() public {
        vm.expectRevert(PassportFactory.ZeroAddress.selector);
        new PassportFactory(address(identifierRegistry), address(verifierRouter), address(0), address(passportNFT));
    }

    function test_Constructor_RevertsOnZeroPassportNFT() public {
        vm.expectRevert(PassportFactory.ZeroAddress.selector);
        new PassportFactory(address(identifierRegistry), address(verifierRouter), address(nullifierRegistry), address(0));
    }

    // ---------------------------------------------------------------------
    // createPassport
    // ---------------------------------------------------------------------

    function test_CreatePassport_RevertsWhenTypeInactive() public {
        vm.expectRevert(abi.encodeWithSelector(PassportFactory.IdentifierTypeInactive.selector, TYPE_ID));
        factory.createPassport(TYPE_ID, NULLIFIER, PROOF, PUBLIC_INPUTS, to, METADATA_URI);
    }

    function test_CreatePassport_RevertsWhenVerificationFails() public {
        identifierRegistry.setStatus(TYPE_ID, true);
        verifierRouter.setVerifyResult(false);

        vm.expectRevert(abi.encodeWithSelector(PassportFactory.VerificationFailed.selector, TYPE_ID));
        factory.createPassport(TYPE_ID, NULLIFIER, PROOF, PUBLIC_INPUTS, to, METADATA_URI);
    }

    function test_CreatePassport_RegistersNullifierAndMintsWithConsumerSource() public {
        identifierRegistry.setStatus(TYPE_ID, true);
        verifierRouter.setVerifyResult(true);

        factory.createPassport(TYPE_ID, NULLIFIER, PROOF, PUBLIC_INPUTS, to, METADATA_URI);

        assertEq(nullifierRegistry.registerCallCount(), 1);
        assertEq(nullifierRegistry.lastTypeId(), TYPE_ID);
        assertEq(nullifierRegistry.lastNullifier(), NULLIFIER);

        assertEq(passportNFT.mintCallCount(), 1);
        assertEq(passportNFT.lastTo(), to);
        assertEq(passportNFT.lastTypeId(), TYPE_ID);
        assertEq(passportNFT.lastNullifier(), NULLIFIER);
        assertEq(passportNFT.lastMetadataURI(), METADATA_URI);
        assertEq(uint8(passportNFT.lastIssuedBy()), uint8(IssuanceSource.Consumer));
    }

    function test_CreatePassport_EmitsEvent() public {
        identifierRegistry.setStatus(TYPE_ID, true);
        verifierRouter.setVerifyResult(true);

        vm.expectEmit(true, true, true, true);
        emit PassportCreated(TYPE_ID, NULLIFIER, to, 1, IssuanceSource.Consumer);

        factory.createPassport(TYPE_ID, NULLIFIER, PROOF, PUBLIC_INPUTS, to, METADATA_URI);
    }

    function test_CreatePassport_ReturnsTokenId() public {
        identifierRegistry.setStatus(TYPE_ID, true);
        verifierRouter.setVerifyResult(true);

        uint256 tokenId = factory.createPassport(TYPE_ID, NULLIFIER, PROOF, PUBLIC_INPUTS, to, METADATA_URI);
        assertEq(tokenId, 1);
    }

    // ---------------------------------------------------------------------
    // createManufacturerPassport
    // ---------------------------------------------------------------------

    function test_CreateManufacturerPassport_RevertsWhenTypeInactive() public {
        vm.expectRevert(abi.encodeWithSelector(PassportFactory.IdentifierTypeInactive.selector, TYPE_ID));
        factory.createManufacturerPassport(TYPE_ID, MANUFACTURER_ID, NULLIFIER, SIG, to, METADATA_URI);
    }

    function test_CreateManufacturerPassport_RevertsWhenVerificationFails() public {
        identifierRegistry.setStatus(TYPE_ID, true);
        verifierRouter.setVerifyManufacturerResult(false);

        vm.expectRevert(abi.encodeWithSelector(PassportFactory.VerificationFailed.selector, TYPE_ID));
        factory.createManufacturerPassport(TYPE_ID, MANUFACTURER_ID, NULLIFIER, SIG, to, METADATA_URI);
    }

    function test_CreateManufacturerPassport_RegistersNullifierAndMintsWithManufacturerSource() public {
        identifierRegistry.setStatus(TYPE_ID, true);
        verifierRouter.setVerifyManufacturerResult(true);

        factory.createManufacturerPassport(TYPE_ID, MANUFACTURER_ID, NULLIFIER, SIG, to, METADATA_URI);

        assertEq(nullifierRegistry.registerCallCount(), 1);
        assertEq(nullifierRegistry.lastTypeId(), TYPE_ID);
        assertEq(nullifierRegistry.lastNullifier(), NULLIFIER);

        assertEq(passportNFT.mintCallCount(), 1);
        assertEq(passportNFT.lastTo(), to);
        assertEq(passportNFT.lastTypeId(), TYPE_ID);
        assertEq(passportNFT.lastNullifier(), NULLIFIER);
        assertEq(passportNFT.lastMetadataURI(), METADATA_URI);
        assertEq(uint8(passportNFT.lastIssuedBy()), uint8(IssuanceSource.Manufacturer));
    }

    function test_CreateManufacturerPassport_EmitsEvent() public {
        identifierRegistry.setStatus(TYPE_ID, true);
        verifierRouter.setVerifyManufacturerResult(true);

        vm.expectEmit(true, true, true, true);
        emit PassportCreated(TYPE_ID, NULLIFIER, to, 1, IssuanceSource.Manufacturer);

        factory.createManufacturerPassport(TYPE_ID, MANUFACTURER_ID, NULLIFIER, SIG, to, METADATA_URI);
    }

    function test_CreateManufacturerPassport_ReturnsTokenId() public {
        identifierRegistry.setStatus(TYPE_ID, true);
        verifierRouter.setVerifyManufacturerResult(true);

        uint256 tokenId = factory.createManufacturerPassport(TYPE_ID, MANUFACTURER_ID, NULLIFIER, SIG, to, METADATA_URI);
        assertEq(tokenId, 1);
    }
}
