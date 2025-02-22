//SPDX-License-Identifier: MIT

// this will be upgraded for new roles and procedures
// principles: minimize memory storage, breakdown a complex on-chain action to several short actions
// roles: borrower, liquidator, inspector, validator(about price info.)
//      inspector should be the owner of the contract, sometimes as liquidator
//      validator acts as priceFeed Aggregator, when expired highest quote one of them
//      can change into liquidator when they deposit the quoteAmount (internal)
// Must functions: connectWallet, showLoanableNFT, setBasePrice(real fp deal in 14days), setThreshold(e.g., 60%on base price),
//                 autoGenOffers(3 offers: amount[100,80,60], period[3,7,14], APR[80,100,120], +some random disturbation),
//                 manGenOffers(amount, period, APR, ),
//                 updateOffers(offerIndex, update=0:del/1:update/2)
//                 acceptOffer(approveTransfer, nftDeposit,loanTransfer)
// Later functions: getPrice, showOffers, makeOffers, approve,sendOffers(by validators)
// objects: offer{evalAmount, loanPeriod, interest}
// Global array: arrPeriod[3,7,14], arrAPR, arrLoanRatio
// randome value: randDeltaAPR,randDeltaLoanRatio
// Global mappings will be used:
//      nftAddr->nftID->{ownerAddress, interest, repayAmount, loanTime{initTime, period, expireTime}}
//      liquidatorAddr->depositLiquid (pre-deposited amount of liquidator)
// Must check after repay & before return NFTs: ownerAddress, repayAmount, time
// after loan: ownerAddress should be updated to borrower address
// after expiration: ownerAddress should be updated to liquidator address
// ? how to get rarity info. then corresponding evalPrice -> metadata
// ? how to achieve bundle or reduce gas fee
//
pragma solidity ^0.8.0;

import "Ownable.sol";
import "IERC721.sol";
import "IERC20.sol";
import "AggregatorV3Interface.sol";

contract Escrow is Ownable {
    address[] public allowedNfts;
    address public lender;
    address public inspector;
    mapping(address => address) public nftPriceFeedMapping;

    IERC20 public dappToken;
    IERC20 public loanToken;

    struct addressId {
        address _nftAddress;
        uint256 _nftId;
    }
    struct loanOffer {
        uint256 _loanAmount; //18 decimals in ether(wei)
        uint256 _loanDays; // in days
        uint256 _loanInterest; //with decimals 10**4, e.g. 2.83% = 283/(10**4)
    }
    uint256 interestDecimals = 4;
    struct nftLockParameters {
        uint256 _repayAmount; //18 decimals in ether(wei)
        // uint256 _lockInitTime; // in seconds
        uint256 _expireTime; // in seconds
        address _holderAddress;
    }
    // mapping borrower address -> borrower stake index -> staked NFT address and ID
    mapping(address => mapping(uint256 => addressId)) public stakedNftAddressId;
    mapping(address => uint256) numOfNftStaked;
    address[] public borrowers;
    // mapping nft address -> nft id -> {priceFeed, loanPeriod, repayAmount, holderAddress}
    mapping(address => mapping(uint256 => nftLockParameters)) nftLoanLockData;

    constructor(address _dappTokenAddress, address _loanTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
        loanToken = IERC20(_loanTokenAddress);
    }

    function nftUnStaking(address _nftAddress, uint256 _nftId)
        public
        onlyBorrower
    {
        // must satisfy:
        // 1. time not expire,
        // 2. repay enough,
        // 3. the owner is the owner
    }

    function loanTransfer(address _nftHolderAddress, uint256 _loanAmount)
        public
        onlyOwner
    {
        // is onlyOwner used here correct?
        loanToken.transfer(_nftHolderAddress, _loanAmount);
    }

    function nftStaking(address _nftAddress, uint256 _nftId) public {
        // what NFT can they stake?
        require(
            nftIsAllowed(_nftAddress),
            "current nft is not allowed in our whitelist!"
        );
        IERC721(_nftAddress).transferFrom(msg.sender, address(this), _nftId);
        stakedNftAddressId[msg.sender][numOfNftStaked[msg.sender]]
            ._nftAddress = _nftAddress;
        stakedNftAddressId[msg.sender][numOfNftStaked[msg.sender]]
            ._nftId = _nftId;
        if (numOfNftStaked[msg.sender] == 0) {
            borrowers.push(msg.sender);
        }
        numOfNftStaked[msg.sender] = numOfNftStaked[msg.sender] + 1;
    }

    function nftLock(
        address _nftAddress,
        uint256 _nftId,
        address _holderAddress,
        uint256 _expireTime,
        uint256 _repayAmount
    ) internal {
        // nft lock parameters setting, is the function public ok?
        nftLoanLockData[_nftAddress][_nftId]._holderAddress = _holderAddress;
        nftLoanLockData[_nftAddress][_nftId]._expireTime = _expireTime;
        nftLoanLockData[_nftAddress][_nftId]._repayAmount = _repayAmount;
    }

    function getNftLockData(address _nftAddress, uint256 _nftId)
        public
        view
        returns (
            address,
            uint256,
            uint256
        )
    {
        return (
            nftLoanLockData[_nftAddress][_nftId]._holderAddress,
            nftLoanLockData[_nftAddress][_nftId]._expireTime,
            nftLoanLockData[_nftAddress][_nftId]._repayAmount
        );
    }

    function requestLoan(
        address _nftAddress,
        uint256 _nftId,
        uint256 _loanAmount,
        uint256 _loanDays,
        uint256 _loanInterest
    ) public {
        require(
            nftIsAllowed(_nftAddress),
            "current nft is not allowed in our whitelist!"
        );
        nftStaking(_nftAddress, _nftId);
        loanTransfer(address(msg.sender), _loanAmount);
        uint256 initTime = block.timestamp;
        uint256 expireTime = initTime + _loanDays * 24 * 60 * 60;
        uint256 repayAmount = _loanAmount *
            (1 + _loanInterest / (10**interestDecimals));
        nftLock(
            _nftAddress,
            _nftId,
            address(msg.sender),
            expireTime,
            repayAmount
        );
    }

    function addAllowedNfts(address _nftAddress) public onlyOwner {
        allowedNfts.push(_nftAddress);
    }

    function nftIsAllowed(address _nftAddress) public view returns (bool) {
        for (
            uint256 allowedNftsIndex = 0;
            allowedNftsIndex < allowedNfts.length;
            allowedNftsIndex++
        ) {
            if (allowedNfts[allowedNftsIndex] == _nftAddress) {
                return true;
            }
        }
        return false;
    }

    modifier onlyLender() {
        require(msg.sender == lender, "Only lender can call this method");
        _;
    }

    function isBorrowers(address _user) public view returns (bool) {
        for (uint256 index = 0; index < allowedNfts.length; index++) {
            if (borrowers[index] == _user) {
                return true;
            }
        }
        return false;
    }

    modifier onlyBorrower() {
        require(isBorrowers(msg.sender), "Only borrower can call this method");
        _;
    }

    modifier onlyInspector() {
        require(msg.sender == inspector, "Only inspector can call this method");
        _;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // e.g.: give 1 DappToken per loanToken loan
    function issueTokens() public onlyOwner {
        // ? get each borrower total loan interest profit
        // ? get each NFT (address, id) loaned interest profit
        // Issue tokens to all stakers
        for (
            uint256 borrowersIndex = 0;
            borrowersIndex < borrowers.length;
            borrowersIndex++
        ) {
            address recipient = borrowers[borrowersIndex];
            uint256 userTotalValue = getUserTotalValue(recipient);
            dappToken.transfer(recipient, userTotalValue);
        }
    }

    function getUserTotalValue(address _user) public view returns (uint256) {
        uint256 totalValue = 0;
        // require(numOfNftStaked[_user] > 0, "No nft staked!");
        if (numOfNftStaked[_user] <= 0) {
            return 0;
        }
        for (
            uint256 nftStakedIndex = 0;
            nftStakedIndex < numOfNftStaked[_user];
            nftStakedIndex++
        ) {
            totalValue =
                totalValue +
                getUserSingleNftValue(
                    _user,
                    stakedNftAddressId[_user][nftStakedIndex]._nftAddress,
                    stakedNftAddressId[_user][nftStakedIndex]._nftId
                );
        }
        return totalValue;
    }

    function getUserSingleNftValue(
        address _user,
        address _nftAddress,
        uint256 _nftId
    ) public view returns (uint256) {
        if (numOfNftStaked[_user] <= 0) {
            return 0;
        }
        (uint256 price, uint256 decimals) = getNftValue(_nftAddress, _nftId);
        return (price / (10**decimals));
        // 10000000000000000000 ETH
        // ETH/USD -> 10000000000
        // 10 * 100 = 1,000
    }

    function getNftValue(address _nftAddress, uint256 _nftId)
        public
        view
        returns (uint256, uint256)
    {
        // // default setted to 1ETH and 18decimals
        // return (1, 18);

        // priceFeedAddress
        // address priceFeedAddress = nftPriceFeedMapping[_nftAddress][_nftId];
        address priceFeedAddress = nftPriceFeedMapping[_nftAddress];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = uint256(priceFeed.decimals());
        return (uint256(price), decimals);
    }

    function setPriceFeedContract(
        address _nftAddress,
        // uint256 _nftId=none,
        address _priceFeed
    ) public onlyOwner {
        // nftPriceFeedMapping[_nftAddress][_nftId] = _priceFeed;
        nftPriceFeedMapping[_nftAddress] = _priceFeed;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "Context.sol";

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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "IERC165.sol";

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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}