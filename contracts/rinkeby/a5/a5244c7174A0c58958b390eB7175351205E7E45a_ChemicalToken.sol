// demo 友和、陶瑞

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ChemicalToken is Ownable {
    // 交易資料上鏈的同時？去觸發 token的 transfer （由合約收發幣）
    mapping(address => uint256) private _balances;

    string private _name;
    string private _symbol;

    // uint256 private _totalSupply;

    event mintBehavior(
        string transacBehavior,
        address indexed toAccount,
        uint256 indexed chemicalAmount
    );
    event transBehavior(
        string transacBehavior,
        address indexed toAccount,
        uint256 indexed chemicalAmount
    );

    // constructor() ERC20("4Ethoxyphenyl", "4Ethoxy") {}

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;

        _mint(msg.sender, 1000000 * 10**17, "constructor"); //just in case
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 17; //20-3
    }

    function _mint(
        address account,
        uint256 amount,
        string memory behavior
    ) internal virtual {
        // _totalSupply += amount;
        _balances[account] += amount;
        emit mintBehavior(behavior, account, amount);
    }

    function _transfer(
        address account,
        uint256 amount,
        string memory behavior
    ) internal virtual {
        require(
            _balances[account] >= amount,
            "invalid quantity (not enough in balance)"
        );
        unchecked {
            //"unchecked" exists in order to save gas
            _balances[account] -= amount;
        }
        emit transBehavior(behavior, account, amount);
    }

    function product(address account, uint256 amount) external onlyOwner {
        _mint(account, amount, "production");
    }

    function useage(address account, uint256 amount) external onlyOwner {
        _transfer(account, amount, "useage");
    }

    function importc(address account, uint256 amount) external onlyOwner {
        _mint(account, amount, "import");
    }

    function export(address account, uint256 amount) external onlyOwner {
        _transfer(account, amount, "export");
    }

    function purchase(address account, uint256 amount) external onlyOwner {
        _mint(account, amount, "purchase");
    }

    function sell(address account, uint256 amount) external onlyOwner {
        _transfer(account, amount, "sell");
    }

    function transAdd(address account, uint256 amount) external onlyOwner {
        _mint(account, amount, "transAdd");
    }

    function transSub(address account, uint256 amount) external onlyOwner {
        _transfer(account, amount, "tranSub");
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }
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