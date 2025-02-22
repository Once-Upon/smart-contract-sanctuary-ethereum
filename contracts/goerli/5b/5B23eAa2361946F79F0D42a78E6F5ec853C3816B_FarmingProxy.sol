// SPDX-License-Identifier: MIT

// Energi Governance system is the fundamental part of Energi Core.

// NOTE: It's not allowed to change the compiler due to byte-to-byte
//       match requirement.

pragma solidity 0.5.16;

import { NonReentrant } from '../NonReentrant.sol';

import { IGovernedProxy_New } from '../interfaces/IGovernedProxy_New.sol';
import { IManager } from '../manager/IManager.sol';
import { IFarmingProxy } from './IFarmingProxy.sol';
import { IERC721 } from '../interfaces/IERC721.sol';

/**
 * SC-9: This contract has no chance of being updated. It must be stupid simple.
 *
 * If another upgrade logic is required in the future - it can be done as proxy stage II.
 */
contract FarmingProxy is NonReentrant, IFarmingProxy {
    address public managerProxyAddress;

    modifier senderOrigin() {
        // Internal calls are expected to use implementation directly.
        // That's due to use of call() instead of delegatecall() on purpose.
        require(tx.origin == msg.sender, 'FarmingProxy: FORBIDDEN, not a direct call');
        _;
    }

    modifier requireManager() {
        require(msg.sender == manager(), 'FarmingProxy: FORBIDDEN, not Manager');
        _;
    }

    constructor(address _managerProxyAddress) public {
        managerProxyAddress = _managerProxyAddress;
    }

    function manager() private view returns (address _manager) {
        _manager = address(
            IGovernedProxy_New(address(uint160(managerProxyAddress))).implementation()
        );
    }

    function transferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _tokenId
    ) external noReentry requireManager {
        IERC721(_token).transferFrom(_from, _to, _tokenId);
    }

    function emitStaked(
        address user,
        uint256 tokenId,
        uint256 lockTime
    ) external requireManager {
        emit Staked(user, tokenId, lockTime);
    }

    function emitWithdrawn(address user, uint256 tokenId) external requireManager {
        emit Withdrawn(user, tokenId);
    }

    function emitRewardPaid(address user, uint256 reward) external requireManager {
        emit RewardPaid(user, reward);
    }

    function emitLockingPeriodUpdate(uint256 lockingPeriodInSeconds) external requireManager {
        emit LockingPeriodUpdate(lockingPeriodInSeconds);
    }

    function proxy() external view returns (address) {
        return address(this);
    }

    // Proxy all other calls to Manager.
    function() external payable senderOrigin {
        // SECURITY: senderOrigin() modifier is mandatory

        IManager _manager = IManager(manager());

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())

            let res := call(sub(gas(), 10000), _manager, callvalue(), ptr, calldatasize(), 0, 0)
            // NOTE: returndatasize should allow repeatable calls
            //       what should save one opcode.
            returndatacopy(ptr, 0, returndatasize())

            switch res
            case 0 {
                revert(ptr, returndatasize())
            }
            default {
                return(ptr, returndatasize())
            }
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.5.16;

interface IManager {
    // View

    function getBalance(address farmingProxy, address account) external view returns (uint256);

    function getOwedRewards(address farmingProxy, address staker) external view returns (uint256);

    function getStakedTokenAmount(address farmingProxy) external view returns (uint256);

    function getLockingPeriodInSeconds(address farmingProxy) external view returns (uint256);

    function getFarmingStorage(address farmingProxy) external view returns (address);

    function getFarmingProxyByIndex(uint256 index) external view returns (address);

    function getAllFarmingProxiesCount() external view returns (uint256);

    function getPayoutPerNftStaked(address farmingProxy) external view returns (uint256);

    function getNftAddress(address farmingProxy) external view returns (address);

    function getOperatorAddress() external view returns (address);

    // Mutative

    function stake(uint256 tokenId) external;

    function stake(address farmingProxy, uint256 tokenId) external;

    function stakeBatch(address[] calldata farmingProxies, uint256[] calldata tokenIds) external;

    function withdrawIfUnlocked(uint256 amount) external;

    function withdrawIfUnlocked(address farmingProxy, uint256 amount) external;

    function withdrawIfUnlockedBatch(address[] calldata farmingProxies, uint256[] calldata tokenIds)
        external;

    function withdrawAllUnlocked() external;

    function withdrawAllUnlocked(address farmingProxy) external;

    function withdrawAllUnlockedBatch(address[] calldata farmingProxies) external;

    function claim() external;

    function claim(address farmingProxy) external;

    function claimBatch(address[] calldata farmingProxies) external;

    function exitIfUnlocked(uint256 tokenId) external;

    function exitIfUnlocked(address farmingProxy, uint256 tokenId) external;

    function exitIfUnlockedBatch(address[] calldata farmingProxies, uint256[] calldata tokenIds)
        external;

    function exitAllUnlocked() external;

    function exitAllUnlocked(address farmingProxy) external;

    function exitAllUnlockedBatch(address[] calldata farmingProxies) external;

    function returnNFTsInBatches(
        address farmingProxy,
        address[] calldata stakerAccounts,
        uint256[] calldata tokenIds,
        bool checkIfUnlocked
    ) external;

    function registerPool(address _farmingProxy, address _farmingStorage) external;

    function setOperatorAddress(address _newOperatorAddress) external;

    function setLockingPeriodInSeconds(address farmingProxy, uint256 lockingPeriod) external;

    function setMaxStakedTokenIdsCount(address farmingProxy, uint256 _maxStakedTokenIdsCount)
        external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.5.16;

import { IProposal } from './IProposal.sol';
import { IGovernedContract } from './IGovernedContract.sol';

contract IUpgradeProposal is IProposal {
    function impl() external view returns (IGovernedContract);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.5.16;

interface IProposal {
    function parent() external view returns (address);

    function created_block() external view returns (uint256);

    function deadline() external view returns (uint256);

    function fee_payer() external view returns (address payable);

    function fee_amount() external view returns (uint256);

    function accepted_weight() external view returns (uint256);

    function rejected_weight() external view returns (uint256);

    function total_weight() external view returns (uint256);

    function quorum_weight() external view returns (uint256);

    function isFinished() external view returns (bool);

    function isAccepted() external view returns (bool);

    function withdraw() external;

    function destroy() external;

    function collect() external;

    function voteAccept() external;

    function voteReject() external;

    function setFee() external payable;

    function canVote(address owner) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.5.16;

import { IGovernedContract } from './IGovernedContract.sol';
import { IUpgradeProposal } from './IUpgradeProposal.sol';

interface IGovernedProxy_New {
    event UpgradeProposal(IGovernedContract indexed implementation, IUpgradeProposal proposal);

    event Upgraded(IGovernedContract indexed implementation, IUpgradeProposal proposal);

    function spork_proxy() external view returns (address);

    function impl() external view returns (IGovernedContract);

    function implementation() external view returns (IGovernedContract);

    function proposeUpgrade(IGovernedContract _newImplementation, uint256 _period)
        external
        payable
        returns (IUpgradeProposal);

    function upgrade(IUpgradeProposal _proposal) external;

    function upgradeProposalImpl(IUpgradeProposal _proposal)
        external
        view
        returns (IGovernedContract newImplementation);

    function listUpgradeProposals() external view returns (IUpgradeProposal[] memory proposals);

    function collectUpgradeProposal(IUpgradeProposal _proposal) external;

    function() external payable;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.5.16;

interface IGovernedContract {
    // Return actual proxy address for secure validation
    function proxy() external view returns (address);

    // It must check that the caller is the proxy
    // and copy all required data from the old address.
    function migrate(IGovernedContract _oldImpl) external;

    // It must check that the caller is the proxy
    // and self destruct to the new address.
    function destroy(IGovernedContract _newImpl) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.5.16;

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool _approved) external;

    function getApproved(uint256 tokenId) external view returns (address operator);

    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.5.16;

interface IFarmingProxy {
    event Staked(address indexed user, uint256 tokenId, uint256 lockTime);
    event Withdrawn(address indexed user, uint256 tokenId);
    event RewardPaid(address indexed user, uint256 reward);
    event LockingPeriodUpdate(uint256 lockingPeriodInSeconds);

    function transferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _tokenId
    ) external;

    function emitStaked(
        address user,
        uint256 tokenId,
        uint256 lockTime
    ) external;

    function emitWithdrawn(address user, uint256 tokenId) external;

    function emitRewardPaid(address user, uint256 reward) external;

    function emitLockingPeriodUpdate(uint256 lockingPeriodInSeconds) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.5.16;

/**
 * A little helper to protect contract from being re-entrant in state
 * modifying functions.
 */

contract NonReentrant {
    uint256 private entry_guard;

    modifier noReentry() {
        require(entry_guard == 0, 'NonReentrant: Reentry');
        entry_guard = 1;
        _;
        entry_guard = 0;
    }
}