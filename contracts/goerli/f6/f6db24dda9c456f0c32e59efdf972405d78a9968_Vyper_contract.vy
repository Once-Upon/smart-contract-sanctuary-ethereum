# @version 0.3.4

from vyper.interfaces import ERC165
from vyper.interfaces import ERC721

implements: ERC165
implements: ERC721

############ ERC-165 #############
# @dev Static list of supported ERC165 interface ids
SUPPORTED_INTERFACES: constant(bytes4[3]) = [
    0x01ffc9a7,  # ERC165 interface ID of ERC165
    0x80ac58cd,  # ERC165 interface ID of ERC721
    0x5b5e139f,  # ERC165 interface ID of ERC721 Metadata Extension
]

############ ERC-721 #############

# Interface for the contract called by safeTransferFrom()
interface ERC721Receiver:
    def onERC721Received(
            operator: address,
            owner: address,
            tokenId: uint256,
            data: Bytes[1024]
        ) -> bytes4: view

# Interface for ERC721Metadata

interface ERC721Metadata:
	def name() -> String[64]: view

	def symbol() -> String[32]: view

	def tokenURI(
		_tokenId: uint256
	) -> String[128]: view

interface ERC721Enumerable:

	def totalSupply() -> uint256: view

	def tokenByIndex(
		_index: uint256
	) -> uint256: view

	def tokenOfOwnerByIndex(
		_address: address,
		_index: uint256
	) -> uint256: view

# events

# @dev Emits when ownership of any NFT changes by any mechanism. This event emits when NFTs are
#      created (`from` == 0) and destroyed (`to` == 0). Exception: during contract creation, any
#      number of NFTs may be created and assigned without emitting Transfer. At the time of any
#      transfer, the approved address for that NFT (if any) is reset to none.
# @param owner Sender of NFT (if address is zero address it indicates token creation).
# @param receiver Receiver of NFT (if address is zero address it indicates token destruction).
# @param tokenId The NFT that got transfered.
event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    tokenId: indexed(uint256)

# @dev This emits when the approved address for an NFT is changed or reaffirmed. The zero
#      address indicates there is no approved address. When a Transfer event emits, this also
#      indicates that the approved address for that NFT (if any) is reset to none.
# @param owner Owner of NFT.
# @param approved Address that we are approving.
# @param tokenId NFT which we are approving.
event Approval:
    owner: indexed(address)
    approved: indexed(address)
    tokenId: indexed(uint256)

# @dev This emits when an operator is enabled or disabled for an owner. The operator can manage
#      all NFTs of the owner.
# @param owner Owner of NFT.
# @param operator Address to which we are setting operator rights.
# @param approved Status of operator rights(true if operator rights are given and false if
# revoked).
event ApprovalForAll:
    owner: indexed(address)
    operator: indexed(address)
    approved: bool

event Paused:
    # Emits a pause event with the address that paused the contract
    account: address

event unPaused:
    # Emits an unpause event with the address that paused the contract
    account: address


owner: public(address)

# pause status True / False
# not part of the core spec but a common feature for NFT projects
paused: public(bool)      

isMinter: public(HashMap[address, bool])

totalSupply: public(uint256)

# @dev TokenID => owner
idToOwner: public(HashMap[uint256, address])

# @dev Mapping from owner address to count of their tokens.
balanceOf: public(HashMap[address, uint256])

# @dev Mapping from owner address to mapping of operator addresses.
isApprovedForAll: public(HashMap[address, HashMap[address, bool]])

# @dev Mapping from NFT ID to approved address.
idToApprovals: public(HashMap[uint256, address])


# ERC20 Token Metadata
NAME: constant(String[20]) = "realNFT"
SYMBOL: constant(String[5]) = "rNFT"
baseURI: public(String[100])

@external
def __init__():
    """
    @dev Contract constructor.
    """
    self.owner = msg.sender
    self.baseURI = "ipfs://QmaZm1rAkt6kHTKTFX8GwEhtPMVMeAGJYMBvoAcJWTddwb"

## contract status ##
@external
def pause():
    """
    @dev Pause the contract, checks if the caller is the owner and if the contract is paused already
    @dev emits a pause event 
    @dev not part of the core spec but a common feature for NFT projects
    """
    assert self.owner == msg.sender, "Ownable: caller is not the owner"
    assert not self.paused, "the contract is already paused"
    self.paused = True
    log Paused(msg.sender)

@external
def unpause():
    """
    @dev Unpause the contract, checks if the caller is the owner and if the contract is paused already
    @dev emits an unpause event 
    @dev not part of the core spec but a common feature for NFT projects
    """
    assert self.owner == msg.sender, "Ownable: caller is not the owner"
    assert self.paused, "the contract is not paused"
    self.paused = False
    log unPaused(msg.sender)

# ERC721 Metadata Extension
@pure
@external
def name() -> String[40]:
    return NAME

@pure
@external
def symbol() -> String[5]:
    return SYMBOL


@view
@external
def tokenURI(tokenId: uint256) -> String[179]:
    return concat(self.baseURI, "/" , uint2str(tokenId))

@external
def setBaseURI(_baseURI: String[100]):
    assert msg.sender == self.owner
    self.baseURI = _baseURI

############ ERC-165 #############

@pure
@external
def supportsInterface(interface_id: bytes4) -> bool:
    """
    @dev Interface identification is specified in ERC-165.
    @param interface_id Id of the interface
    """
    return interface_id in SUPPORTED_INTERFACES


##### ERC-721 VIEW FUNCTIONS #####

@view
@external
def ownerOf(tokenId: uint256) -> address:
    """
    @dev Returns the address of the owner of the NFT.
         Throws if `tokenId` is not a valid NFT.
    @param tokenId The identifier for an NFT.
    """
    owner: address = self.idToOwner[tokenId]
    # Throws if `tokenId` is not a valid NFT
    assert owner != empty(address)
    return owner


@view
@external
def getApproved(tokenId: uint256) -> address:
    """
    @dev Get the approved address for a single NFT.
         Throws if `tokenId` is not a valid NFT.
    @param tokenId ID of the NFT to query the approval of.
    """
    # Throws if `tokenId` is not a valid NFT
    assert self.idToOwner[tokenId] != empty(address)
    return self.idToApprovals[tokenId]


### TRANSFER FUNCTION HELPERS ###

@view
@internal
def _isApprovedOrOwner(spender: address, tokenId: uint256) -> bool:
    """
    @dev Returns whether the given spender can transfer a given token ID
    @param spender address of the spender to query
    @param tokenId uint256 ID of the token to be transferred
    @return bool whether the msg.sender is approved for the given token ID,
        is an operator of the owner, or is the owner of the token
    """
    owner: address = self.idToOwner[tokenId]

    if owner == spender:
        return True

    if spender == self.idToApprovals[tokenId]:
        return True

    if (self.isApprovedForAll[owner])[spender]:
        return True

    return False


@internal
def _transferFrom(owner: address, receiver: address, tokenId: uint256, sender: address):
    """
    @dev Execute transfer of a NFT.
         Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
         address for this NFT. (NOTE: `msg.sender` not allowed in private function so pass `_sender`.)
         address for thisassert self.idToOwner[tokenId] == owner NFT. (NOTE: `msg.sender` not allowed in private function so pass `_sender`.)
         Throws if `receiver` is the zero address.
         Throws if `owner` is not the current owner.
         Throws if `tokenId` is not a valid NFT.
    """
    # Check requirements
    assert not self.paused, "The contract has been paused"
    assert self._isApprovedOrOwner(sender, tokenId)
    assert receiver != empty(address)
    assert owner != empty(address)
    assert self.idToOwner[tokenId] == owner

    # Reset approvals, if any
    if self.idToApprovals[tokenId] != empty(address):
        self.idToApprovals[tokenId] = empty(address)

    # Change the owner
    self.idToOwner[tokenId] = receiver

    # Change count tracking
    self.balanceOf[owner] -= 1
    self.balanceOf[receiver] += 1

    # Log the transfer
    log Transfer(owner, receiver, tokenId)


@external
def transferFrom(owner: address, receiver: address, tokenId: uint256):
    """
    @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
         address for this NFT.
         Throws if `owner` is not the current owner.
         Throws if `receiver` is the zero address.
         Throws if `tokenId` is not a valid NFT.
    @notice The caller is responsible to confirm that `receiver` is capable of receiving NFTs or else
            they maybe be permanently lost.
    @param owner The current owner of the NFT.
    @param receiver The new owner.
    @param tokenId The NFT to transfer.
    """
    assert not self.paused, "The contract has been paused"
    self._transferFrom(owner, receiver, tokenId, msg.sender)


@external
def safeTransferFrom(
        owner: address,
        receiver: address,
        tokenId: uint256,
        data: Bytes[1024]=b""
    ):
    """
    @dev Transfers the ownership of an NFT from one address to another address.
         Throws unless `msg.sender` is the current owner, an authorized operator, or the
         approved address for this NFT.
         Throws if `owner` is not the current owner.
         Throws if `receiver` is the zero address.
         Throws if `tokenId` is not a valid NFT.
         If `receiver` is a smart contract, it calls `onERC721Received` on `receiver` and throws if
         the return value is not `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
         NOTE: bytes4 is represented by bytes32 with padding
    @param owner The current owner of the NFT.
    @param receiver The new owner.
    @param tokenId The NFT to transfer.
    @param data Additional data with no specified format, sent in call to `receiver`.
    """
    assert not self.paused, "The contract has been paused"
    self._transferFrom(owner, receiver, tokenId, msg.sender)
    if receiver.is_contract: # check if `receiver` is a contract address
        returnValue: bytes4 = ERC721Receiver(receiver).onERC721Received(msg.sender, owner, tokenId, data)
        # Throws if transfer destination is a contract which does not implement 'onERC721Received'
        assert returnValue == method_id("onERC721Received(address,address,uint256,bytes)", output_type=bytes4)


@external
def approve(operator: address, tokenId: uint256):
    """
    @dev Set or reaffirm the approved address for an NFT. The zero address indicates there is no approved address.
         Throws unless `msg.sender` is the current NFT owner, or an authorized operator of the current owner.
         Throws if `tokenId` is not a valid NFT. (NOTE: This is not written the EIP)
         Throws if `operator` is the current owner. (NOTE: This is not written the EIP)
    @param operator Address to be approved for the given NFT ID.
    @param tokenId ID of the token to be approved.
    """
    assert not self.paused, "The contract has been paused"
    # Throws if `tokenId` is not a valid NFT
    owner: address = self.idToOwner[tokenId]
    assert owner != empty(address)

    # Throws if `operator` is the current owner
    assert operator != owner

    # Throws if `msg.sender` is not the current owner, or is approved for all actions
    assert owner == msg.sender or (self.isApprovedForAll[owner])[msg.sender]

    self.idToApprovals[tokenId] = operator
    log Approval(owner, operator, tokenId)

@external
def setApprovalForAll(operator: address, approved: bool):
    """
    @dev Enables or disables approval for a third party ("operator") to manage all of
         `msg.sender`'s assets. It also emits the ApprovalForAll event.
    @notice This works even if sender doesn't own any tokens at the time.
    @param operator Address to add to the set of authorized operators.
    @param approved True if the operators is approved, false to revoke approval.
    """
    assert not self.paused, "The contract has been paused"
    self.isApprovedForAll[msg.sender][operator] = approved
    log ApprovalForAll(msg.sender, operator, approved)
@external
def addMinter(minter: address):
    assert not self.paused, "The contract has been paused"
    assert msg.sender == self.owner
    self.isMinter[minter] = True



@external
def mint(receiver: address) -> uint256:
    """
    @dev Create a new Owner NFT
    @notice `tokenId` cannot be owned by someone because of hash production.
    @return uint256 Computed TokenID of new Portfolio.
    """ 
    assert not self.paused, "The contract has been paused"
    assert msg.sender == self.owner or self.isMinter[msg.sender], "Access is denied."

    self.totalSupply += 1
    assert self.idToOwner[self.totalSupply] == empty(address)  # Sanity check
    
    self.idToOwner[self.totalSupply] = receiver
    self.balanceOf[receiver] += 1

    log Transfer(empty(address), receiver, self.totalSupply)

    return self.totalSupply