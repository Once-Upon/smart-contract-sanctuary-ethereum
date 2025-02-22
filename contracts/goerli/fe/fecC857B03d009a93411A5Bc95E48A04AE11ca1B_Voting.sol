// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Trees proofs.
 *
 * The proofs can be generated using the JavaScript library
 * https://github.com/miguelmota/merkletreejs[merkletreejs].
 * Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
 *
 * See `test/utils/cryptography/MerkleProof.test.js` for some examples.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = _efficientHash(computedHash, proofElement);
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = _efficientHash(proofElement, computedHash);
            }
        }
        return computedHash;
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./VoterDataMerkle.sol";
interface IVoterData {
    function verify(uint _votingId, bytes32[] calldata proof, bytes32 leaf) external view returns(bool);
    function addVoterHistory(address _voter, uint _votingId, uint _candidateId, uint _timeStamp) external;
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract VoterDataMerkle {

    struct History {
        uint votingId;
        uint candidateId;
        uint timeStamp;
    }
    
    mapping(uint => bytes32) public votingToRoot;
    mapping(uint => bytes32[]) public votingToLeaves;
    mapping(address => History[]) public voterHistory;
    mapping(address => bytes32) public addressToLeave;
    

    function addLeaf(uint _votingId, bytes32 _leaf, bytes32 _newRoot, address _voter) external {
        bool result = checkLeaf(_votingId,_leaf);
        require(result, "The same leaf already added to the tree");
        votingToLeaves[_votingId].push(_leaf);
        addressToLeave[_voter] = _leaf;
        setRoot(_votingId, _newRoot);
    }
    function checkLeaf (uint _votingId, bytes32 _leaf) public view returns(bool){
        bool result;
        bytes32[] memory leaves = votingToLeaves[_votingId];
        uint length = leaves.length;
        if(length == 0) {
            result = true;
        }else {
           for(uint i; i < length; i++ ) {
            if(leaves[i] != _leaf) {
              result = true;
                }
            }
        }
        return result;
    }

    function setRoot(uint _votingId, bytes32 _root) public {
        votingToRoot[_votingId] = _root;
    }

   function getLeaves(address _voter) external view returns(bytes32) {
        bytes32 voter = addressToLeave[_voter];
        return voter;
   }
   
    function verify(uint _votingId, bytes32[] calldata proof, bytes32 leaf) external view returns(bool){
        bytes32 root = votingToRoot[_votingId];
        return MerkleProof.verify(proof, root, leaf);
    }

    function addVoterHistory(address _voter, uint _votingId, uint _candidateId, uint _timeStamp) external{
        voterHistory[_voter].push(History(_votingId, _candidateId, _timeStamp));
    }

    function getVoterHistory(address _voter) external view returns(History[] memory) {
        History[] memory history = voterHistory[_voter];
        return history;
    }

}
//["0xe4dd56d5e2f519525edb5665356a4e692845c99743276481c38b985558081733","0x0af3f6573dbdf1095c10456a6c548811374e36d2274388b6dd077f583645a464","0xae605a09907dbdbe0d7eefe17447827e901d761c3dcba548e053ed1593f9a16e","0xcb23852aa58909d7af5e0b89e130bc5c4562b59b9b83e84eeb0bc3fe22a3a729"]
//["0x23f693cb6d9166a63dcf57b0f9aad27a926cb3fd2497794b2bad788f5553ad22","0x9c8c37cb729e62a65846b025e5d0b5eeae77ac197971ed4b5180926122fdbde8","0xe7afae1ca32f995d454c6dbf49581bcfdb2868026c11b02879e00008ec52c308"]
/*[
  "0x5d99e948fdca6c6ef8a54685d3ba09b0b7dbeb8af0dba02efcda4d388ede00a3",
  "0x0af3f6573dbdf1095c10456a6c548811374e36d2274388b6dd077f583645a464",
  "0xae605a09907dbdbe0d7eefe17447827e901d761c3dcba548e053ed1593f9a16e",
  "0xcb23852aa58909d7af5e0b89e130bc5c4562b59b9b83e84eeb0bc3fe22a3a729"
]*/

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IVoterData.sol";

contract Voting {

    struct Candidate {
        uint candidateId;
        bytes32 candidate;
        uint votes;
    }

    struct Detail {
        bytes32 title;
        uint duration;
        Candidate[] candidates;
        uint startTime;
        uint roomId;
        address proposer;
    }

    struct History {
        address voter;
        uint candidateId;
        uint timeStamp;
    }


    uint public votingCount = 1;
    IERC20 ballotInterface;
    IVoterData voterDataInterface;
    mapping(uint => Detail) public votingDetails;
    mapping(uint => History[]) public votingHistory;
    mapping(uint => address[]) public voterVerified;

    function setInterface(address _ballotToken, address _voterData) external {
        ballotInterface = IERC20(_ballotToken);
        voterDataInterface = IVoterData(_voterData);
    }

    function startSession(uint _votingId, uint _duration) public{
        Detail storage details = votingDetails[_votingId];
        details.duration = _duration;
        details.startTime = block.timestamp;
    }

    function createVoting(bytes32 _title, uint _duration, uint _startTime, uint _roomId, bytes32[] calldata _candidates) external{
        Detail storage details = votingDetails[votingCount];
        details.title = _title;
        details.duration = _duration;
        uint length = _candidates.length;
        for(uint i; i < length; ++i) {
            bytes32 candidate = _candidates[i];
            details.candidates.push(Candidate(i + 1, candidate, 0));
        }
        details.startTime = (_startTime * 1 hours) + block.timestamp;
        details.roomId = _roomId;
        details.proposer = msg.sender;
        votingCount ++;
    }

    function vote(uint _votingId, address _voter, uint _candidate) external {
        Detail memory details = votingDetails[_votingId];
        bool verified = checkVerifiedVoter(_votingId, _voter);
        bool voted = checkVoterVote(_votingId, _voter);
        uint startTime = details.startTime;
        uint duration = details.duration;
        uint totalDuration = startTime + (duration * 1 hours);

        require(verified == true, "You are not verified");
        require(voted == false, "You already voted to one of the candidates");
        require(startTime < block.timestamp, "Voting session has not started");
        require(totalDuration > block.timestamp, "Duration of the voting session is over");
        uint index = getCandidateIndex(_votingId, _candidate);
        ballotInterface.approve(_voter, 1);
        ballotInterface.transfer(address(this), 1);
        Candidate[] storage  candidates= votingDetails[_votingId].candidates;
        candidates[index].votes = candidates[index].votes + 1;
        votingHistory[_votingId].push(History(_voter, _candidate, block.timestamp));

        voterDataInterface.addVoterHistory(_voter, _votingId, _candidate, block.timestamp);
    }


    function getCandidateIndex(uint _votingId, uint _candidate) internal view returns(uint index) {
        Candidate[] memory  candidates= votingDetails[_votingId].candidates;
        uint length = candidates.length;
        for(uint i; i < length; ++i) {
            uint candidate = candidates[i].candidateId;
            if(candidate == _candidate) {
                index = i;
            }
        }  
    }

    function getCandidates(uint _votingId) external view returns(Candidate[] memory candidates) {
        candidates = votingDetails[_votingId].candidates;
    }

    function getHistory(uint _votingId) external view returns(History[] memory history) {
        history = votingHistory[_votingId];
    }

    function checkVerifiedVoter(uint _votingId, address _voter) internal view returns(bool result) {
        address[] memory verified = voterVerified[_votingId];
        uint length = verified.length;
        for(uint i; i < length; ++i) {
            address _verified = verified[i];
            if(_verified ==_voter) {
                result = true;
            } else {
                result = false;
            }
        }
    }
    
    function checkVoterVote(uint _votingId, address _voter) internal view returns(bool result) {
        History[] memory votes = votingHistory[_votingId];
        uint length = votes.length;
        for(uint i; i < length; i++){
            address voter = votes[i].voter;
            if(voter == _voter){
                result = true;
            } else {
                result = false;
            }
        }
    }

    function verifyVoter(uint _votingId, bytes32[] calldata proof, bytes32 leaf) external {
        bool verify = voterDataInterface.verify(_votingId, proof, leaf);
        bool verified = checkVerifiedVoter(_votingId, msg.sender);
        require(verify, "You are not a verified voter");
        require(!verified, "You are already verified");
        voterVerified[_votingId].push(msg.sender);
        ballotInterface.approve(address(this), 1);
        ballotInterface.transferFrom(address (this), msg.sender, 1);
    }

}