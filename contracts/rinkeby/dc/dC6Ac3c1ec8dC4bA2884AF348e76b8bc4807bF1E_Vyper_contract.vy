# @version 0.2.16
"""
@title Vesting Escrow Factory
@author Curve Finance, Yearn Finance
@license MIT
@notice Stores and distributes ERC20 tokens by deploying `VestingEscrowSimple` contracts
"""

from vyper.interfaces import ERC20

struct VestingInfo:
    contract: address
    funder: address
    recipient: address

interface VestingEscrowSimple:
    def initialize(
        admin: address,
        token: address,
        recipient: address,
        amount: uint256,
        start_time: uint256,
        end_time: uint256,
        cliff_length: uint256,
    ) -> bool: nonpayable


event VestingEscrowCreated:
    funder: indexed(address)
    token: indexed(address)
    recipient: indexed(address)
    escrow: address
    amount: uint256
    vesting_start: uint256
    vesting_duration: uint256
    cliff_length: uint256


target: public(address)
contractCount: public(uint256)
contracts: public(HashMap[uint256, VestingInfo])

@external
def __init__(target: address):
    """
    @notice Contract constructor
    @dev Prior to deployment you must deploy one copy of `VestingEscrowSimple` which
         is used as a library for vesting contracts deployed by this factory
    @param target `VestingEscrowSimple` contract address
    """
    self.target = target
    self.contractCount = 0


@external
def deploy_vesting_contract(
    token: address,
    recipient: address,
    amount: uint256,
    vesting_duration: uint256,
    vesting_start: uint256 = block.timestamp,
    cliff_length: uint256 = 0,
) -> address:
    """
    @notice Deploy a new vesting contract
    @param token Address of the ERC20 token being distributed
    @param recipient Address to vest tokens for
    @param amount Amount of tokens being vested for `recipient`
    @param vesting_duration Time period over which tokens are released
    @param vesting_start Epoch time when tokens begin to vest
    """
    assert cliff_length <= vesting_duration  # dev: incorrect vesting cliff
    escrow: address = create_forwarder_to(self.target)
    assert ERC20(token).transferFrom(msg.sender, self, amount)  # dev: funding failed
    assert ERC20(token).approve(escrow, amount)  # dev: approve failed
    VestingEscrowSimple(escrow).initialize(
        msg.sender,
        token,
        recipient,
        amount,
        vesting_start,
        vesting_start + vesting_duration,
        cliff_length,
    )

    self.contracts[self.contractCount] = VestingInfo({contract: escrow, funder: msg.sender, recipient: recipient})
    self.contractCount += 1

    log VestingEscrowCreated(msg.sender, token, recipient, escrow, amount, vesting_start, vesting_duration, cliff_length)
    return escrow

@view
@external
def get_contract_count() -> uint256:
    return self.contractCount

@view
@external
def vesting_info_by_index(index:uint256) -> VestingInfo:
    return self.contracts[index]