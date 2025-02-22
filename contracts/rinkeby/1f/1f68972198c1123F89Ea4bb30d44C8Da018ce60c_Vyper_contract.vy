# @version 0.3.3
"""
@title PAC DAO 2022 Congressional Scorecard
@author pacdao.eth 
@license MIT
"""

#
#                        ::
#                        ::
#                       .::.
#                     ..::::..
#                    .:-::::-:.
#                   .::::::::::.
#                   :+========+:
#                   ::.:.::.:.::
#            ..     :+========+:    ..
# @@@@@@@...........:.:.:..:.:.:[email protected]@@@@@@@
# @@@@@@@@@@* :::. .:.:.:..:.:.:   . .  [email protected]@@@@@@@@
# @@@@@@@@@@@@@***: :....::-.:.:.:.:[email protected]@@@@@@@@@@@@@
# @@@@@@@@@@@@@@@@..+==========+...:@@@@@@@@@@@@@@@
# https://ascii-generator.site/

from vyper.interfaces import ERC20

interface ERC721:
   def mint(recipient: address, tokenURI: String[64]): nonpayable
   def set_owner(new_owner: address): nonpayable

# General Properties
max_seat_count: constant(uint256) = 1024
seat_count: public(uint256)
claimed_seats: public(uint256)
is_live: public(bool)
seats: public(HashMap[uint256, address])

# Addresses
nft_addr: public(address)
owner: public(address)

# Merkle Data
merkle_root: public(bytes32)
merkle_depth: constant(uint256) = 10

# Auction Variables
auction_bids: public(HashMap[uint256, HashMap[address, uint256]])
auction_leaders: public(HashMap[uint256, address])
auction_live: public(HashMap[uint256, uint256])
auction_duration: public(uint256)
auction_interval: public(uint256)

# Mint Properties
min_price: public(uint256)
min_interval: public(uint256)

# User Variables
seat_by_index: public(HashMap[address, HashMap[uint256, uint256]])
user_claim_count: public(HashMap[address, uint256])


event SeatReserved:
   seat_id: uint256
   owner: address


@external
def __init__(
    nft_addr: address,
):
    self.nft_addr = nft_addr
    self.seat_count = 539
    self.merkle_root = 0x3f82d64913c37840872e02acd7b5514f15a49613ea4542c4536fa946dea032d1

    self.is_live = True
    self.auction_duration = 60 * 60  #auction_duration
    self.auction_interval = 1000000000000000

    self.owner = msg.sender
    self.min_price = 1000000000000000
    self.min_interval = 1000000000000000


@internal
def _mint(target: address, hash: String[64]):
    ERC721(self.nft_addr).mint(target, hash)



@internal
def reserve_seat(target: address, seat_id: uint256):
    assert self.seats[seat_id] == ZERO_ADDRESS  # dev: Seat Assigned
    assert seat_id > 0  # dev: Invalid Seat

    self.seats[seat_id] = target
    self.seat_by_index[target][self.user_claim_count[target]] = seat_id
    self.claimed_seats += 1
    self.user_claim_count[target] += 1
    log SeatReserved(seat_id, target)


@internal
def get_pseudorandom_number(seed: uint256) -> uint256:
    return (block.timestamp * (1+seed)) % self.seat_count + 1


@external
def random(seed: uint256) -> uint256:
    return self.get_pseudorandom_number(seed)


# MERKLE FUNCTIONS
@internal
@view
def _calcMerkleRoot(
    _leaf: bytes32, _index: uint256, _proof: bytes32[merkle_depth]
) -> bytes32:
    """
    @dev Compute the merkle root
    @param _leaf Leaf hash to verify.
    @param _index Position of the leaf hash in the Merkle tree.
    @param _proof A Merkle proof demonstrating membership of the leaf hash.
    @return bytes32 Computed root of the Merkle tree.
    """
    computedHash: bytes32 = _leaf

    # We have no NFT with id 0
    index: uint256 = _index - 1

    for proofElement in _proof:
        if index % 2 == 0:
            computedHash = keccak256(concat(computedHash, proofElement))
        else:
            computedHash = keccak256(concat(proofElement, computedHash))
        index /= 2

    return computedHash


@external
@view
def calcMerkleRoot(
    _leaf: bytes32, _index: uint256, _proof: bytes32[merkle_depth]
) -> bytes32:
    """
    @dev Compute the merkle root
    @param _leaf Leaf hash to verify.
    @param _index Position of the leaf hash in the Merkle tree, which starts with 1.
    @param _proof A Merkle proof demonstrating membership of the leaf hash.
    @return bytes32 Computed root of the Merkle tree.
    """
    return self._calcMerkleRoot(_leaf, _index, _proof)


@external
@view
def verifyMerkleProof(
    _leaf: bytes32, _index: uint256, _rootHash: bytes32, _proof: bytes32[merkle_depth]
) -> bool:
    """
    @dev Checks that a leaf hash is contained in a root hash.
    @param _leaf Leaf hash to verify.
    @param _index Position of the leaf hash in the Merkle tree, which starts with 1.
    @param _rootHash Root of the Merkle tree.
    @param _proof A Merkle proof demonstrating membership of the leaf hash.
    @return bool whether the leaf hash is in the Merkle tree.
    """
    return self._calcMerkleRoot(_leaf, _index, _proof) == _rootHash


# AUCTION METHODS

@external
@view
def auction_index() -> uint256[max_seat_count]:
    ret_arr: uint256[max_seat_count] = empty(uint256[max_seat_count])
    for i in range(max_seat_count):
        if self.auction_live[i] > 0:
            ret_arr[i] = self.auction_bids[i][self.auction_leaders[i]] 
        else:
            ret_arr[i] = 0 
	
    return ret_arr


@external
@view
def auction_deadlines() -> uint256[max_seat_count]:
    ret_arr: uint256[max_seat_count] = empty(uint256[max_seat_count])
    for i in range(max_seat_count):
        ret_arr[i] = self.auction_live[i]

    return ret_arr


@external
@view
def seat_winners() -> address[max_seat_count]:
    ret_arr: address[max_seat_count] = empty(address[max_seat_count])
    for i in range(max_seat_count):
        ret_arr[i] = self.seats[i]

    return ret_arr



@internal
@payable
def _auction_start(
    seat_id: uint256, msg_value: uint256, msg_sender: address
):
    # Verify Merkle
    assert (
        self.auction_live[seat_id] == 0
    ), "Auction already started"  # dev: "Auction already started"

    self.reserve_seat(self, seat_id)
    self.auction_live[seat_id] = block.timestamp + self.auction_duration
    self.auction_leaders[seat_id] = msg_sender
    self.auction_bids[seat_id][msg_sender] += msg_value


@external
@payable
def auction_bid(seat_id: uint256):
    assert msg.value > 0, "No value"
    assert seat_id > 0 and seat_id <= self.seat_count, "Invalid Seat"
    assert msg.value / self.auction_interval * self.auction_interval == msg.value, "Min interval violation"
    if self.auction_live[seat_id] == 0:
         self._auction_start(seat_id, msg.value, msg.sender)
    else:
         assert block.timestamp < self.auction_live[seat_id]  # dev: Auction ended

    self.auction_bids[seat_id][msg.sender] += msg.value
    self.auction_live[seat_id] = block.timestamp + self.auction_duration

    _leader: address = self.auction_leaders[seat_id]
    if self.auction_bids[seat_id][msg.sender] > self.auction_bids[seat_id][_leader]:
        self.auction_leaders[seat_id] = msg.sender


@external
def auction_resolve(
    seat_id: uint256, leaf: bytes32, proof: bytes32[merkle_depth], hash: String[64]
):
    assert (
        0 < self.auction_live[seat_id]
    ), "Auction never started"  # dev: Auction never started
    assert (
        block.timestamp > self.auction_live[seat_id]
    ), "Auction not over"  # dev: Auction not over

    assert keccak256(hash) == leaf, "Failed to hash"
    assert (
        self._calcMerkleRoot(leaf, seat_id, proof) == self.merkle_root
    )  # dev: Merkle Root Fail

    self._mint(self.auction_leaders[seat_id], hash)


@internal
def get_pseudorandom_seat(seed: uint256) -> uint256:
    seat_id: uint256 = self.get_pseudorandom_number(seed)
    offset: bool = False
    _val: uint256 = 0

    for j in range(max_seat_count):
        if seat_id + j > max_seat_count:
            offset = True

        if offset:
            _val = seat_id + j - max_seat_count
        else:
            _val = seat_id + j

        if self.seats[_val] == ZERO_ADDRESS:
            return _val
    assert False  # dev: No Seat Available
    return 0



# MINT RANDOM PACK FUNCTIONS
@internal
@view
def _batch_price(quantity: uint256) -> uint256:
    return self.min_price * quantity

@external
@payable
def mint_batch(quantity: uint256):
    assert self.claimed_seats + quantity <= self.seat_count  # dev: Too few seats left!
    assert self.is_live == True  # dev: Auction has ended
    assert msg.value >= self._batch_price(quantity)  # dev: Did not pay enough

    for i in range(max_seat_count):
        if i >= quantity:
            break

        # Get Pseudorandom Number
        seat_id: uint256 = self.get_pseudorandom_seat(i)

        self.reserve_seat(msg.sender, seat_id)


@external
@view
def mint_batch_price(quantity: uint256) -> uint256:
    return self._batch_price(quantity)

@external
def mint_finalize(
    index: uint256, hash: String[64], leaf: bytes32, proof: bytes32[merkle_depth]
):
    # Verify Merkle
    assert (self._calcMerkleRoot(leaf, index, proof) == self.merkle_root)  # dev: Merkle Verify Fail

    self._mint(self.seats[index], hash)



# ADMIN FUNCTIONS

@external
def admin_claim(index: uint256, hash: String[32]):
    assert self.owner == msg.sender
    self._mint(self.seats[index], "XXX")

@external
def admin_nft_owner(new_owner: address):
    assert self.owner == msg.sender
    ERC721(self.nft_addr).set_owner(new_owner)

@external
def admin_new_owner(new_owner: address):
   assert msg.sender == self.owner
   self.owner = new_owner
   
@external
def admin_withdraw(target: address, amount: uint256):
   assert self.owner == msg.sender
   send(target, amount)

@external
def admin_withdraw_erc20(coin: address, target: address, amount: uint256):
   assert self.owner == msg.sender
   ERC20(coin).transfer(target, amount)

@external
def admin_set_min_price(amount: uint256):
   assert self.owner == msg.sender
   self.min_price = amount