// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ConfirmedOwnerWithProposal.sol";

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwner is ConfirmedOwnerWithProposal {
  constructor(address newOwner) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/OwnableInterface.sol";

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwnerWithProposal is OwnableInterface {
  address private s_owner;
  address private s_pendingOwner;

  event OwnershipTransferRequested(address indexed from, address indexed to);
  event OwnershipTransferred(address indexed from, address indexed to);

  constructor(address newOwner, address pendingOwner) {
    require(newOwner != address(0), "Cannot set owner to zero");

    s_owner = newOwner;
    if (pendingOwner != address(0)) {
      _transferOwnership(pendingOwner);
    }
  }

  /**
   * @notice Allows an owner to begin transferring ownership to a new address,
   * pending.
   */
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /**
   * @notice Allows an ownership transfer to be completed by the recipient.
   */
  function acceptOwnership() external override {
    require(msg.sender == s_pendingOwner, "Must be proposed owner");

    address oldOwner = s_owner;
    s_owner = msg.sender;
    s_pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /**
   * @notice Get the current owner
   */
  function owner() public view override returns (address) {
    return s_owner;
  }

  /**
   * @notice validate, transfer ownership, and emit relevant events
   */
  function _transferOwnership(address to) private {
    require(to != msg.sender, "Cannot transfer to self");

    s_pendingOwner = to;

    emit OwnershipTransferRequested(s_owner, to);
  }

  /**
   * @notice validate access
   */
  function _validateOwnership() internal view {
    require(msg.sender == s_owner, "Only callable by owner");
  }

  /**
   * @notice Reverts if called by anyone other than the contract owner.
   */
  modifier onlyOwner() {
    _validateOwnership();
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

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
 * @dev simple access to a verifiable source of randomness. It ensures 2 things:
 * @dev 1. The fulfillment came from the VRFCoordinator
 * @dev 2. The consumer contract implements fulfillRandomWords.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constructor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash). Create subscription, fund it
 * @dev and your consumer contract as a consumer of it (see VRFCoordinatorInterface
 * @dev subscription management functions).
 * @dev Call requestRandomWords(keyHash, subId, minimumRequestConfirmations,
 * @dev callbackGasLimit, numWords),
 * @dev see (VRFCoordinatorInterface for a description of the arguments).
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomWords method.
 *
 * @dev The randomness argument to fulfillRandomWords is a set of random words
 * @dev generated from your requestId and the blockHash of the request.
 *
 * @dev If your contract could have concurrent requests open, you can use the
 * @dev requestId returned from requestRandomWords to track which response is associated
 * @dev with which randomness request.
 * @dev See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ.
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
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request. It is for this reason that
 * @dev that you can signal to an oracle you'd like them to wait longer before
 * @dev responding to the request (however this is not enforced in the contract
 * @dev and so remains effective only in the case of unmodified oracle software).
 */
abstract contract VRFConsumerBaseV2 {
  error OnlyCoordinatorCanFulfill(address have, address want);
  address private immutable vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) {
    vrfCoordinator = _vrfCoordinator;
  }

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomWords the VRF output expanded to the requested number of words
   */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != vrfCoordinator) {
      revert OnlyCoordinatorCanFulfill(msg.sender, vrfCoordinator);
    }
    fulfillRandomWords(requestId, randomWords);
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
pragma solidity ^0.8.0;

interface OwnableInterface {
  function owner() external returns (address);

  function transferOwnership(address recipient) external;

  function acceptOwnership() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(uint64 subId)
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;

  /*
   * @notice Check to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId - ID of the subscription
   * @return true if there exists at least one unfulfilled request for the subscription, false
   * otherwise.
   */
  function pendingRequestExists(uint64 subId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to] += 1;
        }

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId, 1);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner = ERC721.ownerOf(tokenId);

        // Clear approvals
        delete _tokenApprovals[tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId, 1);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256, /* firstTokenId */
        uint256 batchSize
    ) internal virtual {
        if (batchSize > 1) {
            if (from != address(0)) {
                _balances[from] -= batchSize;
            }
            if (to != address(0)) {
                _balances[to] += batchSize;
            }
        }
    }

    /**
     * @dev Hook that is called after any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens were transferred to `to`.
     * - When `from` is zero, the tokens were minted for `to`.
     * - When `to` is zero, ``from``'s tokens were burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/extensions/ERC721URIStorage.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";

/**
 * @dev ERC721 token with storage based token URI management.
 */
abstract contract ERC721URIStorage is ERC721 {
    using Strings for uint256;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally checks to see if a
     * token-specific URI was set for the token, and if so, it deletes the token URI from
     * the storage mapping.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT

// npx hardhat compile
// npx hardhat run scripts/run.js
// https://buildspace.so/p/mint-nft-collection/lessons/create-contract-that-mints-nfts
// https://blog.simondlr.com/posts/flavours-of-on-chain-svg-nfts-on-ethereum

// https://docs.openzeppelin.com/contracts/2.x/api/token/erc721
// https://docs.openzeppelin.com/contracts/2.x/erc721

pragma solidity ^0.8.1;

import "./FiguresToken.sol";
import "./IFiguresToken.sol";
import "./IMarketplaceCore.sol";
import "./ILazyDelivery.sol";
import "./ILazyDeliveryMetadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

// EP: Who calls the Controller? This should create a new auction every 24h.

contract FiguresController is
    ILazyDelivery,
    ILazyDeliveryMetadata,
    VRFConsumerBaseV2,
    ConfirmedOwner
{
    struct InternalIds {
        uint256 requestId;
        uint256 seed;
        uint256 tokenId;
        uint40 listingId;
    }

    VRFCoordinatorV2Interface immutable COORDINATOR;
    LinkTokenInterface immutable LINKTOKEN;

    // Chainlink params
    uint64 private s_subscriptionId;
    bytes32 private s_keyHash;
    uint32 private s_gasLimit = 2500000;

    // Addresses
    address payable private _treasuryAddress;
    address private _tokenAddress;
    address private _marketplaceAddress;

    // Current params
    InternalIds private _currentIds;

    event RandomWordsRecieved();
    event RandomWordsRequested();

    function supportsInterface(bytes4 interfaceId)
        external
        pure
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(ILazyDelivery).interfaceId ||
            interfaceId == type(ILazyDeliveryMetadata).interfaceId;
    }

    constructor(
        address vrfCoordinator,
        address linkTokenContract,
        bytes32 keyHash,
        address payable treasuryAddress,
        address tokenAddress,
        address marketplaceAddress
    ) ConfirmedOwner(msg.sender) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(linkTokenContract);
        s_keyHash = keyHash;
        _treasuryAddress = treasuryAddress;
        _tokenAddress = tokenAddress;
        _marketplaceAddress = marketplaceAddress;
    }

    function subscriptionId() public view onlyOwner returns (uint256) {
        return s_subscriptionId;
    }

    function currentRequestId() public view onlyOwner returns (uint256) {
        return _currentIds.requestId;
    }

    function currentListingId() public view onlyOwner returns (uint40) {
        return _currentIds.listingId;
    }

    function currentSeed() public view onlyOwner returns (uint256) {
        return _currentIds.seed;
    }

    function setGasLimit(uint32 newGasLimit) public onlyOwner {
        s_gasLimit = newGasLimit;
    }

    function setKeyHash(bytes32 newKeyHash) public onlyOwner {
        s_keyHash = newKeyHash;
    }

    function setMarketplaceAddress(address marketplaceAddress)
        public
        onlyOwner
    {
        _marketplaceAddress = marketplaceAddress;
    }

    function setTokenAddress(address tokenAddress) public onlyOwner {
        _tokenAddress = tokenAddress;
    }

    function setTreasuryAddress(address payable treasuryAddress)
        public
        onlyOwner
    {
        _treasuryAddress = treasuryAddress;
    }

    // Create a new subscription when the contract is initially deployed.
    function createNewSubscription() external onlyOwner returns (uint256) {
        s_subscriptionId = COORDINATOR.createSubscription();
        // Add this contract as a consumer of its own subscription.
        COORDINATOR.addConsumer(s_subscriptionId, address(this));
        return s_subscriptionId;
    }

    // Assumes this contract owns link.
    // 1000000000000000000 = 1 LINK
    function topUpSubscription(uint256 amount) external onlyOwner {
        LINKTOKEN.transferAndCall(
            address(COORDINATOR),
            amount,
            abi.encode(s_subscriptionId)
        );
    }

    function addConsumer(address consumerAddress) external onlyOwner {
        // Add a consumer contract to the subscription.
        COORDINATOR.addConsumer(s_subscriptionId, consumerAddress);
    }

    function removeConsumer(address consumerAddress) external onlyOwner {
        // Remove a consumer contract from the subscription.
        COORDINATOR.removeConsumer(s_subscriptionId, consumerAddress);
    }

    function cancelSubscription(address receivingWallet) external onlyOwner {
        // Cancel the subscription and send the remaining LINK to a wallet address.
        COORDINATOR.cancelSubscription(s_subscriptionId, receivingWallet);
        s_subscriptionId = 0;
    }

    // Transfer this contract's funds to an address.
    // 1000000000000000000 = 1 LINK
    function withdraw(uint256 amount, address to) external onlyOwner {
        LINKTOKEN.transfer(to, amount);
    }

    function initialize() external onlyOwner {
        _currentIds.requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            3, // Confirmations
            s_gasLimit, // Gas Limit
            1 // Number of random words
        );
        emit RandomWordsRequested();
    }

    // Gets called by VRFConsumerBaseV2
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        require(requestId == _currentIds.requestId, "Invalid requestId");

        // Clear _currentRequestId (prevent re-entrancy)
        _currentIds.requestId = 0;

        // Random number seed
        _currentIds.seed = randomWords[0];
        _currentIds.tokenId++;

        emit RandomWordsRecieved();

        uint256[] memory gen = new uint256[](13);
        gen[0] = _currentIds.seed;

        for (uint8 k = 1; k < 13; k++) {
            gen[k] = (gen[k - 1] << 10);
        }

        // Initialize seed
        IFiguresToken(_tokenAddress).initializeSeed(gen);

        IMarketplaceCore.ListingReceiver[]
            memory receivers = new IMarketplaceCore.ListingReceiver[](1);
        receivers[0] = IMarketplaceCore.ListingReceiver(
            _treasuryAddress,
            10000
        );

        _currentIds.listingId = IMarketplaceCore(_marketplaceAddress)
            .createListing(
                IMarketplaceCore.ListingDetails(
                    0, // Initial amount
                    IMarketplaceCore.ListingType.INDIVIDUAL_AUCTION,
                    1,
                    1,
                    600, // Bidding extension interval
                    10, // Min bid increase (in bps)
                    address(0),
                    address(0),
                    0, // Start auction on first bid
                    86400 // 1 day auction
                ),
                IMarketplaceCore.TokenDetails(
                    _currentIds.tokenId,
                    address(this),
                    IMarketplaceCore.Spec.ERC721,
                    true
                ),
                IMarketplaceCore.DeliveryFees(0, 0),
                receivers,
                false,
                "0x0"
            );
    }

    function externalFulfillRandomWords(uint256[] memory randomWords)
        public
        onlyOwner
    {
        // Random number seed
        _currentIds.seed = randomWords[0];
        _currentIds.tokenId++;

        emit RandomWordsRecieved();

        uint256[] memory gen = new uint256[](13);
        gen[0] = _currentIds.seed;

        for (uint8 k = 1; k < 13; k++) {
            gen[k] = (gen[k - 1] << 10);
        }

        // Initialize seed
        IFiguresToken(_tokenAddress).initializeSeed(gen);

        IMarketplaceCore.ListingReceiver[]
            memory receivers = new IMarketplaceCore.ListingReceiver[](1);
        receivers[0] = IMarketplaceCore.ListingReceiver(
            _treasuryAddress,
            10000
        );

        _currentIds.listingId = IMarketplaceCore(_marketplaceAddress)
            .createListing(
                IMarketplaceCore.ListingDetails(
                    0, // Initial amount
                    IMarketplaceCore.ListingType.INDIVIDUAL_AUCTION,
                    1,
                    1,
                    600, // Bidding extension interval
                    10, // Min bid increase (in bps)
                    address(0),
                    address(0),
                    0, // Start auction on first bid
                    86400 // 1 day auction
                ),
                IMarketplaceCore.TokenDetails(
                    _currentIds.tokenId,
                    address(this),
                    IMarketplaceCore.Spec.ERC721,
                    true
                ),
                IMarketplaceCore.DeliveryFees(0, 0),
                receivers,
                false,
                "0x0"
            );
    }

    function deliver(
        uint40 listingId,
        address to,
        uint256 assetId,
        uint24 payableCount,
        uint256,
        address,
        uint256
    ) external override returns (uint256) {
        require(
            msg.sender == _marketplaceAddress &&
                listingId == _currentIds.listingId &&
                assetId == _currentIds.tokenId &&
                payableCount == 1,
            "Unauthorized"
        );

        // Deliver asset
        IFiguresToken(_tokenAddress).mint(
            _currentIds.tokenId,
            _currentIds.seed,
            to
        );

        // Kick off new random number request
        _currentIds.requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            3, // Confirmations
            s_gasLimit, // Gas Limit
            13 // Number of random words
        );

        emit RandomWordsRequested();
        return _currentIds.tokenId;
    }

    function assetURI(uint256 assetId)
        external
        view
        override
        returns (string memory)
    {
        require(assetId == _currentIds.tokenId, "Asset not found");
        return IFiguresToken(_tokenAddress).render(_currentIds.seed);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "./digits/FiguresDoubleDigitsLib.sol";
import "./FiguresUtilLib.sol";

library FiguresDoubles {
    function chooseStringsDoubles(
        uint8 number,
        uint8 index1,
        uint8 index2
    ) public pure returns (bool[][2] memory b) {
        FiguresUtilLib.FigStrings memory strings = getFigStringsDoubles(number);
        return
            FiguresUtilLib._chooseStringsDouble(
                number,
                strings.s1,
                strings.s2,
                index1,
                index2
            );
    }

    function getFigStringsDoubles(uint8 number)
        private
        pure
        returns (FiguresUtilLib.FigStrings memory)
    {
        FiguresUtilLib.FigStrings memory figStrings;

        do {
            if (number == 0) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS0S1,
                    8
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS0S2,
                    8
                );
                break;
            }
            if (number == 1) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS1S1,
                    24
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS1S2,
                    24
                );
                break;
            }
            if (number == 2) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS2S1,
                    24
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS2S2,
                    40
                );
                break;
            }
            if (number == 3) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS3S1,
                    24
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS3S2,
                    40
                );
                break;
            }
            if (number == 4) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS4S1,
                    12
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS4S2,
                    16
                );
                break;
            }
            if (number == 5) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS5S1,
                    24
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS5S2,
                    40
                );
                break;
            }
            if (number == 6) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS6S1,
                    24
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS6S2,
                    56
                );
                break;
            }
            if (number == 7) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS7S1,
                    13
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS7S2,
                    4
                );
                break;
            }
            if (number == 8) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS8S1,
                    36
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS8S2,
                    36
                );
                break;
            }
            if (number == 9) {
                figStrings.s1 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS9S1,
                    60
                );
                figStrings.s2 = FiguresUtilLib._assignValuesDouble(
                    FiguresDoubleDigitsLib.FS9S2,
                    24
                );
                break;
            }
        } while (false);

        return figStrings;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "./digits/Figure0DigitLib.sol";
import "./digits/Figure1DigitLib.sol";
import "./digits/Figure2DigitLib.sol";
import "./digits/Figure3DigitLib.sol";
import "./digits/Figure4DigitLib.sol";
import "./digits/Figure5DigitLib.sol";
import "./digits/Figure6DigitLib.sol";
import "./digits/Figure7DigitLib.sol";
import "./digits/Figure8DigitLib.sol";
import "./digits/Figure9DigitLib.sol";
import "./FiguresUtilLib.sol";

library FiguresSingles {
    function chooseStringsSingles(
        uint8 number,
        uint8 index1,
        uint8 index2
    ) public pure returns (bool[][2] memory b) {
        FiguresUtilLib.FigStrings memory strings = getFigStringsSingles(number);
        return
            FiguresUtilLib._chooseStringsSingle(
                number,
                strings.s1,
                strings.s2,
                index1,
                index2
            );
    }

    function getFigStringsSingles(uint8 number)
        private
        pure
        returns (FiguresUtilLib.FigStrings memory)
    {
        FiguresUtilLib.FigStrings memory figStrings;

        do {
            if (number == 0) {
                figStrings.s1 = FiguresUtilLib._assignValuesSingle(
                    Figure0DigitLib.S1(),
                    144
                );
                figStrings.s2 = FiguresUtilLib._assignValuesSingle(
                    Figure0DigitLib.S2(),
                    144
                );
                break;
            }
            if (number == 1) {
                figStrings.s1 = FiguresUtilLib._assignValuesSingle(
                    Figure1DigitLib.S1(),
                    28
                );
                figStrings.s2 = FiguresUtilLib._assignValuesSingle(
                    Figure1DigitLib.S2(),
                    28
                );
                break;
            }
            if (number == 2) {
                figStrings.s1 = FiguresUtilLib._assignValuesSingle(
                    Figure2DigitLib.S1(),
                    54
                );
                figStrings.s2 = FiguresUtilLib._assignValuesSingle(
                    Figure2DigitLib.S2(),
                    90
                );
                break;
            }
            if (number == 3) {
                figStrings.s1 = FiguresUtilLib._assignValuesSingle(
                    Figure3DigitLib.S1(),
                    54
                );
                figStrings.s2 = FiguresUtilLib._assignValuesSingle(
                    Figure3DigitLib.S2(),
                    90
                );
                break;
            }
            if (number == 4) {
                figStrings.s1 = FiguresUtilLib._assignValuesSingle(
                    Figure4DigitLib.S1(),
                    144
                );
                figStrings.s2 = FiguresUtilLib._assignValuesSingle(
                    Figure4DigitLib.S2(),
                    30
                );
                break;
            }
            if (number == 5) {
                figStrings.s1 = FiguresUtilLib._assignValuesSingle(
                    Figure5DigitLib.S1(),
                    54
                );
                figStrings.s2 = FiguresUtilLib._assignValuesSingle(
                    Figure5DigitLib.S2(),
                    90
                );
                break;
            }
            if (number == 6) {
                figStrings.s1 = FiguresUtilLib._assignValuesSingle(
                    Figure6DigitLib.S1(),
                    54
                );
                figStrings.s2 = FiguresUtilLib._assignValuesSingle(
                    Figure6DigitLib.S2(),
                    360
                );
                break;
            }
            if (number == 7) {
                figStrings.s1 = FiguresUtilLib._assignValuesSingle(
                    Figure7DigitLib.S1(),
                    18
                );
                figStrings.s2 = FiguresUtilLib._assignValuesSingle(
                    Figure7DigitLib.S2(),
                    6
                );
                break;
            }
            if (number == 8) {
                figStrings.s1 = FiguresUtilLib._assignValuesSingle(
                    Figure8DigitLib.S1(),
                    216
                );
                figStrings.s2 = FiguresUtilLib._assignValuesSingle(
                    Figure8DigitLib.S2(),
                    216
                );
                break;
            }
            if (number == 9) {
                figStrings.s1 = FiguresUtilLib._assignValuesSingle(
                    Figure9DigitLib.S1(),
                    360
                );
                figStrings.s2 = FiguresUtilLib._assignValuesSingle(
                    Figure9DigitLib.S2(),
                    54
                );
                break;
            }
        } while (false);

        return figStrings;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "./IFiguresToken.sol";
import "./FiguresSingles.sol";
import "./FiguresDoubles.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract FiguresToken is ERC721URIStorage, IFiguresToken, Ownable  {
    using Counters for Counters.Counter;

    address public CONTROLLER_ADDRESS;

    string private _baseSvg = "";
    uint256 private _scaleFactor = 20;
    string[3] private _backgroundColors = [
        "252,100,211",
        "255,216,28",
        "33,162,248"
    ];

    struct RandomVariables {
        uint8 number;
        uint8[4] bgColor1Index;
        uint8[4] bgColor2Index;
        uint8 figureIndex1_1;
        uint8 figureIndex1_2;
        uint8 figureIndex2_1;
        uint8 figureIndex2_2;
    }

    mapping(uint256 => uint256) private _seeds;
    mapping(uint256 => RandomVariables) private _seedRandom;

    constructor() ERC721("Figures", "FIG") {}

    function setControllerAddress(
        address controllerAddress
    ) external onlyOwner {
        CONTROLLER_ADDRESS = controllerAddress;
    }

    function getControllerAddress() public view returns (address) {
        return CONTROLLER_ADDRESS;
    }

    /**
     * @dev See {IFiguresToken-initializeSeed}.
     */
    function initializeSeed(uint256[] memory seed) external override {
        require(msg.sender == CONTROLLER_ADDRESS, "Permission denied");
        // generate all the random numbers you need here!
        _seedRandom[seed[0]] = RandomVariables({
            number: uint8(_random(100, seed[0])),
            bgColor1Index: [
                uint8(_random(20, seed[1])),
                uint8(_random(20, seed[2])),
                uint8(_random(20, seed[3])),
                uint8(_random(20, seed[4]))
            ],
            bgColor2Index: [
                uint8(_random(20, seed[5])),
                uint8(_random(20, seed[6])),
                uint8(_random(20, seed[7])),
                uint8(_random(20, seed[8]))
            ],
            // 360 is the max number of options for number '9'
            figureIndex1_1: uint8(_random(360, seed[9])),
            figureIndex1_2: uint8(_random(360, seed[10])),
            figureIndex2_1: uint8(_random(360, seed[11])),
            figureIndex2_2: uint8(_random(360, seed[12]))
        });
    }

    /**
     * @dev See {IFiguresToken-mint}.
     */
    function mint(
        uint256 tokenId,
        uint256 seed,
        address recipient
    ) external override {
        require(msg.sender == CONTROLLER_ADDRESS, "Permission denied");
        // Store render data for this token
        _seeds[tokenId] = seed;

        // Mint token
        _mint(recipient, tokenId);
    }

    /**
     * @dev See {IERC721-tokenURI}.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireMinted(tokenId);
        return render(_seeds[tokenId]);
    }

    function tokenNumber(
        uint256 tokenId
    ) public view returns (uint8) {
        _requireMinted(tokenId);
        return _seedRandom[_seeds[tokenId]].number;
    }

    /**
     * @dev See {IFiguresToken-render}.
     */
    function render(
        uint256 seed
    ) public view override returns (string memory s) {
        uint256 n;

        RandomVariables memory variables = _seedRandom[seed];

        n = variables.number;
        s = _concat(s, "data:image/svg+xml;utf8,");
        s = _concat(
            s,
            "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' id='figures' width='"
        );
        s = _concat(s, Strings.toString(10 * _scaleFactor));
        s = _concat(s, "' height='");
        s = _concat(s, Strings.toString(10 * _scaleFactor));
        s = _concat(s, "'>");
        s = _concat(
            s,
            _drawBackground(variables.bgColor1Index, variables.bgColor2Index)
        );

        if (n < 10) {
            bool[][2] memory figArrays = FiguresSingles.chooseStringsSingles(
                uint8(n),
                variables.figureIndex1_1,
                variables.figureIndex1_2
            );
            s = _concat(
                s,
                _drawFigure(
                    false,
                    figArrays
                )
            );

        } else {
            uint8 leftNumber = uint8(n / 10);
            uint8 rightNumber = uint8(n % 10);

            bool[][2] memory figArraysLeft = FiguresDoubles.chooseStringsDoubles(
                leftNumber,
                variables.figureIndex1_1,
                variables.figureIndex1_2
            );

            bool[][2] memory figArraysRight = FiguresDoubles.chooseStringsDoubles(
                rightNumber,
                variables.figureIndex2_1,
                variables.figureIndex2_2
            );

            s = _concat(
                s,
                _drawFigure(
                    false,
                    figArraysLeft
                )
            );
            s = _concat(
                s,
                _drawFigure(
                    true,
                    figArraysRight
                )
            );
        }
        s = _concat(s, "</svg>");

        return
            string(
                abi.encodePacked(
                    'data:application/json;utf8,{"name":"Figure", "description":"Figure", "created_by":"Figures", "number":"',
                    Strings.toString(n),
                    '", "image":"',
                    s,
                    '"}'
                )
            );
    }

    function _random(
        uint256 number,
        uint256 count
    ) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender,
                        count
                    )
                )
            ) % number;
    }

    function _concat(
        string memory a,
        string memory b
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    function _generateRect(
        uint256 x,
        uint256 y,
        uint256 width,
        uint256 height,
        string memory color,
        string memory style
    ) internal pure returns (string memory) {
        string memory s = "";
        s = _concat(s, "<rect x='");
        s = _concat(s, Strings.toString(x));
        s = _concat(s, "' y='");
        s = _concat(s, Strings.toString(y));
        s = _concat(s, "' width='");
        s = _concat(s, Strings.toString(width));
        s = _concat(s, "' height='");
        s = _concat(s, Strings.toString(height));
        s = _concat(s, "' style='fill:rgb(");
        s = _concat(s, color);
        s = _concat(s, "); ");
        s = _concat(s, style);
        s = _concat(s, "'/>");
        return s;
    }

    function _generatePixelSVG(
        uint256 x,
        uint256 y,
        uint256 factor,
        string memory color
    ) internal pure returns (string memory) {
        string memory s = "";
        s = _concat(s, "<rect x='");
        s = _concat(s, Strings.toString(x));
        s = _concat(s, "' y='");
        s = _concat(s, Strings.toString(y));
        s = _concat(s, "' width='");
        s = _concat(s, Strings.toString(factor));
        s = _concat(s, "' height='");
        s = _concat(s, Strings.toString(factor));
        s = _concat(s, "' style='fill:rgb(");
        s = _concat(s, color);
        s = _concat(s, "); mix-blend-mode: multiply;'/>");
        return s;
    }

    function _drawBackground(
        uint8[4] memory bgColor1Index,
        uint8[4] memory bgColor2Index
    ) internal view returns (string memory) {
        // Draw first layer of bg by laying 4 randomly colored tiled
        string memory s = "";

        for (uint256 i = 0; i < 4; i++) {
            uint bgColor1IndexAvailable = bgColor1Index[i] % 3;
            uint bgColor2IndexAvailable = bgColor2Index[i] % 4;
            s = _concat(s, "<g>");
            s = _concat(
                s,
                (
                    _generateRect(
                        (i % 2) * uint256(5) * _scaleFactor,
                        (i / 2) * uint256(5) * _scaleFactor,
                        uint256(5) * _scaleFactor,
                        uint256(5) * _scaleFactor,
                        _backgroundColors[bgColor1IndexAvailable],
                        ""
                    )
                )
            );
            if (bgColor2IndexAvailable == 3) {
                s = _concat(s, "</g>");
                continue;
            }

            s = _concat(
                s,
                (
                    _generateRect(
                        (i % 2) * uint256(5) * _scaleFactor,
                        (i / 2) * uint256(5) * _scaleFactor,
                        uint256(5) * _scaleFactor,
                        uint256(5) * _scaleFactor,
                        _backgroundColors[bgColor2IndexAvailable],
                        "mix-blend-mode: multiply;"
                    )
                )
            );
            s = _concat(s, "</g>");
        }
        return s;
    }

    function _drawFigure(
        bool rightOffset,
        bool[][2] memory figArrays
    ) internal view returns (string memory) {
        uint256 rightOffsetX = 0;

        if (rightOffset) {
            rightOffsetX = uint256(5) * _scaleFactor;
        }

        string memory s = "";

        // k is top and bottom
        for (uint256 k = 0; k < 2; k++) {
            // i is each pixel
            for (uint256 i = 0; i < figArrays[k].length; ++i) {
                uint8 size = uint8(figArrays[k].length / 5);
                if (figArrays[k][i]) {
                    continue;
                }
                uint256 xOffset = _scaleFactor;
                uint256 yOffset = _scaleFactor;
                uint256 x = (i % size) * xOffset + rightOffsetX;
                uint256 y = 0;

                if (k == 1) {
                    y = (5 * yOffset);
                }
                y += (i / size) * yOffset;

                s = _concat(s, _generatePixelSVG(x, y, _scaleFactor, "252,100,211"));
            }
        }

        return s;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library FiguresUtilLib {
    struct FigStrings {
        string[] s1;
        string[] s2;
    }

    function substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function _assignValuesSingle(string memory input, uint16 size)
        internal
        pure
        returns (string[] memory)
    {
        return _assignValues(input, size, 50);
    }

    function _assignValuesDouble(string memory input, uint16 size)
        internal
        pure
        returns (string[] memory)
    {
        return _assignValues(input, size, 25);
    }

    function _assignValues(
        string memory input,
        uint16 size,
        uint8 length
    ) internal pure returns (string[] memory) {
        string[] memory output = new string[](size);
        for (uint256 i = 0; i < size; i++) {
            output[i] = substring(input, i * length, i * length + length);
        }
        return output;
    }

    function _chooseStringsSingle(
        uint8 number,
        string[] memory strings1,
        string[] memory strings2,
        uint8 index1,
        uint8 index2
    ) internal pure returns (bool[][2] memory b) {
        return _chooseStrings(number, strings1, strings2, index1, index2, 50);
    }

    function _chooseStringsDouble(
        uint8 number,
        string[] memory strings1,
        string[] memory strings2,
        uint8 index1,
        uint8 index2
    ) internal pure returns (bool[][2] memory b) {
        return _chooseStrings(number, strings1, strings2, index1, index2, 25);
    }

    function _chooseStrings(
        uint8 number,
        string[] memory strings1,
        string[] memory strings2,
        uint8 index1,
        uint8 index2,
        uint8 length
    ) private pure returns (bool[][2] memory b) {
        string[2] memory s;
        // some arrays are shorter than the random number generated
        uint256 availableIndex1 = index1 % strings1.length;
        uint256 availableIndex2 = index2 % strings2.length;
        s[0] = strings1[availableIndex1];
        s[1] = strings2[availableIndex2];

        // Special cases for 0, 1, 7
        if (number == 0 || number == 1 || number == 7) {
            if (length == 25) {
                while (
                    keccak256(bytes(substring(s[0], 20, 24))) !=
                    keccak256(bytes(substring(s[1], 0, 4)))
                ) {
                    uint256 is2 = ((availableIndex2 + availableIndex1++) %
                        strings2.length);
                    s[1] = strings2[is2];
                }
            }
            if (length == 50) {
                while (
                    keccak256(bytes(substring(s[0], 40, 49))) !=
                    keccak256(bytes(substring(s[1], 0, 9)))
                ) {
                    uint256 is2 = ((availableIndex2 + availableIndex1++) %
                        strings2.length);
                    s[1] = strings2[is2];
                }
            }
        }

        b[0] = _returnBoolArray(s[0]);
        b[1] = _returnBoolArray(s[1]);

        return b;
    }

    function checkString(string memory s1, string memory s2) private pure {}

    function _returnBoolArray(string memory s)
        internal
        pure
        returns (bool[] memory)
    {
        bytes memory b = bytes(s);
        bool[] memory a = new bool[](b.length);
        for (uint256 i = 0; i < b.length; i++) {
            uint8 z = (uint8(b[i]));
            if (z == 48) {
                a[i] = true;
            } else if (z == 49) {
                a[i] = false;
            }
        }
        return a;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IFiguresToken is IERC721 {
    /**
     * Initialize seed random variables used to render token
     * Can only be called by controller
     */
    function initializeSeed(uint256[] memory seed) external;

    /**
     * Mint a token with the given seed.
     * Can only be called by controller
     */
    function mint(
        uint256 tokenId,
        uint256 seed,
        address recipient
    ) external;

    /**
     * Render token based on seed
     */
    function render(uint256 seed) external view returns (string memory s);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ILazyDelivery is IERC165 {

    /**
     *  @dev Deliver an asset and deliver to the specified party
     *  When implementing this interface, please ensure you restrict access.
     *  If using LazyDeliver.sol, you can use authorizedDelivererRequired modifier to restrict access. 
     *  Delivery can be for an existing asset or newly minted assets.
     * 
     *  @param listingId      The listingId associated with this delivery.  Useful for permissioning.
     *  @param to             The address to deliver the asset to
     *  @param assetId        The assetId to deliver
     *  @param payableCount   The number of assets to deliver
     *  @param payableAmount  The amount seller will receive upon delivery of asset
     *  @param payableERC20   The erc20 token address of the amount (0x0 if ETH)
     *  @param index          (Optional): Index value for certain sales methods, such as ranked auctions
     *
     *  @return any Only used for Ranked Auctions and represents the refund amount you want to give.
     *              Value is unused for all other listing types
     *
     *  Suggestion: If determining a refund amount based on total sales data, do not enable this function
     *              until the sales data is finalized and recorded in contract
     *
     *  Exploit Prevention for dynamic/random assignment
     *  1. Ensure attributes are not assigned until AFTER underlying mint if using _safeMint.
     *     This is to ensure a receiver cannot check attribute values on receive and revert transaction.
     *     However, even if this is the case, the recipient can wrap its mint in a contract that checks 
     *     post mint completion and reverts if unsuccessful.
     *  2. Ensure that "to" is not a contract address. This prevents a contract from doing the lazy 
     *     mint, which could exploit random assignment by reverting if they do not receive the desired
     *     item post mint.
     */
    function deliver(uint40 listingId, address to, uint256 assetId, uint24 payableCount, uint256 payableAmount, address payableERC20, uint256 index) external returns(uint256);

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * Metadata for lazy delivery tokens
 */
interface ILazyDeliveryMetadata is IERC165 {

    function assetURI(uint256 assetId) external view returns(string memory);

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMarketplaceCore {

    // Listing types
    enum ListingType {
        INVALID,
        INDIVIDUAL_AUCTION,
        FIXED_PRICE,
        DYNAMIC_PRICE,
        RANKED_AUCTION
    }

    enum Spec {
        NONE,
        ERC721,
        ERC1155
    }

    /**
     * @dev Listing details structure
     *
     * @param initialAmount     - The initial amount of the listing. For auctions, it represents the reserve price.  For DYNAMIC_PRICE listings, it must be 0.
     * @param type_             - Listing type
     * @param totalAvailable    - Total number of tokens available.  Must be divisible by totalPerSale. For INDIVIDUAL_AUCTION, totalAvailable must equal totalPerSale
     * @param totalPerSale      - Number of tokens the buyer will get per purchase.  Must be 1 if it is a lazy token
     * @param extensionInterval - Only valid for *_AUCTION types. Indicates how long an auction will extend if a bid is made within the last <extensionInterval> seconds of the auction.
     * @param minIncrementBPS   - Only valid for *_AUCTION types. Indicates the minimum bid increase required
     * @param erc20             - If not 0x0, it indicates the erc20 token accepted for this sale
     * @param identityVerifier  - If not 0x0, it indicates the buyers should be verified before any bid or purchase
     * @param startTime         - The start time of the sale.  If set to 0, startTime will be set to the first bid/purchase.
     * @param endTime           - The end time of the sale.  If startTime is 0, represents the duration of the listing upon first bid/purchase.
     */
    struct ListingDetails {
        uint256 initialAmount;
        ListingType type_;
        uint24 totalAvailable;
        uint24 totalPerSale;
        uint16 extensionInterval;
        uint16 minIncrementBPS;
        address erc20;
        address identityVerifier;
        uint48 startTime;
        uint48 endTime;
    }

   /**
     * @dev Token detail structure
     *
     * @param address_  - The contract address of the token
     * @param id        - The token id (or for a lazy asset, the asset id)
     * @param spec      - The spec of the token.  If it's a lazy token, it must be blank.
     * @param lazy      - True if token is to be lazy minted, false otherwise.  If lazy, the contract address must support ILazyDelivery
     */
    struct TokenDetails {
        uint256 id;
        address address_;
        Spec spec;
        bool lazy;
    }

    /**
     * @dev Fee configuration for listing
     *
     * @param deliverBPS         - Additional fee needed to deliver the token (BPS)
     * @param deliverFixed       - Additional fee needed to deliver the token (fixed)
     */
    struct DeliveryFees {
        uint16 deliverBPS;
        uint240 deliverFixed;
    }

    /**
     * Listing receiver.  The array of listing receivers must add up to 10000 BPS if provided.
     */
    struct ListingReceiver {
        address payable receiver;
        uint16 receiverBPS;
    }

    /**
     * @dev Create listing
     */
    function createListing(ListingDetails calldata listingDetails, TokenDetails calldata tokenDetails, DeliveryFees calldata deliveryFees, ListingReceiver[] calldata listingReceivers, bool enableReferrer, bytes calldata data) external returns (uint40);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library Figure0DigitLib {
    function S1() public pure returns (string memory) {
        return
            "000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000011111111001111111100000000000000000000000000000000111111100011111110000000000000000000000000000000000111111100011111110000000000000000000000000000000011111100001111110000000000000000000000000000000000011111100001111110000000000000000000000000000000000011111100001111110000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000111111110011111111001111111100000000000000000000001111111000111111100011111110000000000000000000000001111111000111111100011111110000000000000000000000111111000011111100001111110000000000000000000000000111111000011111100001111110000000000000000000000000111111000011111100001111110000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000111000000011100000001110000000000000000000000000000111000000011100000001110000000000000000000000000000111000000011100000001110000000000000000000000000000111000000011100000001110000000000000000000000000000111000000011100000001110000000000000000000000000000111000000011100000001110000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000001111111100111111110011111111001111111100000000000011111110001111111000111111100011111110000000000000011111110001111111000111111100011111110000000000001111110000111111000011111100001111110000000000000001111110000111111000011111100001111110000000000000001111110000111111000011111100001111110000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000001110000000111000000011100000001110000000000000000001110000000111000000011100000001110000000000000000001110000000111000000011100000001110000000000000000001110000000111000000011100000001110000000000000000001110000000111000000011100000001110000000000000000001110000000111000000011100000001110000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010";
    }

    function S2() public pure returns (string memory) {
        return
            "010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000011111100001111110000111111000011111100000000000000011111100001111110000111111000011111100000000000000011111100001111110000111111000011111100000000000011111110001111111000111111100011111110000000000000011111110001111111000111111100011111110000000000001111111100111111110011111111001111111100000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000001111100000111110000011111000000000000000000000000001111100000111110000011111000000000000000000000000001111100000111110000011111000000000000000000000000001111100000111110000011111000000000000000000000011111100001111110000111111000000000000000000000000011111100001111110000111111000000000000000000000000011111100001111110000111111000000000000000000000011111110001111111000111111100000000000000000000000011111110001111111000111111100000000000000000000001111111100111111110011111111000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000001111100000111110000000000000000000000000000000000001111100000111110000000000000000000000000000000000001111100000111110000000000000000000000000000000000001111100000111110000000000000000000000000000000011111100001111110000000000000000000000000000000000011111100001111110000000000000000000000000000000000011111100001111110000000000000000000000000000000011111110001111111000000000000000000000000000000000011111110001111111000000000000000000000000000000001111111100111111110000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library Figure1DigitLib {
    function S1() public pure returns (string memory) {
        return
            "00000000011000000001100000000110000000011000000001000000000100000000011000000001100000000110000000010000000001000000000100000000011000000001100000000100000000010000000001000000000100000000011000000001000000000111000000011100000001110000000111000000010000000001000000000111000000011100000001110000000100000000010000000001000000000111000000011100000001000000000100000000010000000001000000000111000000010000000001111000000111100000011110000001111000000100000000010000000001111000000111100000011110000001000000000100000000010000000001111000000111100000010000000001000000000100000000010000000001111000000100000000111110000011111000001111100000111110000011000000001100000000111110000011111000001111100000110000000011000000001100000000111110000011111000001100000000110000000011000000001100000000111110000011000000011111100001111110000111111000011111100001110000000111000000011111100001111110000111111000011100000001110000000111000000011111100001111110000111000000011100000001110000000111000000011111100001110000000011110000001111000000111100000011110000001100000000110000000011110000001111000000111100000011000000001100000000110000000011110000001111000000110000000011000000001100000000110000000011110000001100000000111000000011100000001110000000111000000011000000001100000000111000000011100000001110000000110000000011000000001100000000111000000011100000001100000000110000000011000000001100000000111000000011";
    }

    function S2() public pure returns (string memory) {
        return
            "10000000011000000001100000000110000000010000000000100000000110000000011000000001000000000000000000001000000001100000000100000000000000000000000000000010000000010000000000000000000000000000000000000000110000000111000000011100000001110000000100000000001100000001110000000111000000010000000000000000000011000000011100000001000000000000000000000000000000110000000100000000000000000000000000000000000000001110000001111000000111100000011110000001000000000011100000011110000001111000000100000000000000000000111000000111100000010000000000000000000000000000001110000001000000000000000000000000000000000000000011100000111110000011111000001111100000110000000000111000001111100000111110000011000000000000000000001110000011111000001100000000000000000000000000000011100000110000000000000000000000000000000000000000111000011111100001111110000111111000011100000000001110000111111000011111100001110000000000000000000011100001111110000111000000000000000000000000000000111000011100000000000000000000000000000000000000001100000011110000001111000000111100000011000000000011000000111100000011110000001100000000000000000000110000001111000000110000000000000000000000000000001100000011000000000000000000000000000000000000000010000000111000000011100000001110000000110000000000100000001110000000111000000011000000000000000000001000000011100000001100000000000000000000000000000010000000110000000000000000000000000000000000000000";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library Figure2DigitLib {
    function S1() public pure returns (string memory) {
        return
            "000000000011111111101111111110111111111000000000000000000000111111110011111111001111111100000000000000000000001111111000111111100011111110000000000000000000000011111100001111110000111111000000000000000000000000111110000011111000001111100000000000000000000000001111000000111100000011110000000000000000000000000011100000001110000000111000000000000000000000000000110000000011000000001100000000000000000000000000001000000000100000000010000000000000000000000000000011111111101111111110000000000000000000000000000000111111110011111111000000000000000000000000000000001111111000111111100000000000000000000000000000000011111100001111110000000000000000000000000000000000111110000011111000000000000000000000000000000000001111000000111100000000000000000000000000000000000011100000001110000000000000000000000000000000000000110000000011000000000000000000000000000000000000001000000000100000000000000000000000000000000000000000000000001111111110111111111000000000000000000000000000000011111111001111111100000000000000000000000000000000111111100011111110000000000000000000000000000000001111110000111111000000000000000000000000000000000011111000001111100000000000000000000000000000000000111100000011110000000000000000000000000000000000001110000000111000000000000000000000000000000000000011000000001100000000000000000000000000000000000000100000000010000000000000000000000000000011111111100000000000000000000000000000000000000000111111110000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000001111111110000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000111111111000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000010000000000000000000";
    }

    function S2() public pure returns (string memory) {
        return
            "000000000000000000010000000001000000000100000000000000000000000000001100000000110000000011000000000000000000000000000111000000011100000001110000000000000000000000000011110000001111000000111100000000000000000000000001111100000111110000011111000000000000000000000000111111000011111100001111110000000000000000000000011111110001111111000111111100000000000000000000001111111100111111110011111111000000000000000000000111111111011111111101111111110000000000000000000000000000010000000001000000000000000000000000000000000000001100000000110000000000000000000000000000000000000111000000011100000000000000000000000000000000000011110000001111000000000000000000000000000000000001111100000111110000000000000000000000000000000000111111000011111100000000000000000000000000000000011111110001111111000000000000000000000000000000001111111100111111110000000000000000000000000000000111111111011111111100000000000000000000000000000000000000000000000001000000000100000000000000000000000000000000000000110000000011000000000000000000000000000000000000011100000001110000000000000000000000000000000000001111000000111100000000000000000000000000000000000111110000011111000000000000000000000000000000000011111100001111110000000000000000000000000000000001111111000111111100000000000000000000000000000000111111110011111111000000000000000000000000000000011111111101111111110000000000000000000000000000010000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000111111111000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000011111111100000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000011111111000000000000000000000000000000000000000001111111110000000000000000000100000000010000000001000000000100000000000000000011000000001100000000110000000011000000000000000001110000000111000000011100000001110000000000000000111100000011110000001111000000111100000000000000011111000001111100000111110000011111000000000000001111110000111111000011111100001111110000000000000111111100011111110001111111000111111100000000000011111111001111111100111111110011111111000000000001111111110111111111011111111101111111110000000000000000000100000000010000000001000000000000000000000000000011000000001100000000110000000000000000000000000001110000000111000000011100000000000000000000000000111100000011110000001111000000000000000000000000011111000001111100000111110000000000000000000000001111110000111111000011111100000000000000000000000111111100011111110001111111000000000000000000000011111111001111111100111111110000000000000000000001111111110111111111011111111100000000000000000000000000000100000000010000000000000000000000000000000000000011000000001100000000000000000000000000000000000001110000000111000000000000000000000000000000000000111100000011110000000000000000000000000000000000011111000001111100000000000000000000000000000000001111110000111111000000000000000000000000000000000111111100011111110000000000000000000000000000000011111111001111111100000000000000000000000000000001111111110111111111000000000000000000000000000000000000000100000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000011111111000000000000000000000000000000000000000001111111110000000000000000000000000000000000000000";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library Figure3DigitLib {
    function S1() public pure returns (string memory) {
        return
            "000000000011111111101111111110111111111000000000000000000000111111110011111111001111111100000000000000000000001111111000111111100011111110000000000000000000000011111100001111110000111111000000000000000000000000111110000011111000001111100000000000000000000000001111000000111100000011110000000000000000000000000011100000001110000000111000000000000000000000000000110000000011000000001100000000000000000000000000001000000000100000000010000000000000000000000000000011111111101111111110000000000000000000000000000000111111110011111111000000000000000000000000000000001111111000111111100000000000000000000000000000000011111100001111110000000000000000000000000000000000111110000011111000000000000000000000000000000000001111000000111100000000000000000000000000000000000011100000001110000000000000000000000000000000000000110000000011000000000000000000000000000000000000001000000000100000000000000000000000000000000000000000000000001111111110111111111000000000000000000000000000000011111111001111111100000000000000000000000000000000111111100011111110000000000000000000000000000000001111110000111111000000000000000000000000000000000011111000001111100000000000000000000000000000000000111100000011110000000000000000000000000000000000001110000000111000000000000000000000000000000000000011000000001100000000000000000000000000000000000000100000000010000000000000000000000000000011111111100000000000000000000000000000000000000000111111110000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000001111111110000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000111111111000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000010000000000000000000";
    }

    function S2() public pure returns (string memory) {
        return
            "000000000011111111101111111110111111111000000000000000000000111111110011111111001111111100000000000000000000001111111000111111100011111110000000000000000000000011111100001111110000111111000000000000000000000000111110000011111000001111100000000000000000000000001111000000111100000011110000000000000000000000000011100000001110000000111000000000000000000000000000110000000011000000001100000000000000000000000000001000000000100000000010000000000000000000000000000011111111101111111110000000000000000000000000000000111111110011111111000000000000000000000000000000001111111000111111100000000000000000000000000000000011111100001111110000000000000000000000000000000000111110000011111000000000000000000000000000000000001111000000111100000000000000000000000000000000000011100000001110000000000000000000000000000000000000110000000011000000000000000000000000000000000000001000000000100000000000000000000000000000000000000000000000001111111110111111111000000000000000000000000000000011111111001111111100000000000000000000000000000000111111100011111110000000000000000000000000000000001111110000111111000000000000000000000000000000000011111000001111100000000000000000000000000000000000111100000011110000000000000000000000000000000000001110000000111000000000000000000000000000000000000011000000001100000000000000000000000000000000000000100000000010000000000000000000000000000011111111100000000000000000000000000000000000000000111111110000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000001111111110000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000111111111000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000010000000000000000000111111111011111111101111111110111111111000000000001111111100111111110011111111001111111100000000000011111110001111111000111111100011111110000000000000111111000011111100001111110000111111000000000000001111100000111110000011111000001111100000000000000011110000001111000000111100000011110000000000000000111000000011100000001110000000111000000000000000001100000000110000000011000000001100000000000000000010000000001000000000100000000010000000000000000000111111111011111111101111111110000000000000000000001111111100111111110011111111000000000000000000000011111110001111111000111111100000000000000000000000111111000011111100001111110000000000000000000000001111100000111110000011111000000000000000000000000011110000001111000000111100000000000000000000000000111000000011100000001110000000000000000000000000001100000000110000000011000000000000000000000000000010000000001000000000100000000000000000000000000000111111111011111111100000000000000000000000000000001111111100111111110000000000000000000000000000000011111110001111111000000000000000000000000000000000111111000011111100000000000000000000000000000000001111100000111110000000000000000000000000000000000011110000001111000000000000000000000000000000000000111000000011100000000000000000000000000000000000001100000000110000000000000000000000000000000000000010000000001000000000000000000000000000000000000000111111111000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library Figure4DigitLib {
    function S1() public pure returns (string memory) {
        return
            "011111110101111111010111111101011111110101111111010111111101011111110101111111010111111101000000000001111111010111111101011111110100000000000000000000011111110101111111010000000000000000000000000000000111111011011111101101111110110111111011011111101101111110110111111011011111101101111110110000000000011111101101111110110111111011000000000000000000000111111011011111101100000000000000000000000000000001111101110111110111011111011101111101110111110111011111011101111101110111110111011111011100000000000111110111011111011101111101110000000000000000000001111101110111110111000000000000000000000000000000011110111101111011110111101111011110111101111011110111101111011110111101111011110111101111000000000001111011110111101111011110111100000000000000000000011110111101111011110000000000000000000000000000000011111101001111110100111111010011111101001111110100111111010011111101001111110100111111010000000000001111110100111111010011111101000000000000000000000011111101001111110100000000000000000000000000000000111110110011111011001111101100111110110011111011001111101100111110110011111011001111101100000000000011111011001111101100111110110000000000000000000000111110110011111011000000000000000000000000000000001111011100111101110011110111001111011100111101110011110111001111011100111101110011110111000000000000111101110011110111001111011100000000000000000000001111011100111101110000000000000000000000000000000011101111001110111100111011110011101111001110111100111011110011101111001110111100111011110000000000001110111100111011110011101111000000000000000000000011101111001110111100000000000000000000000000000000011111010001111101000111110100011111010001111101000111110100011111010001111101000111110100000000000001111101000111110100011111010000000000000000000000011111010001111101000000000000000000000000000000000111101100011110110001111011000111101100011110110001111011000111101100011110110001111011000000000000011110110001111011000111101100000000000000000000000111101100011110110000000000000000000000000000000001110111000111011100011101110001110111000111011100011101110001110111000111011100011101110000000000000111011100011101110001110111000000000000000000000001110111000111011100000000000000000000000000000000011011110001101111000110111100011011110001101111000110111100011011110001101111000110111100000000000001101111000110111100011011110000000000000000000000011011110001101111000000000000000000000000000000000011110100001111010000111101000011110100001111010000111101000011110100001111010000111101000000000000001111010000111101000011110100000000000000000000000011110100001111010000000000000000000000000000000000111011000011101100001110110000111011000011101100001110110000111011000011101100001110110000000000000011101100001110110000111011000000000000000000000000111011000011101100000000000000000000000000000000001101110000110111000011011100001101110000110111000011011100001101110000110111000011011100000000000000110111000011011100001101110000000000000000000000001101110000110111000000000000000000000000000000000010111100001011110000101111000010111100001011110000101111000010111100001011110000101111000000000000001011110000101111000010111100000000000000000000000010111100001011110000000000000000000000000000000111111001011111100101111110010111111001011111100101111110010111111001011111100101111110010000000000011111100101111110010111111001000000000000000000000111111001011111100100000000000000000000000000000001111100110111110011011111001101111100110111110011011111001101111100110111110011011111001100000000000111110011011111001101111100110000000000000000000001111100110111110011000000000000000000000000000000011110011101111001110111100111011110011101111001110111100111011110011101111001110111100111000000000001111001110111100111011110011100000000000000000000011110011101111001110000000000000000000000000000000111100011011110001101111000110111100011011110001101111000110111100011011110001101111000110000000000011110001101111000110111100011000000000000000000000111100011011110001100000000000000000000000000000001111100010111110001011111000101111100010111110001011111000101111100010111110001011111000100000000000111110001011111000101111100010000000000000000000001111100010111110001000000000000000000000000000000001111100100111110010011111001001111100100111110010011111001001111100100111110010011111001000000000000111110010011111001001111100100000000000000000000001111100100111110010000000000000000000000000000000011110011001111001100111100110011110011001111001100111100110011110011001111001100111100110000000000001111001100111100110011110011000000000000000000000011110011001111001100000000000000000000000000000000111001110011100111001110011100111001110011100111001110011100111001110011100111001110011100000000000011100111001110011100111001110000000000000000000000111001110011100111000000000000000000000000000000001110001100111000110011100011001110001100111000110011100011001110001100111000110011100011000000000000111000110011100011001110001100000000000000000000001110001100111000110000000000000000000000000000000011110001001111000100111100010011110001001111000100111100010011110001001111000100111100010000000000001111000100111100010011110001000000000000000000000011110001001111000100000000000000000000000000000000011110010001111001000111100100011110010001111001000111100100011110010001111001000111100100000000000001111001000111100100011110010000000000000000000000011110010001111001000000000000000000000000000000000111001100011100110001110011000111001100011100110001110011000111001100011100110001110011000000000000011100110001110011000111001100000000000000000000000111001100011100110000000000000000000000000000000001100111000110011100011001110001100111000110011100011001110001100111000110011100011001110000000000000110011100011001110001100111000000000000000000000001100111000110011100000000000000000000000000000000011000110001100011000110001100011000110001100011000110001100011000110001100011000110001100000000000001100011000110001100011000110000000000000000000000011000110001100011000000000000000000000000000000000111000100011100010001110001000111000100011100010001110001000111000100011100010001110001000000000000011100010001110001000111000100000000000000000000000111000100011100010000000000000000000000000000000000111001000011100100001110010000111001000011100100001110010000111001000011100100001110010000000000000011100100001110010000111001000000000000000000000000111001000011100100000000000000000000000000000000001100110000110011000011001100001100110000110011000011001100001100110000110011000011001100000000000000110011000011001100001100110000000000000000000000001100110000110011000000000000000000000000000000000010011100001001110000100111000010011100001001110000100111000010011100001001110000100111000000000000001001110000100111000010011100000000000000000000000010011100001001110000000000000000000000000000000000100011000010001100001000110000100011000010001100001000110000100011000010001100001000110000000000000010001100001000110000100011000000000000000000000000100011000010001100000000000000000000000000000000001100010000110001000011000100001100010000110001000011000100001100010000110001000011000100000000000000110001000011000100001100010000000000000000000000001100010000110001000000000000000000000000000000";
    }

    function S2() public pure returns (string memory) {
        return
            "000000000011111111011111111101111111110111111111010000000000111111101111111110111111111011111111101100000000001111110111111111011111111101111111110111000000000011111011111111101111111110111111111011110000000000000000000011111111011111111101111111110100000000000000000000111111101111111110111111111011000000000000000000001111110111111111011111111101110000000000000000000011111011111111101111111110111100000000000000000000000000000011111111011111111101000000000000000000000000000000111111101111111110110000000000000000000000000000001111110111111111011100000000000000000000000000000011111011111111101111000000000011111110011111111001111111100111111110010000000000111111001111111100111111110011111111001100000000001111100111111110011111111001111111100111000000000000000000001111111001111111100111111110010000000000000000000011111100111111110011111111001100000000000000000000111110011111111001111111100111000000000000000000000000000000111111100111111110010000000000000000000000000000001111110011111111001100000000000000000000000000000011111001111111100111000000000011111100011111110001111111000111111100010000000000111110001111111000111111100011111110001100000000000000000000111111000111111100011111110001000000000000000000001111100011111110001111111000110000000000000000000000000000001111110001111111000100000000000000000000000000000011111000111111100011000000000011111000011111100001111110000111111000010000000000000000000011111000011111100001111110000100000000000000000000000000000011111000011111100001";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library Figure5DigitLib {
    function S1() public pure returns (string memory) {
        return
            "000000000000000000010000000001000000000100000000000000000000000000001100000000110000000011000000000000000000000000000111000000011100000001110000000000000000000000000011110000001111000000111100000000000000000000000001111100000111110000011111000000000000000000000000111111000011111100001111110000000000000000000000011111110001111111000111111100000000000000000000001111111100111111110011111111000000000000000000000111111111011111111101111111110000000000000000000000000000010000000001000000000000000000000000000000000000001100000000110000000000000000000000000000000000000111000000011100000000000000000000000000000000000011110000001111000000000000000000000000000000000001111100000111110000000000000000000000000000000000111111000011111100000000000000000000000000000000011111110001111111000000000000000000000000000000001111111100111111110000000000000000000000000000000111111111011111111100000000000000000000000000000000000000000000000001000000000100000000000000000000000000000000000000110000000011000000000000000000000000000000000000011100000001110000000000000000000000000000000000001111000000111100000000000000000000000000000000000111110000011111000000000000000000000000000000000011111100001111110000000000000000000000000000000001111111000111111100000000000000000000000000000000111111110011111111000000000000000000000000000000011111111101111111110000000000000000000000000000010000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000111111111000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000011111111100000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000011111111000000000000000000000000000000000000000001111111110000000000";
    }

    function S2() public pure returns (string memory) {
        return
            "000000000011111111101111111110111111111000000000000000000000111111110011111111001111111100000000000000000000001111111000111111100011111110000000000000000000000011111100001111110000111111000000000000000000000000111110000011111000001111100000000000000000000000001111000000111100000011110000000000000000000000000011100000001110000000111000000000000000000000000000110000000011000000001100000000000000000000000000001000000000100000000010000000000000000000000000000011111111101111111110000000000000000000000000000000111111110011111111000000000000000000000000000000001111111000111111100000000000000000000000000000000011111100001111110000000000000000000000000000000000111110000011111000000000000000000000000000000000001111000000111100000000000000000000000000000000000011100000001110000000000000000000000000000000000000110000000011000000000000000000000000000000000000001000000000100000000000000000000000000000000000000000000000001111111110111111111000000000000000000000000000000011111111001111111100000000000000000000000000000000111111100011111110000000000000000000000000000000001111110000111111000000000000000000000000000000000011111000001111100000000000000000000000000000000000111100000011110000000000000000000000000000000000001110000000111000000000000000000000000000000000000011000000001100000000000000000000000000000000000000100000000010000000000000000000000000000011111111100000000000000000000000000000000000000000111111110000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000001111111110000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000111111111000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000010000000000000000000111111111011111111101111111110111111111000000000001111111100111111110011111111001111111100000000000011111110001111111000111111100011111110000000000000111111000011111100001111110000111111000000000000001111100000111110000011111000001111100000000000000011110000001111000000111100000011110000000000000000111000000011100000001110000000111000000000000000001100000000110000000011000000001100000000000000000010000000001000000000100000000010000000000000000000111111111011111111101111111110000000000000000000001111111100111111110011111111000000000000000000000011111110001111111000111111100000000000000000000000111111000011111100001111110000000000000000000000001111100000111110000011111000000000000000000000000011110000001111000000111100000000000000000000000000111000000011100000001110000000000000000000000000001100000000110000000011000000000000000000000000000010000000001000000000100000000000000000000000000000111111111011111111100000000000000000000000000000001111111100111111110000000000000000000000000000000011111110001111111000000000000000000000000000000000111111000011111100000000000000000000000000000000001111100000111110000000000000000000000000000000000011110000001111000000000000000000000000000000000000111000000011100000000000000000000000000000000000001100000000110000000000000000000000000000000000000010000000001000000000000000000000000000000000000000111111111000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library Figure6DigitLib {
    function S1() public pure returns (string memory) {
        return
            "000000000000000000010000000001000000000100000000000000000000000000001100000000110000000011000000000000000000000000000111000000011100000001110000000000000000000000000011110000001111000000111100000000000000000000000001111100000111110000011111000000000000000000000000111111000011111100001111110000000000000000000000011111110001111111000111111100000000000000000000001111111100111111110011111111000000000000000000000111111111011111111101111111110000000000000000000000000000010000000001000000000000000000000000000000000000001100000000110000000000000000000000000000000000000111000000011100000000000000000000000000000000000011110000001111000000000000000000000000000000000001111100000111110000000000000000000000000000000000111111000011111100000000000000000000000000000000011111110001111111000000000000000000000000000000001111111100111111110000000000000000000000000000000111111111011111111100000000000000000000000000000000000000000000000001000000000100000000000000000000000000000000000000110000000011000000000000000000000000000000000000011100000001110000000000000000000000000000000000001111000000111100000000000000000000000000000000000111110000011111000000000000000000000000000000000011111100001111110000000000000000000000000000000001111111000111111100000000000000000000000000000000111111110011111111000000000000000000000000000000011111111101111111110000000000000000000000000000010000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000111111111000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000011111111100000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000011111111000000000000000000000000000000000000000001111111110000000000";
    }

    function S2() public pure returns (string memory) {
        return
            "010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000011111100001111110000111111000011111100000000000000011111100001111110000111111000011111100000000000000011111100001111110000111111000011111100000000000011111110001111111000111111100011111110000000000000011111110001111111000111111100011111110000000000001111111100111111110011111111001111111100000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000001111100000111110000011111000000000000000000000000001111100000111110000011111000000000000000000000000001111100000111110000011111000000000000000000000000001111100000111110000011111000000000000000000000011111100001111110000111111000000000000000000000000011111100001111110000111111000000000000000000000000011111100001111110000111111000000000000000000000011111110001111111000111111100000000000000000000000011111110001111111000111111100000000000000000000001111111100111111110011111111000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000001111100000111110000000000000000000000000000000000001111100000111110000000000000000000000000000000000001111100000111110000000000000000000000000000000000001111100000111110000000000000000000000000000000011111100001111110000000000000000000000000000000000011111100001111110000000000000000000000000000000000011111100001111110000000000000000000000000000000011111110001111111000000000000000000000000000000000011111110001111111000000000000000000000000000000001111111100111111110000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000001111110000111111000011111100000000000000000000000001111110000111111000011111100000000000000000000000001111110000111111000011111100000000000000000000001111111000111111100011111110000000000000000000000001111111000111111100011111110000000000000000000000111111110011111111001111111100000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000001111110000111111000000000000000000000000000000000001111110000111111000000000000000000000000000000000001111110000111111000000000000000000000000000000001111111000111111100000000000000000000000000000000001111111000111111100000000000000000000000000000000111111110011111111000000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000111111000011111100000000000000000000000000000000000111111000011111100000000000000000000000000000000000111111000011111100000000000000000000000000000000111111100011111110000000000000000000000000000000000111111100011111110000000000000000000000000000000011111111001111111100000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111111100000000000";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library Figure7DigitLib {
    function S1() public pure returns (string memory) {
        return
            "000000000000000000001111111100111111110011111111000000000000000000000011111110001111111000111111100000000000000000000000111111000011111100001111110000000000000000000000001111100000111110000011111000000000000000000000000011110000001111000000111100000000000000000000000000111000000011100000001110000000000000000000000000000000000000111111110011111111000000000000000000000000000000001111111000111111100000000000000000000000000000000011111100001111110000000000000000000000000000000000111110000011111000000000000000000000000000000000001111000000111100000000000000000000000000000000000011100000001110000000000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000001110000000";
    }

    function S2() public pure returns (string memory) {
        return
            "111111110011111111001111111100111111110011111111001111111000111111100011111110001111111000111111100011111100001111110000111111000011111100001111110000111110000011111000001111100000111110000011111000001111000000111100000011110000001111000000111100000011100000001110000000111000000011100000001110000000";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library Figure8DigitLib {
    function S1() public pure returns (string memory) {
        return
            "000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000001111110000111111000011111100000000000000000000000001111110000111111000011111100000000000000000000000001111110000111111000011111100000000000000000000001111111000111111100011111110000000000000000000000001111111000111111100011111110000000000000000000000111111110011111111001111111100000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000001111110000111111000000000000000000000000000000000001111110000111111000000000000000000000000000000000001111110000111111000000000000000000000000000000001111111000111111100000000000000000000000000000000001111111000111111100000000000000000000000000000000111111110011111111000000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000111111000011111100000000000000000000000000000000000111111000011111100000000000000000000000000000000000111111000011111100000000000000000000000000000000111111100011111110000000000000000000000000000000000111111100011111110000000000000000000000000000000011111111001111111100000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111111100000000000";
    }

    function S2() public pure returns (string memory) {
        return
            "000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000001111110000111111000011111100000000000000000000000001111110000111111000011111100000000000000000000000001111110000111111000011111100000000000000000000001111111000111111100011111110000000000000000000000001111111000111111100011111110000000000000000000000111111110011111111001111111100000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000001111110000111111000000000000000000000000000000000001111110000111111000000000000000000000000000000000001111110000111111000000000000000000000000000000001111111000111111100000000000000000000000000000000001111111000111111100000000000000000000000000000000111111110011111111000000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000111111000011111100000000000000000000000000000000000111111000011111100000000000000000000000000000000000111111000011111100000000000000000000000000000000111111100011111110000000000000000000000000000000000111111100011111110000000000000000000000000000000011111111001111111100000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111111100000000000";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library Figure9DigitLib {
    function S1() public pure returns (string memory) {
        return
            "010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000000000000010000000001000000000100000000010000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000000000001100000000110000000011000000001100000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000000000011100000001110000000111000000011100000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000000000011110000001111000000111100000011110000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000000001111100000111110000011111000001111100000000000011111100001111110000111111000011111100000000000000011111100001111110000111111000011111100000000000000011111100001111110000111111000011111100000000000011111110001111111000111111100011111110000000000000011111110001111111000111111100011111110000000000001111111100111111110011111111001111111100000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000000000000010000000001000000000100000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000000000001100000000110000000011000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000000000011100000001110000000111000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000000000011110000001111000000111100000000000000000000001111100000111110000011111000000000000000000000000001111100000111110000011111000000000000000000000000001111100000111110000011111000000000000000000000000001111100000111110000011111000000000000000000000011111100001111110000111111000000000000000000000000011111100001111110000111111000000000000000000000000011111100001111110000111111000000000000000000000011111110001111111000111111100000000000000000000000011111110001111111000111111100000000000000000000001111111100111111110011111111000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000010000000001000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000000000001100000000110000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000000000011100000001110000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000000000011110000001111000000000000000000000000000000001111100000111110000000000000000000000000000000000001111100000111110000000000000000000000000000000000001111100000111110000000000000000000000000000000000001111100000111110000000000000000000000000000000011111100001111110000000000000000000000000000000000011111100001111110000000000000000000000000000000000011111100001111110000000000000000000000000000000011111110001111111000000000000000000000000000000000011111110001111111000000000000000000000000000000001111111100111111110000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000000000001000000000100000000010000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000000000000110000000011000000001100000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000000000001110000000111000000011100000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000000001111000000111100000011110000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000000000111110000011111000001111100000000000000000000001111110000111111000011111100000000000000000000000001111110000111111000011111100000000000000000000000001111110000111111000011111100000000000000000000001111111000111111100011111110000000000000000000000001111111000111111100011111110000000000000000000000111111110011111111001111111100000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000000000001000000000100000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000000000000110000000011000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000000000001110000000111000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000000001111000000111100000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000000000111110000011111000000000000000000000000000000001111110000111111000000000000000000000000000000000001111110000111111000000000000000000000000000000000001111110000111111000000000000000000000000000000001111111000111111100000000000000000000000000000000001111111000111111100000000000000000000000000000000111111110011111111000000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000100000000010000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000000000011000000001100000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000000000111000000011100000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000000000111100000011110000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000000011111000001111100000000000000000000000000000000111111000011111100000000000000000000000000000000000111111000011111100000000000000000000000000000000000111111000011111100000000000000000000000000000000111111100011111110000000000000000000000000000000000111111100011111110000000000000000000000000000000011111111001111111100000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000011111110000000000000000000000000000000000000000001111111100000000000";
    }

    function S2() public pure returns (string memory) {
        return
            "000000000011111111101111111110111111111000000000000000000000111111110011111111001111111100000000000000000000001111111000111111100011111110000000000000000000000011111100001111110000111111000000000000000000000000111110000011111000001111100000000000000000000000001111000000111100000011110000000000000000000000000011100000001110000000111000000000000000000000000000110000000011000000001100000000000000000000000000001000000000100000000010000000000000000000000000000011111111101111111110000000000000000000000000000000111111110011111111000000000000000000000000000000001111111000111111100000000000000000000000000000000011111100001111110000000000000000000000000000000000111110000011111000000000000000000000000000000000001111000000111100000000000000000000000000000000000011100000001110000000000000000000000000000000000000110000000011000000000000000000000000000000000000001000000000100000000000000000000000000000000000000000000000001111111110111111111000000000000000000000000000000011111111001111111100000000000000000000000000000000111111100011111110000000000000000000000000000000001111110000111111000000000000000000000000000000000011111000001111100000000000000000000000000000000000111100000011110000000000000000000000000000000000001110000000111000000000000000000000000000000000000011000000001100000000000000000000000000000000000000100000000010000000000000000000000000000011111111100000000000000000000000000000000000000000111111110000000000000000000000000000000000000000001111111000000000000000000000000000000000000000000011111100000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000001111111110000000000000000000000000000000000000000011111111000000000000000000000000000000000000000000111111100000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000111111111000000000000000000000000000000000000000001111111100000000000000000000000000000000000000000011111110000000000000000000000000000000000000000000111111000000000000000000000000000000000000000000001111100000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000010000000000000000000";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

library FiguresDoubleDigitsLib {
    string public constant FS0S1 =
        "00000011100111001110011100000000000011100111001110000000000000000011100111000000000000000000000011100000000100001000010000100000000000000100001000010000000000000000000100001000000000000000000000000100";
    string public constant FS0S2 =
        "01110011100111001110000000111001110011100000000000011100111000000000000000001110000000000000000000000010000100001000010000000001000010000100000000000000100001000000000000000000010000000000000000000000";

    string public constant FS1S1 =
        "000011000110001100011000100001000011000110001100010000100001000011000110001000010000100001000011000100001110011100111001110010000100001110011100111001000010000100001110011100100001000010000100001110010000111101111011110111101000010000111101111011110100001000010000111101111010000100001000010000111101000111101111011110111101100011000111101111011110110001100011000111101111011000110001100011000111101100111101111011110111101110011100111101111011110111001110011100111101111011100111001110011100111101110001110011100111001110011000110001110011100111001100011000110001110011100110001100011000110001110011";

    string public constant FS1S2 =
        "100011000110001100010000010001100011000100000000001000110001000000000000000100010000000000000000000011001110011100111001000001100111001110010000000000110011100100000000000000011001000000000000000000001110111101111011110100000111011110111101000000000011101111010000000000000001110100000000000000000000110111101111011110110000011011110111101100000000001101111011000000000000000110110000000000000000000010111101111011110111000001011110111101110000000000101111011100000000000000010111000000000000000000001001110011100111001100000100111001110011000000000010011100110000000000000001001100000000000000000000";

    string public constant FS2S1 =
        "000001111011110111100000000000111001110011100000000000011000110001100000000000001000010000100000000000000111101111000000000000000011100111000000000000000001100011000000000000000000100001000000000000000000000000111101111000000000000000011100111000000000000000001100011000000000000000000100001000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000";

    string public constant FS2S2 =
        "0000001111011110111100000000000011100111001110000000000000110001100011000000000000001000010000100000011110111101111011110000000111001110011100111000000001100011000110001100000000010000100001000010000001111011110111100000000000011100111001110000000000000110001100011000000000000001000010000100000000000111101111000000000000000001110011100000000000000000011000110000000000000000000100001000000000000000000000111101111000000000000000001110011100000000000000000011000110000000000000000000100001000000000000000000000111101111000000000000000001110011100000000000000000011000110000000000000000000100001000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000000000000000000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000000000000000000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000000000000000000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000";

    string public constant FS3S1 =
        "000001111011110111100000000000111001110011100000000000011000110001100000000000001000010000100000000000000111101111000000000000000011100111000000000000000001100011000000000000000000100001000000000000000000000000111101111000000000000000011100111000000000000000001100011000000000000000000100001000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000";

    string public constant FS3S2 =
        "1111011110111101111000000111001110011100111000000011000110001100011000000001000010000100001000000000111101111011110000000000011100111001110000000000001100011000110000000000000100001000010000000000000000000111101111011110000000000011100111001110000000000001100011000110000000000000100001000010000000001111011110000000000000000111001110000000000000000011000110000000000000000001000010000000000000000000000001111011110000000000000000111001110000000000000000011000110000000000000000001000010000000000000000000000001111011110000000000000000111001110000000000000000011000110000000000000000001000010000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000";

    string public constant FS4S1 =
        "011010110101101011010110101101011010110101101000000110101101011010000000000011010110100000000000000000101001010010100101001010010100101001010010100000001010010100101000000000000101001010000000000000000100101001010010100101001010010100101001010010000001001010010100100000000000100101001000000000000000";

    string public constant FS4S2 =
        "0000011101111011110111101000001101111011110111101100000110011100111001110010000010001100011000110001000000000011101111011110100000000001101111011110110000000000110011100111001000000000010001100011000100000000000000011101111010000000000000001101111011000000000000000110011100100000000000000010001100010000000000000000000011101000000000000000000001101100000000000000000000110010000000000000000000010001";

    string public constant FS5S1 =
        "000000111101111011110000000000001110011100111000000000000011000110001100000000000000100001000010000000000011110111100000000000000000111001110000000000000000001100011000000000000000000010000100000000000000000000011110111100000000000000000111001110000000000000000001100011000000000000000000010000100000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000000000000000000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000000000000000000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000";

    string public constant FS5S2 =
        "1111011110111101111000000111001110011100111000000011000110001100011000000001000010000100001000000000111101111011110000000000011100111001110000000000001100011000110000000000000100001000010000000000000000000111101111011110000000000011100111001110000000000001100011000110000000000000100001000010000000001111011110000000000000000111001110000000000000000011000110000000000000000001000010000000000000000000000001111011110000000000000000111001110000000000000000011000110000000000000000001000010000000000000000000000001111011110000000000000000111001110000000000000000011000110000000000000000001000010000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000";

    string public constant FS6S1 =
        "000000111101111011110000000000001110011100111000000000000011000110001100000000000000100001000010000000000011110111100000000000000000111001110000000000000000001100011000000000000000000010000100000000000000000000011110111100000000000000000111001110000000000000000001100011000000000000000000010000100000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000000000000000000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000000000000000000000000111100000000000000000000001110000000000000000000000011000000000000000000000000100000";

    string public constant FS6S2 =
        "01110011100111001110000000000001110011100111000000011100111001110000000000000000000000111001110000000000001110011100000000000011100111000000000000000000110001100011000110000000110001100011000110000000000000000000000011100000000000000000111000000000000000001110000000000000000011100000000000000000000001000010000100001000000000010000100001000010000000000100001000010000100000001000010000100000000000000010000100001000000000000000100001000010000000000000000010000100001000000000000000100001000010000000000000001000010000100000001000010000000000000000000010000100000000000000000000100001000000000000000000000010000100000000000000000000100001000000000000000000001000010000000000000000000000100001000000000000000000001000010000000000000000000010000100000001000000000000000000000000010000000000000000000000000100000000000000000000000000010000000000000000000000000100000000000000000000000001000000000000000000000000000100000000000000000000000001000000000000000000000000010000000000000000000000000001000000000000000000000000010000000000000000000000000100000001100000000000000000000000000001100000000000000000000000000001100000000000000000000000000001100000000110001100000000000000000000000110001100000000000000000000000110001100000000011000110000000000000000000000011000110000000000000000000000011000110000000110001100011000000000000000000110001100011000000000110001100011000000000000000000110001100011000000";

    string public constant FS7S1 =
        "0000011110111101111011110000000000011110111101111000000000000000011110111100000000000000000000011110000000000000000000000000000000111001110011100111000000000000111001110011100000000000000000111001110000000000000000000000111000000011000110001100011000000000000011000110001100000000000000000011000110000000000000000000000011000";

    string public constant FS7S2 =
        "1111011110111101111011110111001110011100111001110011000110001100011000110001000010000100001000010000";

    string public constant FS8S1 =
        "000000111001110011100000000000000000111001110000000000001110011100000000000000000110001100011000000000000001100011000110000000000000000000000111000000000000000001110000000000000000011100000000000000000000001000010000100000000000000010000100001000000000000000100001000010000000000001100000000000000000000000000001100000000000000000000000000001100000000000000110000000000000000000000000000110000000000000000000000000000110000000000000000010000100000000000000000000100001000000000000000000001000010000000000001000010000000000000000000010000100000000000000000000100001000000000000000001100011000000000000000000000001100011000000000000001100011000000000000000000000001100011000000000000100000000000000000000000001000000000000000000000000010000000000000000000000000001000000000000000000000000010000000000000000000000000100000000000000000000000000010000000000000000000000000100000000000000000000000001000000";

    string public constant FS8S2 =
        "000000111001110011100000000000000000111001110000000000001110011100000000000000000110001100011000000000000001100011000110000000000000000000000111000000000000000001110000000000000000011100000000000000000000001000010000100000000000000010000100001000000000000000100001000010000000000001100000000000000000000000000001100000000000000000000000000001100000000000000110000000000000000000000000000110000000000000000000000000000110000000000000000010000100000000000000000000100001000000000000000000001000010000000000001000010000000000000000000010000100000000000000000000100001000000000000000001100011000000000000000000000001100011000000000000001100011000000000000000000000001100011000000000000100000000000000000000000001000000000000000000000000010000000000000000000000000001000000000000000000000000010000000000000000000000000100000000000000000000000000010000000000000000000000000100000000000000000000000001000000";

    string public constant FS9S1 =
        "000000111001110011100111000000011100111001110000000000000000011100111001110000000111001110000000000000000000000111001110000000000000000000000111001110000000011000110001100011000000011000110001100011000000001110000000000000000000000000001110000000000000000000000000001110000000000000000000000000001110000000100001000010000100000000001000010000100001000000000010000100001000010000000000001000010000100000000000000010000100001000000000000000100001000010000000100001000010000000000000001000010000100000000000000010000100001000000000000000000000010000100000000000000000000100001000000000000000000001000010000000000001000010000000000000000000010000100000000000000000000100001000000000000100001000000000000000000001000010000000000000000000010000100000000000000000000000000000000100000000000000000000000001000000000000000000000000010000000000000000010000000000000000000000000100000000000000000000000001000000000000000001000000000000000000000000010000000000000000000000000100000000000000000100000000000000000000000001000000000000000000000000010000000000000000000000000000000000000110000000000000000001100000000000000000011000000000000000000110000000000000000000000000000000000000001100000000000000000011000000000000000000110000000000000000001100000000000000000000000000000000110001100000000000001100011000000000000011000110000000000000000000000000000011000110000000000000110001100000000000001100011000000000000000000000011000110001100000000110001100011000000000000000000011000110001100000000110001100011000000";

    string public constant FS9S2 =
        "000001111011110111100000000000111001110011100000000000011000110001100000000000001000010000100000000000000111101111000000000000000011100111000000000000000001100011000000000000000000100001000000000000000000000000111101111000000000000000011100111000000000000000001100011000000000000000000100001000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000000000000000000000001111000000000000000000000111000000000000000000000011000000000000000000000001000000000";
}
//01110011100111001110000000000001110011100111000000011100111001110000000000000000000000111001110000000000001110011100000000000011100111000000000000000000110001100011000110000000110001100011000110000000000000000000000011100000000000000000111000000000000000001110000000000000000011100000000000000000000001000010000100001000000000010000100001000010000000000100001000010000100000001000010000100000000000000010000100001000000000000000100001000010000000000000000010000100001000000000000000100001000010000000000000001000010000100000001000010000000000000000000010000100000000000000000000100001000000000000000000000010000100000000000000000000100001000000000000000000001000010000000000000000000000100001000000000000000000001000010000000000000000000010000100000001000000000000000000000000010000000000000000000000000100000000000000000000000000010000000000000000000000000100000000000000000000000001000000000000000000000000000100000000000000000000000001000000000000000000000000010000000000000000000000000001000000000000000000000000010000000000000000000000000100000001100000000000000000000000000001100000000000000000000000000001100000000000000000000000000001100000000110001100000000000000000000000110001100000000000000000000000110001100000000011000110000000000000000000000011000110000000000000000000000011000110000000110001100011000000000000000000110001100011000000000110001100011000000000000000000110001100011000000

// SPDX-License-Identifier: MIT
pragma solidity >= 0.4.22 <0.9.0;

library console {
	address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

	function _sendLogPayload(bytes memory payload) private view {
		uint256 payloadLength = payload.length;
		address consoleAddress = CONSOLE_ADDRESS;
		assembly {
			let payloadStart := add(payload, 32)
			let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
		}
	}

	function log() internal view {
		_sendLogPayload(abi.encodeWithSignature("log()"));
	}

	function logInt(int256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int256)", p0));
	}

	function logUint(uint256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
	}

	function logString(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function logBool(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function logAddress(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function logBytes(bytes memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
	}

	function logBytes1(bytes1 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
	}

	function logBytes2(bytes2 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
	}

	function logBytes3(bytes3 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
	}

	function logBytes4(bytes4 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
	}

	function logBytes5(bytes5 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
	}

	function logBytes6(bytes6 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
	}

	function logBytes7(bytes7 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
	}

	function logBytes8(bytes8 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
	}

	function logBytes9(bytes9 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
	}

	function logBytes10(bytes10 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
	}

	function logBytes11(bytes11 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
	}

	function logBytes12(bytes12 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
	}

	function logBytes13(bytes13 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
	}

	function logBytes14(bytes14 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
	}

	function logBytes15(bytes15 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
	}

	function logBytes16(bytes16 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
	}

	function logBytes17(bytes17 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
	}

	function logBytes18(bytes18 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
	}

	function logBytes19(bytes19 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
	}

	function logBytes20(bytes20 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
	}

	function logBytes21(bytes21 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
	}

	function logBytes22(bytes22 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
	}

	function logBytes23(bytes23 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
	}

	function logBytes24(bytes24 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
	}

	function logBytes25(bytes25 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
	}

	function logBytes26(bytes26 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
	}

	function logBytes27(bytes27 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
	}

	function logBytes28(bytes28 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
	}

	function logBytes29(bytes29 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
	}

	function logBytes30(bytes30 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
	}

	function logBytes31(bytes31 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
	}

	function logBytes32(bytes32 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
	}

	function log(uint256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
	}

	function log(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function log(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function log(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function log(uint256 p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256)", p0, p1));
	}

	function log(uint256 p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string)", p0, p1));
	}

	function log(uint256 p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool)", p0, p1));
	}

	function log(uint256 p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address)", p0, p1));
	}

	function log(string memory p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256)", p0, p1));
	}

	function log(string memory p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
	}

	function log(string memory p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
	}

	function log(string memory p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
	}

	function log(bool p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256)", p0, p1));
	}

	function log(bool p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
	}

	function log(bool p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
	}

	function log(bool p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
	}

	function log(address p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256)", p0, p1));
	}

	function log(address p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
	}

	function log(address p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
	}

	function log(address p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
	}

	function log(uint256 p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
	}

	function log(string memory p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256)", p0, p1, p2));
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
	}

	function log(string memory p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
	}

	function log(string memory p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
	}

	function log(bool p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256)", p0, p1, p2));
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
	}

	function log(bool p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
	}

	function log(bool p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
	}

	function log(bool p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256)", p0, p1, p2));
	}

	function log(bool p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
	}

	function log(bool p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
	}

	function log(bool p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256)", p0, p1, p2));
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
	}

	function log(address p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
	}

	function log(address p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
	}

	function log(address p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256)", p0, p1, p2));
	}

	function log(address p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
	}

	function log(address p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
	}

	function log(address p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
	}

	function log(address p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256)", p0, p1, p2));
	}

	function log(address p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
	}

	function log(address p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
	}

	function log(address p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
	}

}