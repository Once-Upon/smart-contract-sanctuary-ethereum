// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Base} from "../base/Base.sol";
import {IMint} from "../interfaces/IMint.sol";
import {LibMerkleProof} from "../libraries/LibMerkleProof.sol";
import {LibMint} from "../libraries/LibMint.sol";
import {ITokenOwnershipFacet} from "../interfaces/ITokenOwnershipFacet.sol";


contract MintFacet is Base, IMint {

    modifier canMint() {
        if (msg.value != LibMint.getPrice()) revert InvalidETHAmount();
        if (LibMint.minted(msg.sender)) revert AlreadyMinted();
        _;
    }

    function mintWithProof(bytes32[] calldata _merkleProof)
        external
        payable
        onlyEoA
        canMint
    {
        if (!LibMint.isPrivateSaleActive()) revert PrivateSaleNotActive();
        if (!LibMerkleProof.verifyPrivateSale(_merkleProof)) revert InvalidProof();
        LibMint.setMinted(msg.sender);
        LibMint.mint(msg.sender, s);
    }

    function whaleMintWithProof(bytes32[] calldata _merkleProof)
        external
        payable
        onlyEoA
        canMint
    {
        if (!LibMint.isPrivateSaleActive()) revert PrivateSaleNotActive();
        if (!LibMerkleProof.verifyClaim(_merkleProof)) revert InvalidProof();
        if (!LibMint.meetsCondition(msg.sender)) revert DoesNotMeetMintCondition();
        LibMint.setMinted(msg.sender);
        LibMint.mint(msg.sender, s);
    }

    function mint() external payable onlyEoA canMint {
        if (!LibMint.isPublicSaleActive()) revert PrivateSaleNotActive();
        LibMint.setMinted(msg.sender);
        LibMint.mint(msg.sender, s);
    }

    function setPublicSale(bool active_) external {
        active_ ? LibMint.startPublicSale() : LibMint.stopPublicSale();
    }

    function setPrivateSale(bool active_) external {
        active_ ? LibMint.startPrivateSale() : LibMint.stopPrivateSale();
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import {AppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IBase} from "../interfaces/IBase.sol";
import {ISecurity} from "../interfaces/ISecurity.sol";


abstract contract Base is IBase {
    AppStorage internal s;
    uint256 private constant MAX_UINT = type(uint256).max;

    modifier onlyEoA() {
         // solhint-disable-next-line avoid-tx-origin
        if(tx.origin != msg.sender) revert CallerNotEoA();
        _;
    }

    modifier isTransferable() {
        if(!s.nftStorage.transfersEnabled) revert TransfersPaused();
        _;
    }

    modifier tokenLocked(uint256 tokenId) {
        if(s.nftStorage.lockedTokens[tokenId]) revert ISecurity.TokenLocked();
        _;
    }

    /// @notice check that a String is NOT NULL
    /// @dev Explain to a developer any extra details
    /// @param string_ the string to check
    modifier isEmpty(string calldata string_) {
        if (bytes(string_).length == 0 ) revert EmptyString();
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IMint {
    error InvalidProof();
    error InvalidETHAmount();
    error AlreadyClaimed();
    error AlreadyMinted();
    error ClaimingNotActive();
    error PrivateSaleNotActive();
    error TransferToNonERC721ReceiverImplementer();
    error InvalidTransferToZeroAddress();
    error MintZeroTokenId();
    error DoesNotMeetMintCondition();
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {LibMint} from "./LibMint.sol";

library LibMerkleProof {
    function verifyClaim(bytes32[] memory proof)
        internal
        view
        returns (bool)
    {
        return
            _verify(proof, LibMint.mintStorage().claimingMerkleRoot);
    }

    function verifyPrivateSale(bytes32[] memory proof)
        internal
        view
        returns (bool)
    {
        return
            _verify(proof, LibMint.mintStorage().privateSaleMerkleRoot);
    }

    function _verify(bytes32[] memory proof, bytes32 merkleRoot) private view returns (bool) {
        return MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender)));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {AppStorage} from "./LibAppStorage.sol";
import {IMint} from "../interfaces/IMint.sol";
import {IERC721Receiver} from "../interfaces/IERC721Receiver.sol";
import {IERC721} from "../interfaces/IERC721.sol";

library LibMint {
    struct MintStorage {
        uint256 price;
        uint256 supply;
        uint256 maxMintsPerTx;
        uint256 maxMintsPerAddress;
        bytes32 privateSaleMerkleRoot;
        bytes32 claimingMerkleRoot;
        bool claimingActive;
        bool publicSaleActive;
        bool privateSaleActive;
        mapping(address => bool) minted;
        address conditionContract;
        uint256 conditionAmount;
    }

    bytes32 private constant MINT_STORAGE_POSITION = keccak256("lol.momentum.mint");

    /// @notice Emitted when `tokenId` token is transferred from `from` to `to`.
    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    /// @param _from transfer address
    /// @param _to receiver address
    /// @param _tokenId the NFT transfered
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );

    function setPrice(uint256 price) internal {
        mintStorage().price = price;
    }

    function activateClaiming() internal {
        MintStorage storage ms = mintStorage();
        ms.claimingActive = true;
    }

    function deactivateClaiming() internal {
        MintStorage storage ms = mintStorage();
        ms.claimingActive = false;
    }

    function startPublicSale() internal {
        MintStorage storage ms = mintStorage();
        ms.publicSaleActive = true;
    }

    function stopPublicSale() internal {
        MintStorage storage ms = mintStorage();
        ms.publicSaleActive = false;
    }

    function startPrivateSale() internal {
        MintStorage storage ms = mintStorage();
        ms.privateSaleActive = true;
    }

    function stopPrivateSale() internal {
        MintStorage storage ms = mintStorage();
        ms.privateSaleActive = false;
    }

    function setClaimed(address user_) internal {
        mintStorage().minted[user_] = true;
    }

    function init(
        uint256 price,
        uint256 supply,
        uint256 maxMintsPerTx,
        uint256 maxMintsPerAddress,
        bytes32 privateSaleMerkleRoot,
        bytes32 claimingMerkleRoot,
        address conditionContract,
        uint256 conditionAmount
    ) internal {
        MintStorage storage ms = mintStorage();
        ms.price = price;
        ms.supply = supply;
        ms.maxMintsPerTx = maxMintsPerTx;
        ms.maxMintsPerAddress = maxMintsPerAddress;
        ms.privateSaleMerkleRoot = privateSaleMerkleRoot;
        ms.claimingMerkleRoot = claimingMerkleRoot;
        ms.conditionContract = conditionContract;
        ms.conditionAmount = conditionAmount;
    }

    function setMinted(address user_) internal {
        mintStorage().minted[user_] = true;
    }

    /// @notice Same as calling {safeMint} without data
    function safeMint(address _to,
        AppStorage storage s) internal {
        safeMint(_to, "", s);
    }

    /// @notice Same as calling {_mint} and then checking for IERC721Receiver
    function safeMint(
        address _to,
        bytes memory _data,
        AppStorage storage s
    ) internal {
        mint(_to, s);
        unchecked {
            if (_to.code.length != 0) {
                    if (
                        !_checkERC721Received(address(0), _to, s.nftStorage.nextTokenId - 1, _data)
                    ) {
                        revert IMint.TransferToNonERC721ReceiverImplementer();
                    }
            }
        }
    }

    /// @notice Mint a quantity of NFTs to an address
    /// @dev Saves the first token id minted by the address to a map of
    ///      used to verify ownership initially.
    ///      {s.nftStorage.tokenOwnersOrdered} will be used to find the owner unless the token
    ///      has been transfered. In that case, it will be available in {s.nftStorage.tokenOwners} instead.
    ///      This is done to reduce gas requirements of minting while keeping on-chain lookups
    ///      cheaper as tokens are transfered around. It helps with the burning of tokens.
    /// @param _to Receiver address
    function mint(address _to, AppStorage storage s) internal {
        if (_to == address(0)) revert IMint.InvalidTransferToZeroAddress();
        unchecked {
            s.nftStorage.balances[_to]++;
            s.nftStorage.tokenOwners[s.nftStorage.nextTokenId] = _to;
            emit Transfer(address(0), _to, s.nftStorage.nextTokenId);
            s.nftStorage.nextTokenId++;
        }
    }

    /// @notice Checking if the receiving contract implements IERC721Receiver
    /// @param from Token owner
    /// @param to Receiver
    /// @param tokenId The token id
    /// @param _data Extra data
    function _checkERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal returns (bool)
    {
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
            return retval == IERC721Receiver(to).onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert IMint.TransferToNonERC721ReceiverImplementer();
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    function meetsCondition(address user_) internal view returns (bool) {
        MintStorage storage ms = mintStorage();
        return IERC721(ms.conditionContract).balanceOf(user_) >= ms.conditionAmount;
    }

    function minted(address user_) internal view returns (bool) {
        return mintStorage().minted[user_];
    }

    function isClaimingActive() internal view returns (bool) {
        return mintStorage().claimingActive;
    }

    function isPrivateSaleActive() internal view returns (bool) {
        return mintStorage().privateSaleActive;
    }

    function isPublicSaleActive() internal view returns (bool) {
        return mintStorage().publicSaleActive;
    }

    function getPrice() internal view returns (uint256) {
        return mintStorage().price;
    }

    function claimed(address user_) internal view returns (bool) {
        return mintStorage().minted[user_];
    }

    function mintStorage() internal pure returns (MintStorage storage ms) {
        bytes32 position = MINT_STORAGE_POSITION;
        assembly {
            ms.slot := position
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

/// @title ITokenOwnershipFacet
/// @author Kfish n Chips
/// @dev Required interface of an ERC721 compliant contract.
/// @custom:security-contact [email protected]
interface ITokenOwnershipFacet  {
    error QueryBalanceOfZeroAddress();
    error QueryNonExistentToken();
    error QueryBurnedToken();

    function ownerOf(uint256 _tokenId) external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import {LibNFTStorage} from "./LibNFTStorage.sol";
import {LibRoyaltyStorage} from "./LibRoyaltyStorage.sol";

struct AppStorage {
    LibNFTStorage nftStorage;
    LibRoyaltyStorage royaltyStorage;
    mapping(uint256 => uint256) flaggedPasses;
    mapping(uint256 => uint256) reversedFlaggedPasses;
    uint256  flaggedPassHead;
    mapping(address => address)  flaggedAddresses;
    mapping(address => address)  reversedFlaggedAddresses;
    address  flaggedAddressHead;
    bool  isRefundingGas;
    uint256  maxRefundAmount;
    uint256  refundGasBuffer;
    uint256  flaggedAddressesCount;
    uint256  flaggedPassesCount;
    mapping(address => bool) adminTransferUsers;
    address operatorFilter;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamond Standard: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {LibMeta} from "./LibMeta.sol";

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint16 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array

    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint16 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // maps function selector to role based access control
        mapping(bytes4 => bytes32[]) selectorToAccessControl;
        // facet addresses
        address[] facetAddresses;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // Owner of the contract
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(LibMeta.msgSender() == diamondStorage().contractOwner, "LibDiamond: Must be contract owner");
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    function addDiamondFunctions(
        address _diamondCutFacet,
        address _diamondLoupeFacet,
        address _ownershipFacet
    ) internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);
        IDiamondCut.FunctionSelector[] memory functionSelectors = new IDiamondCut.FunctionSelector[](1);
        bytes32[] memory roles = new bytes32[](0);
        functionSelectors[0] = IDiamondCut.FunctionSelector(IDiamondCut.diamondCut.selector, roles);
        cut[0] = IDiamondCut.FacetCut({facetAddress: _diamondCutFacet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: functionSelectors});
        functionSelectors = new IDiamondCut.FunctionSelector[](5);
        functionSelectors[0] = IDiamondCut.FunctionSelector(IDiamondLoupe.facets.selector, roles);
        functionSelectors[1] = IDiamondCut.FunctionSelector(IDiamondLoupe.facetFunctionSelectors.selector, roles);
        functionSelectors[2] = IDiamondCut.FunctionSelector(IDiamondLoupe.facetAddresses.selector, roles);
        functionSelectors[3] = IDiamondCut.FunctionSelector(IDiamondLoupe.facetAddress.selector, roles);
        functionSelectors[4] = IDiamondCut.FunctionSelector(IERC165.supportsInterface.selector, roles);
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: _diamondLoupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        functionSelectors = new IDiamondCut.FunctionSelector[](2);
        functionSelectors[0] = IDiamondCut.FunctionSelector(IERC173.transferOwnership.selector, roles);
        functionSelectors[1] = IDiamondCut.FunctionSelector(IERC173.owner.selector, roles);
        cut[2] = IDiamondCut.FacetCut({facetAddress: _ownershipFacet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: functionSelectors});
        diamondCut(cut, address(0), "");
    }

    // Internal function version of diamondCut
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert("LibDiamondCut: Incorrect FacetCutAction");
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, IDiamondCut.FunctionSelector[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        // uint16 selectorCount = uint16(diamondStorage().selectors.length);
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint16 selectorPosition = uint16(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            enforceHasContractCode(_facetAddress, "LibDiamondCut: New facet has no code");
            ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = uint16(ds.facetAddresses.length);
            ds.facetAddresses.push(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex].selector;
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress == address(0), "LibDiamondCut: Can't add function that already exists");
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(selector);
            ds.selectorToFacetAndPosition[selector].facetAddress = _facetAddress;
            ds.selectorToFacetAndPosition[selector].functionSelectorPosition = selectorPosition;
            ds.selectorToAccessControl[selector] = _functionSelectors[selectorIndex].roles;
            selectorPosition++;
        }
    }

    function replaceFunctions(address _facetAddress, IDiamondCut.FunctionSelector[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint16 selectorPosition = uint16(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            enforceHasContractCode(_facetAddress, "LibDiamondCut: New facet has no code");
            ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = uint16(ds.facetAddresses.length);
            ds.facetAddresses.push(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex].selector;
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress != _facetAddress, "LibDiamondCut: Can't replace function with same function");
            removeFunction(oldFacetAddress, selector);
            // add function
            ds.selectorToFacetAndPosition[selector].functionSelectorPosition = selectorPosition;
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(selector);
            ds.selectorToFacetAndPosition[selector].facetAddress = _facetAddress;
            ds.selectorToAccessControl[selector] = _functionSelectors[selectorIndex].roles;
            selectorPosition++;
        }
    }

    function removeFunctions(address _facetAddress, IDiamondCut.FunctionSelector[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        // if function does not exist then do nothing and return
        require(_facetAddress == address(0), "LibDiamondCut: Remove facet address must be address(0)");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex].selector;
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(oldFacetAddress, selector);
        }
    }

    function removeFunction(address _facetAddress, bytes4 _selector) internal {
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamondCut: Can't remove function that doesn't exist");
        // an immutable function is a function defined directly in a diamond
        require(_facetAddress != address(this), "LibDiamondCut: Can't remove immutable function");
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint16(selectorPosition);
        }
        // delete the last selector
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = uint16(facetAddressPosition);
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }

        // delete role based access control of selector
        delete ds.selectorToAccessControl[_selector];
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            require(_calldata.length == 0, "LibDiamondCut: _init is address(0) but_calldata is not empty");
        } else {
            require(_calldata.length > 0, "LibDiamondCut: _calldata is empty but _init is not address(0)");
            if (_init != address(this)) {
                enforceHasContractCode(_init, "LibDiamondCut: _init address has no code");
            }
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (success == false) {
                if (error.length > 0) {
                    // bubble up the error
                    revert(string(error));
                } else {
                    revert("LibDiamondCut: _init function reverted");
                }
            }
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize != 0, _errorMessage);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IBase {
    error TransfersPaused();
    error CallerNotEoA();
    error EmptyString();
    /**
        RBAC
    */
    error CallerNotAuthorized();
    event TransfersLockedChanged(address indexed sender, bool locked);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface ISecurity {
    event PassFlagged(address indexed sender, uint256 tokenId);
    event PassUnflagged(address indexed sender, uint256 tokenId);
    event AddressFlagged(address indexed sender, address flaggedAddress);
    event AddressUnflagged(address indexed sender, address unflaggedAddress);
    event PassBurned(address indexed sender, uint256 tokenId);

    error TokenNotOwnedByFromAddress();
    error TokenLocked();
    error FlagZeroAddress();
    error AddressAlreadyFlagged();
    error AddressNotFlagged();
    error PassAlreadyFlagged();
    error PassNotFlagged();
    event TokensLocked(address indexed owner, uint256[] tokenIds);
    event TokensUnlocked(address indexed sender, address indexed owner, uint256[] tokenIds);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
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
     * @dev Calldata version of {verify}
     *
     * _Available since v4.7._
     */
    function verifyCalldata(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
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
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Calldata version of {processProof}
     *
     * _Available since v4.7._
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Returns true if the `leaves` can be proved to be a part of a Merkle tree defined by
     * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
     *
     * _Available since v4.7._
     */
    function multiProofVerify(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProof(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Calldata version of {multiProofVerify}
     *
     * _Available since v4.7._
     */
    function multiProofVerifyCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProofCalldata(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Returns the root of a tree reconstructed from `leaves` and the sibling nodes in `proof`,
     * consuming from one or the other at each step according to the instructions given by
     * `proofFlags`.
     *
     * _Available since v4.7._
     */
    function processMultiProof(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proof.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            return hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Calldata version of {processMultiProof}
     *
     * _Available since v4.7._
     */
    function processMultiProofCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proof.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            return hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @dev Note: the ERC-165 identifier for this interface is 0x150b7a02.
interface IERC721Receiver {
    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the recipient
    ///  after a `transfer`. This function MAY throw to revert and reject the
    ///  transfer. Return of other than the magic value MUST result in the
    ///  transaction being reverted.
    ///  Note: the contract address is always the message sender.
    /// @param _operator The address which called `safeTransferFrom` function
    /// @param _from The address which previously owned the token
    /// @param _tokenId The NFT identifier which is being transferred
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    ///  unless throwing
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    )
        external
        returns (bytes4);
}

// https://eips.ethereum.org/EIPS/eip-721, http://erc721.org/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @title ERC-721 Non-Fungible Token Standard
/// @dev See https://eips.ethereum.org/EIPS/eip-721
///  Note: the ERC-165 identifier for this interface is 0x80ac58cd.
interface IERC721 /* is ERC165 */ {
    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view returns (uint256);

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) external payable;

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external payable;

    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external;

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address);

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

interface ERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

struct LibNFTStorage {
    string name;
    string symbol;
    string baseURI;
    string contractURI;

    uint256 nextTokenId;
    uint256 startingTokenId;
    uint256 burnCounter;

    bool initialized;
    bool transfersEnabled;

    mapping(uint256 => bool) lockedTokens;
    mapping(uint256 => address) tokenOwners;
    mapping(uint256 => address) tokenOperators;
    mapping(uint256 => bool) burnedTokens;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => bool)) operators;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

struct LibRoyaltyStorage {
    uint256 denominator;
    uint256 numerator;
    address receiver;
    mapping(uint256 => uint256) tokenNumerators;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
/******************************************************************************/

interface IDiamondCut {
    enum FacetCutAction {Add, Replace, Remove}

    struct FunctionSelector {
        bytes4 selector;
        bytes32[] roles;
    }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        FunctionSelector[] functionSelectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// A loupe is a small magnifying glass used to look at diamonds.
// These functions look at diamonds
interface IDiamondLoupe {
    /// These functions are expected to be called frequently
    /// by tools.

    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all facet addresses and their four byte function selectors.
    /// @return facets_ Facet
    function facets() external view returns (Facet[] memory facets_);

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceId The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @title ERC-173 Contract Ownership Standard
///  Note: the ERC-165 identifier for this interface is 0x7f5828d0
/* is ERC165 */
interface IERC173 {
    /// @notice Get the address of the owner
    /// @return owner_ The address of the owner.
    function owner() external view returns (address owner_);

    /// @notice Set the address of the new owner of the contract
    /// @dev Set _newOwner to address(0) to renounce any ownership.
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

library LibMeta {
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(bytes("EIP712Domain(string name,string version,uint256 salt,address verifyingContract)"));

    function domainSeparator(string memory name, string memory version) internal view returns (bytes32 domainSeparator_) {
        domainSeparator_ = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes(version)), getChainID(), address(this))
        );
    }

    function getChainID() internal view returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    function msgSender() internal view returns (address sender_) {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender_ := and(mload(add(array, index)), 0xffffffffffffffffffffffffffffffffffffffff)
            }
        } else {
            sender_ = msg.sender;
        }
    }
}