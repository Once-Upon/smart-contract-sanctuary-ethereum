/**
 *Submitted for verification at Etherscan.io on 2022-07-28
*/

// File: contracts/SignerVerifiable.sol


pragma solidity ^0.8.15;

contract SignerVerifiable {

    mapping(address => uint256) public nonces;

    function getMessageHash(
        address _player,
        uint _amount,
        string memory _message,
        uint256 _battle_id,
        uint _deadline
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(nonces[_player], _player, _amount, _message, _battle_id, _deadline));
    }

    function decodeSignature(
        address _player,
        uint _amount,
        string memory _message,
        uint256 _battle_id,
        uint256 _deadline,
        bytes memory signature
    ) public returns (address) {
        bytes32 messageHash = getMessageHash(_player, _amount, _message, _battle_id, _deadline);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        address decoded_signer = recoverSigner(ethSignedMessageHash, signature);

        require(block.timestamp < _deadline, "Transaction expired");
        require(decoded_signer != address(0x0), "Error: invalid signer");

        nonces[_player]++;

        return decoded_signer;
    }

    // INTERNAL FUNCTIONS

    function getEthSignedMessageHash(bytes32 _messageHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
        internal
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/Battling.sol


pragma solidity ^0.8.15;



contract Battling is Ownable, SignerVerifiable {
    struct Battle {
        address player_one;
        address player_two;
    }

    uint256 public team_balance = 0;
    mapping(address => uint256) public balances;
    mapping(uint256 => bool) public winner_paid;
    mapping(uint256 => mapping(address => bool)) public draw_paid_out;
    mapping(string => Battle) public battle_contestants;

    bool public contract_frozen = false;
    address public SIGNER = 0x499f6d0c92b17f922ed8A0846cEC3A4AFe458c86;
    
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

    modifier frozen {
        require(!contract_frozen, "Contract is currently paused");
        _;
    }

    modifier callerVerified(uint256 _amount, string memory _message, uint256 _battle_id, uint256 _deadline, bytes memory _signature) {
        require(decodeSignature(msg.sender, _amount, _message, _battle_id, _deadline, _signature) == SIGNER, "Call is not authorized");
        _;
    }

    constructor () { }

    // USER FUNCTIONS
    
    function userDepositIntoContract() external payable frozen {
        balances[msg.sender] += msg.value;
    }
    
    function userWithdrawFromContract(uint256 _amount) external payable frozen {
        require(_amount <= balances[msg.sender], "Not enough balance to withdraw");
        balances[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    // END USER FUNCTIONS

    // AUTHORIZED FUNCTIONS

    function initiateBattle(uint256 _amount, string memory _message, uint256 _battle_id, uint256 _deadline, bytes memory _signature, string memory _battle_seed) external frozen callerVerified(_amount, _message, _battle_id, _deadline, _signature) {
        require(_amount <= balances[msg.sender], "Player does not have enough balance");

        require(battle_contestants[_battle_seed].player_one == address(0x0) || battle_contestants[_battle_seed].player_two == address(0x0), "Battle is full");

        if (battle_contestants[_battle_seed].player_one == address(0x0)) {
            battle_contestants[_battle_seed].player_one = msg.sender;
        } else {
            battle_contestants[_battle_seed].player_two = msg.sender;
        }

        balances[msg.sender] -= _amount;
    }
    
    function claimWinnings(uint256 _amount, string memory _message, uint256 _battle_id, uint256 _deadline, bytes memory _signature, string memory _battle_seed) external frozen callerVerified(_amount, _message, _battle_id, _deadline, _signature) {
        require(!winner_paid[_battle_id], "Rewards already claimed for battle");
        require(battle_contestants[_battle_seed].player_one == msg.sender || battle_contestants[_battle_seed].player_two == msg.sender, "User is not in this battle");
        
        winner_paid[_battle_id] = true;
        balances[msg.sender] += 95 * _amount / 100;
        team_balance += 5 * _amount / 100;
    }

    function returnWager(uint256 _amount, string memory _message, uint256 _battle_id, uint256 _deadline, bytes memory _signature, string memory _battle_seed) external frozen callerVerified(_amount, _message, _battle_id, _deadline, _signature) {
        require(!draw_paid_out[_battle_id][msg.sender], "Rewards already claimed for battle");
        require(battle_contestants[_battle_seed].player_one == msg.sender || battle_contestants[_battle_seed].player_two == msg.sender, "User is not in this battle");

        draw_paid_out[_battle_id][msg.sender] = true;
        balances[msg.sender] += _amount;
    }

    // END AUTHORIZED FUNCTIONS

    // OWNER FUNCTIONS

    function withdrawTeamBalance() external onlyOwner {
        payable(msg.sender).transfer(team_balance);
        team_balance = 0;
    }

    function toggleContractFreeze() external onlyOwner {
        contract_frozen = !contract_frozen;
    }
    
    function setSignerAddress(address _new_signer) external onlyOwner {
        SIGNER = _new_signer;
    }

    // END OWNER FUNCTIONS

    // HELPER FUNCTIONS

    function drawPaidOut(uint256 _battle_id, address _player) external view returns(bool) {
        return draw_paid_out[_battle_id][_player];
    }

    // END HELPER FUNCTIONS
    
}