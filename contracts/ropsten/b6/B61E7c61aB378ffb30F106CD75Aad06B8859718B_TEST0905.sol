/**
 *Submitted for verification at Etherscan.io on 2022-09-05
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

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
}

interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

contract Lockable is Context {
    event Locked(address account);
    event Unlocked(address account);

    event Freezed();
    event UnFreezed();

    bool public _freezed;
    mapping(address => bool) private _locked;

    modifier validFreeze {
        require(_freezed == false, "ERC20: all token is freezed");
        _;
    }

    function _freeze() internal virtual {
        _freezed = true;
        emit Freezed();
    }

    function _unfreeze() internal virtual {
        _freezed = false;
        emit UnFreezed();
    }

    function locked(address _to) public view returns (bool) {
        return _locked[_to];
    }

    function _lock(address to) internal virtual {
        require(to != address(0), "ERC20: lock to the zero address");

        _locked[to] = true;
        emit Locked(to);
    }

    function _unlock(address to) internal virtual {
        require(to != address(0), "ERC20: lock to the zero address");

        _locked[to] = false;
        emit Unlocked(to);
    }
}

contract ERC20Base is Context, ERC20, Ownable, Lockable {
    using SafeMath for uint256;

    uint8 public taxFee = 5; // 5% burn fee

    address payable public _Owner;

    // function to adjust the burn fee
    function setTaxFee(uint8 _taxFee) public {
        require(_taxFee <= 100, "ERC20: tax fee must be less than 100%");
        taxFee = _taxFee;
    }

     // Info of each pool.
    struct LockInfo {
        uint256 total;
        uint256 currentTime; // this is the current time of the block.timestamp
        uint256 releaseAmount;
        uint256 duration; // duration is in seconds .
    }

    mapping (address => LockInfo) private _lockInfos; // lock info of each pool
    mapping (address => bool) public _manualEntity;

       mapping (address => bool) private _isExcludedFromTax;

    string internal constant TOKEN_LOCKED = "ERC20: Tokens is locked";

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_){
        _Owner = payable(_msgSender());
        _isExcludedFromTax[_Owner] = true;
        _isExcludedFromTax[address(this)] = true;
    }

    function excludeFromTax(address account) public onlyOwner {
        _isExcludedFromTax[account] = true;
    }

        function includeInTax(address account) public onlyOwner {
        _isExcludedFromTax[account] = false;
    }

    function mint(address account, uint256 amount) internal virtual onlyOwner {
        _mint(account, amount);
    }

    /**
    @dev burn tokens from the owner's account
    @param amount amount of tokens to burn
    @return true if success
     */
    function burn(uint256 amount) internal returns(bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    /**
    @dev burn tokens when the owner have given allowance to the spender
    @param account spender address
    @param amount amount of tokens to burn
    @return true if success
     */
    function burnFrom(address account, uint256 amount) public returns (bool) {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
        return true;
    }

    function allFreeze() public onlyOwner {
        _freeze();
    }

    function allUnFreeze() public onlyOwner {
        _unfreeze();
    }

    function lock(address to) public onlyOwner {
        _lock(to);
    }

    function unlock(address to) public onlyOwner {
        _unlock(to);
    }


    function tokensLockedAtTime(address to, uint256 amountToBeLocked, uint256 currenttime, uint256 duration) public onlyOwner {
        require(to != address(0), "ERC20: lock to the zero address");
        require(amountToBeLocked > 0, "ERC20: amount is over zero");
        require(currenttime > block.timestamp, "currentTime Should be greater than unixtime by 50 seconds or greater");
        require(amountToBeLocked <= balanceOf(to), "TimeLock: lock time amount exceeds balance");

        uint amountToBeReleased = amountToBeLocked;

        bool isEntity = _manualEntity[to];
        if(!isEntity) {
            _manualEntity[to] = true;
            _lockInfos[to] = LockInfo(amountToBeLocked, currenttime, amountToBeReleased, duration); // duration is in seconds as block.timestamp is in seconds it can be off sometimes by 50 seconds or so. 
        }
    }

    function getTokensLockedInfo(address to) public view returns(LockInfo memory) {
        require(to != address(0), "ERC20: lock to the zero address");
        bool isEntity = _manualEntity[to];
        require(isEntity == true, "TimeLock: There is not lockinfo");
        
        return _lockInfos[to];
    }

    function transferFrom(address from,
        address to,
        uint256 amount
    ) public 
    validFreeze 
    virtual override returns (bool) { 
        require(locked(from) == false, TOKEN_LOCKED);

        bool isEntity = _manualEntity[from];
        if(isEntity) {

            LockInfo storage li = _lockInfos[from];
            require(li.releaseAmount >= amount, "TimeLock : Please check release amount");
        }

        bool rst = _TransferFrom(from, to, amount);
        if(!rst) {
            revert();
        }

        if(isEntity) {
            LockInfo storage li = _lockInfos[msg.sender];
            li.releaseAmount -= amount;
        }

        return rst;
    }

    function transfer(address to, uint256 amount) 
    public
    validFreeze 
    virtual override returns (bool) {
        require(locked(msg.sender) == false, TOKEN_LOCKED);

        bool isEntity = _manualEntity[msg.sender];
        if(isEntity) {

            LockInfo storage li = _lockInfos[msg.sender];
            require(li.releaseAmount >= amount, "TimeLock : Please check release amount");
        }

        bool rst = _Transfer(to, amount);
        if(!rst) {
            revert();
        }

        if(isEntity) {
            LockInfo storage li = _lockInfos[msg.sender];
            li.releaseAmount -= amount;
        }

        return rst;
    }

  // a function for transfering tax fees from every transaction to owner address
    function _transferTaxfee(uint256 _taxFeeAmount) internal {   
            address owner = _Owner;
            _transfer(msg.sender, owner , _taxFeeAmount);
        }


    /**
    @dev transfer tokens from the owner's account to another account
    @dev burntAmount is the amount of tokens to burn
     */
     function _Transfer(address to, uint256 amount) internal returns (bool) {
        if(_isExcludedFromTax[msg.sender] == true) {
            _transfer(_msgSender(), to, amount);
        } else {
            uint taxAmount = amount.mul(taxFee) / 100;
            _transferTaxfee(taxAmount);
            _transfer(_msgSender(), to, amount.sub(taxAmount));
        }
        return true;
    }

    function _TransferFrom(address from, address to, uint256 amount) internal returns (bool) {
        if(_isExcludedFromTax[msg.sender] == true) {
            _spendAllowance(from, msg.sender, amount);
            _transfer(_msgSender(), to, amount);
        } else {
            uint taxAmount = amount.mul(taxFee) / 100;
            _transferTaxfee(taxAmount);
            _spendAllowance(from, msg.sender, amount);
            _transfer(from, to, amount.sub(taxAmount));
        }
        return true;
    }

  //A function to withdraw tokens from the contract
    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance); //transfer all the tokens to the sender
        IERC20(address(this)).transfer(msg.sender, IERC20(address(this)).balanceOf(address(this))); // IERC20(address(this)).balanceOf(address(this)) is the balance of the contract itself, AND IT IS NOT THE BALANCE OF THE OWNER, so we are transferring the balance of the contract to the owner
    }


}

contract TEST0905 is ERC20Base {
    constructor() ERC20Base("TEST0905", "T0905") {
        mint(msg.sender, 100*(10**8)*(10**uint256(decimals())));
    }

    /** Additional Issuance 
    @dev mint tokens from the owner's account
    @param amount amount of tokens to mint
     */
    function _mint(uint256 amount) public onlyOwner { // write amount in wei, it is the Standard Unit of ethereum
        mint(msg.sender, amount*(10**uint256(decimals()))); // 1 Ether = 1,000,000,000,000,000,000 WEI = 10**18
    }

}