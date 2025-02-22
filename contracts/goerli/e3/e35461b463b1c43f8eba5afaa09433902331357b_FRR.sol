/**
 *Submitted for verification at Etherscan.io on 2022-08-24
*/

/**
 *Submitted for verification at Etherscan.io on 2021-11-26
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.5.0;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }

    function pow(uint256 base, uint256 exponent) internal pure returns (uint256) {
        if (exponent == 0) {
            return 1;
        }
        else if (exponent == 1) {
            return base;
        }
        else if (base == 0 && exponent != 0) {
            return 0;
        }
        else {
            uint256 z = base;
            for (uint256 i = 1; i < exponent; i++)
                z = mul(z, base);
            return z;
        }
    }
}

library Roles {
    struct Role {
        mapping(address => bool) bearer;
    }

    function add(Role storage role, address account) internal {
        require(account != address(0));
        require(!has(role, account));
        role.bearer[account] = true;
    }

    function remove(Role storage role, address account) internal {
        require(account != address(0));
        require(has(role, account));
        role.bearer[account] = false;
    }

    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0));
        return role.bearer[account];
    }
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function isOwner(address account) public view returns (bool) {
        if (account == owner) {
            return true;
        }
        else {
            return false;
        }
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract AdminRole is Ownable {
    using Roles for Roles.Role;

    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    Roles.Role private _admin_list;

    constructor () internal {
        _addAdmin(msg.sender);
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender) || isOwner(msg.sender));
        _;
    }

    function isAdmin(address account) public view returns (bool) {
        return _admin_list.has(account);
    }

    function addAdmin(address account) public onlyAdmin {
        _addAdmin(account);
    }

    function removeAdmin(address account) public onlyOwner {
        _removeAdmin(account);
    }

    function renounceAdmin() public {
        _removeAdmin(msg.sender);
    }

    function _addAdmin(address account) internal {
        _admin_list.add(account);
        emit AdminAdded(account);
    }

    function _removeAdmin(address account) internal {
        _admin_list.remove(account);
        emit AdminRemoved(account);
    }
}

contract Pausable is AdminRole {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor () internal {
        _paused = false;
    }

    /**
     * @return true if the contract is paused, false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() public onlyAdmin whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyAdmin whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowed;

    uint256 private _totalSupply;

    /**
    * @dev Total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param owner The address to query the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
    * @dev Transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        emit Approval(from, msg.sender, _allowed[from][msg.sender]);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed_[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed_[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].sub(subtractedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
    * @dev Transfer token for a specified addresses
    * @param from The address to transfer from.
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "require(account != address(0)");
        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account, deducting from the sender's allowance for said account. Uses the
     * internal burn function.
     * Emits an Approval event (reflecting the reduced allowance).
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burnFrom(address account, uint256 value) internal {
        require(_allowed[account][msg.sender] > 0, "Nothing allowed.");
        _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(value);
        _burn(account, value);
        emit Approval(account, msg.sender, _allowed[account][msg.sender]);
    }
}

contract ERC20Pausable is ERC20, Pausable {
    function transfer(address to, uint256 value) public whenNotPaused returns (bool) {
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public whenNotPaused returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function approve(address spender, uint256 value) public whenNotPaused returns (bool) {
        return super.approve(spender, value);
    }

    function increaseAllowance(address spender, uint addedValue) public whenNotPaused returns (bool success) {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint subtractedValue) public whenNotPaused returns (bool success) {
        return super.decreaseAllowance(spender, subtractedValue);
    }
}

contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @return the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

contract FRR is ERC20Detailed, ERC20Pausable {
    struct LockInfo {
        uint256 _releaseTime;
        uint256 _amount;
    }

    mapping(address => LockInfo[]) public timelockList;
    mapping(address => bool) public frozenAccount;

    event Freeze(address indexed holder);
    event Unfreeze(address indexed holder);
    event Lock(address indexed holder, uint256 value, uint256 releaseTime);
    event Unlock(address indexed holder, uint256 value);

    modifier notFrozen(address _holder) {
        require(!frozenAccount[_holder], "freezing");
        _;
    }

    constructor() ERC20Detailed("Frontrow", "FRR", 18) public {
        uint256 totalSupply = SafeMath.mul(SafeMath.pow(10, decimals()), 10000000000);
        _mint(msg.sender, totalSupply);

        transfer(0x36c2946355a9eC0D322279bF788dC6C8f25cF15A, SafeMath.mul(SafeMath.pow(10, decimals()), 2250000000));
        transfer(0xC3EF77f20aeFb0cF4525f98a146c6D3460f66EB9, SafeMath.mul(SafeMath.pow(10, decimals()), 2000000000));
        transfer(0xf7277750cf08446455B3FD678F99A5e33C95157C, SafeMath.mul(SafeMath.pow(10, decimals()), 1000000000));
        transfer(0xF15b11e8FDCf33BdAE06a963fea4BB8E51129566, SafeMath.mul(SafeMath.pow(10, decimals()), 1000000000));
        transfer(0x994bf51475E05Ca6256B71E8a073c317Dc8f7ece, SafeMath.mul(SafeMath.pow(10, decimals()), 1000000000));

        transfer(0xA615053842cB8C9C18a3B5679cEAE8E9ac9079Be, SafeMath.mul(SafeMath.pow(10, decimals()), 500000000));
        transfer(0xAb5bD3428004E32Ede5eCDB42373Fa5915720f8A, SafeMath.mul(SafeMath.pow(10, decimals()), 333333333));
        transfer(0xBFBaa1Ed544D24D893DA51F36c5360290A37313b, SafeMath.mul(SafeMath.pow(10, decimals()), 166666667));
        transfer(0x43e31Ea8F0b22D465a0a65D81Dc76436B54ea502, SafeMath.mul(SafeMath.pow(10, decimals()), 166666667));
        transfer(0xF8a58eCAE5ff3685AD7a1F308e0B20d08E78C2ca, SafeMath.mul(SafeMath.pow(10, decimals()), 125000000));

        transfer(0xdB9f59dc864fC75CC450Cd9aDF43A0972Afd896b, SafeMath.mul(SafeMath.pow(10, decimals()), 125000000));
        transfer(0xa175A911bbbB56B00Db2A36BC007fbc84dc16612, SafeMath.mul(SafeMath.pow(10, decimals()), 125000000));
        transfer(0x7D72fdec94F86Ae5C1Ddb30aA81907a1D835908a, SafeMath.mul(SafeMath.pow(10, decimals()), 125000000));
        transfer(0x3c51c6d9d9cC61A82C8bd93d1ef16F60a11096C0, SafeMath.mul(SafeMath.pow(10, decimals()), 125000000));
        transfer(0x2dE2A4068b34632B0268D04a770a94e6fEEc0BC7, SafeMath.mul(SafeMath.pow(10, decimals()), 125000000));

        transfer(0x785136C221026Fec6dA31d51839c942657E4f484, SafeMath.mul(SafeMath.pow(10, decimals()), 125000000));
        transfer(0x31f3e0Ca764CDd722bfbD2D8F068f8969df56930, SafeMath.mul(SafeMath.pow(10, decimals()), 100000000));
        transfer(0x25C1cb4bcE4eb170b185BAF540FFAcaFDca61518, SafeMath.mul(SafeMath.pow(10, decimals()), 100000000));
        transfer(0x8e9F54b2A5D880DF75C9411322396BEA93E873EB, SafeMath.mul(SafeMath.pow(10, decimals()), 100000000));
        transfer(0xe71f47f6F6FEDdDaCB8293340175C63451dFb2c6, SafeMath.mul(SafeMath.pow(10, decimals()), 100000000));

        transfer(0x5f8060638DdCb51fc229638794D0397a629bc1D7, SafeMath.mul(SafeMath.pow(10, decimals()), 100000000));
        transfer(0xF36E9eDC14F5FfDc7827df7aC479b449670bd612, SafeMath.mul(SafeMath.pow(10, decimals()), 100000000));
        transfer(0x92aE72a7837e90548E9B94245bC3620A8856246C, SafeMath.mul(SafeMath.pow(10, decimals()), 100000000));
        transfer(0x0707Ce952F35331ea7b552C9226cC223414CaB55, SafeMath.mul(SafeMath.pow(10, decimals()), 8333333));
    }

    function balanceOf(address owner) public view returns (uint256) {
        uint256 unlockBalance = super.balanceOf(owner);
        uint256 lockedBalance = lockedBalanceOf(owner);
        return SafeMath.add(unlockBalance, lockedBalance);
    }

    function lockedBalanceOf(address owner) public view returns (uint256) {
        uint256 totalBalance = 0;
        if (timelockList[owner].length > 0) {
            for (uint i = 0; i < timelockList[owner].length; i++) {
                totalBalance = totalBalance.add(timelockList[owner][i]._amount);
            }
        }
        return totalBalance;
    }

    function transfer(address to, uint256 value) public notFrozen(msg.sender) returns (bool) {
        if (timelockList[msg.sender].length > 0) {
            _autoUnlock(msg.sender);
        }
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public notFrozen(from) returns (bool) {
        if (timelockList[from].length > 0) {
            _autoUnlock(from);
        }
        return super.transferFrom(from, to, value);
    }

    function freezeAccount(address holder) public onlyAdmin returns (bool) {
        require(!frozenAccount[holder]);
        frozenAccount[holder] = true;
        emit Freeze(holder);
        return true;
    }

    function unfreezeAccount(address holder) public onlyAdmin returns (bool) {
        require(frozenAccount[holder]);
        frozenAccount[holder] = false;
        emit Unfreeze(holder);
        return true;
    }

    function lock(address holder, uint256 value, uint256 releaseTime) public onlyAdmin returns (bool) {
        require(releaseTime > now, "require(releaseTime > now)");
        require(_balances[holder] >= value, "There is not enough balance of holder.");
        _lock(holder, value, releaseTime);
        return true;
    }

    function transferWithLock(address holder, uint256 value, uint256 releaseTime) public onlyAdmin returns (bool) {
        require(releaseTime > now, "require(releaseTime > now)");
        _transfer(msg.sender, holder, value);
        _lock(holder, value, releaseTime);
        return true;
    }

    function unlock(address holder, uint256 idx) public onlyAdmin returns (bool) {
        require(timelockList[holder].length > idx, "There is not lock info.");
        _unlock(holder, idx);
        return true;
    }

    function _lock(address holder, uint256 value, uint256 releaseTime) internal returns (bool) {
        _balances[holder] = _balances[holder].sub(value);
        timelockList[holder].push(LockInfo(releaseTime, value));
        emit Lock(holder, value, releaseTime);
        return true;
    }

    function _unlock(address holder, uint256 idx) internal returns (bool) {
        LockInfo storage lockinfo = timelockList[holder][idx];
        uint256 releaseAmount = lockinfo._amount;
        delete timelockList[holder][idx];
        timelockList[holder][idx] = timelockList[holder][timelockList[holder].length.sub(1)];
        timelockList[holder].length -= 1;
        emit Unlock(holder, releaseAmount);
        _balances[holder] = _balances[holder].add(releaseAmount);
        return true;
    }

    function _autoUnlock(address holder) internal returns (bool) {
        for (uint256 idx = 0; idx < timelockList[holder].length; idx++) {
            if (timelockList[holder][idx]._releaseTime <= now) {
                // If lockupinfo was deleted, loop restart at same position.
                if (_unlock(holder, idx)) {
                    idx -= 1;
                }
            }
        }
        return true;
    }

    function autoUnlock() public returns (bool) {
        if (timelockList[msg.sender].length > 0) {
            return _autoUnlock(msg.sender);
        }
        else {
            return false;
        }
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of token to be burned.
     */
    function burn(uint256 value) public notFrozen(msg.sender) {
        if (timelockList[msg.sender].length > 0) {
            _autoUnlock(msg.sender);
        }
        require(SafeMath.sub(balanceOf(msg.sender), lockedBalanceOf(msg.sender)) >= value, "not enough balance.");
        _burn(msg.sender, value);
    }

    /**
     * @dev Burns a specific amount of tokens from the target address and decrements allowance
     * @param from address The address which you want to send tokens from
     * @param value uint256 The amount of token to be burned
     */
    function burnFrom(address from, uint256 value) public notFrozen(from) {
        if (timelockList[from].length > 0) {
            _autoUnlock(from);
        }
        require(SafeMath.sub(balanceOf(msg.sender), lockedBalanceOf(msg.sender)) >= value, "not enough balance.");
        _burnFrom(from, value);
    }
}