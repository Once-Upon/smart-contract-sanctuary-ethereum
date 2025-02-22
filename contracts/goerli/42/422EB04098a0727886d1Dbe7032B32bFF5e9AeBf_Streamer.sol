// SPDX-License-Identifier: MIT

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
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

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
pragma solidity >=0.7.0 <=0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Streamer is Ownable {
    struct Voucher {
        uint256 updatedBalance;
        Signature sig;
    }
    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    mapping(address => uint256) balances;
    mapping(address => uint256) canCloseAt;

    event Opened(address, uint256);
    event Challenged(address);
    event Withdrawn(address, uint256);
    event Closed(address);

    function fundChannel() public payable {
        require(balances[msg.sender] == 0, "You have a running channel");
        balances[msg.sender] = msg.value;
        emit Opened(msg.sender, msg.value);
    }

    function timeLeft(address channel) public view returns (uint256) {
        require(canCloseAt[channel] != 0, "channel is not closing");
        return canCloseAt[channel] - block.timestamp;
    }

    function withdrawEarnings(Voucher calldata voucher) public onlyOwner {
        bytes32 hashed = keccak256(abi.encode(voucher.updatedBalance));

        bytes memory prefixed = abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            hashed
        );
        bytes32 prefixedHashed = keccak256(prefixed);

        address signer = ecrecover(
            prefixedHashed,
            voucher.sig.v,
            voucher.sig.r,
            voucher.sig.s
        );

        require(
            balances[signer] > voucher.updatedBalance,
            "The channel isn't running"
        );
        uint256 payment = balances[signer] - voucher.updatedBalance;
        balances[signer] = payment;

        payable(signer).transfer(voucher.updatedBalance);

        emit Withdrawn(signer, payment);
    }

    function challengeChannel() public {
        require(balances[msg.sender] != 0, "Don't have running channel");
        canCloseAt[msg.sender] = block.timestamp + 30 seconds;

        emit Challenged(msg.sender);
    }

    function defundChannel() public {
        require(canCloseAt[msg.sender] != 0, "You have running channels");
        require(
            block.timestamp > canCloseAt[msg.sender],
            "cannot change the channel yet"
        );
        uint256 withdraw = balances[msg.sender];
        balances[msg.sender] = 0;

        (bool sent, ) = payable(msg.sender).call{value: withdraw}("");
        require(sent);

        emit Closed(msg.sender);
    }
}