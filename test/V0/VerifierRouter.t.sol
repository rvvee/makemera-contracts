// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {VerifierRouter} from "../../src/V0/VerifierRouter.sol";
import {IdentifierRegistry} from "../../src/V0/IdentifierRegistry.sol";
import {ManufacturerRegistry} from "../../src/V0/ManufacturerRegistry.sol";
import {IZKVerifier} from "../../src/V0/interfaces/IZKVerifier.sol";

contract MockZKVerifier is IZKVerifier {
    bool public result;

    constructor(bool _result) {
        result = _result;
    }

    function setResult(bool _result) external {
        result = _result;
    }

    function verifyProof(uint256[2] calldata, uint256[2][2] calldata, uint256[2] calldata, uint256[1] calldata)
        external
        view
        returns (bool)
    {
        return result;
    }
}

contract VerifierRouterTest is Test {
    VerifierRouter public router;
    IdentifierRegistry public identifierRegistry;
    ManufacturerRegistry public manufacturerRegistry;
    MockZKVerifier public mockVerifier;

    address public admin = makeAddr("admin");

    uint8 constant TYPE_ID = 1;
    uint8 constant TIER = 1;
    bytes32 constant NULLIFIER = keccak256("nullifier");
    bytes32 constant MANUFACTURER_ID = keccak256("apple");

    uint256 constant SIGNER_KEY = 0xA11CE;

    function setUp() public {
        identifierRegistry = new IdentifierRegistry(admin);
        manufacturerRegistry = new ManufacturerRegistry(admin);
        mockVerifier = new MockZKVerifier(true);
        router = new VerifierRouter(address(identifierRegistry), address(manufacturerRegistry));
    }

    function _registerActiveType() internal {
        vm.prank(admin);
        identifierRegistry.registerType(TYPE_ID, TIER, address(mockVerifier));
    }

    function _encodeProof() internal pure returns (bytes memory) {
        uint256[2] memory a = [uint256(1), uint256(2)];
        uint256[2][2] memory b = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory c = [uint256(7), uint256(8)];
        return abi.encode(a, b, c);
    }

    function _encodePublicInputs(bytes32 nullifier) internal pure returns (bytes memory) {
        uint256[1] memory publicSignals = [uint256(nullifier)];
        return abi.encode(publicSignals);
    }

    function _signManufacturer(uint256 privateKey, uint8 typeId_, bytes32 manufacturerId_, bytes32 nullifier_)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encodePacked(typeId_, manufacturerId_, nullifier_)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    // ---------------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------------

    function test_Constructor_RevertsOnZeroIdentifierRegistry() public {
        vm.expectRevert(VerifierRouter.ZeroAddress.selector);
        new VerifierRouter(address(0), address(manufacturerRegistry));
    }

    function test_Constructor_RevertsOnZeroManufacturerRegistry() public {
        vm.expectRevert(VerifierRouter.ZeroAddress.selector);
        new VerifierRouter(address(identifierRegistry), address(0));
    }

    // ---------------------------------------------------------------------
    // verify
    // ---------------------------------------------------------------------

    function test_Verify_RevertsWhenTypeUnknown() public {
        vm.expectRevert(abi.encodeWithSelector(VerifierRouter.UnknownIdentifierType.selector, TYPE_ID));
        router.verify(TYPE_ID, NULLIFIER, _encodeProof(), _encodePublicInputs(NULLIFIER));
    }

    function test_Verify_RevertsWhenTypeInactive() public {
        _registerActiveType();
        vm.prank(admin);
        identifierRegistry.setStatus(TYPE_ID, false);

        vm.expectRevert(abi.encodeWithSelector(VerifierRouter.InactiveIdentifierType.selector, TYPE_ID));
        router.verify(TYPE_ID, NULLIFIER, _encodeProof(), _encodePublicInputs(NULLIFIER));
    }

    function test_Verify_RevertsWhenPublicSignalDoesNotMatchNullifier() public {
        _registerActiveType();
        bytes32 wrongNullifier = keccak256("wrong");

        vm.expectRevert(abi.encodeWithSelector(VerifierRouter.PublicInputMismatch.selector, TYPE_ID, NULLIFIER));
        router.verify(TYPE_ID, NULLIFIER, _encodeProof(), _encodePublicInputs(wrongNullifier));
    }

    function test_Verify_ReturnsTrueWhenProofValid() public {
        _registerActiveType();
        mockVerifier.setResult(true);

        bool result = router.verify(TYPE_ID, NULLIFIER, _encodeProof(), _encodePublicInputs(NULLIFIER));
        assertTrue(result);
    }

    function test_Verify_ReturnsFalseWhenProofInvalid() public {
        _registerActiveType();
        mockVerifier.setResult(false);

        bool result = router.verify(TYPE_ID, NULLIFIER, _encodeProof(), _encodePublicInputs(NULLIFIER));
        assertFalse(result);
    }

    // ---------------------------------------------------------------------
    // verifyManufacturer
    // ---------------------------------------------------------------------

    function test_VerifyManufacturer_RevertsWhenTypeUnknown() public {
        bytes memory sig = _signManufacturer(SIGNER_KEY, TYPE_ID, MANUFACTURER_ID, NULLIFIER);

        vm.expectRevert(abi.encodeWithSelector(VerifierRouter.UnknownIdentifierType.selector, TYPE_ID));
        router.verifyManufacturer(TYPE_ID, MANUFACTURER_ID, NULLIFIER, sig);
    }

    function test_VerifyManufacturer_RevertsWhenTypeInactive() public {
        _registerActiveType();
        vm.prank(admin);
        identifierRegistry.setStatus(TYPE_ID, false);

        bytes memory sig = _signManufacturer(SIGNER_KEY, TYPE_ID, MANUFACTURER_ID, NULLIFIER);

        vm.expectRevert(abi.encodeWithSelector(VerifierRouter.InactiveIdentifierType.selector, TYPE_ID));
        router.verifyManufacturer(TYPE_ID, MANUFACTURER_ID, NULLIFIER, sig);
    }

    function test_VerifyManufacturer_RevertsWhenManufacturerUnknown() public {
        _registerActiveType();
        bytes memory sig = _signManufacturer(SIGNER_KEY, TYPE_ID, MANUFACTURER_ID, NULLIFIER);

        vm.expectRevert(abi.encodeWithSelector(VerifierRouter.UnknownManufacturer.selector, MANUFACTURER_ID));
        router.verifyManufacturer(TYPE_ID, MANUFACTURER_ID, NULLIFIER, sig);
    }

    function test_VerifyManufacturer_RevertsWhenManufacturerInactive() public {
        _registerActiveType();
        address signerAddr = vm.addr(SIGNER_KEY);

        vm.startPrank(admin);
        manufacturerRegistry.registerManufacturer(MANUFACTURER_ID, signerAddr);
        manufacturerRegistry.deactivateManufacturer(MANUFACTURER_ID);
        vm.stopPrank();

        bytes memory sig = _signManufacturer(SIGNER_KEY, TYPE_ID, MANUFACTURER_ID, NULLIFIER);

        vm.expectRevert(abi.encodeWithSelector(VerifierRouter.InactiveManufacturer.selector, MANUFACTURER_ID));
        router.verifyManufacturer(TYPE_ID, MANUFACTURER_ID, NULLIFIER, sig);
    }

    function test_VerifyManufacturer_ReturnsTrueForValidSignature() public {
        _registerActiveType();
        address signerAddr = vm.addr(SIGNER_KEY);

        vm.prank(admin);
        manufacturerRegistry.registerManufacturer(MANUFACTURER_ID, signerAddr);

        bytes memory sig = _signManufacturer(SIGNER_KEY, TYPE_ID, MANUFACTURER_ID, NULLIFIER);

        bool result = router.verifyManufacturer(TYPE_ID, MANUFACTURER_ID, NULLIFIER, sig);
        assertTrue(result);
    }

    function test_VerifyManufacturer_ReturnsFalseForSignatureFromWrongSigner() public {
        _registerActiveType();
        address signerAddr = vm.addr(SIGNER_KEY);

        vm.prank(admin);
        manufacturerRegistry.registerManufacturer(MANUFACTURER_ID, signerAddr);

        uint256 wrongKey = 0xB0B;
        bytes memory sig = _signManufacturer(wrongKey, TYPE_ID, MANUFACTURER_ID, NULLIFIER);

        bool result = router.verifyManufacturer(TYPE_ID, MANUFACTURER_ID, NULLIFIER, sig);
        assertFalse(result);
    }

    function test_VerifyManufacturer_ReturnsFalseWhenNullifierDiffersFromSignedDigest() public {
        _registerActiveType();
        address signerAddr = vm.addr(SIGNER_KEY);

        vm.prank(admin);
        manufacturerRegistry.registerManufacturer(MANUFACTURER_ID, signerAddr);

        bytes32 signedNullifier = keccak256("signed-nullifier");
        bytes memory sig = _signManufacturer(SIGNER_KEY, TYPE_ID, MANUFACTURER_ID, signedNullifier);

        bool result = router.verifyManufacturer(TYPE_ID, MANUFACTURER_ID, NULLIFIER, sig);
        assertFalse(result);
    }
}
