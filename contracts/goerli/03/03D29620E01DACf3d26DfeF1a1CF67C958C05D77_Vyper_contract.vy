# @version 0.3.1

"""
@title Curve LP Token
@author Curve.Fi
@notice Base implementation for an LP token provided for
        supplying liquidity to `StableSwap`
@dev Follows the ERC-20 token standard as defined at
     https://eips.ethereum.org/EIPS/eip-20
"""

from vyper.interfaces import ERC20

implements: ERC20


interface Curve:
    def owner() -> address: view


event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256


event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256


event SetName:
    old_name: String[64]
    old_symbol: String[32]
    name: String[64]
    symbol: String[32]
    owner: address
    time: uint256


name: public(String[64])
symbol: public(String[32])

balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])
totalSupply: public(uint256)

minter: public(address)


@external
def __init__(_name: String[64], _symbol: String[32]):
    self.name = _name
    self.symbol = _symbol
    self.minter = msg.sender
    log Transfer(empty(address), msg.sender, 0)


@view
@external
def decimals() -> uint256:
    """
    @notice Get the number of decimals for this token
    @dev Implemented as a view method to reduce gas costs
    @return uint256 decimal places
    """
    return 18


@external
def transfer(_to: address, _value: uint256) -> bool:
    """
    @dev Transfer token for a specified address
    @param _to The address to transfer to.
    @param _value The amount to be transferred.
    """
    # NOTE: vyper does not allow underflows
    #       so the following subtraction would revert on insufficient balance
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value

    log Transfer(msg.sender, _to, _value)
    return True


@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    """
    @dev Transfer tokens from one address to another.
    @param _from address The address which you want to send tokens from
    @param _to address The address which you want to transfer to
    @param _value uint256 the amount of tokens to be transferred
    """
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value

    _allowance: uint256 = self.allowance[_from][msg.sender]
    # kjill fix
    max_value:uint256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935
    # if _allowance != max_value(uint256):
    if _allowance != max_value:

        self.allowance[_from][msg.sender] = _allowance - _value

    log Transfer(_from, _to, _value)
    return True


@external
def approve(_spender: address, _value: uint256) -> bool:
    """
    @notice Approve the passed address to transfer the specified amount of
            tokens on behalf of msg.sender
    @dev Beware that changing an allowance via this method brings the risk
         that someone may use both the old and new allowance by unfortunate
         transaction ordering. This may be mitigated with the use of
         {increaseAllowance} and {decreaseAllowance}.
         https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will transfer the funds
    @param _value The amount of tokens that may be transferred
    @return bool success
    """
    self.allowance[msg.sender][_spender] = _value

    log Approval(msg.sender, _spender, _value)
    return True


@external
def increaseAllowance(_spender: address, _added_value: uint256) -> bool:
    """
    @notice Increase the allowance granted to `_spender` by the caller
    @dev This is alternative to {approve} that can be used as a mitigation for
         the potential race condition
    @param _spender The address which will transfer the funds
    @param _added_value The amount of to increase the allowance
    @return bool success
    """
    allowance: uint256 = self.allowance[msg.sender][_spender] + _added_value
    self.allowance[msg.sender][_spender] = allowance

    log Approval(msg.sender, _spender, allowance)
    return True


@external
def decreaseAllowance(_spender: address, _subtracted_value: uint256) -> bool:
    """
    @notice Decrease the allowance granted to `_spender` by the caller
    @dev This is alternative to {approve} that can be used as a mitigation for
         the potential race condition
    @param _spender The address which will transfer the funds
    @param _subtracted_value The amount of to decrease the allowance
    @return bool success
    """
    allowance: uint256 = (
        self.allowance[msg.sender][_spender] - _subtracted_value
    )
    self.allowance[msg.sender][_spender] = allowance

    log Approval(msg.sender, _spender, allowance)
    return True


@external
def mint(_to: address, _value: uint256) -> bool:
    """
    @dev Mint an amount of the token and assigns it to an account.
         This encapsulates the modification of balances such that the
         proper events are emitted.
    @param _to The account that will receive the created tokens.
    @param _value The amount that will be created.
    """
    assert msg.sender == self.minter

    self.totalSupply += _value
    self.balanceOf[_to] += _value

    log Transfer(empty(address), _to, _value)
    return True


@external
def mint_relative(_to: address, frac: uint256) -> uint256:
    """
    @dev Increases supply by factor of (1 + frac/1e18) and mints it for _to
    """
    assert msg.sender == self.minter

    supply: uint256 = self.totalSupply
    d_supply: uint256 = supply * frac / 10**18
    if d_supply > 0:
        self.totalSupply = supply + d_supply
        self.balanceOf[_to] += d_supply
        log Transfer(empty(address), _to, d_supply)

    return d_supply


@external
def burnFrom(_to: address, _value: uint256) -> bool:
    """
    @dev Burn an amount of the token from a given account.
    @param _to The account whose tokens will be burned.
    @param _value The amount that will be burned.
    """
    assert msg.sender == self.minter

    self.totalSupply -= _value
    self.balanceOf[_to] -= _value

    log Transfer(_to, empty(address), _value)
    return True


@external
def set_minter(_minter: address):
    assert msg.sender == self.minter
    self.minter = _minter


@external
def set_name(_name: String[64], _symbol: String[32]):
    assert Curve(self.minter).owner() == msg.sender
    old_name: String[64] = self.name
    old_symbol: String[32] = self.symbol
    self.name = _name
    self.symbol = _symbol

    log SetName(
        old_name, old_symbol, _name, _symbol, msg.sender, block.timestamp
    )