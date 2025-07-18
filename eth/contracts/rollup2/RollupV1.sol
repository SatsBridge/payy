// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IVerifier} from "../noir/IVerifier.sol";
import "../IUSDC.sol";
import "./base/Util.sol";

struct Mint {
    bytes32 note_kind;
    uint256 amount;
}

struct Signature {
    bytes32 r;
    bytes32 s;
    uint v;
}

struct ValidatorSet {
    mapping(address => bool) validators;
    address[] validatorsArray;
    // The height at which this validator set becomes valid, inclusive
    uint256 validFrom;
}

// We can't return a mapping from a public function, so this struct is used for the public
// return valjue
struct PublicValidatorSet {
    address[] validators;
    uint256 validFrom;
}

string constant NETWORK = "Payy";
uint64 constant NETWORK_LEN = 4;

contract RollupV1 is Initializable, OwnableUpgradeable {
    event RollupVerified(uint256 indexed height, bytes32 root);
    event Minted(bytes32 indexed hash, uint256 value, address token);
    event ValidatorSetAdded(uint256 index, uint256 validFrom);
    // TODO: do we not want to include the recipient address here?
    event Burned(
        address indexed token,
        bytes32 indexed burn_hash,
        bool substitute,
        bool success
    );
    event MintAdded(
        bytes32 indexed mint_hash,
        uint256 value,
        bytes32 note_kind
    );

    // Since the Initializable._initialized version number is private, we need to keep track of it ourselves
    uint8 public version;

    // Contracts
    IVerifier public aggregateVerifier;
    IVerifier public mintVerifier;
    IUSDC public usdc;

    // Allowed Proofs
    mapping(bytes32 => bool) allowedVerificationKeyHash;

    // Core rollup values
    uint256 public blockHeight;
    bytes32 public rootHash;

    // Mint - mints are removed after the rollup validates them. Mint hash is hash of commitments.
    mapping(bytes32 => Mint) public mints;

    // Burn Substitutor - stores a mapping of paid out substituted burns, so they can be refunded
    // once the rollup completes the original burn
    // burn hash => burn address => note_kind => amount => to address
    mapping(bytes32 => mapping(address => mapping(bytes32 => mapping(uint256 => address))))
        public substitutedBurns;

    // Allowed Tokens
    mapping(bytes32 => address) tokens;

    // Actors
    mapping(address => uint) provers;

    // Validators
    mapping(uint256 => ValidatorSet) private validatorSets;
    uint256 private validatorSetsLength;
    uint256 private validatorSetIndex;

    // Burn substitutors
    mapping(address => bool) private burnSubstitutors;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        address _usdcAddress,
        address _aggregateVerifier,
        address _mintVerifier,
        address prover,
        address[] calldata initialValidators,
        bytes32 emptyMerkleTreeRootHash,
        bytes32 verificationKeyHash
    ) public initializer {
        version = 1;

        __Ownable_init(owner);

        usdc = IUSDC(_usdcAddress);
        aggregateVerifier = IVerifier(_aggregateVerifier);
        mintVerifier = IVerifier(_mintVerifier);
        provers[prover] = 1;
        allowedVerificationKeyHash[verificationKeyHash] = true;

        _setValidators(0, initialValidators);

        setRoot(emptyMerkleTreeRootHash);
        addToken(
            0x000200000000000000893c499c542cef5e3811e1192ce70d8cc03d5c33590000,
            _usdcAddress
        );
        burnSubstitutors[owner] = true;
    }

    modifier onlyProver() {
        require(provers[msg.sender] == 1, "You are not a prover");
        _;
    }

    function addProver(address prover) public onlyOwner {
        provers[prover] = 1;
    }

    modifier onlyBurnSubstitutor() {
        require(
            burnSubstitutors[msg.sender] == true,
            "You are not a burn substitutor"
        );
        _;
    }

    function addBurnSubstitutor(address burnSubstitutor) public onlyOwner {
        burnSubstitutors[burnSubstitutor] = true;
    }

    function removeBurnSubstitutor(address burnSubstitutor) public onlyOwner {
        burnSubstitutors[burnSubstitutor] = false;
    }

    function setRoot(bytes32 newRoot) public onlyOwner {
        rootHash = newRoot;
    }

    function currentRootHash() public view returns (bytes32) {
        return rootHash;
    }

    function addToken(bytes32 noteKind, address tokenAddress) public onlyOwner {
        require(
            tokens[noteKind] == address(0),
            "RollupV1: Token already exists"
        );

        tokens[noteKind] = tokenAddress;
    }

    function noteKindTokenAddress(
        bytes32 noteKind
    ) public view returns (address) {
        return tokens[noteKind];
    }

    function setAllowedVerificationKeyHash(
        bytes32 verificationKeyHash,
        bool isAllowed
    ) public onlyOwner {
        allowedVerificationKeyHash[verificationKeyHash] = isAllowed;
    }

    function isVerificationKeyHashAllowed(
        bytes32 verificationKeyHash
    ) public view returns (bool) {
        return allowedVerificationKeyHash[verificationKeyHash];
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("Rollup")),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(this)
                )
            );
    }

    bytes32 constant MINT_WITH_AUTHORIZATION_TYPE_HASH =
        keccak256(
            "MintWithAuthorization(bytes32 commitment,bytes32 value,bytes32 kind,address from,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
        );

    /////////////////
    //
    // VERIFY
    //
    ///////////

    // TODO: we should break up this fn for more re-use
    // Verify rollup with 36 messages
    function verifyRollup36(
        uint256 height,
        bytes calldata aggrProof,
        // verificationKeyHash, oldRoot, newRoot, commitHash, 6 utxo x 6 messages per utxo + 16 kzg
        bytes32[] calldata publicInputs,
        bytes32 otherHashFromBlockHash,
        Signature[] calldata signatures
    ) public onlyProver {
        bytes32 verificationKeyHash = publicInputs[0];
        bytes32 oldRoot = publicInputs[1];
        bytes32 newRoot = publicInputs[2];
        bytes32 commitHash = publicInputs[3];

        require(
            allowedVerificationKeyHash[verificationKeyHash],
            "RollupV1: Proof verification key not allowed"
        );

        require(
            oldRoot == rootHash,
            "RollupV1: Old root does not match the current root"
        );

        verifyCommitHash(commitHash);

        // Verify validator
        verifyValidatorSignatures(
            newRoot,
            height,
            otherHashFromBlockHash,
            signatures
        );

        // Check mints/burns
        uint i = 4;
        while (i < 4 + 36) {
            i = verifyMessages(i, publicInputs);
        }

        require(
            aggregateVerifier.verify(aggrProof, publicInputs),
            "RollupV1: Rollup proof verification failed"
        );

        setRoot(newRoot);
        rootHash = newRoot;
        blockHeight = height;

        emit RollupVerified(height, newRoot);
    }

    // Placeholder for asserting the commit hash is stored on Celestia
    function verifyCommitHash(bytes32 commitHash) internal {}

    function verifyMessages(
        uint index,
        // This is actually publicInputs, which includes messages
        bytes32[] calldata messages
    ) internal returns (uint) {
        // Get the kind from last byte (least sig number)
        uint8 kind = uint8(bytes1(messages[index][31]));

        if (kind == 0) {
            return index + 1;
        } else if (kind == 1) {
            // Send
            return index + 1;
        } else if (kind == 2) {
            // Mint
            return verifyMint(index, messages);
        } else if (kind == 3) {
            // Burn
            return verifyBurn(index, messages);
        } else {
            // Not allowed
            revert("Invalid message kind");
        }
    }

    function verifyMint(
        uint i,
        bytes32[] calldata messages
    ) internal returns (uint) {
        bytes32 note_kind = messages[i + 1];
        bytes32 value = messages[i + 2];
        bytes32 hash = messages[i + 3];

        require(mints[hash].amount == uint256(value), "Mint value invalid");
        require(mints[hash].note_kind == note_kind, "Mint note kind invalid");

        // Remove the mint once we've ack it
        mints[hash].note_kind = 0;
        mints[hash].amount = 0;

        return i + 6;
    }

    function verifyBurn(
        uint i,
        bytes32[] calldata messages
    ) internal returns (uint) {
        bytes32 note_kind = messages[i + 1];
        uint256 value = uint256(messages[i + 2]);
        bytes32 hash = messages[i + 3];
        address burn_addr = bytes32ToAddress(messages[i + 4]);

        address token = tokens[note_kind];

        address substitutor = substitutedBurns[hash][burn_addr][note_kind][
            value
        ];
        if (substitutor != address(0)) {
            executeBurn(
                token,
                substitutedBurns[hash][burn_addr][note_kind][value],
                hash,
                value,
                false
            );
        } else {
            executeBurn(token, burn_addr, hash, value, false);
        }

        return i + 6;
    }

    function bytes32ToAddress(bytes32 _bytes32) public pure returns (address) {
        // TODO: can we not do address(uint160(_bytes32))
        return address(uint160(uint256(_bytes32)));
    }

    /////////////////
    //
    // BURNS
    //
    ///////////

    function executeBurn(
        address token,
        address recipient,
        bytes32 burn_hash,
        uint256 value,
        bool substitute
    ) internal returns (bool) {
        bool success = executeBurnToAddress(token, recipient, value);
        emit Burned(token, burn_hash, substitute, success);
        return success;
    }

    function executeBurnToAddress(
        address token,
        address recipient,
        uint256 value
    ) internal returns (bool) {
        try IERC20(token).transfer(recipient, value) {
            return true;
        } catch {
            return false;
        }
    }

    function wasBurnSubstituted(
        address burn_address,
        bytes32 note_kind,
        bytes32 hash,
        uint256 amount
    ) public view returns (bool) {
        return
            substitutedBurns[hash][burn_address][note_kind][amount] !=
            address(0);
    }

    function substituteBurn(
        address burnAddress,
        bytes32 note_kind,
        bytes32 hash,
        uint256 amount,
        uint256 burnBlockHeight
    ) public onlyBurnSubstitutor {
        substituteBurnTo(
            burnAddress,
            msg.sender,
            note_kind,
            hash,
            amount,
            burnBlockHeight
        );
    }

    function substituteBurnTo(
        address burnAddress,
        address substituteAddress,
        bytes32 note_kind,
        bytes32 hash,
        uint256 amount,
        uint256 burnBlockHeight
    ) private {
        require(
            substitutedBurns[hash][burnAddress][note_kind][amount] ==
                address(0),
            "RollupV1: Burn already substituted"
        );
        require(
            blockHeight < burnBlockHeight,
            "RollupV1: block height already rolled up"
        );

        address token = tokens[note_kind];
        require(token != address(0), "RollupV1: Token not found for note kind");

        require(
            IERC20(token).transferFrom(
                substituteAddress,
                address(this),
                amount
            ),
            "RollupV1: Transfer failed"
        );

        bool success = executeBurn(token, burnAddress, hash, amount, true);
        require(success, "RollupV1: Burn failed");

        // This will be returned to the msg.sender when the rollup block for it is submitted
        substitutedBurns[hash][burnAddress][note_kind][
            amount
        ] = substituteAddress;
    }

    /////////////////
    //
    // MINTS
    //
    ///////////

    function getMint(bytes32 hash) public view returns (Mint memory) {
        return mints[hash];
    }

    // Anyone can call mint, although this is likely to be performed on behalf of the user
    // as they may not have gas to pay for the txn
    function mint(bytes32 mint_hash, bytes32 value, bytes32 note_kind) public {
        if (mints[mint_hash].amount != 0) {
            revert("Mint already exists");
        }

        address tokenAddress = tokens[note_kind];
        require(
            tokenAddress != address(0),
            "RollupV1: Token not found for note kind"
        );

        // Take the money from the external account, sender must have been previously
        // approved as per the ERC20 standard
        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            uint256(value)
        );

        // Add mint to pending mints, this still needs to be verifier with the verifyBlock,
        // but Solid validators will check that this commitment exists in the mint map before
        // accepting the mint txn into a block
        mints[mint_hash] = Mint({note_kind: note_kind, amount: uint256(value)});

        emit MintAdded(mint_hash, uint256(value), note_kind);
    }

    function mintWithAuthorization(
        bytes32 mint_hash,
        bytes32 value,
        bytes32 note_kind,
        address from,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint256 v,
        bytes32 r,
        bytes32 s,
        // Second signature, not for receiveWithAuthorization,
        // but for this mintWithAuthorization call
        uint256 v2,
        bytes32 r2,
        bytes32 s2
    ) public {
        if (mints[mint_hash].amount != 0) {
            revert("Mint already exists");
        }

        bytes32 structHash = keccak256(
            abi.encode(
                MINT_WITH_AUTHORIZATION_TYPE_HASH,
                mint_hash,
                value,
                note_kind,
                from,
                validAfter,
                validBefore,
                nonce
            )
        );
        bytes32 computedHash = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash)
        );
        address signer = ECDSA.recover(computedHash, uint8(v2), r2, s2);
        require(signer == from, "RollupV1: Invalid signer");

        address tokenAddress = tokens[note_kind];
        require(
            tokenAddress != address(0),
            "RollupV1: Token not found for note kind"
        );

        // This will fail if the token does not support receiveWithAuthorization
        // method in the defined format. Users of this method must ensure that
        // the token supports it.
        IUSDC(tokenAddress).receiveWithAuthorization(
            from,
            address(this),
            uint256(value),
            validAfter,
            validBefore,
            nonce,
            uint8(v),
            r,
            s
        );

        mints[mint_hash] = Mint({note_kind: note_kind, amount: uint256(value)});
        emit MintAdded(mint_hash, uint256(value), note_kind);
    }

    /////////////////
    //
    // VALIDATORS
    //
    ///////////
    function verifyValidatorSignatures(
        bytes32 newRoot,
        uint256 height,
        bytes32 otherHashFromBlockHash,
        Signature[] calldata signatures
    ) internal {
        updateValidatorSetIndex(height);
        ValidatorSet storage validatorSet = getValidators();

        require(signatures.length > 0, "No signatures");

        uint minValidators = (validatorSet.validatorsArray.length * 2) / 3 + 1;
        require(
            signatures.length >= minValidators,
            "Not enough signatures from validators to verify block"
        );

        bytes32 sigHash = getSignatureMessageHash(
            newRoot,
            height,
            otherHashFromBlockHash
        );

        address previous = address(0);
        for (uint i = 0; i < signatures.length; i++) {
            Signature calldata signature = signatures[i];
            address signer = ECDSA.recover(
                sigHash,
                uint8(signature.v),
                signature.r,
                signature.s
            );
            require(
                validatorSet.validators[signer] == true,
                "Signer is not a validator"
            );

            require(signer > previous, "Signers are not sorted");
            previous = signer;
        }
    }

    function getSignatureMessageHash(
        bytes32 newRoot,
        uint256 height,
        bytes32 otherHashFromBlockHash
    ) internal pure returns (bytes32) {
        bytes32 proposalHash = keccak256(
            abi.encode(newRoot, height, otherHashFromBlockHash)
        );
        bytes32 acceptMsg = keccak256(abi.encode(height + 1, proposalHash));
        bytes32 sigMsg = keccak256(
            abi.encodePacked(NETWORK_LEN, NETWORK, acceptMsg)
        );
        return sigMsg;
    }

    // Returns all validator sets from a given index, inclusive
    function getValidatorSets(
        uint256 from
    ) public view returns (PublicValidatorSet[] memory) {
        PublicValidatorSet[] memory sets = new PublicValidatorSet[](
            validatorSetsLength - from
        );

        for (uint256 i = from; i < validatorSetsLength; i++) {
            sets[i - from] = PublicValidatorSet(
                validatorSets[i].validatorsArray,
                validatorSets[i].validFrom
            );
        }

        return sets;
    }

    function getValidators() internal view returns (ValidatorSet storage) {
        return validatorSets[validatorSetIndex];
    }

    function _setValidators(
        uint256 validFrom,
        address[] calldata validators
    ) private {
        require(
            validatorSetsLength == 0 ||
                validatorSets[validatorSetsLength - 1].validFrom < validFrom,
            "New validator set must have a validFrom greater than the last set"
        );

        validatorSets[validatorSetsLength].validFrom = validFrom;
        validatorSets[validatorSetsLength].validatorsArray = validators;

        for (uint256 i = 0; i < validators.length; i++) {
            require(
                validatorSets[validatorSetsLength].validators[validators[i]] ==
                    false,
                "Validator already exists"
            );

            validatorSets[validatorSetsLength].validators[validators[i]] = true;
        }

        emit ValidatorSetAdded(validatorSetsLength, validFrom);
        validatorSetsLength += 1;
    }

    function setValidators(
        uint256 validFrom,
        address[] calldata validators
    ) public onlyOwner {
        _setValidators(validFrom, validators);
    }

    function updateValidatorSetIndex(uint256 height) internal {
        for (uint256 i = validatorSetIndex + 1; i < validatorSetsLength; i++) {
            if (validatorSets[i].validFrom > height) {
                break;
            }

            validatorSetIndex = i;
        }
    }
}
