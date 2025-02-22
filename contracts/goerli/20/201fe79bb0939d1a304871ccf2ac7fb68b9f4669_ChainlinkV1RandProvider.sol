// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {unsafeWadDiv} from "solmate/utils/SignedWadMath.sol";

import {VRGDA} from "./VRGDA.sol";
import {LogisticVRGDA} from "./LogisticVRGDA.sol";

abstract contract LogisticToLinearVRGDA is LogisticVRGDA {
    int256 internal immutable soldBySwitch;

    int256 internal immutable switchTime;

    int256 internal immutable perTimeUnit;

    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _logisticAsymptote,
        int256 _timeScale,
        int256 _soldBySwitch,
        int256 _switchTime,
        int256 _perTimeUnit
    ) LogisticVRGDA(_targetPrice, _priceDecayPercent, _logisticAsymptote, _timeScale) {
        soldBySwitch = _soldBySwitch;

        switchTime = _switchTime;

        perTimeUnit = _perTimeUnit;
    }

    function getTargetSaleTime(int256 sold) public view virtual override returns (int256) {
        if (sold < soldBySwitch) return LogisticVRGDA.getTargetSaleTime(sold);

        unchecked {
            return unsafeWadDiv(sold - soldBySwitch, perTimeUnit) + switchTime;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {wadLn, unsafeDiv, unsafeWadDiv} from "solmate/utils/SignedWadMath.sol";

import {VRGDA} from "./VRGDA.sol";

abstract contract LogisticVRGDA is VRGDA {
    int256 internal immutable logisticLimit;

    int256 internal immutable logisticLimitDoubled;

    int256 internal immutable timeScale;

    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _maxSellable,
        int256 _timeScale
    ) VRGDA(_targetPrice, _priceDecayPercent) {
        logisticLimit = _maxSellable + 1e18;

        logisticLimitDoubled = logisticLimit * 2e18;

        timeScale = _timeScale;
    }

    function getTargetSaleTime(int256 sold) public view virtual override returns (int256) {
        unchecked {
            return -unsafeWadDiv(wadLn(unsafeDiv(logisticLimitDoubled, sold + logisticLimit) - 1e18), timeScale);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {wadExp, wadLn, wadMul, unsafeWadMul, toWadUnsafe} from "solmate/utils/SignedWadMath.sol";


abstract contract VRGDA {
    int256 public immutable targetPrice;

    int256 internal immutable decayConstant;

    constructor(int256 _targetPrice, int256 _priceDecayPercent) {
        targetPrice = _targetPrice;

        decayConstant = wadLn(1e18 - _priceDecayPercent);

        require(decayConstant < 0, "NON_NEGATIVE_DECAY_CONSTANT");
    }

    function getVRGDAPrice(int256 timeSinceStart, uint256 sold) public view virtual returns (uint256) {
        unchecked {
            return uint256(wadMul(targetPrice, wadExp(unsafeWadMul(decayConstant,
                timeSinceStart - getTargetSaleTime(toWadUnsafe(sold + 1))
            ))));
        }
    }

    function getTargetSaleTime(int256 sold) public view virtual returns (int256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/LinkTokenInterface.sol";

import "./VRFRequestIDBase.sol";

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constructor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator, _link) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash), and have told you the minimum LINK
 * @dev price for VRF service. Make sure your contract has sufficient LINK, and
 * @dev call requestRandomness(keyHash, fee, seed), where seed is the input you
 * @dev want to generate randomness from.
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomness method.
 *
 * @dev The randomness argument to fulfillRandomness is the actual random value
 * @dev generated from your seed.
 *
 * @dev The requestId argument is generated from the keyHash and the seed by
 * @dev makeRequestId(keyHash, seed). If your contract could have concurrent
 * @dev requests open, you can use the requestId to track which seed is
 * @dev associated with which randomness. See VRFRequestIDBase.sol for more
 * @dev details. (See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.)
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ. (Which is critical to making unpredictable randomness! See the
 * @dev next section.)
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the ultimate input to the VRF is mixed with the block hash of the
 * @dev block in which the request is made, user-provided seeds have no impact
 * @dev on its economic security properties. They are only included for API
 * @dev compatability with previous versions of this contract.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request.
 */
abstract contract VRFConsumerBase is VRFRequestIDBase {
  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBase expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomness the VRF output
   */
  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal virtual;

  /**
   * @dev In order to keep backwards compatibility we have kept the user
   * seed field around. We remove the use of it because given that the blockhash
   * enters later, it overrides whatever randomness the used seed provides.
   * Given that it adds no security, and can easily lead to misunderstandings,
   * we have removed it from usage and can now provide a simpler API.
   */
  uint256 private constant USER_SEED_PLACEHOLDER = 0;

  /**
   * @notice requestRandomness initiates a request for VRF output given _seed
   *
   * @dev The fulfillRandomness method receives the output, once it's provided
   * @dev by the Oracle, and verified by the vrfCoordinator.
   *
   * @dev The _keyHash must already be registered with the VRFCoordinator, and
   * @dev the _fee must exceed the fee specified during registration of the
   * @dev _keyHash.
   *
   * @dev The _seed parameter is vestigial, and is kept only for API
   * @dev compatibility with older versions. It can't *hurt* to mix in some of
   * @dev your own randomness, here, but it's not necessary because the VRF
   * @dev oracle will mix the hash of the block containing your request into the
   * @dev VRF seed it ultimately uses.
   *
   * @param _keyHash ID of public key against which randomness is generated
   * @param _fee The amount of LINK to send with the request
   *
   * @return requestId unique ID for this request
   *
   * @dev The returned requestId can be used to distinguish responses to
   * @dev concurrent requests. It is passed as the first argument to
   * @dev fulfillRandomness.
   */
  function requestRandomness(bytes32 _keyHash, uint256 _fee) internal returns (bytes32 requestId) {
    LINK.transferAndCall(vrfCoordinator, _fee, abi.encode(_keyHash, USER_SEED_PLACEHOLDER));
    // This is the seed passed to VRFCoordinator. The oracle will mix this with
    // the hash of the block containing this request to obtain the seed/input
    // which is finally passed to the VRF cryptographic machinery.
    uint256 vRFSeed = makeVRFInputSeed(_keyHash, USER_SEED_PLACEHOLDER, address(this), nonces[_keyHash]);
    // nonces[_keyHash] must stay in sync with
    // VRFCoordinator.nonces[_keyHash][this], which was incremented by the above
    // successful LINK.transferAndCall (in VRFCoordinator.randomnessRequest).
    // This provides protection against the user repeating their input seed,
    // which would result in a predictable/duplicate output, if multiple such
    // requests appeared in the same block.
    nonces[_keyHash] = nonces[_keyHash] + 1;
    return makeRequestId(_keyHash, vRFSeed);
  }

  LinkTokenInterface internal immutable LINK;
  address private immutable vrfCoordinator;

  // Nonces for each VRF key from which randomness has been requested.
  //
  // Must stay in sync with VRFCoordinator[_keyHash][this]
  mapping(bytes32 => uint256) /* keyHash */ /* nonce */
    private nonces;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   * @param _link address of LINK token contract
   *
   * @dev https://docs.chain.link/docs/link-token-contracts
   */
  constructor(address _vrfCoordinator, address _link) {
    vrfCoordinator = _vrfCoordinator;
    LINK = LinkTokenInterface(_link);
  }

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomness(bytes32 requestId, uint256 randomness) external {
    require(msg.sender == vrfCoordinator, "Only VRFCoordinator can fulfill");
    fulfillRandomness(requestId, randomness);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VRFRequestIDBase {
  /**
   * @notice returns the seed which is actually input to the VRF coordinator
   *
   * @dev To prevent repetition of VRF output due to repetition of the
   * @dev user-supplied seed, that seed is combined in a hash with the
   * @dev user-specific nonce, and the address of the consuming contract. The
   * @dev risk of repetition is mostly mitigated by inclusion of a blockhash in
   * @dev the final seed, but the nonce does protect against repetition in
   * @dev requests which are included in a single block.
   *
   * @param _userSeed VRF seed input provided by user
   * @param _requester Address of the requesting contract
   * @param _nonce User-specific nonce at the time of the request
   */
  function makeVRFInputSeed(
    bytes32 _keyHash,
    uint256 _userSeed,
    address _requester,
    uint256 _nonce
  ) internal pure returns (uint256) {
    return uint256(keccak256(abi.encode(_keyHash, _userSeed, _requester, _nonce)));
  }

  /**
   * @notice Returns the id for this request
   * @param _keyHash The serviceAgreement ID to be used for this request
   * @param _vRFInputSeed The seed to be passed directly to the VRF
   * @return The id for this request
   *
   * @dev Note that _vRFInputSeed is not the seed passed by the consuming
   * @dev contract, but the one generated by makeVRFInputSeed
   */
  function makeRequestId(bytes32 _keyHash, uint256 _vRFInputSeed) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_keyHash, _vRFInputSeed));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";


library LibEOM {
    using FixedPointMathLib for uint256;

    function computeGOOBalance(
        uint256 emissionMultiple,
        uint256 lastBalanceWad,
        uint256 timeElapsedWad
    ) internal pure returns (uint256) {
        unchecked {
            uint256 timeElapsedSquaredWad = timeElapsedWad.mulWadDown(timeElapsedWad);

            return lastBalanceWad +

            ((emissionMultiple * timeElapsedSquaredWad) >> 2) +

            timeElapsedWad.mulWadDown( 
               (emissionMultiple * lastBalanceWad * 1e18).sqrt()
            );
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

abstract contract Owned {
    event OwnershipTransferred(address indexed user, address indexed newOwner);

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

abstract contract ERC1155 {

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);


    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;


    function uri(uint256 id) public view virtual returns (string memory);


    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;

            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }


    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || 
            interfaceId == 0xd9b67a26 || 
            interfaceId == 0x0e89341c;
    }

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        balanceOf[to][id] += amount;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        uint256 idsLength = ids.length;

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[to][ids[i]] += amounts[i];

            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        uint256 idsLength = ids.length;

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            balanceOf[from][ids[i]] -= amounts[i];

            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, amounts);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[from][id] -= amount;

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

abstract contract ERC20 {

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    string public name;

    string public symbol;

    uint8 public immutable decimals;


    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;


    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;


    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }


    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }


    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

abstract contract ERC721 {

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);


    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    mapping(uint256 => address) internal _ownerOf;

    mapping(address => uint256) internal _balanceOf;

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        require((owner = _ownerOf[id]) != address(0), "NOT_MINTED");
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        return _balanceOf[owner];
    }

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;


    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }


    function approve(address spender, uint256 id) public virtual {
        address owner = _ownerOf[id];

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        require(from == _ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }


    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || 
            interfaceId == 0x80ac58cd ||
            interfaceId == 0x5b5e139f;
    }


    function _mint(address to, uint256 id) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");

        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = _ownerOf[id];

        require(owner != address(0), "NOT_MINTED");

        unchecked {
            _balanceOf[owner]--;
        }

        delete _ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }


    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}

abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

library FixedPointMathLib {

    uint256 internal constant MAX_UINT256 = 2**256 - 1;

    uint256 internal constant WAD = 1e18; 

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD);
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD);
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y);
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y);
    }


    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            z := div(mul(x, y), denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    z := scalar
                }
                default {
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    z := scalar
                }
                default {
                    z := x
                }

                let half := shr(1, scalar)

                for {
                    n := shr(1, n)
                } n {
                    n := shr(1, n)
                } {
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    let xx := mul(x, x)

                    let xxRound := add(xx, half)

                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    x := div(xxRound, scalar)

                    if mod(n, 2) {
                        let zx := mul(z, x)

                        if iszero(eq(div(zx, x), z)) {
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        let zxRound := add(zx, half)

                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }


    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            let y := x 

            z := 181 

            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            z := sub(z, lt(div(x, z), z))
        }
    }

    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := mod(x, y)
        }
    }

    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        assembly {
            r := div(x, y)
        }
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

library LibString {
    function toString(uint256 value) internal pure returns (string memory str) {
        assembly {
            let newFreeMemoryPointer := add(mload(0x40), 160)

            mstore(0x40, newFreeMemoryPointer)

            str := sub(newFreeMemoryPointer, 32)

            mstore(str, 0)

            let end := str

           for { let temp := value } 1 {} {
                str := sub(str, 1)

                mstore8(str, add(48, mod(temp, 10)))

                temp := div(temp, 10)

                if iszero(temp) { break }
            }

            let length := sub(end, str)

            str := sub(str, 32)

            mstore(str, length)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

library MerkleProofLib {
    function verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool isValid) {
        assembly {
            if proof.length {
                let end := add(proof.offset, shl(5, proof.length))

                let offset := proof.offset

                for {} 1 {} {
                    let leafSlot := shl(5, gt(leaf, calldataload(offset)))

                    mstore(leafSlot, leaf)
                    mstore(xor(leafSlot, 32), calldataload(offset))

                    leaf := keccak256(0, 64)

                    offset := add(offset, 32) 
                    if iszero(lt(offset, end)) { break }
                }
            }

            isValid := eq(leaf, root) 
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

function toWadUnsafe(uint256 x) pure returns (int256 r) {
    assembly {
        r := mul(x, 1000000000000000000)
    }
}

function toDaysWadUnsafe(uint256 x) pure returns (int256 r) {
    assembly {
        r := div(mul(x, 1000000000000000000), 86400)
    }
}

function fromDaysWadUnsafe(int256 x) pure returns (uint256 r) {
    assembly {
        r := div(mul(x, 86400), 1000000000000000000)
    }
}

function unsafeWadMul(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        r := sdiv(mul(x, y), 1000000000000000000)
    }
}

function unsafeWadDiv(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        r := sdiv(mul(x, 1000000000000000000), y)
    }
}

function wadMul(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        r := mul(x, y)

        if iszero(or(iszero(x), eq(sdiv(r, x), y))) {
            revert(0, 0)
        }

        r := sdiv(r, 1000000000000000000)
    }
}

function wadDiv(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        r := mul(x, 1000000000000000000)

        if iszero(and(iszero(iszero(y)), eq(sdiv(r, 1000000000000000000), x))) {
            revert(0, 0)
        }

        r := sdiv(r, y)
    }
}

function wadExp(int256 x) pure returns (int256 r) {
    unchecked {
        if (x <= -42139678854452767551) return 0;

        if (x >= 135305999368893231589) revert("EXP_OVERFLOW");

        x = (x << 78) / 5**18;

        int256 k = ((x << 96) / 54916777467707473351141471128 + 2**95) >> 96;
        x = x - k * 54916777467707473351141471128;

        int256 y = x + 1346386616545796478920950773328;
        y = ((y * x) >> 96) + 57155421227552351082224309758442;
        int256 p = y + x - 94201549194550492254356042504812;
        p = ((p * y) >> 96) + 28719021644029726153956944680412240;
        p = p * x + (4385272521454847904659076985693276 << 96);

        int256 q = x - 2855989394907223263936484059900;
        q = ((q * x) >> 96) + 50020603652535783019961831881945;
        q = ((q * x) >> 96) - 533845033583426703283633433725380;
        q = ((q * x) >> 96) + 3604857256930695427073651918091429;
        q = ((q * x) >> 96) - 14423608567350463180887372962807573;
        q = ((q * x) >> 96) + 26449188498355588339934803723976023;

        assembly {
            r := sdiv(p, q)
        }

        r = int256((uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k));
    }
}

function wadLn(int256 x) pure returns (int256 r) {
    unchecked {
        require(x > 0, "UNDEFINED");

        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            r := or(r, shl(2, lt(0xf, shr(r, x))))
            r := or(r, shl(1, lt(0x3, shr(r, x))))
            r := or(r, lt(0x1, shr(r, x)))
        }

        int256 k = r - 96;
        x <<= uint256(159 - k);
        x = int256(uint256(x) >> 159);

        int256 p = x + 3273285459638523848632254066296;
        p = ((p * x) >> 96) + 24828157081833163892658089445524;
        p = ((p * x) >> 96) + 43456485725739037958740375743393;
        p = ((p * x) >> 96) - 11111509109440967052023855526967;
        p = ((p * x) >> 96) - 45023709667254063763336534515857;
        p = ((p * x) >> 96) - 14706773417378608786704636184526;
        p = p * x - (795164235651350426258249787498 << 96);

        int256 q = x + 5573035233440673466300451813936;
        q = ((q * x) >> 96) + 71694874799317883764090561454958;
        q = ((q * x) >> 96) + 283447036172924575727196451306956;
        q = ((q * x) >> 96) + 401686690394027663651624208769553;
        q = ((q * x) >> 96) + 204048457590392012362485061816622;
        q = ((q * x) >> 96) + 31853899698501571402653359427138;
        q = ((q * x) >> 96) + 909429971244387300277376558375;
        assembly {
            r := sdiv(p, q)
        }

        r *= 1677202110996718588342820967067443963516166;
        r += 16597577552685614221487285958193947469193820559219878177908093499208371 * k;
        r += 600920179829731861736702779321621459595472258049074101567377883020018308;
        r >>= 174;
    }
}

function unsafeDiv(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        r := sdiv(x, y)
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";


contract Eom is ERC20("Eom", "EOM", 18) {
    address public immutable zeroEggs;

    address public immutable pass;

    error Unauthorized();

    constructor(address _zeroEggs, address _pass) {
        zeroEggs = _zeroEggs;
        pass = _pass;
    }

    modifier only(address user) {
        if (msg.sender != user) revert Unauthorized();

        _;
    }

    function mintForEggs(address to, uint256 amount) external only(zeroEggs) {
        _mint(to, amount);
    }

    function burnForEggs(address from, uint256 amount) external only(zeroEggs) {
        _burn(from, amount);
    }

    function burnForPass(address from, uint256 amount) external only(pass) {
        _burn(from, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {LibString} from "solmate/utils/LibString.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

import {LogisticToLinearVRGDA} from "VRGDAs/LogisticToLinearVRGDA.sol";

import {PassERC721} from "./utils/token/PassERC721.sol";

import {Eom} from "./Eom.sol";
import {ZeroEggs} from "./ZeroEggs.sol";

contract Pass is PassERC721, LogisticToLinearVRGDA {
    using LibString for uint256;

    Eom public immutable eom;

    address public immutable community;

    string public BASE_URI;

    uint256 public immutable mintStart;

    uint128 public currentId;

    uint128 public numMintedForCommunity;

    int256 internal constant SWITCH_DAY_WAD = 233e18;

    int256 internal constant SOLD_BY_SWITCH_WAD = 8336.760939794622713006e18;


    event PassPurchased(address indexed user, uint256 indexed passId, uint256 price);

    event CommunityPassMinted(address indexed user, uint256 lastMintedPassId, uint256 numPass);

    error ReserveImbalance();

    error PriceExceededMax(uint256 currentPrice);

    constructor(
        uint256 _mintStart,
        Eom _eom,
        address _community,
        ZeroEggs _zeroEggs,
        string memory _baseUri
    )
        PassERC721(_zeroEggs, "Pass", "PASS")
        LogisticToLinearVRGDA(
            4.2069e18, 
            0.31e18,
            9000e18,
            0.014e18,
            SOLD_BY_SWITCH_WAD,
            SWITCH_DAY_WAD,
            9e18
        )
    {
        mintStart = _mintStart;

        eom = _eom;

        community = _community;

        BASE_URI = _baseUri;
    }

    function mintFromEom(uint256 maxPrice, bool useVirtualBalance) external returns (uint256 passId) {
        uint256 currentPrice = passPrice();

        if (currentPrice > maxPrice) revert PriceExceededMax(currentPrice);

        useVirtualBalance
            ? zeroEggs.burnEomForPass(msg.sender, currentPrice)
            : eom.burnForPass(msg.sender, currentPrice);

        unchecked {
            emit PassPurchased(msg.sender, passId = ++currentId, currentPrice);

            _mint(msg.sender, passId);
        }
    }

    function passPrice() public view returns (uint256) {
        uint256 timeSinceStart = block.timestamp - mintStart;

        unchecked {
            return getVRGDAPrice(toDaysWadUnsafe(timeSinceStart), currentId - numMintedForCommunity);
        }
    }

    function mintCommunityPass(uint256 numPass) external returns (uint256 lastMintedPassId) {
        unchecked {
            uint256 newNumMintedForCommunity = numMintedForCommunity += uint128(numPass);

            if (newNumMintedForCommunity > ((lastMintedPassId = currentId) + numPass) / 10) revert ReserveImbalance();

            lastMintedPassId = _batchMint(community, numPass, lastMintedPassId);

            currentId = uint128(lastMintedPassId);
            emit CommunityPassMinted(msg.sender, lastMintedPassId, numPass);
        }
    }

    function tokenURI(uint256 passId) public view virtual override returns (string memory) {
        if (passId == 0 || passId > currentId) revert("NOT_MINTED");

        return string.concat(BASE_URI, passId.toString());
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {toWadUnsafe, toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

import {LibEOM} from "eom-issuance/LibEOM.sol";
import {LogisticVRGDA} from "VRGDAs/LogisticVRGDA.sol";

import {RandProvider} from "./utils/rand/RandProvider.sol";
import {EggsERC721} from "./utils/token/EggsERC721.sol";

import {Eom} from "./Eom.sol";
import {Pass} from "./Pass.sol";


contract ZeroEggs is EggsERC721, LogisticVRGDA, Owned, ERC1155TokenReceiver {
    using LibString for uint256;
    using FixedPointMathLib for uint256;

    Eom public immutable eom;

    Pass public immutable pass;

    address public immutable team;

    address public immutable community;

    RandProvider public randProvider;

    uint256 public constant MAX_SUPPLY = 10000;

    uint256 public constant MINTLIST_SUPPLY = 2000;

    uint256 public constant LEGENDARY_SUPPLY = 10;

    uint256 public constant RESERVED_SUPPLY = (MAX_SUPPLY - MINTLIST_SUPPLY - LEGENDARY_SUPPLY) / 5;

    uint256 public constant MAX_MINTABLE = MAX_SUPPLY
        - MINTLIST_SUPPLY
        - LEGENDARY_SUPPLY
        - RESERVED_SUPPLY;
    
    bytes32 public immutable PROVENANCE_HASH;

    string public UNREVEALED_URI;

    string public BASE_URI;

    bytes32 public immutable merkleRoot;

    mapping(address => bool) public hasClaimedMintlistEgg;

    uint256 public immutable mintStart;

    uint128 public numMintedFromEom;

    uint128 public currentNonLegendaryId;

    uint256 public numMintedForReserves;

    uint256 public constant LEGENDARY_EGG_INITIAL_START_PRICE = 69;

    uint256 public constant FIRST_LEGENDARY_EGG_ID = MAX_SUPPLY - LEGENDARY_SUPPLY + 1;

    uint256 public constant LEGENDARY_AUCTION_INTERVAL = MAX_MINTABLE / (LEGENDARY_SUPPLY + 1);

    struct LegendaryEggAuctionData {
        uint128 startPrice;
        uint128 numSold;
    }

    LegendaryEggAuctionData public legendaryEggAuctionData;

    struct EggRevealsData {
        uint64 randomSeed;
        uint64 nextRevealTimestamp;
        uint64 lastRevealedId;
        uint56 toBeRevealed;
        bool waitingForSeed;
    }

    EggRevealsData public eggRevealsData;

    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public getCopiesOfZeroEggedByEgg;

    event EomBalanceUpdated(address indexed user, uint256 newEomBalance);

    event EggClaimed(address indexed user, uint256 indexed eggId);
    event EggPurchased(address indexed user, uint256 indexed eggId, uint256 price);
    event LegendaryEggMinted(address indexed user, uint256 indexed eggId, uint256[] burnedEggIds);
    event ReservedEggsMinted(address indexed user, uint256 lastMintedEggId, uint256 numEggsEach);

    event RandomnessFulfilled(uint256 randomness);
    event RandomnessRequested(address indexed user, uint256 toBeRevealed);
    event RandProviderUpgraded(address indexed user, RandProvider indexed newRandProvider);

    event EggsRevealed(address indexed user, uint256 numEggs, uint256 lastRevealedId);

    event ZeroEgged(address indexed user, uint256 indexed eggId, address indexed nft, uint256 id);

    error InvalidProof();
    error AlreadyClaimed();
    error MintStartPending();

    error SeedPending();
    error RevealsPending();
    error RequestTooEarly();
    error ZeroToBeRevealed();
    error NotRandProvider();

    error ReserveImbalance();

    error Cannibalism();
    error OwnerMismatch(address owner);

    error NoRemainingLegendaryEggs();
    error CannotBurnLegendary(uint256 eggId);
    error InsufficientEggAmount(uint256 cost);
    error LegendaryAuctionNotStarted(uint256 eggsLeft);

    error PriceExceededMax(uint256 currentPrice);

    error NotEnoughRemainingToBeRevealed(uint256 totalRemainingToBeRevealed);

    error UnauthorizedCaller(address caller);

    constructor(
        bytes32 _merkleRoot,
        uint256 _mintStart,
        Eom _eom,
        Pass _pass,
        address _team,
        address _community,
        RandProvider _randProvider,
        string memory _baseUri,
        string memory _unrevealedUri,
        bytes32 _provenanceHash
    )
        EggsERC721("Zero Eggs", "EGG")
        Owned(msg.sender)
        LogisticVRGDA(
            69.42e18,
            0.31e18,
            toWadUnsafe(MAX_MINTABLE),
            0.0023e18
        )
    {
        mintStart = _mintStart;
        merkleRoot = _merkleRoot;

        eom = _eom;
        pass = _pass;
        team = _team;
        community = _community;
        randProvider = _randProvider;

        BASE_URI = _baseUri;
        UNREVEALED_URI = _unrevealedUri;

        PROVENANCE_HASH = _provenanceHash;

        legendaryEggAuctionData.startPrice = uint128(LEGENDARY_EGG_INITIAL_START_PRICE);

        eggRevealsData.nextRevealTimestamp = uint64(_mintStart + 1 days);
    }

    function claimEgg(bytes32[] calldata proof) external returns (uint256 eggId) {
        if (mintStart > block.timestamp) revert MintStartPending();

        if (hasClaimedMintlistEgg[msg.sender]) revert AlreadyClaimed();

        if (!MerkleProofLib.verify(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender)))) revert InvalidProof();

        hasClaimedMintlistEgg[msg.sender] = true;

        unchecked {
            emit EggClaimed(msg.sender, eggId = ++currentNonLegendaryId);
        }

        _mint(msg.sender, eggId);
    }


    function mintFromEom(uint256 maxPrice, bool useVirtualBalance) external returns (uint256 eggId) {
        uint256 currentPrice = eggPrice();

        if (currentPrice > maxPrice) revert PriceExceededMax(currentPrice);

        useVirtualBalance
            ? updateUserEomBalance(msg.sender, currentPrice, EomBalanceUpdateType.DECREASE)
            : eom.burnForEggs(msg.sender, currentPrice);

        unchecked {
            ++numMintedFromEom; 

            emit EggPurchased(msg.sender, eggId = ++currentNonLegendaryId, currentPrice);
        }

        _mint(msg.sender, eggId);
    }

    function eggPrice() public view returns (uint256) {
        uint256 timeSinceStart = block.timestamp - mintStart;

        return getVRGDAPrice(toDaysWadUnsafe(timeSinceStart), numMintedFromEom);
    }

    
    function mintLegendaryEgg(uint256[] calldata eggIds) external returns (uint256 eggId) {
        uint256 numSold = legendaryEggAuctionData.numSold;

        eggId = FIRST_LEGENDARY_EGG_ID + numSold;

        uint256 cost = legendaryEggPrice();

        if (eggIds.length < cost) revert InsufficientEggAmount(cost);

        unchecked {
            uint256 burnedMultipleTotal;

            uint256 id;

            for (uint256 i = 0; i < cost; ++i) {
                id = eggIds[i];

                if (id >= FIRST_LEGENDARY_EGG_ID) revert CannotBurnLegendary(id);

                EggData storage egg = getEggData[id];

                require(egg.owner == msg.sender, "WRONG_FROM");

                burnedMultipleTotal += egg.emissionMultiple;

                delete getApproved[id];

                emit Transfer(msg.sender, egg.owner = address(0), id);
            }

            getEggData[eggId].emissionMultiple = uint32(burnedMultipleTotal * 2);

            getUserData[msg.sender].lastBalance = uint128(eomBalance(msg.sender));
            getUserData[msg.sender].lastTimestamp = uint64(block.timestamp);
            getUserData[msg.sender].emissionMultiple += uint32(burnedMultipleTotal);
            getUserData[msg.sender].eggsOwned -= uint32(cost);

            legendaryEggAuctionData.startPrice = uint128(
                cost <= LEGENDARY_EGG_INITIAL_START_PRICE / 2 ? LEGENDARY_EGG_INITIAL_START_PRICE : cost * 2
            );
            legendaryEggAuctionData.numSold = uint128(numSold + 1); // Increment the # of legendaries sold.

            emit LegendaryEggMinted(msg.sender, eggId, eggIds[:cost]);

            _mint(msg.sender, eggId);
        }
    }

    function legendaryEggPrice() public view returns (uint256) {
        uint256 startPrice = legendaryEggAuctionData.startPrice;
        uint256 numSold = legendaryEggAuctionData.numSold;

        if (numSold == LEGENDARY_SUPPLY) revert NoRemainingLegendaryEggs();

        unchecked {
            uint256 mintedFromEom = numMintedFromEom;

            uint256 numMintedAtStart = (numSold + 1) * LEGENDARY_AUCTION_INTERVAL;

            if (numMintedAtStart > mintedFromEom) revert LegendaryAuctionNotStarted(numMintedAtStart - mintedFromEom);

            uint256 numMintedSinceStart = mintedFromEom - numMintedAtStart;

            if (numMintedSinceStart >= LEGENDARY_AUCTION_INTERVAL) return 0;
            else return FixedPointMathLib.unsafeDivUp(startPrice * (LEGENDARY_AUCTION_INTERVAL - numMintedSinceStart), LEGENDARY_AUCTION_INTERVAL);
        }
    }

    function requestRandomSeed() external returns (bytes32) {
        uint256 nextRevealTimestamp = eggRevealsData.nextRevealTimestamp;

        if (block.timestamp < nextRevealTimestamp) revert RequestTooEarly();

        if (eggRevealsData.toBeRevealed != 0) revert RevealsPending();

        unchecked {
            eggRevealsData.waitingForSeed = true;

            uint256 toBeRevealed = currentNonLegendaryId - eggRevealsData.lastRevealedId;

            if (toBeRevealed == 0) revert ZeroToBeRevealed();

            eggRevealsData.toBeRevealed = uint56(toBeRevealed);

            eggRevealsData.nextRevealTimestamp = uint64(nextRevealTimestamp + 1 days);

            emit RandomnessRequested(msg.sender, toBeRevealed);
        }

        return randProvider.requestRandomBytes();
    }

    function acceptRandomSeed(bytes32, uint256 randomness) external {
        if (msg.sender != address(randProvider)) revert NotRandProvider();

        eggRevealsData.randomSeed = uint64(randomness);

        eggRevealsData.waitingForSeed = false;

        emit RandomnessFulfilled(randomness);
    }

    function upgradeRandProvider(RandProvider newRandProvider) external onlyOwner {
        if (eggRevealsData.waitingForSeed) {
            eggRevealsData.waitingForSeed = false;
            eggRevealsData.toBeRevealed = 0;
            eggRevealsData.nextRevealTimestamp -= 1 days;
        }

        randProvider = newRandProvider;

        emit RandProviderUpgraded(msg.sender, newRandProvider);
    }

    function revealEggs(uint256 numEggs) external {
        uint256 randomSeed = eggRevealsData.randomSeed;

        uint256 lastRevealedId = eggRevealsData.lastRevealedId;

        uint256 totalRemainingToBeRevealed = eggRevealsData.toBeRevealed;

        if (eggRevealsData.waitingForSeed) revert SeedPending();

        if (numEggs > totalRemainingToBeRevealed) revert NotEnoughRemainingToBeRevealed(totalRemainingToBeRevealed);

        unchecked {
            for (uint256 i = 0; i < numEggs; ++i) {
                uint256 remainingIds = FIRST_LEGENDARY_EGG_ID - lastRevealedId - 1;

                uint256 distance = randomSeed % remainingIds;

                uint256 currentId = ++lastRevealedId;

                uint256 swapId = currentId + distance;

                uint64 swapIndex = getEggData[swapId].idx == 0
                    ? uint64(swapId)
                    : getEggData[swapId].idx;

                address currentIdOwner = getEggData[currentId].owner;

                uint64 currentIndex = getEggData[currentId].idx == 0
                    ? uint64(currentId)
                    : getEggData[currentId].idx;

                uint256 newCurrentIdMultiple = 9;

                assembly {
                    newCurrentIdMultiple := sub(sub(sub(
                        newCurrentIdMultiple,
                        lt(swapIndex, 7964)),
                        lt(swapIndex, 5673)),
                        lt(swapIndex, 3055)
                    )
                }

                getEggData[currentId].idx = swapIndex;
                getEggData[currentId].emissionMultiple = uint32(newCurrentIdMultiple);

                getEggData[swapId].idx = currentIndex;

                getUserData[currentIdOwner].lastBalance = uint128(eomBalance(currentIdOwner));
                getUserData[currentIdOwner].lastTimestamp = uint64(block.timestamp);
                getUserData[currentIdOwner].emissionMultiple += uint32(newCurrentIdMultiple);

                assembly {
                    mstore(0, randomSeed)

                    randomSeed := mod(keccak256(0, 32), exp(2, 64))
                }
            }

            eggRevealsData.randomSeed = uint64(randomSeed);
            eggRevealsData.lastRevealedId = uint64(lastRevealedId);
            eggRevealsData.toBeRevealed = uint56(totalRemainingToBeRevealed - numEggs);

            emit EggsRevealed(msg.sender, numEggs, lastRevealedId);
        }
    }

    function tokenURI(uint256 eggId) public view virtual override returns (string memory) {
        if (eggId <= eggRevealsData.lastRevealedId) {
            if (eggId == 0) revert("NOT_MINTED"); // 0 is not a valid id for Zero Eggs.

            return string.concat(BASE_URI, uint256(getEggData[eggId].idx).toString());
        }

        if (eggId <= currentNonLegendaryId) return UNREVEALED_URI;

        if (eggId < FIRST_LEGENDARY_EGG_ID) revert("NOT_MINTED");

        if (eggId < FIRST_LEGENDARY_EGG_ID + legendaryEggAuctionData.numSold)
            return string.concat(BASE_URI, eggId.toString());

        revert("NOT_MINTED");
    }

    function egg(
        uint256 eggId,
        address nft,
        uint256 id,
        bool isERC1155
    ) external {
        address owner = getEggData[eggId].owner;

        if (owner != msg.sender) revert OwnerMismatch(owner);

        if (nft == address(this)) revert Cannibalism();

        unchecked {
            ++getCopiesOfZeroEggedByEgg[eggId][nft][id];
        }

        emit ZeroEgged(msg.sender, eggId, nft, id);

        isERC1155
            ? ERC1155(nft).safeTransferFrom(msg.sender, address(this), id, 1, "")
            : ERC721(nft).transferFrom(msg.sender, address(this), id);
    }

   function eomBalance(address user) public view returns (uint256) {
        return LibEOM.computeGOOBalance(
            getUserData[user].emissionMultiple,
            getUserData[user].lastBalance,
            uint256(toDaysWadUnsafe(block.timestamp - getUserData[user].lastTimestamp))
        );
    }

    function addEom(uint256 eomAmount) external {
        eom.burnForEggs(msg.sender, eomAmount);

        updateUserEomBalance(msg.sender, eomAmount, EomBalanceUpdateType.INCREASE);
    }

    function removeEom(uint256 eomAmount) external {
        updateUserEomBalance(msg.sender, eomAmount, EomBalanceUpdateType.DECREASE);

        eom.mintForEggs(msg.sender, eomAmount);
    }

    function burnEomForPass(address user, uint256 eomAmount) external {
        if (msg.sender != address(pass)) revert UnauthorizedCaller(msg.sender);

        updateUserEomBalance(user, eomAmount, EomBalanceUpdateType.DECREASE);
    }

    enum EomBalanceUpdateType {
        INCREASE,
        DECREASE
    }

    function updateUserEomBalance(
        address user,
        uint256 eomAmount,
        EomBalanceUpdateType updateType
    ) internal {
        uint256 updatedBalance = updateType == EomBalanceUpdateType.INCREASE
            ? eomBalance(user) + eomAmount
            : eomBalance(user) - eomAmount;

        getUserData[user].lastBalance = uint128(updatedBalance);
        getUserData[user].lastTimestamp = uint64(block.timestamp);

        emit EomBalanceUpdated(user, updatedBalance);
    }

    function mintReservedEggs(uint256 numEggsEach) external returns (uint256 lastMintedEggId) {
        unchecked {
            uint256 newNumMintedForReserves = numMintedForReserves += (numEggsEach * 2);

            if (newNumMintedForReserves > (numMintedFromEom + newNumMintedForReserves) / 5) revert ReserveImbalance();
        }

        lastMintedEggId = _batchMint(team, numEggsEach, currentNonLegendaryId);
        lastMintedEggId = _batchMint(community, numEggsEach, lastMintedEggId);

        currentNonLegendaryId = uint128(lastMintedEggId); // Set currentNonLegendaryId.

        emit ReservedEggsMinted(msg.sender, lastMintedEggId, numEggsEach);
    }

    function getEggEmissionMultiple(uint256 eggId) external view returns (uint256) {
        return getEggData[eggId].emissionMultiple;
    }

    function getUserEmissionMultiple(address user) external view returns (uint256) {
        return getUserData[user].emissionMultiple;
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        require(from == getEggData[id].owner, "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        delete getApproved[id];

        getEggData[id].owner = to;

        unchecked {
            uint32 emissionMultiple = getEggData[id].emissionMultiple; 

            getUserData[from].lastBalance = uint128(eomBalance(from));
            getUserData[from].lastTimestamp = uint64(block.timestamp);
            getUserData[from].emissionMultiple -= emissionMultiple;
            getUserData[from].eggsOwned -= 1;

            getUserData[to].lastBalance = uint128(eomBalance(to));
            getUserData[to].lastTimestamp = uint64(block.timestamp);
            getUserData[to].emissionMultiple += emissionMultiple;
            getUserData[to].eggsOwned += 1;
        }

        emit Transfer(from, to, id);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {VRFConsumerBase} from "chainlink/v0.8/VRFConsumerBase.sol";

import {ZeroEggs} from "../../ZeroEggs.sol";

import {RandProvider} from "./RandProvider.sol";


contract ChainlinkV1RandProvider is RandProvider, VRFConsumerBase {
    ZeroEggs public immutable zeroEggs;

    bytes32 internal immutable chainlinkKeyHash;

    uint256 internal immutable chainlinkFee;

    error NotEggs();

    constructor(
        ZeroEggs _zeroEggs,
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _chainlinkKeyHash,
        uint256 _chainlinkFee
    ) VRFConsumerBase(_vrfCoordinator, _linkToken) {
        zeroEggs = _zeroEggs;

        chainlinkKeyHash = _chainlinkKeyHash;
        chainlinkFee = _chainlinkFee;
    }

    function requestRandomBytes() external returns (bytes32 requestId) {
        if (msg.sender != address(zeroEggs)) revert NotEggs();

        emit RandomBytesRequested(requestId = requestRandomness(chainlinkKeyHash, chainlinkFee));
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        emit RandomBytesReturned(requestId, randomness);

        zeroEggs.acceptRandomSeed(requestId, randomness);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface RandProvider {
    event RandomBytesRequested(bytes32 requestId);
    event RandomBytesReturned(bytes32 requestId, uint256 randomness);

    function requestRandomBytes() external returns (bytes32 requestId);
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

abstract contract EggsERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    string public name;

    string public symbol;

    function tokenURI(uint256 id) external view virtual returns (string memory);

    struct EggData {
        address owner;
        uint64 idx;
        uint32 emissionMultiple;
    }

    mapping(uint256 => EggData) public getEggData;

    struct UserData {
        uint32 eggsOwned;
        uint32 emissionMultiple;
        uint128 lastBalance;
        uint64 lastTimestamp;
    }

    mapping(address => UserData) public getUserData;

    function ownerOf(uint256 id) external view returns (address owner) {
        require((owner = getEggData[id].owner) != address(0), "NOT_MINTED");
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        return getUserData[owner].eggsOwned;
    }

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function approve(address spender, uint256 id) external {
        address owner = getEggData[id].owner;

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) external {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) external {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || 
            interfaceId == 0x80ac58cd || 
            interfaceId == 0x5b5e139f;
    }

    function _mint(address to, uint256 id) internal {
        unchecked {
            ++getUserData[to].eggsOwned;
        }

        getEggData[id].owner = to;

        emit Transfer(address(0), to, id);
    }

    function _batchMint(
        address to,
        uint256 amount,
        uint256 lastMintedId
    ) internal returns (uint256) {
        unchecked {
            getUserData[to].eggsOwned += uint32(amount);

            for (uint256 i = 0; i < amount; ++i) {
                getEggData[++lastMintedId].owner = to;

                emit Transfer(address(0), to, lastMintedId);
            }
        }

        return lastMintedId;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ZeroEggs} from "../../ZeroEggs.sol";

abstract contract PassERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    string public name;

    string public symbol;

    function tokenURI(uint256 id) external view virtual returns (string memory);

    ZeroEggs public immutable zeroEggs;

    constructor(
        ZeroEggs _zeroEggs,
        string memory _name,
        string memory _symbol
    ) {
        name = _name;
        symbol = _symbol;
        zeroEggs = _zeroEggs;
    }

    mapping(uint256 => address) internal _ownerOf;

    mapping(address => uint256) internal _balanceOf;

    function ownerOf(uint256 id) external view returns (address owner) {
        require((owner = _ownerOf[id]) != address(0), "NOT_MINTED");
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        return _balanceOf[owner];
    }


    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) internal _isApprovedForAll;

    function isApprovedForAll(address owner, address operator) public view returns (bool isApproved) {
        if (operator == address(zeroEggs)) return true; 

        return _isApprovedForAll[owner][operator];
    }

    function approve(address spender, uint256 id) external {
        address owner = _ownerOf[id];

        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) external {
        _isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public {
        require(from == _ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from || isApprovedForAll(from, msg.sender) || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) external {
        transferFrom(from, to, id);

        if (to.code.length != 0)
            require(
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                    ERC721TokenReceiver.onERC721Received.selector,
                "UNSAFE_RECIPIENT"
            );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) external {
        transferFrom(from, to, id);

        if (to.code.length != 0)
            require(
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                    ERC721TokenReceiver.onERC721Received.selector,
                "UNSAFE_RECIPIENT"
            );
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || 
            interfaceId == 0x80ac58cd || 
            interfaceId == 0x5b5e139f; 

    }
    
    function _mint(address to, uint256 id) internal {
        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _batchMint(
        address to,
        uint256 amount,
        uint256 lastMintedId
    ) internal returns (uint256) {
        unchecked {
            _balanceOf[to] += amount;

            for (uint256 i = 0; i < amount; ++i) {
                _ownerOf[++lastMintedId] = to;

                emit Transfer(address(0), to, lastMintedId);
            }
        }

        return lastMintedId;
    }
}