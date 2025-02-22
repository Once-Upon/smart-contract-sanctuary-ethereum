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
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title An ICO Contract that distributes the token among public if the preSale is active
 * buyers are divided into whitelist users & common public
 */
contract ICO is Ownable {
    /// @dev store the total supply of token in this variable
    uint256 public totalSupply;
    /// @dev store the start time of preSale in the variable
    uint256 public startTime;
    /// @dev store the wallet owner's address in this variable, this address will release funds
    address payable ownerWallet;

    /// @dev store the trade rate at which tokens will be given to whitelist & common users
    uint256 foundersProfitRate = 5;
    uint256 crowdSaleProfitRate = 2;

    /// @dev Pass the address of the token Contract you want to transfer tokens from
    IERC20 token;

    /// @dev this variable stores the total amount of funds collected by trading tokens
    uint256 public fundsRaised;

    /**
     * @notice this modifier only lets the buyers buy tokens when preSale is active
     */
    modifier preSaleActive() {
        require(block.timestamp < startTime + 5000, "PreSale is ended");
        _;
    }

    /// @notice notifies who invested how much
    event fundsRecieved(address investor, uint256 amount);
    /// @notice notifies if the investor has collected his profit or not
    event profitCollected(address investor, uint256 profitAmount);

    /** @dev Deploy the token contract before this one
     *@dev set wallet of `msg.sender` as the owner's wallet
     * @dev sets totalSupply of token from the user
     * @notice this will check if zero address is passed as the owner of the contract
     **/
    constructor(
        address payable _ownerWallet,
        IERC20 _token,
        uint256 _totalSupply
    ) {
        require(_ownerWallet != address(0));

        startTime = block.timestamp;
        ownerWallet = _ownerWallet;
        token = _token;
        totalSupply = _totalSupply;
    }

    /** @notice this will store the total number of available public tokens & tokens reserved for founders
     **/
    uint256 publicTokens;
    uint256 founderTokens;

    /**
     * @dev getTotalPublicTokens function returns the total number of tokens reserved for public
     */
    function getTotalPublicTokens() public returns (uint256) {
        publicTokens = (totalSupply / 100) * 75;
        return publicTokens;
    }

    uint256 max = getTotalPublicTokens();

    /**
     * @dev getTotalFounderTokens function returns the total number of tokens reserved for founders
     */
    function getTotalFounderTokens() public returns (uint256) {
        founderTokens = (totalSupply / 100) * 25;
        return founderTokens;
    }

    /**
     * @dev getAvailablePercentageOfFounderTokens function returns the total number of tokens reserved
     * for founders for the given time frame
     */
    function getAvailablePercentageOfFounderTokens() public returns (uint256) {
        uint256 developerTokens;

        if (block.timestamp <= startTime + 500) {
            developerTokens = (getTotalFounderTokens() / 100) * 20;  
        } else if (block.timestamp <= startTime + 1000) {
            developerTokens = (getTotalFounderTokens() / 100) * 40;
        } else {
            developerTokens = (getTotalFounderTokens() / 100) * 40;
        }
        return developerTokens;
    }

    /**
     * @dev getAvailablePercentageOfPublicTokens function returns the total number of tokens reserved for public
     * for the given time frame
     */
    function getAvailablePercentageOfPublicTokens() public returns (uint256) {
        uint256 commonTokens;

        if (block.timestamp <= startTime + 500) {
            commonTokens = (getTotalPublicTokens() / 100) * 20;
        } else if (block.timestamp < startTime + 1000) {
            commonTokens = (getTotalPublicTokens() / 100) * 40;
        } else {
            commonTokens = (getTotalPublicTokens() / 100) * 40;
        }
        return commonTokens;
    }

    /// funds invested by each investor are saved against their addresses
    mapping(address => uint256) fundsInvested;
    /// profit due for each investor is saved against their addresses
    mapping(address => uint256) profitDue;
    /// all the investor addresses are saved in this array
    address[] public whitelistInvesters;

    /**
     * @dev addWhitelistInvester function adds the whitelist user
     * @notice this function can only be called by the owner of this contract
     */
    function addWhitelistInvester(address investor) public onlyOwner {
        whitelistInvesters.push(investor);
    }

    /**
     * @dev invest function  adds the wlets the investor invest his funds in the ICO
     * @notice this function can only be called if the preSale is active
     * @notice before investing, this function checks if the invested amount is greater than zero
     * @notice this function seperately calculates the profit for whitelist admins & public investors
     */
    function invest() public payable preSaleActive {
        require(msg.value > 0);
        fundsInvested[msg.sender] = msg.value;

        ownerWallet.transfer(msg.value);

        fundsRaised += msg.value;

        uint256 profit;

        for (uint256 i = 0; i < whitelistInvesters.length; i++) {
            if (whitelistInvesters[i] == msg.sender) {
                profit = msg.value * foundersProfitRate;
            } else {
                profit = msg.value * crowdSaleProfitRate;
            }
        }

        profitDue[msg.sender] = profit;
        emit fundsRecieved(msg.sender, msg.value);
    }

    /**
     * @dev collectProfit function lets the investor collect profit for the funds they invested
     * @notice this function checks if the msg.sender is even an investor or not
     * @notice before transferring the profit, it checks if the available supply of tokens for both(whitelist admins & public)
     * is exceeded or not
     */
    function collectProfit() public payable {
        require(fundsInvested[msg.sender] != 0, "You are not an investor");

        uint256 transferableTokens;
        for (uint256 i = 0; i < whitelistInvesters.length; i++) {
            if (whitelistInvesters[i] == msg.sender) {
                require(
                    profitDue[msg.sender] <=
                        getAvailablePercentageOfFounderTokens(),
                    "Not enough tokens left to award, Please wait for the next phase."
                );
                transferableTokens = profitDue[msg.sender];
                founderTokens -= transferableTokens;
            } else {
                require(
                    profitDue[msg.sender] <=
                        getAvailablePercentageOfPublicTokens(),
                    "Not enough tokens left to award, Please wait for the next phase."
                );
                transferableTokens = profitDue[msg.sender];
                publicTokens -= transferableTokens;
            }
        }

        token.transfer(msg.sender, transferableTokens);
        emit profitCollected(msg.sender, transferableTokens);
    }
}