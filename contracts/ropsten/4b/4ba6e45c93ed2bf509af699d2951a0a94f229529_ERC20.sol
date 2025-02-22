/**
 *Submitted for verification at Etherscan.io on 2022-02-18
*/

// SPDX-License-Identifier: MIT

pragma solidity = 0.8.12;

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string public name = "TemplateToken";
    string public symbol = "TPT-003";
    uint8 public decimals = 18;

    mapping(address => address) public recommenderMap;

    address public market = 0x4548943a228f401366e5F7F7ACfcCb1372cBcCc2;
    address public marketing = 0x92D7d64cec0aD3b2Ebf1A5D5c4cacfc9a7A06Cd3;

    uint8 marketRate = 10;
    uint8 marketingRate = 10;
    uint8 lpRate = 10;
    uint8 lpShareRate = 20;
    uint8 burnRate = 10;
    uint8[] bonusRate = [20, 5, 5, 4, 4, 4, 4, 4];

    constructor() {
        _mint(_msgSender(), 6000000 * 10 ** decimals);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        _balances[from] = fromBalance - amount;

        // 保存推荐关系
        _saveRecommender(from, to);

        // 扣费
        uint256 finalAmount = _countFee(from, amount);

        _balances[to] += finalAmount;

        emit Transfer(from, to, finalAmount);
    }

    function _mint(address account, uint256 amount) private {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;

        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) private {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) private {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");

             _approve(owner, spender, currentAllowance - amount); 
        }
    }

    function _saveRecommender(address from, address to) private {
        if (_balances[to] != 0 || recommenderMap[to] != address(0)) {
            return;
        }

        if (Address.isContract(from)
            || Address.isContract(to)
            || from == address(0)
            || to == address(0)) {
            return;
        }

        recommenderMap[to] = from;
    }

    function _countFee(address from, uint256 amount) private returns(uint256 finalAmount) {
        uint256 marketFee = amount * marketRate / 1000;
        uint256 marketingFee = amount * marketingRate / 1000;
        uint256 lpFee = amount * lpRate / 1000;
        uint256 lpShareFee = amount * lpShareRate / 1000;
        uint256 burnFee = amount * burnRate / 1000;

        (uint256 level, uint256 totalRate) = _countBonusLevel();
        uint256 bonusFee = amount * totalRate / 1000;
        finalAmount = amount - marketFee - marketingFee - lpFee - lpShareFee - burnFee - bonusFee;

        address recommender = recommenderMap[from];
        for (uint256 i ; i < level && recommender != address(0) ; i++) {
            uint256 bonus = amount * bonusRate[i] / 1000;
            _addBalance(from, recommender, bonus);
            bonusFee -= bonus;

            recommender = recommenderMap[recommender];
        }

        _addBalance(from, market, marketFee + bonusFee);
        _addBalance(from, marketing, marketingFee);
        _addBalance(from, address(this), lpFee + lpShareFee);
        
        _totalSupply -= burnFee;
        emit Transfer(from, address(0), burnFee);
    }

    function _countBonusLevel() private view returns(uint256 level, uint256 totalRate) {
        uint256 l;
        for (uint256 i ; i < bonusRate.length ; i++) {
            if (bonusRate[i] > 0) {
                l = 0;
            } else {
                l++;
            }

            totalRate += bonusRate[i];
        }

        level = bonusRate.length - l;
    }

    function _addBalance(address from, address to, uint256 amount) private {
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }
}