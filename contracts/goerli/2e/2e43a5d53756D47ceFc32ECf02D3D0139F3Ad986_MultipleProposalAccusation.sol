// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/libraries/parsers/BClaimsParserLibrary.sol";

struct Snapshot {
    uint256 committedAt;
    BClaimsParserLibrary.BClaims blockClaims;
}

interface ISnapshots {
    event SnapshotTaken(
        uint256 chainId,
        uint256 indexed epoch,
        uint256 height,
        address indexed validator,
        bool isSafeToProceedConsensus,
        uint256[4] masterPublicKey,
        uint256[2] signature,
        BClaimsParserLibrary.BClaims bClaims
    );

    function setSnapshotDesperationDelay(uint32 desperationDelay_) external;

    function setSnapshotDesperationFactor(uint32 desperationFactor_) external;

    function setMinimumIntervalBetweenSnapshots(uint32 minimumIntervalBetweenSnapshots_) external;

    function snapshot(
        bytes calldata signatureGroup_,
        bytes calldata bClaims_
    ) external returns (bool);

    function migrateSnapshots(
        bytes[] memory groupSignature_,
        bytes[] memory bClaims_
    ) external returns (bool);

    function getSnapshotDesperationDelay() external view returns (uint256);

    function getSnapshotDesperationFactor() external view returns (uint256);

    function getMinimumIntervalBetweenSnapshots() external view returns (uint256);

    function getChainId() external view returns (uint256);

    function getEpoch() external view returns (uint256);

    function getEpochLength() external view returns (uint256);

    function getChainIdFromSnapshot(uint256 epoch_) external view returns (uint256);

    function getChainIdFromLatestSnapshot() external view returns (uint256);

    function getBlockClaimsFromSnapshot(
        uint256 epoch_
    ) external view returns (BClaimsParserLibrary.BClaims memory);

    function getBlockClaimsFromLatestSnapshot()
        external
        view
        returns (BClaimsParserLibrary.BClaims memory);

    function getCommittedHeightFromSnapshot(uint256 epoch_) external view returns (uint256);

    function getCommittedHeightFromLatestSnapshot() external view returns (uint256);

    function getAliceNetHeightFromSnapshot(uint256 epoch_) external view returns (uint256);

    function getAliceNetHeightFromLatestSnapshot() external view returns (uint256);

    function getSnapshot(uint256 epoch_) external view returns (Snapshot memory);

    function getLatestSnapshot() external view returns (Snapshot memory);

    function getEpochFromHeight(uint256 height) external view returns (uint256);

    function checkBClaimsSignature(
        bytes calldata groupSignature_,
        bytes calldata bClaims_
    ) external view returns (bool);

    function isValidatorElectedToPerformSnapshot(
        address validator,
        uint256 lastSnapshotCommittedAt,
        bytes32 groupSignatureHash
    ) external view returns (bool);

    function mayValidatorSnapshot(
        uint256 numValidators,
        uint256 myIdx,
        uint256 blocksSinceDesperation,
        bytes32 blsig,
        uint256 desperationFactor
    ) external pure returns (bool);
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/utils/CustomEnumerableMaps.sol";

interface IValidatorPool {
    event ValidatorJoined(address indexed account, uint256 validatorStakingTokenID);
    event ValidatorLeft(address indexed account, uint256 publicStakingTokenID);
    event ValidatorMinorSlashed(address indexed account, uint256 publicStakingTokenID);
    event ValidatorMajorSlashed(address indexed account);
    event MaintenanceScheduled();

    function setStakeAmount(uint256 stakeAmount_) external;

    function setMaxIntervalWithoutSnapshots(uint256 maxIntervalWithoutSnapshots) external;

    function setMaxNumValidators(uint256 maxNumValidators_) external;

    function setDisputerReward(uint256 disputerReward_) external;

    function setLocation(string calldata ip) external;

    function scheduleMaintenance() external;

    function initializeETHDKG() external;

    function completeETHDKG() external;

    function pauseConsensus() external;

    function pauseConsensusOnArbitraryHeight(uint256 aliceNetHeight) external;

    function registerValidators(
        address[] calldata validators,
        uint256[] calldata publicStakingTokenIDs
    ) external;

    function unregisterValidators(address[] calldata validators) external;

    function unregisterAllValidators() external;

    function collectProfits() external returns (uint256 payoutEth, uint256 payoutToken);

    function claimExitingNFTPosition() external returns (uint256);

    function majorSlash(address dishonestValidator_, address disputer_) external;

    function minorSlash(address dishonestValidator_, address disputer_) external;

    function getMaxIntervalWithoutSnapshots()
        external
        view
        returns (uint256 maxIntervalWithoutSnapshots);

    function getValidatorsCount() external view returns (uint256);

    function getValidatorsAddresses() external view returns (address[] memory);

    function getValidator(uint256 index) external view returns (address);

    function getValidatorData(uint256 index) external view returns (ValidatorData memory);

    function getLocation(address validator) external view returns (string memory);

    function getLocations(address[] calldata validators_) external view returns (string[] memory);

    function getStakeAmount() external view returns (uint256);

    function getMaxNumValidators() external view returns (uint256);

    function getDisputerReward() external view returns (uint256);

    function tryGetTokenID(address account_) external view returns (bool, address, uint256);

    function isValidator(address participant) external view returns (bool);

    function isInExitingQueue(address participant) external view returns (bool);

    function isAccusable(address participant) external view returns (bool);

    function isMaintenanceScheduled() external view returns (bool);

    function isConsensusRunning() external view returns (bool);
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

library AccusationsErrors {
    error NoTransactionInAccusedProposal();
    error HeightDeltaShouldBeOne(uint256 bClaimsHeight, uint256 pClaimsHeight);
    error PClaimsHeightsDoNotMatch(uint256 pClaims0Height, uint256 pClaims1Height);
    error ChainIdDoesNotMatch(
        uint256 bClaimsChainId,
        uint256 pClaimsChainId,
        uint256 snapshotsChainId
    );
    error SignersDoNotMatch(address signer1, address signer2);
    error SignerNotValidValidator(address signer);
    error UTXODoesnotMatch(bytes32 proofAgainstStateRootKey, bytes32 proofOfInclusionTxHashKey);
    error PClaimsRoundsDoNotMatch(uint32 pClaims0Round, uint32 pClaims1Round);
    error PClaimsChainIdsDoNotMatch(uint256 pClaims0ChainId, uint256 pClaims1ChainId);
    error InvalidChainId(uint256 pClaimsChainId, uint256 expectedChainId);
    error MerkleProofKeyDoesNotMatchConsumedDepositKey(
        bytes32 proofOfInclusionTxHashKey,
        bytes32 proofAgainstStateRootKey
    );
    error MerkleProofKeyDoesNotMatchUTXOIDBeingSpent(
        bytes32 utxoId,
        bytes32 proofAgainstStateRootKey
    );
    error SignatureVerificationFailed();
    error PClaimsAreEqual();
    error SignatureLengthMustBe65Bytes(uint256 signatureLength);
    error InvalidSignatureVersion(uint8 signatureVersion);
    error ExpiredAccusation(uint256 accusationHeight, uint256 latestSnapshotHeight, uint256 epoch);
    error InvalidMasterPublicKey(bytes32 signature);
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

library BaseParserLibraryErrors {
    error OffsetParameterOverflow(uint256 offset);
    error OffsetOutOfBounds(uint256 offset, uint256 srcLength);
    error LEUint16OffsetParameterOverflow(uint256 offset);
    error LEUint16OffsetOutOfBounds(uint256 offset, uint256 srcLength);
    error BEUint16OffsetParameterOverflow(uint256 offset);
    error BEUint16OffsetOutOfBounds(uint256 offset, uint256 srcLength);
    error BooleanOffsetParameterOverflow(uint256 offset);
    error BooleanOffsetOutOfBounds(uint256 offset, uint256 srcLength);
    error LEUint256OffsetParameterOverflow(uint256 offset);
    error LEUint256OffsetOutOfBounds(uint256 offset, uint256 srcLength);
    error BEUint256OffsetParameterOverflow(uint256 offset);
    error BEUint256OffsetOutOfBounds(uint256 offset, uint256 srcLength);
    error BytesOffsetParameterOverflow(uint256 offset);
    error BytesOffsetOutOfBounds(uint256 offset, uint256 srcLength);
    error Bytes32OffsetParameterOverflow(uint256 offset);
    error Bytes32OffsetOutOfBounds(uint256 offset, uint256 srcLength);
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

library BClaimsParserLibraryErrors {
    error SizeThresholdExceeded(uint16 dataSectionSize);
    error DataOffsetOverflow(uint256 dataOffset);
    error NotEnoughBytes(uint256 dataOffset, uint256 srcLength);
    error ChainIdZero();
    error HeightZero();
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

library CryptoLibraryErrors {
    error EllipticCurveAdditionFailed();
    error EllipticCurveMultiplicationFailed();
    error ModularExponentiationFailed();
    error EllipticCurvePairingFailed();
    error HashPointNotOnCurve();
    error HashPointUnsafeForSigning();
    error PointNotOnCurve();
    error SignatureIndicesLengthMismatch(uint256 signaturesLength, uint256 indicesLength);
    error SignaturesLengthThresholdNotMet(uint256 signaturesLength, uint256 threshold);
    error InverseArrayIncorrect();
    error InvalidInverseArrayLength();
    error KMustNotEqualJ();
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

library CustomEnumerableMapsErrors {
    error KeyNotInMap(address key);
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

library GenericParserLibraryErrors {
    error DataOffsetOverflow();
    error InsufficientBytes(uint256 bytesLength, uint256 requiredBytesLength);
    error ChainIdZero();
    error HeightZero();
    error RoundZero();
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/libraries/errors/CryptoLibraryErrors.sol";

/*
    Author: Philipp Schindler
    Source code and documentation available on Github: https://github.com/PhilippSchindler/ethdkg

    Copyright 2019 Philipp Schindler

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// TODO: we may want to check some of the functions to ensure that they are valid.
//       some of them may not be if there are attempts they are called with
//       invalid points.
library CryptoLibrary {
    ////////////////////////////////////////////////////////////////////////////////////////////////
    //// CRYPTOGRAPHIC CONSTANTS

    ////////
    //// These constants are updated to reflect our version, not theirs.
    ////////

    // GROUP_ORDER is the are the number of group elements in the groups G1, G2, and GT.
    uint256 public constant GROUP_ORDER =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // FIELD_MODULUS is the prime number over which the elliptic curves are based.
    uint256 public constant FIELD_MODULUS =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;
    // CURVE_B is the constant of the elliptic curve for G1:
    //
    //      y^2 == x^3 + CURVE_B,
    //
    // with CURVE_B == 3.
    uint256 public constant CURVE_B = 3;

    // G1 == (G1_X, G1_Y) is the standard generator for group G1.
    // uint256 constant G1_X  = 1;
    // uint256 constant G1_Y  = 2;
    // H1 == (H1X, H1Y) = hashToG1([]byte("MadHive Rocks!") from golang code;
    // this is another generator for G1 and dlog_G1(H1) is unknown,
    // which is necessary for security.
    //
    // In the future, the specific value of H1 could be changed every time
    // there is a change in validator set. For right now, though, this will
    // be a fixed constant.
    uint256 public constant H1_X =
        2788159449993757418373833378244720686978228247930022635519861138679785693683;
    uint256 public constant H1_Y =
        12344898367754966892037554998108864957174899548424978619954608743682688483244;

    // H2 == ([H2_XI, H2_X], [H2_YI, H2_Y]) is the *negation* of the
    // standard generator of group G2.
    // The standard generator comes from the Ethereum bn256 Go code.
    // The negated form is required because bn128_pairing check in Solidty requires this.
    //
    // In particular, to check
    //
    //      sig = H(msg)^privK
    //
    // is a valid signature for
    //
    //      pubK = H2Gen^privK,
    //
    // we need
    //
    //      e(sig, H2Gen) == e(H(msg), pubK).
    //
    // This is equivalent to
    //
    //      e(sig, H2) * e(H(msg), pubK) == 1.
    uint256 public constant H2_XI =
        11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 public constant H2_X =
        10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 public constant H2_YI =
        17805874995975841540914202342111839520379459829704422454583296818431106115052;
    uint256 public constant H2_Y =
        13392588948715843804641432497768002650278120570034223513918757245338268106653;

    uint256 public constant G1_X = 1;
    uint256 public constant G1_Y = 2;

    // TWO_256_MOD_P == 2^256 mod FIELD_MODULUS;
    // this is used in hashToBase to obtain a more uniform hash value.
    uint256 public constant TWO_256_MOD_P =
        6350874878119819312338956282401532409788428879151445726012394534686998597021;

    // P_MINUS1 == -1 mod FIELD_MODULUS;
    // this is used in sign0 and all ``negative'' values have this sign value.
    uint256 public constant P_MINUS1 =
        21888242871839275222246405745257275088696311157297823662689037894645226208582;

    // P_MINUS2 == FIELD_MODULUS - 2;
    // this is the exponent used in finite field inversion.
    uint256 public constant P_MINUS2 =
        21888242871839275222246405745257275088696311157297823662689037894645226208581;

    // P_MINUS1_OVER2 == (FIELD_MODULUS - 1) / 2;
    // this is the exponent used in computing the Legendre symbol and is
    // also used in sign0 as the cutoff point between ``positive'' and
    // ``negative'' numbers.
    uint256 public constant P_MINUS1_OVER2 =
        10944121435919637611123202872628637544348155578648911831344518947322613104291;

    // P_PLUS1_OVER4 == (FIELD_MODULUS + 1) / 4;
    // this is the exponent used in computing finite field square roots.
    uint256 public constant P_PLUS1_OVER4 =
        5472060717959818805561601436314318772174077789324455915672259473661306552146;

    // baseToG1 constants
    //
    // These are precomputed constants which are independent of t.
    // All of these constants are computed modulo FIELD_MODULUS.
    //
    // (-1 + sqrt(-3))/2
    uint256 public constant HASH_CONST_1 =
        2203960485148121921418603742825762020974279258880205651966;
    // sqrt(-3)
    uint256 public constant HASH_CONST_2 =
        4407920970296243842837207485651524041948558517760411303933;
    // 1/3
    uint256 public constant HASH_CONST_3 =
        14592161914559516814830937163504850059130874104865215775126025263096817472389;
    // 1 + CURVE_B (CURVE_B == 3)
    uint256 public constant HASH_CONST_4 = 4;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    //// HELPER FUNCTIONS

    function discreteLogEquality(
        uint256[2] memory x1,
        uint256[2] memory y1,
        uint256[2] memory x2,
        uint256[2] memory y2,
        uint256[2] memory proof
    ) internal view returns (bool proofIsValid) {
        uint256[2] memory tmp1;
        uint256[2] memory tmp2;

        tmp1 = bn128Multiply([x1[0], x1[1], proof[1]]);
        tmp2 = bn128Multiply([y1[0], y1[1], proof[0]]);
        uint256[2] memory t1prime = bn128Add([tmp1[0], tmp1[1], tmp2[0], tmp2[1]]);

        tmp1 = bn128Multiply([x2[0], x2[1], proof[1]]);
        tmp2 = bn128Multiply([y2[0], y2[1], proof[0]]);
        uint256[2] memory t2prime = bn128Add([tmp1[0], tmp1[1], tmp2[0], tmp2[1]]);

        uint256 challenge = uint256(keccak256(abi.encodePacked(x1, y1, x2, y2, t1prime, t2prime)));
        proofIsValid = challenge == proof[0];
    }

    function bn128Add(uint256[4] memory input) internal view returns (uint256[2] memory result) {
        // computes P + Q
        // input: 4 values of 256 bit each
        //  *) x-coordinate of point P
        //  *) y-coordinate of point P
        //  *) x-coordinate of point Q
        //  *) y-coordinate of point Q

        bool success;
        assembly ("memory-safe") {
            // 0x06     id of precompiled bn256Add contract
            // 0        number of ether to transfer
            // 128      size of call parameters, i.e. 128 bytes total
            // 64       size of call return value, i.e. 64 bytes / 512 bit for a BN256 curve point
            success := staticcall(not(0), 0x06, input, 128, result, 64)
        }

        if (!success) {
            revert CryptoLibraryErrors.EllipticCurveAdditionFailed();
        }
    }

    function bn128Multiply(
        uint256[3] memory input
    ) internal view returns (uint256[2] memory result) {
        // computes P*x
        // input: 3 values of 256 bit each
        //  *) x-coordinate of point P
        //  *) y-coordinate of point P
        //  *) scalar x

        bool success;
        assembly ("memory-safe") {
            // 0x07     id of precompiled bn256ScalarMul contract
            // 0        number of ether to transfer
            // 96       size of call parameters, i.e. 96 bytes total (256 bit for x, 256 bit for y, 256 bit for scalar)
            // 64       size of call return value, i.e. 64 bytes / 512 bit for a BN256 curve point
            success := staticcall(not(0), 0x07, input, 96, result, 64)
        }
        if (!success) {
            revert CryptoLibraryErrors.EllipticCurveMultiplicationFailed();
        }
    }

    function bn128CheckPairing(uint256[12] memory input) internal view returns (bool) {
        uint256[1] memory result;
        bool success;
        assembly ("memory-safe") {
            // 0x08     id of precompiled bn256Pairing contract     (checking the elliptic curve pairings)
            // 0        number of ether to transfer
            // 384       size of call parameters, i.e. 12*256 bits == 384 bytes
            // 32        size of result (one 32 byte boolean!)
            success := staticcall(not(0), 0x08, input, 384, result, 32)
        }
        if (!success) {
            revert CryptoLibraryErrors.EllipticCurvePairingFailed();
        }
        return result[0] == 1;
    }

    //// Begin new helper functions added
    // expmod perform modular exponentiation with all variables uint256;
    // this is used in legendre, sqrt, and invert.
    //
    // Copied from
    //      https://medium.com/@rbkhmrcr/precompiles-solidity-e5d29bd428c4
    // and slightly modified
    function expmod(uint256 base, uint256 e, uint256 m) internal view returns (uint256 result) {
        bool success;
        assembly ("memory-safe") {
            // define pointer
            let p := mload(0x40)
            // store data assembly-favouring ways
            mstore(p, 0x20) // Length of Base
            mstore(add(p, 0x20), 0x20) // Length of Exponent
            mstore(add(p, 0x40), 0x20) // Length of Modulus
            mstore(add(p, 0x60), base) // Base
            mstore(add(p, 0x80), e) // Exponent
            mstore(add(p, 0xa0), m) // Modulus
            // 0x05           id of precompiled modular exponentiation contract
            // 0xc0 == 192    size of call parameters
            // 0x20 ==  32    size of result
            success := staticcall(gas(), 0x05, p, 0xc0, p, 0x20)
            // data
            result := mload(p)
        }
        if (!success) {
            revert CryptoLibraryErrors.ModularExponentiationFailed();
        }
    }

    // Sign takes byte slice message and private key privK.
    // It then calls HashToG1 with message as input and performs scalar
    // multiplication to produce the resulting signature.
    function sign(
        bytes memory message,
        uint256 privK
    ) internal view returns (uint256[2] memory sig) {
        uint256[2] memory hashPoint;
        hashPoint = hashToG1(message);
        sig = bn128Multiply([hashPoint[0], hashPoint[1], privK]);
    }

    // Verify takes byte slice message, signature sig (element of G1),
    // public key pubK (element of G2), and checks that sig is a valid
    // signature for pubK for message. Also look at the definition of H2.
    function verifySignature(
        bytes memory message,
        uint256[2] memory sig,
        uint256[4] memory pubK
    ) internal view returns (bool v) {
        uint256[2] memory hashPoint;
        hashPoint = hashToG1(message);
        v = bn128CheckPairing(
            [
                sig[0],
                sig[1],
                H2_XI,
                H2_X,
                H2_YI,
                H2_Y,
                hashPoint[0],
                hashPoint[1],
                pubK[0],
                pubK[1],
                pubK[2],
                pubK[3]
            ]
        );
    }

    // Optimized version written in ASM of the Verify function. It takes byte slice message, signature
    // sig (element of G1), public key pubK (element of G2), and checks that sig is a valid signature
    // for pubK for message. Also look at the definition of H2.
    function verifySignatureASM(
        bytes memory message,
        uint256[2] memory sig,
        uint256[4] memory pubK
    ) internal view returns (bool v) {
        uint256[2] memory hashPoint;
        hashPoint = hashToG1ASM(message);
        v = bn128CheckPairing(
            [
                sig[0],
                sig[1],
                H2_XI,
                H2_X,
                H2_YI,
                H2_Y,
                hashPoint[0],
                hashPoint[1],
                pubK[0],
                pubK[1],
                pubK[2],
                pubK[3]
            ]
        );
    }

    // HashToG1 takes byte slice message and outputs an element of G1.
    // This function is based on the Fouque and Tibouchi 2012 paper
    // ``Indifferentiable Hashing to Barreto--Naehrig Curves''.
    // There are a couple improvements included from Wahby and Boneh's 2019 paper
    // ``Fast and simple constant-time hashing to the BLS12-381 elliptic curve''.
    //
    // There are two parts: hashToBase and baseToG1.
    //
    // hashToBase takes a byte slice (with additional bytes for domain
    // separation) and returns uint256 t with 0 <= t < FIELD_MODULUS; thus,
    // it is a valid element of F_p, the base field of the elliptic curve.
    // This is the ``hash'' portion of the hash function. The two byte
    // values are used for domain separation in order to obtain independent
    // hash functions.
    //
    // baseToG1 is a deterministic function which takes t in F_p and returns
    // a valid element of the elliptic curve.
    //
    // By combining hashToBase and baseToG1, we get a HashToG1. Now, we
    // perform this operation twice because without it, we would not have
    // a valid hash function. The reason is that baseToG1 only maps to
    // approximately 9/16ths of the points in the elliptic curve.
    // By doing this twice (with independent hash functions) and adding the
    // resulting points, we have an actual hash function to G1.
    // For more information relating to the hash-to-curve theory,
    // see the FT 2012 paper.
    function hashToG1(bytes memory message) internal view returns (uint256[2] memory h) {
        uint256 t0 = hashToBase(message, 0x00, 0x01);
        uint256 t1 = hashToBase(message, 0x02, 0x03);

        uint256[2] memory h0 = baseToG1(t0);
        uint256[2] memory h1 = baseToG1(t1);

        // Each BaseToG1 call involves a check that we have a valid curve point.
        // Here, we check that we have a valid curve point after the addition.
        // Again, this is to ensure that even if something strange happens, we
        // will not return an invalid curvepoint.
        h = bn128Add([h0[0], h0[1], h1[0], h1[1]]);

        if (!bn128IsOnCurve(h)) {
            revert CryptoLibraryErrors.HashPointNotOnCurve();
        }
        if (!safeSigningPoint(h)) {
            revert CryptoLibraryErrors.HashPointUnsafeForSigning();
        }
    }

    /// HashToG1 takes byte slice message and outputs an element of G1. Optimized version of `hashToG1`
    /// written in EVM assembly.
    function hashToG1ASM(bytes memory message) internal view returns (uint256[2] memory h) {
        assembly ("memory-safe") {
            function revertASM(str, len) {
                let ptr := mload(0x40)
                let startPtr := ptr
                mstore(ptr, hex"08c379a0") // keccak256('Error(string)')[0:4]
                ptr := add(ptr, 0x4)
                mstore(ptr, 0x20)
                ptr := add(ptr, 0x20)
                mstore(ptr, len) // string length
                ptr := add(ptr, 0x20)
                mstore(ptr, str)
                ptr := add(ptr, 0x20)
                revert(startPtr, sub(ptr, startPtr))
            }

            function memCopy(dest, src, len) {
                if lt(len, 32) {
                    revertASM("invalid length", 18)
                }
                // Copy word-length chunks while possible
                for {

                } gt(len, 31) {
                    len := sub(len, 32)
                } {
                    mstore(dest, mload(src))
                    src := add(src, 32)
                    dest := add(dest, 32)
                }

                if iszero(eq(len, 0)) {
                    // Copy remaining bytes
                    let mask := sub(exp(256, sub(32, len)), 1)
                    // e.g len = 4, yields
                    // mask    = 00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                    // notMask = ffffffff00000000000000000000000000000000000000000000000000000000
                    let srcpart := and(mload(src), not(mask))
                    let destpart := and(mload(dest), mask)
                    mstore(dest, or(destpart, srcpart))
                }
            }

            function bn128CheckPairing(ptr, paramPtr, x, y) -> result {
                mstore(add(ptr, 0xb0), x)
                mstore(add(ptr, 0xc0), y)
                memCopy(ptr, paramPtr, 0xb0)
                let success := staticcall(gas(), 0x08, ptr, 384, ptr, 32)
                if iszero(success) {
                    revertASM("invalid bn128 pairing", 21)
                }
                result := mload(ptr)
            }

            function bn128IsOnCurve(p0, p1) -> result {
                let o1 := mulmod(p0, p0, FIELD_MODULUS)
                o1 := mulmod(p0, o1, FIELD_MODULUS)
                o1 := addmod(o1, 3, FIELD_MODULUS)
                let o2 := mulmod(p1, p1, FIELD_MODULUS)
                result := eq(o1, o2)
            }

            function baseToG1(ptr, t, output) {
                let fp := add(ptr, 0xc0)
                let ap1 := mulmod(t, t, FIELD_MODULUS)

                let alpha := mulmod(ap1, addmod(ap1, HASH_CONST_4, FIELD_MODULUS), FIELD_MODULUS)
                // invert alpha
                mstore(add(ptr, 0x60), alpha)
                mstore(add(ptr, 0x80), P_MINUS2)
                if iszero(staticcall(gas(), 0x05, ptr, 0xc0, fp, 0x20)) {
                    revertASM("exp mod failed at 1", 19)
                }
                alpha := mload(fp)

                ap1 := mulmod(ap1, ap1, FIELD_MODULUS)

                let x := mulmod(ap1, HASH_CONST_2, FIELD_MODULUS)
                x := mulmod(x, alpha, FIELD_MODULUS)
                // negating x
                x := sub(FIELD_MODULUS, x)
                x := addmod(x, HASH_CONST_1, FIELD_MODULUS)

                let x_three := mulmod(x, x, FIELD_MODULUS)
                x_three := mulmod(x_three, x, FIELD_MODULUS)
                x_three := addmod(x_three, 3, FIELD_MODULUS)
                mstore(add(ptr, 0x80), P_PLUS1_OVER4)
                mstore(add(ptr, 0x60), x_three)
                if iszero(staticcall(gas(), 0x05, ptr, 0xc0, fp, 0x20)) {
                    revertASM("exp mod failed at 2", 19)
                }

                let ymul := 1
                if gt(t, P_MINUS1_OVER2) {
                    ymul := P_MINUS1
                }
                let y := mulmod(mload(fp), ymul, FIELD_MODULUS)
                let y_two := mulmod(y, y, FIELD_MODULUS)
                if eq(x_three, y_two) {
                    mstore(output, x)
                    mstore(add(output, 0x20), y)
                    leave
                }
                x := addmod(x, 1, FIELD_MODULUS)
                x := sub(FIELD_MODULUS, x)
                x_three := mulmod(x, x, FIELD_MODULUS)
                x_three := mulmod(x_three, x, FIELD_MODULUS)
                x_three := addmod(x_three, 3, FIELD_MODULUS)
                mstore(add(ptr, 0x60), x_three)
                if iszero(staticcall(gas(), 0x05, ptr, 0xc0, fp, 0x20)) {
                    revertASM("exp mod failed at 3", 19)
                }
                y := mulmod(mload(fp), ymul, FIELD_MODULUS)
                y_two := mulmod(y, y, FIELD_MODULUS)
                if eq(x_three, y_two) {
                    mstore(output, x)
                    mstore(add(output, 0x20), y)
                    leave
                }
                ap1 := addmod(mulmod(t, t, FIELD_MODULUS), 4, FIELD_MODULUS)
                x := mulmod(ap1, ap1, FIELD_MODULUS)
                x := mulmod(x, ap1, FIELD_MODULUS)
                x := mulmod(x, HASH_CONST_3, FIELD_MODULUS)
                x := mulmod(x, alpha, FIELD_MODULUS)
                x := sub(FIELD_MODULUS, x)
                x := addmod(x, 1, FIELD_MODULUS)
                x_three := mulmod(x, x, FIELD_MODULUS)
                x_three := mulmod(x_three, x, FIELD_MODULUS)
                x_three := addmod(x_three, 3, FIELD_MODULUS)
                mstore(add(ptr, 0x60), x_three)
                if iszero(staticcall(gas(), 0x05, ptr, 0xc0, fp, 0x20)) {
                    revertASM("exp mod failed at 4", 19)
                }
                y := mulmod(mload(fp), ymul, FIELD_MODULUS)
                mstore(output, x)
                mstore(add(output, 0x20), y)
            }

            function hashToG1(ptr, messageptr, messagesize, output) {
                let size := add(messagesize, 1)
                memCopy(add(ptr, 1), messageptr, messagesize)
                mstore8(ptr, 0x00)
                let h0 := keccak256(ptr, size)
                mstore8(ptr, 0x01)
                let h1 := keccak256(ptr, size)
                mstore8(ptr, 0x02)
                let h2 := keccak256(ptr, size)
                mstore8(ptr, 0x03)
                let h3 := keccak256(ptr, size)
                mstore(ptr, 0x20)
                mstore(add(ptr, 0x20), 0x20)
                mstore(add(ptr, 0x40), 0x20)
                mstore(add(ptr, 0xa0), FIELD_MODULUS)
                h1 := addmod(h1, mulmod(h0, TWO_256_MOD_P, FIELD_MODULUS), FIELD_MODULUS)
                h2 := addmod(h3, mulmod(h2, TWO_256_MOD_P, FIELD_MODULUS), FIELD_MODULUS)
                baseToG1(ptr, h1, output)
                let x1 := mload(output)
                let y1 := mload(add(output, 0x20))
                let success := bn128IsOnCurve(x1, y1)
                if iszero(success) {
                    revertASM("x1 y1 not in curve", 18)
                }
                baseToG1(ptr, h2, output)
                let x2 := mload(output)
                let y2 := mload(add(output, 0x20))
                success := bn128IsOnCurve(x2, y2)
                if iszero(success) {
                    revertASM("x2 y2 not in curve", 18)
                }
                mstore(ptr, x1)
                mstore(add(ptr, 0x20), y1)
                mstore(add(ptr, 0x40), x2)
                mstore(add(ptr, 0x60), y2)
                if iszero(staticcall(gas(), 0x06, ptr, 128, ptr, 64)) {
                    revertASM("bn256 add failed", 16)
                }
                let x := mload(ptr)
                let y := mload(add(ptr, 0x20))
                success := bn128IsOnCurve(x, y)
                if iszero(success) {
                    revertASM("x y not in curve", 16)
                }
                if or(iszero(x), eq(y, 1)) {
                    revertASM("point not safe to sign", 22)
                }
                mstore(output, x)
                mstore(add(output, 0x20), y)
            }

            let messageptr := add(message, 0x20)
            let messagesize := mload(message)
            let ptr := mload(0x40)
            hashToG1(ptr, messageptr, messagesize, h)
        }
    }

    // baseToG1 is a deterministic map from the base field F_p to the elliptic
    // curve. All values in [0, FIELD_MODULUS) are valid including 0, so we
    // do not need to worry about any exceptions.
    //
    // We remember our elliptic curve has the form
    //
    //      y^2 == x^3 + b
    //          == g(x)
    //
    // The main idea is that given t, we can produce x values x1, x2, and x3
    // such that
    //
    //      g(x1)*g(x2)*g(x3) == s^2.
    //
    // The above equation along with quadratic residues means that
    // when s != 0, at least one of g(x1), g(x2), or g(x3) is a square,
    // which implies that x1, x2, or x3 is a valid x-coordinate to a point
    // on the elliptic curve. For uniqueness, we choose the smallest coordinate.
    // In our construction, the above s value will always be nonzero, so we will
    // always have a solution. This means that baseToG1 is a deterministic
    // map from the base field to the elliptic curve.
    function baseToG1(uint256 t) internal view returns (uint256[2] memory h) {
        // ap1 and ap2 are temporary variables, originally named to represent
        // alpha part 1 and alpha part 2. Now they are somewhat general purpose
        // variables due to using too many variables on stack.
        uint256 ap1;
        uint256 ap2;

        // One of the main constants variables to form x1, x2, and x3
        // is alpha, which has the following definition:
        //
        //      alpha == (ap1*ap2)^(-1)
        //            == [t^2*(t^2 + h4)]^(-1)
        //
        //      ap1 == t^2
        //      ap2 == t^2 + h4
        //      h4  == HASH_CONST_4
        //
        // Defining alpha helps decrease the calls to expmod,
        // which is the most expensive operation we do.
        uint256 alpha;
        ap1 = mulmod(t, t, FIELD_MODULUS);
        ap2 = addmod(ap1, HASH_CONST_4, FIELD_MODULUS);
        alpha = mulmod(ap1, ap2, FIELD_MODULUS);
        alpha = invert(alpha);

        // Another important constant which is used when computing x3 is tmp,
        // which has the following definition:
        //
        //      tmp == (t^2 + h4)^3
        //          == ap2^3
        //
        //      h4  == HASH_CONST_4
        //
        // This is cheap to compute because ap2 has not changed
        uint256 tmp;
        tmp = mulmod(ap2, ap2, FIELD_MODULUS);
        tmp = mulmod(tmp, ap2, FIELD_MODULUS);

        // When computing x1, we need to compute t^4. ap1 will be the
        // temporary variable which stores this value now:
        //
        // Previous definition:
        //      ap1 == t^2
        //
        // Current definition:
        //      ap1 == t^4
        ap1 = mulmod(ap1, ap1, FIELD_MODULUS);

        // One of the potential x-coordinates of our elliptic curve point:
        //
        //      x1 == h1 - h2*t^4*alpha
        //         == h1 - h2*ap1*alpha
        //
        //      ap1 == t^4 (note previous assignment)
        //      h1  == HASH_CONST_1
        //      h2  == HASH_CONST_2
        //
        // When t == 0, x1 is a valid x-coordinate of a point on the elliptic
        // curve, so we need no exceptions; this is different than the original
        // Fouque and Tibouchi 2012 paper. This comes from the fact that
        // 0^(-1) == 0 mod p, as we use expmod for inversion.
        uint256 x1;
        x1 = mulmod(HASH_CONST_2, ap1, FIELD_MODULUS);
        x1 = mulmod(x1, alpha, FIELD_MODULUS);
        x1 = neg(x1);
        x1 = addmod(x1, HASH_CONST_1, FIELD_MODULUS);

        // One of the potential x-coordinates of our elliptic curve point:
        //
        //      x2 == -1 - x1
        uint256 x2;
        x2 = addmod(x1, 1, FIELD_MODULUS);
        x2 = neg(x2);

        // One of the potential x-coordinates of our elliptic curve point:
        //
        //      x3 == 1 - h3*tmp*alpha
        //
        //      h3 == HASH_CONST_3
        uint256 x3;
        x3 = mulmod(HASH_CONST_3, tmp, FIELD_MODULUS);
        x3 = mulmod(x3, alpha, FIELD_MODULUS);
        x3 = neg(x3);
        x3 = addmod(x3, 1, FIELD_MODULUS);

        // We now focus on determing residue1; if residue1 == 1,
        // then x1 is a valid x-coordinate for a point on E(F_p).
        //
        // When computing residues, the original FT 2012 paper suggests
        // blinding for security. We do not use that suggestion here
        // because of the possibility of a random integer being returned
        // which is 0, which would completely destroy the output.
        // Additionally, computing random numbers on Ethereum is difficult.
        uint256 y;
        y = mulmod(x1, x1, FIELD_MODULUS);
        y = mulmod(y, x1, FIELD_MODULUS);
        y = addmod(y, CURVE_B, FIELD_MODULUS);
        int256 residue1 = legendre(y);

        // We now focus on determing residue2; if residue2 == 1,
        // then x2 is a valid x-coordinate for a point on E(F_p).
        y = mulmod(x2, x2, FIELD_MODULUS);
        y = mulmod(y, x2, FIELD_MODULUS);
        y = addmod(y, CURVE_B, FIELD_MODULUS);
        int256 residue2 = legendre(y);

        // i is the index which gives us the correct x value (x1, x2, or x3)
        int256 i = ((residue1 - 1) * (residue2 - 3)) / 4 + 1;

        // This is the simplest way to determine which x value is correct
        // but is not secure. If possible, we should improve this.
        uint256 x;
        if (i == 1) {
            x = x1;
        } else if (i == 2) {
            x = x2;
        } else {
            x = x3;
        }

        // Now that we know x, we compute y
        y = mulmod(x, x, FIELD_MODULUS);
        y = mulmod(y, x, FIELD_MODULUS);
        y = addmod(y, CURVE_B, FIELD_MODULUS);
        y = sqrt(y);

        // We now determine the sign of y based on t; this is a change from
        // the original FT 2012 paper and uses the suggestion from WB 2019.
        //
        // This is done to save computation, as using sign0 reduces the
        // number of calls to expmod from 5 to 4; currently, we call expmod
        // for inversion (alpha), two legendre calls (for residue1 and
        // residue2), and one sqrt call.
        // This change nullifies the proof in FT 2012 that we have a valid
        // hash function. Whether the proof could be slightly modified to
        // compensate for this change is possible but not currently known.
        //
        // (CHG: At the least, I am not sure that the proof holds, nor am I
        // able to see how the proof could potentially be fixed in order
        // for the hash function to be admissible.)
        //
        // If this is included as a precompile, it may be worth it to ignore
        // the cost savings in order to ensure uniformity of the hash function.
        // Also, we would need to change legendre so that legendre(0) == 1,
        // or else things would fail when t == 0. We could also have a separate
        // function for the sign determiniation.
        uint256 ySign;
        ySign = sign0(t);
        y = mulmod(y, ySign, FIELD_MODULUS);

        // Before returning the value, we check to make sure we have a valid
        // curve point. This ensures we will always have a valid point.
        // From Fouque-Tibouchi 2012, the only way to get an invalid point is
        // when t == 0, but we have already taken care of that to ensure that
        // when t == 0, we still return a valid curve point.
        if (!bn128IsOnCurve([x, y])) {
            revert CryptoLibraryErrors.PointNotOnCurve();
        }

        h[0] = x;
        h[1] = y;
    }

    // invert computes the multiplicative inverse of t modulo FIELD_MODULUS.
    // When t == 0, s == 0.
    function invert(uint256 t) internal view returns (uint256 s) {
        s = expmod(t, P_MINUS2, FIELD_MODULUS);
    }

    // sqrt computes the multiplicative square root of t modulo FIELD_MODULUS.
    // sqrt does not check that a square root is possible; see legendre.
    function sqrt(uint256 t) internal view returns (uint256 s) {
        s = expmod(t, P_PLUS1_OVER4, FIELD_MODULUS);
    }

    // legendre computes the legendre symbol of t with respect to FIELD_MODULUS.
    // That is, legendre(t) == 1 when a square root of t exists modulo
    // FIELD_MODULUS, legendre(t) == -1 when a square root of t does not exist
    // modulo FIELD_MODULUS, and legendre(t) == 0 when t == 0 mod FIELD_MODULUS.
    function legendre(uint256 t) internal view returns (int256 chi) {
        uint256 s = expmod(t, P_MINUS1_OVER2, FIELD_MODULUS);
        if (s != 0) {
            chi = 2 * int256(s & 1) - 1;
        } else {
            chi = 0;
        }
    }

    // AggregateSignatures takes takes the signature array sigs, index array
    // indices, and threshold to compute the thresholded group signature.
    // After ensuring some basic requirements are met, it calls
    // LagrangeInterpolationG1 to perform this interpolation.
    //
    // To trade computation (and expensive gas costs) for space, we choose
    // to require that the multiplicative inverses modulo GROUP_ORDER be
    // entered for this function call in invArray. This allows the expensive
    // portion of gas cost to grow linearly in the size of the group rather
    // than quadratically. Additional improvements made be included
    // in the future.
    //
    // One advantage to how this function is designed is that we do not need
    // to know the number of participants, as we only require inverses which
    // will be required as deteremined by indices.
    function aggregateSignatures(
        uint256[2][] memory sigs,
        uint256[] memory indices,
        uint256 threshold,
        uint256[] memory invArray
    ) internal view returns (uint256[2] memory) {
        if (sigs.length != indices.length) {
            revert CryptoLibraryErrors.SignatureIndicesLengthMismatch(sigs.length, indices.length);
        }

        if (sigs.length <= threshold) {
            revert CryptoLibraryErrors.SignaturesLengthThresholdNotMet(sigs.length, threshold);
        }

        uint256 maxIndex = computeArrayMax(indices);
        if (!checkInverses(invArray, maxIndex)) {
            revert CryptoLibraryErrors.InverseArrayIncorrect();
        }
        uint256[2] memory grpsig;
        grpsig = lagrangeInterpolationG1(sigs, indices, threshold, invArray);
        return grpsig;
    }

    // LagrangeInterpolationG1 efficiently computes Lagrange interpolation
    // of pointsG1 using indices as the point location in the finite field.
    // This is an efficient method of Lagrange interpolation as we assume
    // finite field inverses are in invArray.
    function lagrangeInterpolationG1(
        uint256[2][] memory pointsG1,
        uint256[] memory indices,
        uint256 threshold,
        uint256[] memory invArray
    ) internal view returns (uint256[2] memory) {
        if (pointsG1.length != indices.length) {
            revert CryptoLibraryErrors.SignatureIndicesLengthMismatch(
                pointsG1.length,
                indices.length
            );
        }
        uint256[2] memory val;
        val[0] = 0;
        val[1] = 0;
        uint256 i;
        uint256 ell;
        uint256 idxJ;
        uint256 idxK;
        uint256 rj;
        uint256 rjPartial;
        uint256[2] memory partialVal;
        for (i = 0; i < indices.length; i++) {
            idxJ = indices[i];
            if (i > threshold) {
                break;
            }
            rj = 1;
            for (ell = 0; ell < indices.length; ell++) {
                idxK = indices[ell];
                if (ell > threshold) {
                    break;
                }
                if (idxK == idxJ) {
                    continue;
                }
                rjPartial = liRjPartialConst(idxK, idxJ, invArray);
                rj = mulmod(rj, rjPartial, GROUP_ORDER);
            }
            partialVal = pointsG1[i];
            partialVal = bn128Multiply([partialVal[0], partialVal[1], rj]);
            val = bn128Add([val[0], val[1], partialVal[0], partialVal[1]]);
        }
        return val;
    }

    // liRjPartialConst computes the partial constants of rj in Lagrange
    // interpolation based on the the multiplicative inverses in invArray.
    function liRjPartialConst(
        uint256 k,
        uint256 j,
        uint256[] memory invArray
    ) internal pure returns (uint256) {
        if (k == j) {
            revert CryptoLibraryErrors.KMustNotEqualJ();
        }
        uint256 tmp1 = k;
        uint256 tmp2;
        if (k > j) {
            tmp2 = k - j;
        } else {
            tmp1 = mulmod(tmp1, GROUP_ORDER - 1, GROUP_ORDER);
            tmp2 = j - k;
        }
        tmp2 = invArray[tmp2 - 1];
        tmp2 = mulmod(tmp1, tmp2, GROUP_ORDER);
        return tmp2;
    }

    // TODO: identity (0, 0) should be considered a valid point
    function bn128IsOnCurve(uint256[2] memory point) internal pure returns (bool) {
        // check if the provided point is on the bn128 curve (y**2 = x**3 + 3)
        return
            mulmod(point[1], point[1], FIELD_MODULUS) ==
            addmod(
                mulmod(point[0], mulmod(point[0], point[0], FIELD_MODULUS), FIELD_MODULUS),
                3,
                FIELD_MODULUS
            );
    }

    // hashToBase takes in a byte slice message and bytes c0 and c1 for
    // domain separation. The idea is that we treat keccak256 as a random
    // oracle which outputs uint256. The problem is that we want to hash modulo
    // FIELD_MODULUS (p, a prime number). Just using uint256 mod p will lead
    // to bias in the distribution. In particular, there is bias towards the
    // lower 5% of the numbers in [0, FIELD_MODULUS). The 1-norm error between
    // s0 mod p and a uniform distribution is ~ 1/4. By itself, this 1-norm
    // error is not too enlightening, but continue reading, as we will compare
    // it with another distribution that has much smaller 1-norm error.
    //
    // To obtain a better distribution with less bias, we take 2 uint256 hash
    // outputs (using c0 and c1 for domain separation so the hashes are
    // independent) and ``combine them'' to form a ``uint512''. Of course,
    // this is not possible in practice, so we view the combined output as
    //
    //      x == s0*2^256 + s1.
    //
    // This implies that x (combined from s0 and s1 in this way) is a
    // 512-bit uint. If s0 and s1 are uniformly distributed modulo 2^256,
    // then x is uniformly distributed modulo 2^512. We now want to reduce
    // this modulo FIELD_MODULUS (p). This is done as follows:
    //
    //      x mod p == [(s0 mod p)*(2^256 mod p)] + s1 mod p.
    //
    // This allows us easily compute the result without needing to implement
    // higher precision. The 1-norm error between x mod p and a uniform
    // distribution is ~1e-77. This is a *signficant* improvement from s0 mod p.
    // For all practical purposes, there is no difference from a
    // uniform distribution.
    function hashToBase(
        bytes memory message,
        bytes1 c0,
        bytes1 c1
    ) internal pure returns (uint256 t) {
        uint256 s0 = uint256(keccak256(abi.encodePacked(c0, message)));
        uint256 s1 = uint256(keccak256(abi.encodePacked(c1, message)));
        t = addmod(mulmod(s0, TWO_256_MOD_P, FIELD_MODULUS), s1, FIELD_MODULUS);
    }

    // safeSigningPoint ensures that the HashToG1 point we are returning
    // is safe to sign; in particular, it is not Infinity (the group identity
    // element) or the standard curve generator (curveGen) or its negation.
    //
    // TODO: may want to confirm point is valid first as well as reducing mod field prime
    function safeSigningPoint(uint256[2] memory input) internal pure returns (bool) {
        if (input[0] == 0 || input[0] == 1) {
            return false;
        } else {
            return true;
        }
    }

    // neg computes the additive inverse (the negative) modulo FIELD_MODULUS.
    function neg(uint256 t) internal pure returns (uint256 s) {
        if (t == 0) {
            s = 0;
        } else {
            s = FIELD_MODULUS - t;
        }
    }

    // sign0 computes the sign of a finite field element.
    // sign0 is used instead of legendre in baseToG1 from the suggestion
    // of WB 2019.
    function sign0(uint256 t) internal pure returns (uint256 s) {
        s = 1;
        if (t > P_MINUS1_OVER2) {
            s = P_MINUS1;
        }
    }

    // checkInverses takes maxIndex as the maximum element of indices
    // (used in AggregateSignatures) and checks that all of the necessary
    // multiplicative inverses in invArray are correct and present.
    function checkInverses(
        uint256[] memory invArray,
        uint256 maxIndex
    ) internal pure returns (bool) {
        uint256 k;
        uint256 kInv;
        uint256 res;
        bool validInverses = true;
        if ((maxIndex - 1) > invArray.length) {
            revert CryptoLibraryErrors.InvalidInverseArrayLength();
        }
        for (k = 1; k < maxIndex; k++) {
            kInv = invArray[k - 1];
            res = mulmod(k, kInv, GROUP_ORDER);
            if (res != 1) {
                validInverses = false;
                break;
            }
        }
        return validInverses;
    }

    // checkIndices determines whether or not each of these arrays contain
    // unique indices. There is no reason any index should appear twice.
    // All indices should be in {1, 2, ..., n} and this function ensures this.
    // n is the total number of participants; that is, n == addresses.length.
    function checkIndices(
        uint256[] memory honestIndices,
        uint256[] memory dishonestIndices,
        uint256 n
    ) internal pure returns (bool validIndices) {
        validIndices = true;
        uint256 k;
        uint256 f;
        uint256 curIdx;

        assert(n > 0);
        assert(n < 256);

        // Make sure each honestIndices list is unique
        for (k = 0; k < honestIndices.length; k++) {
            curIdx = honestIndices[k];
            // All indices must be between 1 and n
            if ((curIdx == 0) || (curIdx > n)) {
                validIndices = false;
                break;
            }
            // Only check for equality with previous indices
            if ((f & (1 << curIdx)) == 0) {
                f |= 1 << curIdx;
            } else {
                // We have seen this index before; invalid index sets
                validIndices = false;
                break;
            }
        }
        if (!validIndices) {
            return validIndices;
        }

        // Make sure each dishonestIndices list is unique and does not match
        // any from honestIndices.
        for (k = 0; k < dishonestIndices.length; k++) {
            curIdx = dishonestIndices[k];
            // All indices must be between 1 and n
            if ((curIdx == 0) || (curIdx > n)) {
                validIndices = false;
                break;
            }
            // Only check for equality with previous indices
            if ((f & (1 << curIdx)) == 0) {
                f |= 1 << curIdx;
            } else {
                // We have seen this index before; invalid index sets
                validIndices = false;
                break;
            }
        }
        return validIndices;
    }

    // computeArrayMax computes the maximum uin256 element of uint256Array
    function computeArrayMax(uint256[] memory uint256Array) internal pure returns (uint256) {
        uint256 curVal;
        uint256 maxVal = uint256Array[0];
        for (uint256 i = 1; i < uint256Array.length; i++) {
            curVal = uint256Array[i];
            if (curVal > maxVal) {
                maxVal = curVal;
            }
        }
        return maxVal;
    }
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/libraries/errors/BaseParserLibraryErrors.sol";

library BaseParserLibrary {
    // Size of a word, in bytes.
    uint256 internal constant _WORD_SIZE = 32;
    // Size of the header of a 'bytes' array.
    uint256 internal constant _BYTES_HEADER_SIZE = 32;

    /// @notice Extracts a uint32 from a little endian bytes array.
    /// @param src the binary state
    /// @param offset place inside `src` to start reading state from
    /// @return val a uint32
    /// @dev ~559 gas
    function extractUInt32(bytes memory src, uint256 offset) internal pure returns (uint32 val) {
        if (offset + 4 <= offset) {
            revert BaseParserLibraryErrors.OffsetParameterOverflow(offset);
        }

        if (offset + 4 > src.length) {
            revert BaseParserLibraryErrors.OffsetOutOfBounds(offset + 4, src.length);
        }

        assembly ("memory-safe") {
            val := shr(sub(256, 32), mload(add(add(src, 0x20), offset)))
            val := or(
                or(
                    or(shr(24, and(val, 0xff000000)), shr(8, and(val, 0x00ff0000))),
                    shl(8, and(val, 0x0000ff00))
                ),
                shl(24, and(val, 0x000000ff))
            )
        }
    }

    /// @notice Extracts a uint16 from a little endian bytes array.
    /// @param src the binary state
    /// @param offset place inside `src` to start reading state from
    /// @return val a uint16
    /// @dev ~204 gas
    function extractUInt16(bytes memory src, uint256 offset) internal pure returns (uint16 val) {
        if (offset + 2 <= offset) {
            revert BaseParserLibraryErrors.LEUint16OffsetParameterOverflow(offset);
        }

        if (offset + 2 > src.length) {
            revert BaseParserLibraryErrors.LEUint16OffsetOutOfBounds(offset + 2, src.length);
        }

        assembly ("memory-safe") {
            val := shr(sub(256, 16), mload(add(add(src, 0x20), offset)))
            val := or(shr(8, and(val, 0xff00)), shl(8, and(val, 0x00ff)))
        }
    }

    /// @notice Extracts a uint16 from a big endian bytes array.
    /// @param src the binary state
    /// @param offset place inside `src` to start reading state from
    /// @return val a uint16
    /// @dev ~204 gas
    function extractUInt16FromBigEndian(
        bytes memory src,
        uint256 offset
    ) internal pure returns (uint16 val) {
        if (offset + 2 <= offset) {
            revert BaseParserLibraryErrors.BEUint16OffsetParameterOverflow(offset);
        }

        if (offset + 2 > src.length) {
            revert BaseParserLibraryErrors.BEUint16OffsetOutOfBounds(offset + 2, src.length);
        }

        assembly ("memory-safe") {
            val := and(shr(sub(256, 16), mload(add(add(src, 0x20), offset))), 0xffff)
        }
    }

    /// @notice Extracts a bool from a bytes array.
    /// @param src the binary state
    /// @param offset place inside `src` to start reading state from
    /// @return a bool
    /// @dev ~204 gas
    function extractBool(bytes memory src, uint256 offset) internal pure returns (bool) {
        if (offset + 1 <= offset) {
            revert BaseParserLibraryErrors.BooleanOffsetParameterOverflow(offset);
        }

        if (offset + 1 > src.length) {
            revert BaseParserLibraryErrors.BooleanOffsetOutOfBounds(offset + 1, src.length);
        }

        uint256 val;
        assembly ("memory-safe") {
            val := shr(sub(256, 8), mload(add(add(src, 0x20), offset)))
            val := and(val, 0x01)
        }
        return val == 1;
    }

    /// @notice Extracts a uint256 from a little endian bytes array.
    /// @param src the binary state
    /// @param offset place inside `src` to start reading state from
    /// @return val a uint256
    /// @dev ~5155 gas
    function extractUInt256(bytes memory src, uint256 offset) internal pure returns (uint256 val) {
        if (offset + 32 <= offset) {
            revert BaseParserLibraryErrors.LEUint256OffsetParameterOverflow(offset);
        }

        if (offset + 32 > src.length) {
            revert BaseParserLibraryErrors.LEUint256OffsetOutOfBounds(offset + 32, src.length);
        }

        assembly ("memory-safe") {
            val := mload(add(add(src, 0x20), offset))
        }
    }

    /// @notice Extracts a uint256 from a big endian bytes array.
    /// @param src the binary state
    /// @param offset place inside `src` to start reading state from
    /// @return val a uint256
    /// @dev ~1400 gas
    function extractUInt256FromBigEndian(
        bytes memory src,
        uint256 offset
    ) internal pure returns (uint256 val) {
        if (offset + 32 <= offset) {
            revert BaseParserLibraryErrors.BEUint256OffsetParameterOverflow(offset);
        }

        if (offset + 32 > src.length) {
            revert BaseParserLibraryErrors.BEUint256OffsetOutOfBounds(offset + 32, src.length);
        }

        uint256 srcDataPointer;
        uint32 val0 = 0;
        uint32 val1 = 0;
        uint32 val2 = 0;
        uint32 val3 = 0;
        uint32 val4 = 0;
        uint32 val5 = 0;
        uint32 val6 = 0;
        uint32 val7 = 0;

        assembly ("memory-safe") {
            srcDataPointer := mload(add(add(src, 0x20), offset))
            val0 := and(srcDataPointer, 0xffffffff)
            val1 := and(shr(32, srcDataPointer), 0xffffffff)
            val2 := and(shr(64, srcDataPointer), 0xffffffff)
            val3 := and(shr(96, srcDataPointer), 0xffffffff)
            val4 := and(shr(128, srcDataPointer), 0xffffffff)
            val5 := and(shr(160, srcDataPointer), 0xffffffff)
            val6 := and(shr(192, srcDataPointer), 0xffffffff)
            val7 := and(shr(224, srcDataPointer), 0xffffffff)

            val0 := or(
                or(
                    or(shr(24, and(val0, 0xff000000)), shr(8, and(val0, 0x00ff0000))),
                    shl(8, and(val0, 0x0000ff00))
                ),
                shl(24, and(val0, 0x000000ff))
            )
            val1 := or(
                or(
                    or(shr(24, and(val1, 0xff000000)), shr(8, and(val1, 0x00ff0000))),
                    shl(8, and(val1, 0x0000ff00))
                ),
                shl(24, and(val1, 0x000000ff))
            )
            val2 := or(
                or(
                    or(shr(24, and(val2, 0xff000000)), shr(8, and(val2, 0x00ff0000))),
                    shl(8, and(val2, 0x0000ff00))
                ),
                shl(24, and(val2, 0x000000ff))
            )
            val3 := or(
                or(
                    or(shr(24, and(val3, 0xff000000)), shr(8, and(val3, 0x00ff0000))),
                    shl(8, and(val3, 0x0000ff00))
                ),
                shl(24, and(val3, 0x000000ff))
            )
            val4 := or(
                or(
                    or(shr(24, and(val4, 0xff000000)), shr(8, and(val4, 0x00ff0000))),
                    shl(8, and(val4, 0x0000ff00))
                ),
                shl(24, and(val4, 0x000000ff))
            )
            val5 := or(
                or(
                    or(shr(24, and(val5, 0xff000000)), shr(8, and(val5, 0x00ff0000))),
                    shl(8, and(val5, 0x0000ff00))
                ),
                shl(24, and(val5, 0x000000ff))
            )
            val6 := or(
                or(
                    or(shr(24, and(val6, 0xff000000)), shr(8, and(val6, 0x00ff0000))),
                    shl(8, and(val6, 0x0000ff00))
                ),
                shl(24, and(val6, 0x000000ff))
            )
            val7 := or(
                or(
                    or(shr(24, and(val7, 0xff000000)), shr(8, and(val7, 0x00ff0000))),
                    shl(8, and(val7, 0x0000ff00))
                ),
                shl(24, and(val7, 0x000000ff))
            )

            val := or(
                or(
                    or(
                        or(
                            or(
                                or(or(shl(224, val0), shl(192, val1)), shl(160, val2)),
                                shl(128, val3)
                            ),
                            shl(96, val4)
                        ),
                        shl(64, val5)
                    ),
                    shl(32, val6)
                ),
                val7
            )
        }
    }

    /// @notice Reverts a bytes array. Can be used to convert an array from little endian to big endian and vice-versa.
    /// @param orig the binary state
    /// @return reversed the reverted bytes array
    /// @dev ~13832 gas
    function reverse(bytes memory orig) internal pure returns (bytes memory reversed) {
        reversed = new bytes(orig.length);
        for (uint256 idx = 0; idx < orig.length; idx++) {
            reversed[orig.length - idx - 1] = orig[idx];
        }
    }

    /// @notice Copy 'len' bytes from memory address 'src', to address 'dest'. This function does not check the or destination, it only copies the bytes.
    /// @param src the pointer to the source
    /// @param dest the pointer to the destination
    /// @param len the len of state to be copied
    function copy(uint256 src, uint256 dest, uint256 len) internal pure {
        // Copy word-length chunks while possible
        for (; len >= _WORD_SIZE; len -= _WORD_SIZE) {
            assembly ("memory-safe") {
                mstore(dest, mload(src))
            }
            dest += _WORD_SIZE;
            src += _WORD_SIZE;
        }
        // Returning earlier if there's no leftover bytes to copy
        if (len == 0) {
            return;
        }
        // Copy remaining bytes
        uint256 mask = 256 ** (_WORD_SIZE - len) - 1;
        assembly ("memory-safe") {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /// @notice Returns a memory pointer to the state portion of the provided bytes array.
    /// @param bts the bytes array to get a pointer from
    /// @return addr the pointer to the `bts` bytes array
    function dataPtr(bytes memory bts) internal pure returns (uint256 addr) {
        assembly ("memory-safe") {
            addr := add(bts, _BYTES_HEADER_SIZE)
        }
    }

    /// @notice Extracts a bytes array with length `howManyBytes` from `src`'s `offset` forward.
    /// @param src the bytes array to extract from
    /// @param offset where to start extracting from
    /// @param howManyBytes how many bytes we want to extract from `src`
    /// @return out the extracted bytes array
    /// @dev Extracting the 32-64th bytes out of a 64 bytes array takes ~7828 gas.
    function extractBytes(
        bytes memory src,
        uint256 offset,
        uint256 howManyBytes
    ) internal pure returns (bytes memory out) {
        if (offset + howManyBytes < offset) {
            revert BaseParserLibraryErrors.BytesOffsetParameterOverflow(offset);
        }

        if (offset + howManyBytes > src.length) {
            revert BaseParserLibraryErrors.BytesOffsetOutOfBounds(
                offset + howManyBytes,
                src.length
            );
        }

        out = new bytes(howManyBytes);
        uint256 start;

        assembly ("memory-safe") {
            start := add(add(src, offset), _BYTES_HEADER_SIZE)
        }

        copy(start, dataPtr(out), howManyBytes);
    }

    /// @notice Extracts a bytes32 extracted from `src`'s `offset` forward.
    /// @param src the source bytes array to extract from
    /// @param offset where to start extracting from
    /// @return out the bytes32 state extracted from `src`
    /// @dev ~439 gas
    function extractBytes32(bytes memory src, uint256 offset) internal pure returns (bytes32 out) {
        if (offset + 32 <= offset) {
            revert BaseParserLibraryErrors.Bytes32OffsetParameterOverflow(offset);
        }

        if (offset + 32 > src.length) {
            revert BaseParserLibraryErrors.Bytes32OffsetOutOfBounds(offset + 32, src.length);
        }

        assembly ("memory-safe") {
            out := mload(add(add(src, _BYTES_HEADER_SIZE), offset))
        }
    }
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/libraries/errors/BClaimsParserLibraryErrors.sol";
import "contracts/libraries/errors/GenericParserLibraryErrors.sol";

import "contracts/libraries/parsers/BaseParserLibrary.sol";

/// @title Library to parse the BClaims structure from a blob of capnproto state
library BClaimsParserLibrary {
    struct BClaims {
        uint32 chainId;
        uint32 height;
        uint32 txCount;
        bytes32 prevBlock;
        bytes32 txRoot;
        bytes32 stateRoot;
        bytes32 headerRoot;
    }

    /** @dev size in bytes of a BCLAIMS cap'npro structure without the cap'n
      proto header bytes*/
    uint256 internal constant _BCLAIMS_SIZE = 176;
    /** @dev Number of bytes of a capnproto header, the state starts after the
      header */
    uint256 internal constant _CAPNPROTO_HEADER_SIZE = 8;

    /**
    @notice This function computes the offset adjustment in the pointer section
    of the capnproto blob of state. In case the txCount is 0, the value is not
    included in the binary blob by capnproto. Therefore, we need to deduce 8
    bytes from the pointer's offset.
    */
    /// @param src Binary state containing a BClaims serialized struct
    /// @param dataOffset Blob of binary state with a capnproto serialization
    /// @return pointerOffsetAdjustment the pointer offset adjustment in the blob state
    /// @dev Execution cost: 499 gas
    function getPointerOffsetAdjustment(
        bytes memory src,
        uint256 dataOffset
    ) internal pure returns (uint16 pointerOffsetAdjustment) {
        // Size in capnproto words (16 bytes) of the state section
        uint16 dataSectionSize = BaseParserLibrary.extractUInt16(src, dataOffset);

        if (dataSectionSize <= 0 || dataSectionSize > 2) {
            revert BClaimsParserLibraryErrors.SizeThresholdExceeded(dataSectionSize);
        }

        // In case the txCount is 0, the value is not included in the binary
        // blob by capnproto. Therefore, we need to deduce 8 bytes from the
        // pointer's offset.
        if (dataSectionSize == 1) {
            pointerOffsetAdjustment = 8;
        } else {
            pointerOffsetAdjustment = 0;
        }
    }

    /**
    @notice This function is for deserializing state directly from capnproto
            BClaims. It will skip the first 8 bytes (capnproto headers) and
            deserialize the BClaims Data. This function also computes the right
            PointerOffset adjustment (see the documentation on
            `getPointerOffsetAdjustment(bytes, uint256)` for more details). If
            BClaims is being extracted from inside of other structure (E.g
            PClaims capnproto) use the `extractInnerBClaims(bytes, uint,
            uint16)` instead.
    */
    /// @param src Binary state containing a BClaims serialized struct with Capn Proto headers
    /// @return bClaims the BClaims struct
    /// @dev Execution cost: 2484 gas
    function extractBClaims(bytes memory src) internal pure returns (BClaims memory bClaims) {
        return extractInnerBClaims(src, _CAPNPROTO_HEADER_SIZE, getPointerOffsetAdjustment(src, 4));
    }

    /**
    @notice This function is for deserializing the BClaims struct from an defined
            location inside a binary blob. E.G Extract BClaims from inside of
            other structure (E.g PClaims capnproto) or skipping the capnproto
            headers.
    */
    /// @param src Binary state containing a BClaims serialized struct without Capn proto headers
    /// @param dataOffset offset to start reading the BClaims state from inside src
    /// @param pointerOffsetAdjustment Pointer's offset that will be deduced from the pointers location, in case txCount is missing in the binary
    /// @return bClaims the BClaims struct
    /// @dev Execution cost: 2126 gas
    function extractInnerBClaims(
        bytes memory src,
        uint256 dataOffset,
        uint16 pointerOffsetAdjustment
    ) internal pure returns (BClaims memory bClaims) {
        if (dataOffset + _BCLAIMS_SIZE - pointerOffsetAdjustment <= dataOffset) {
            revert BClaimsParserLibraryErrors.DataOffsetOverflow(dataOffset);
        }
        if (dataOffset + _BCLAIMS_SIZE - pointerOffsetAdjustment > src.length) {
            revert BClaimsParserLibraryErrors.NotEnoughBytes(
                dataOffset + _BCLAIMS_SIZE - pointerOffsetAdjustment,
                src.length
            );
        }

        if (pointerOffsetAdjustment == 0) {
            bClaims.txCount = BaseParserLibrary.extractUInt32(src, dataOffset + 8);
        } else {
            // In case the txCount is 0, the value is not included in the binary
            // blob by capnproto.
            bClaims.txCount = 0;
        }

        bClaims.chainId = BaseParserLibrary.extractUInt32(src, dataOffset);
        if (bClaims.chainId == 0) {
            revert GenericParserLibraryErrors.ChainIdZero();
        }

        bClaims.height = BaseParserLibrary.extractUInt32(src, dataOffset + 4);
        if (bClaims.height == 0) {
            revert GenericParserLibraryErrors.HeightZero();
        }

        bClaims.prevBlock = BaseParserLibrary.extractBytes32(
            src,
            dataOffset + 48 - pointerOffsetAdjustment
        );
        bClaims.txRoot = BaseParserLibrary.extractBytes32(
            src,
            dataOffset + 80 - pointerOffsetAdjustment
        );
        bClaims.stateRoot = BaseParserLibrary.extractBytes32(
            src,
            dataOffset + 112 - pointerOffsetAdjustment
        );
        bClaims.headerRoot = BaseParserLibrary.extractBytes32(
            src,
            dataOffset + 144 - pointerOffsetAdjustment
        );
    }
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/libraries/errors/GenericParserLibraryErrors.sol";

import "contracts/libraries/parsers/BaseParserLibrary.sol";
import "contracts/libraries/parsers/BClaimsParserLibrary.sol";
import "contracts/libraries/parsers/RCertParserLibrary.sol";

/// @title Library to parse the PClaims structure from a blob of capnproto state
library PClaimsParserLibrary {
    struct PClaims {
        BClaimsParserLibrary.BClaims bClaims;
        RCertParserLibrary.RCert rCert;
    }
    /** @dev size in bytes of a PCLAIMS cap'npro structure without the cap'n
      proto header bytes*/
    uint256 internal constant _PCLAIMS_SIZE = 456;
    /** @dev Number of bytes of a capnproto header, the state starts after the
      header */
    uint256 internal constant _CAPNPROTO_HEADER_SIZE = 8;

    /**
    @notice This function is for deserializing state directly from capnproto
            PClaims. Use `extractInnerPClaims()` if you are extracting PClaims
            from other capnproto structure (e.g Proposal).
    */
    /// @param src Binary state containing a RCert serialized struct with Capn Proto headers
    /// @return pClaims the PClaims struct
    /// @dev Execution cost: 7725 gas
    function extractPClaims(bytes memory src) internal pure returns (PClaims memory pClaims) {
        (pClaims, ) = extractInnerPClaims(src, _CAPNPROTO_HEADER_SIZE);
    }

    /**
    @notice This function is for deserializing the PClaims struct from an defined
            location inside a binary blob. E.G Extract PClaims from inside of
            other structure (E.g Proposal capnproto) or skipping the capnproto
            headers. Since PClaims is composed of a BClaims struct which has not
            a fixed sized depending on the txCount value, this function returns
            the pClaims struct deserialized and its binary size. The
            binary size must be used to adjust any other state that
            is being deserialized after PClaims in case PClaims is being
            deserialized from inside another struct.
    */
    /// @param src Binary state containing a PClaims serialized struct without Capn Proto headers
    /// @param dataOffset offset to start reading the PClaims state from inside src
    /// @return pClaims the PClaims struct
    /// @return pClaimsBinarySize the size of this PClaims
    /// @dev Execution cost: 7026 gas
    function extractInnerPClaims(
        bytes memory src,
        uint256 dataOffset
    ) internal pure returns (PClaims memory pClaims, uint256 pClaimsBinarySize) {
        if (dataOffset + _PCLAIMS_SIZE <= dataOffset) {
            revert GenericParserLibraryErrors.DataOffsetOverflow();
        }
        uint16 pointerOffsetAdjustment = BClaimsParserLibrary.getPointerOffsetAdjustment(
            src,
            dataOffset + 4
        );
        pClaimsBinarySize = _PCLAIMS_SIZE - pointerOffsetAdjustment;
        if (src.length < dataOffset + pClaimsBinarySize) {
            revert GenericParserLibraryErrors.InsufficientBytes(
                src.length,
                dataOffset + pClaimsBinarySize
            );
        }
        pClaims.bClaims = BClaimsParserLibrary.extractInnerBClaims(
            src,
            dataOffset + 16,
            pointerOffsetAdjustment
        );
        pClaims.rCert = RCertParserLibrary.extractInnerRCert(
            src,
            dataOffset + 16 + BClaimsParserLibrary._BCLAIMS_SIZE - pointerOffsetAdjustment
        );
    }
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/libraries/errors/GenericParserLibraryErrors.sol";

import "contracts/libraries/parsers/BaseParserLibrary.sol";
import "contracts/libraries/parsers/RClaimsParserLibrary.sol";

/// @title Library to parse the RCert structure from a blob of capnproto state
library RCertParserLibrary {
    struct RCert {
        RClaimsParserLibrary.RClaims rClaims;
        uint256[4] sigGroupPublicKey;
        uint256[2] sigGroupSignature;
    }

    /** @dev size in bytes of a RCert cap'npro structure without the cap'n proto
      header bytes */
    uint256 internal constant _RCERT_SIZE = 264;
    /** @dev Number of bytes of a capnproto header, the state starts after the
      header */
    uint256 internal constant _CAPNPROTO_HEADER_SIZE = 8;
    /** @dev Number of Bytes of the sig group array */
    uint256 internal constant _SIG_GROUP_SIZE = 192;

    /// @notice Extracts the signature group out of a Capn Proto blob.
    /// @param src Binary state containing signature group state
    /// @param dataOffset offset of the signature group state inside src
    /// @return publicKey the public keys
    /// @return signature the signature
    /// @dev Execution cost: 1645 gas.
    function extractSigGroup(
        bytes memory src,
        uint256 dataOffset
    ) internal pure returns (uint256[4] memory publicKey, uint256[2] memory signature) {
        if (dataOffset + RCertParserLibrary._SIG_GROUP_SIZE <= dataOffset) {
            revert GenericParserLibraryErrors.DataOffsetOverflow();
        }
        if (src.length < dataOffset + RCertParserLibrary._SIG_GROUP_SIZE) {
            revert GenericParserLibraryErrors.InsufficientBytes(
                src.length,
                dataOffset + RCertParserLibrary._SIG_GROUP_SIZE
            );
        }
        // _SIG_GROUP_SIZE = 192 bytes -> size in bytes of 6 uint256/bytes32 elements (6*32)
        publicKey[0] = BaseParserLibrary.extractUInt256(src, dataOffset + 0);
        publicKey[1] = BaseParserLibrary.extractUInt256(src, dataOffset + 32);
        publicKey[2] = BaseParserLibrary.extractUInt256(src, dataOffset + 64);
        publicKey[3] = BaseParserLibrary.extractUInt256(src, dataOffset + 96);
        signature[0] = BaseParserLibrary.extractUInt256(src, dataOffset + 128);
        signature[1] = BaseParserLibrary.extractUInt256(src, dataOffset + 160);
    }

    /**
    @notice This function is for deserializing state directly from capnproto
            RCert. It will skip the first 8 bytes (capnproto headers) and
            deserialize the RCert Data. If RCert is being extracted from
            inside of other structure (E.g PClaim capnproto) use the
            `extractInnerRCert(bytes, uint)` instead.
    */
    /// @param src Binary state containing a RCert serialized struct with Capn Proto headers
    /// @return the RCert struct
    /// @dev Execution cost: 4076 gas
    function extractRCert(bytes memory src) internal pure returns (RCert memory) {
        return extractInnerRCert(src, _CAPNPROTO_HEADER_SIZE);
    }

    /**
    @notice This function is for deserializing the RCert struct from an defined
            location inside a binary blob. E.G Extract RCert from inside of
            other structure (E.g RCert capnproto) or skipping the capnproto
            headers.
    */
    /// @param src Binary state containing a RCert serialized struct without Capn Proto headers
    /// @param dataOffset offset to start reading the RCert state from inside src
    /// @return rCert the RCert struct
    /// @dev Execution cost: 3691 gas
    function extractInnerRCert(
        bytes memory src,
        uint256 dataOffset
    ) internal pure returns (RCert memory rCert) {
        if (dataOffset + _RCERT_SIZE <= dataOffset) {
            revert GenericParserLibraryErrors.DataOffsetOverflow();
        }
        if (src.length < dataOffset + _RCERT_SIZE) {
            revert GenericParserLibraryErrors.InsufficientBytes(
                src.length,
                dataOffset + _RCERT_SIZE
            );
        }
        rCert.rClaims = RClaimsParserLibrary.extractInnerRClaims(src, dataOffset + 16);
        (rCert.sigGroupPublicKey, rCert.sigGroupSignature) = extractSigGroup(src, dataOffset + 72);
    }
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/libraries/errors/GenericParserLibraryErrors.sol";

import "contracts/libraries/parsers/BaseParserLibrary.sol";

/// @title Library to parse the RClaims structure from a blob of capnproto state
library RClaimsParserLibrary {
    struct RClaims {
        uint32 chainId;
        uint32 height;
        uint32 round;
        bytes32 prevBlock;
    }

    /** @dev size in bytes of a RCLAIMS cap'npro structure without the cap'n
      proto header bytes*/
    uint256 internal constant _RCLAIMS_SIZE = 56;
    /** @dev Number of bytes of a capnproto header, the state starts after the
      header */
    uint256 internal constant _CAPNPROTO_HEADER_SIZE = 8;

    /**
    @notice This function is for deserializing state directly from capnproto
            RClaims. It will skip the first 8 bytes (capnproto headers) and
            deserialize the RClaims Data. If RClaims is being extracted from
            inside of other structure (E.g RCert capnproto) use the
            `extractInnerRClaims(bytes, uint)` instead.
    */
    /// @param src Binary state containing a RClaims serialized struct with Capn Proto headers
    /// @dev Execution cost: 1506 gas
    function extractRClaims(bytes memory src) internal pure returns (RClaims memory rClaims) {
        return extractInnerRClaims(src, _CAPNPROTO_HEADER_SIZE);
    }

    /**
    @notice This function is for serializing the RClaims struct from an defined
            location inside a binary blob. E.G Extract RClaims from inside of
            other structure (E.g RCert capnproto) or skipping the capnproto
            headers.
    */
    /// @param src Binary state containing a RClaims serialized struct without Capn Proto headers
    /// @param dataOffset offset to start reading the RClaims state from inside src
    /// @dev Execution cost: 1332 gas
    function extractInnerRClaims(
        bytes memory src,
        uint256 dataOffset
    ) internal pure returns (RClaims memory rClaims) {
        if (dataOffset + _RCLAIMS_SIZE <= dataOffset) {
            revert GenericParserLibraryErrors.DataOffsetOverflow();
        }
        if (src.length < dataOffset + _RCLAIMS_SIZE) {
            revert GenericParserLibraryErrors.InsufficientBytes(
                src.length,
                dataOffset + _RCLAIMS_SIZE
            );
        }
        rClaims.chainId = BaseParserLibrary.extractUInt32(src, dataOffset);
        if (rClaims.chainId == 0) {
            revert GenericParserLibraryErrors.ChainIdZero();
        }
        rClaims.height = BaseParserLibrary.extractUInt32(src, dataOffset + 4);
        if (rClaims.height == 0) {
            revert GenericParserLibraryErrors.HeightZero();
        }
        rClaims.round = BaseParserLibrary.extractUInt32(src, dataOffset + 8);
        if (rClaims.round == 0) {
            revert GenericParserLibraryErrors.RoundZero();
        }
        rClaims.prevBlock = BaseParserLibrary.extractBytes32(src, dataOffset + 24);
    }
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/interfaces/IValidatorPool.sol";
import "contracts/interfaces/ISnapshots.sol";
import "contracts/libraries/parsers/PClaimsParserLibrary.sol";
import "contracts/libraries/math/CryptoLibrary.sol";
import "contracts/utils/auth/ImmutableFactory.sol";
import "contracts/utils/auth/ImmutableSnapshots.sol";
import "contracts/utils/auth/ImmutableETHDKG.sol";
import "contracts/utils/auth/ImmutableValidatorPool.sol";
import "contracts/utils/AccusationsLibrary.sol";
import "contracts/libraries/errors/AccusationsErrors.sol";

/// @custom:salt MultipleProposalAccusation
/// @custom:deploy-type deployUpgradeable
/// @custom:salt-type Accusation
contract MultipleProposalAccusation is
    ImmutableFactory,
    ImmutableSnapshots,
    ImmutableETHDKG,
    ImmutableValidatorPool
{
    mapping(bytes32 => bool) internal _accusations;

    constructor()
        ImmutableFactory(msg.sender)
        ImmutableSnapshots()
        ImmutableETHDKG()
        ImmutableValidatorPool()
    {}

    /// @notice This function validates an accusation of multiple proposals.
    /// @param _signature0 The signature of pclaims0
    /// @param _pClaims0 The PClaims of the accusation
    /// @param _signature1 The signature of pclaims1
    /// @param _pClaims1 The PClaims of the accusation
    /// @return the address of the signer
    function accuseMultipleProposal(
        bytes calldata _signature0,
        bytes calldata _pClaims0,
        bytes calldata _signature1,
        bytes calldata _pClaims1
    ) public view returns (address) {
        // ecrecover sig0/1 and ensure both are valid and accounts are equal
        address signerAccount0 = AccusationsLibrary.recoverMadNetSigner(_signature0, _pClaims0);
        address signerAccount1 = AccusationsLibrary.recoverMadNetSigner(_signature1, _pClaims1);

        if (signerAccount0 != signerAccount1) {
            revert AccusationsErrors.SignersDoNotMatch(signerAccount0, signerAccount1);
        }

        // ensure the hashes of blob0/1 are different
        if (keccak256(_pClaims0) == keccak256(_pClaims1)) {
            revert AccusationsErrors.PClaimsAreEqual();
        }

        PClaimsParserLibrary.PClaims memory pClaims0 = PClaimsParserLibrary.extractPClaims(
            _pClaims0
        );
        PClaimsParserLibrary.PClaims memory pClaims1 = PClaimsParserLibrary.extractPClaims(
            _pClaims1
        );

        // ensure the height of blob0/1 are equal using RCert sub object of PClaims
        if (pClaims0.rCert.rClaims.height != pClaims1.rCert.rClaims.height) {
            revert AccusationsErrors.PClaimsHeightsDoNotMatch(
                pClaims0.rCert.rClaims.height,
                pClaims1.rCert.rClaims.height
            );
        }

        // ensure the round of blob0/1 are equal using RCert sub object of PClaims
        if (pClaims0.rCert.rClaims.round != pClaims1.rCert.rClaims.round) {
            revert AccusationsErrors.PClaimsRoundsDoNotMatch(
                pClaims0.rCert.rClaims.round,
                pClaims1.rCert.rClaims.round
            );
        }

        // ensure the chainid of blob0/1 are equal using RCert sub object of PClaims
        if (pClaims0.rCert.rClaims.chainId != pClaims1.rCert.rClaims.chainId) {
            revert AccusationsErrors.PClaimsChainIdsDoNotMatch(
                pClaims0.rCert.rClaims.chainId,
                pClaims1.rCert.rClaims.chainId
            );
        }

        // ensure the chainid of blob0 is correct for this chain using RCert sub object of PClaims
        uint256 chainId = ISnapshots(_snapshotsAddress()).getChainId();
        if (pClaims0.rCert.rClaims.chainId != chainId) {
            revert AccusationsErrors.InvalidChainId(pClaims0.rCert.rClaims.chainId, chainId);
        }

        // ensure both accounts are applicable to a currently locked validator - Note<may be done in different layer?>
        if (!IValidatorPool(_validatorPoolAddress()).isAccusable(signerAccount0)) {
            revert AccusationsErrors.SignerNotValidValidator(signerAccount0);
        }

        return signerAccount0;
    }
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/libraries/errors/AccusationsErrors.sol";

library AccusationsLibrary {
    /// @notice Recovers the signer of a message
    /// @param signature The ECDSA signature
    /// @param prefix The prefix of the message
    /// @param message The message
    /// @return the address of the signer
    function recoverSigner(
        bytes memory signature,
        bytes memory prefix,
        bytes memory message
    ) internal pure returns (address) {
        if (signature.length != 65) {
            revert AccusationsErrors.SignatureLengthMustBe65Bytes(signature.length);
        }

        bytes32 hashedMessage = keccak256(abi.encodePacked(prefix, message));

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly ("memory-safe") {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        v = (v < 27) ? (v + 27) : v;

        if (v != 27 && v != 28) {
            revert AccusationsErrors.InvalidSignatureVersion(v);
        }

        return ecrecover(hashedMessage, v, r, s);
    }

    /// @notice Recovers the signer of a message in MadNet
    /// @param signature The ECDSA signature
    /// @param message The message
    /// @return the address of the signer
    function recoverMadNetSigner(
        bytes memory signature,
        bytes memory message
    ) internal pure returns (address) {
        return recoverSigner(signature, "Proposal", message);
    }

    /// @notice Computes the UTXOID
    /// @param txHash the transaction hash
    /// @param txIdx the transaction index
    /// @return the UTXOID
    function computeUTXOID(bytes32 txHash, uint32 txIdx) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(txHash, txIdx));
    }
}

// This file is auto-generated by hardhat generate-immutable-auth-contract task. DO NOT EDIT.
// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/utils/DeterministicAddress.sol";
import "contracts/utils/auth/ImmutableFactory.sol";

abstract contract ImmutableETHDKG is ImmutableFactory {
    address private immutable _ethdkg;
    error OnlyETHDKG(address sender, address expected);

    modifier onlyETHDKG() {
        if (msg.sender != _ethdkg) {
            revert OnlyETHDKG(msg.sender, _ethdkg);
        }
        _;
    }

    constructor() {
        _ethdkg = getMetamorphicContractAddress(
            0x455448444b470000000000000000000000000000000000000000000000000000,
            _factoryAddress()
        );
    }

    function _ethdkgAddress() internal view returns (address) {
        return _ethdkg;
    }

    function _saltForETHDKG() internal pure returns (bytes32) {
        return 0x455448444b470000000000000000000000000000000000000000000000000000;
    }
}

// This file is auto-generated by hardhat generate-immutable-auth-contract task. DO NOT EDIT.
// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/utils/DeterministicAddress.sol";

abstract contract ImmutableFactory is DeterministicAddress {
    address private immutable _factory;
    error OnlyFactory(address sender, address expected);

    modifier onlyFactory() {
        if (msg.sender != _factory) {
            revert OnlyFactory(msg.sender, _factory);
        }
        _;
    }

    constructor(address factory_) {
        _factory = factory_;
    }

    function _factoryAddress() internal view returns (address) {
        return _factory;
    }
}

// This file is auto-generated by hardhat generate-immutable-auth-contract task. DO NOT EDIT.
// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/utils/DeterministicAddress.sol";
import "contracts/utils/auth/ImmutableFactory.sol";

abstract contract ImmutableSnapshots is ImmutableFactory {
    address private immutable _snapshots;
    error OnlySnapshots(address sender, address expected);

    modifier onlySnapshots() {
        if (msg.sender != _snapshots) {
            revert OnlySnapshots(msg.sender, _snapshots);
        }
        _;
    }

    constructor() {
        _snapshots = getMetamorphicContractAddress(
            0x536e617073686f74730000000000000000000000000000000000000000000000,
            _factoryAddress()
        );
    }

    function _snapshotsAddress() internal view returns (address) {
        return _snapshots;
    }

    function _saltForSnapshots() internal pure returns (bytes32) {
        return 0x536e617073686f74730000000000000000000000000000000000000000000000;
    }
}

// This file is auto-generated by hardhat generate-immutable-auth-contract task. DO NOT EDIT.
// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/utils/DeterministicAddress.sol";
import "contracts/utils/auth/ImmutableFactory.sol";

abstract contract ImmutableValidatorPool is ImmutableFactory {
    address private immutable _validatorPool;
    error OnlyValidatorPool(address sender, address expected);

    modifier onlyValidatorPool() {
        if (msg.sender != _validatorPool) {
            revert OnlyValidatorPool(msg.sender, _validatorPool);
        }
        _;
    }

    constructor() {
        _validatorPool = getMetamorphicContractAddress(
            0x56616c696461746f72506f6f6c00000000000000000000000000000000000000,
            _factoryAddress()
        );
    }

    function _validatorPoolAddress() internal view returns (address) {
        return _validatorPool;
    }

    function _saltForValidatorPool() internal pure returns (bytes32) {
        return 0x56616c696461746f72506f6f6c00000000000000000000000000000000000000;
    }
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

import "contracts/libraries/errors/CustomEnumerableMapsErrors.sol";

struct ValidatorData {
    address _address;
    uint256 _tokenID;
}

struct ExitingValidatorData {
    uint128 _tokenID;
    uint128 _freeAfter;
}

struct ValidatorDataMap {
    ValidatorData[] _values;
    mapping(address => uint256) _indexes;
}

library CustomEnumerableMaps {
    /**
     * @dev Add a value to a map. O(1).
     *
     * Returns true if the value was added to the map, that is if it was not
     * already present.
     */
    function add(ValidatorDataMap storage map, ValidatorData memory value) internal returns (bool) {
        if (!contains(map, value._address)) {
            map._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            map._indexes[value._address] = map._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a map using its address. O(1).
     *
     * Returns true if the value was removed from the map, that is if it was
     * present.
     */
    function remove(ValidatorDataMap storage map, address key) internal returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = map._indexes[key];

        if (valueIndex != 0) {
            // Equivalent to contains(map, key)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = map._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                ValidatorData memory lastValue = map._values[lastIndex];

                // Move the last value to the index where the value to delete is
                map._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                map._indexes[lastValue._address] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved key was stored
            map._values.pop();

            // Delete the index for the deleted slot
            delete map._indexes[key];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(ValidatorDataMap storage map, address key) internal view returns (bool) {
        return map._indexes[key] != 0;
    }

    /**
     * @dev Returns the number of values in the map. O(1).
     */
    function length(ValidatorDataMap storage map) internal view returns (uint256) {
        return map._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the map. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(
        ValidatorDataMap storage map,
        uint256 index
    ) internal view returns (ValidatorData memory) {
        return map._values[index];
    }

    /**
     * @dev Tries to returns the value associated with `key`.  O(1).
     * Does not revert if `key` is not in the map.
     *
     */
    function tryGet(
        ValidatorDataMap storage map,
        address key
    ) internal view returns (bool, ValidatorData memory) {
        uint256 index = map._indexes[key];
        if (index == 0) {
            return (false, ValidatorData(address(0), 0));
        } else {
            return (true, map._values[index - 1]);
        }
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(
        ValidatorDataMap storage map,
        address key
    ) internal view returns (ValidatorData memory) {
        (bool success, ValidatorData memory value) = tryGet(map, key);
        if (!success) {
            revert CustomEnumerableMapsErrors.KeyNotInMap(key);
        }
        return value;
    }

    /**
     * @dev Return the entire map in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(ValidatorDataMap storage map) internal view returns (ValidatorData[] memory) {
        return map._values;
    }

    /**
     * @dev Return the address of every entry in the entire map in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function addressValues(ValidatorDataMap storage map) internal view returns (address[] memory) {
        ValidatorData[] memory _values = values(map);
        address[] memory addresses = new address[](_values.length);
        for (uint256 i = 0; i < _values.length; i++) {
            addresses[i] = _values[i]._address;
        }
        return addresses;
    }
}

// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.16;

abstract contract DeterministicAddress {
    function getMetamorphicContractAddress(
        bytes32 _salt,
        address _factory
    ) public pure returns (address) {
        // byte code for metamorphic contract
        // 6020363636335afa1536363636515af43d36363e3d36f3
        bytes32 metamorphicContractBytecodeHash_ = 0x1c0bf703a3415cada9785e89e9d70314c3111ae7d8e04f33bb42eb1d264088be;
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                hex"ff",
                                _factory,
                                _salt,
                                metamorphicContractBytecodeHash_
                            )
                        )
                    )
                )
            );
    }
}