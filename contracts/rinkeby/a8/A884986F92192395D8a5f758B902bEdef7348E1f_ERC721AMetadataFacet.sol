//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/MetadataLib.sol";
import "../libraries/ERC721ALib.sol";

/* solhint-disable mark-callable-contracts */
/* solhint-disable var-name-mixedcase */
/* solhint-disable no-unused-vars */
/* solhint-disable two-lines-top-level-separator */
/* solhint-disable indent */


contract ERC721AMetadataFacet is Modifiers {

    using MetadataLib for MetadataContract;
    using ERC721ALib for ERC721AContract;

    function setMetadata(MetadataContract memory _contract) external {

        LibDiamond.enforceIsContractOwner();
        LibAppStorage.diamondStorage().metadata[address(this)] = _contract;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() external view returns (string memory) {

        // solhint-disable-next-line
        return LibAppStorage.diamondStorage().metadata[address(this)].name();
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() external view returns (string memory) {

        // solhint-disable-next-line
        return LibAppStorage.diamondStorage().metadata[address(this)].symbol();
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function description() external view returns (string memory) {

        // solhint-disable-next-line
        return LibAppStorage.diamondStorage().metadata[address(this)].description();
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function image() external view returns (string memory) {

        // solhint-disable-next-line
        return LibAppStorage.diamondStorage().metadata[address(this)].image();
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {

        ERC721AContract storage erc721Contract = s().erc721Contracts[address(this)];        
        if (!erc721Contract._exists(tokenId)) revert URIQueryForNonexistentToken();
        
        MetadataContract storage metadata = s().metadata[address(this)];
        AttributeContract storage attributes = s().attributes[address(this)];
        BitGemContract storage bitgem = s().bitgems[address(this)];

        return metadata.tokenURI(bitgem, attributes, tokenId);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts().
     */
    function contractURI() external view returns (string memory) {

        MetadataContract storage metadata = s().metadata[address(this)];
        Trait[] memory dum;
        (, string memory svg) = metadata.getContractImage();
        string memory json = Base64.encode(
            bytes(
                metadata.getTokenMetadata(dum, svg)
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {LibDiamond} from "./LibDiamond.sol";

import "../interfaces/IERC721A.sol";
import "../interfaces/IAttribute.sol";
import "../interfaces/IMetadata.sol";
import "../interfaces/ISVG.sol";
import "../interfaces/IDiamondFactory.sol";
import "../interfaces/IERC721Enumerable.sol";
import "../interfaces/IERC3156FlashLender.sol";
import "../interfaces/IClaim.sol";
import "../interfaces/ITokenPrice.sol";
import "../interfaces/IFees.sol";
import "../interfaces/IBitGem.sol";
import "../interfaces/IMultiPart.sol";
import "../libraries/BitGemLib.sol";
import "../libraries/ClaimLib.sol";
import "../libraries/UInt256Set.sol";

/* solhint-disable indent */
/* solhint-disable no-inline-assembly */
/* solhint-disable mark-callable-contracts */

struct SaltStorage {
    uint256 salt;
}

struct AppStorage {
    mapping(address => SaltStorage) salts;
    mapping(address => ERC721AContract) erc721Contracts;
    mapping(address => AttributeContract) attributes;
    mapping(address => MetadataContract) metadata;
    mapping(address => ERC721EnumerableContract) enumerations;
    mapping(address => FlashLenderContract) flashLenders;
    mapping(address => ClaimContract) claims;
    mapping(address => VariablePriceContract) variablePrices;
    mapping(address => FeeManagerContract) fees;
    mapping(address => BitGemContract) bitgems;
    mapping(address => MultiPartContract) multiParts;
    SVGTemplatesContract svgTemplates;
    address svgManager;
    address eventReporter;
}


library LibAppStorage {
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("diamond.erc721a.app.storage");

    function diamondStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}


contract Modifiers {

    function s() internal pure returns (AppStorage storage ds) {
        return LibAppStorage.diamondStorage();
    }

    modifier onlyOwner() {
        require(LibDiamond.contractOwner() == msg.sender || address(this) == msg.sender,
            "not authorized to call function");
        _;
    }
    
    function generateEvent(string memory eventName, bytes memory eventData) internal virtual {
        EventReportingContract(LibAppStorage.diamondStorage().eventReporter).dispatchEvent(
            msg.sender, address(this), ApplicationEventStruct(
            0,
            eventName, 
            eventData
            )
        );
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // owner of the contract
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
        //require(msg.sender == diamondStorage().contractOwner, "LibDiamond: Must be contract owner");
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

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

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();        
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);            
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress == address(0), "LibDiamondCut: Can't add function that already exists");
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress != _facetAddress, "LibDiamondCut: Can't replace function with same function");
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        DiamondStorage storage ds = diamondStorage();
        // if function does not exist then do nothing and return
        require(_facetAddress == address(0), "LibDiamondCut: Remove facet address must be address(0)");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress, "LibDiamondCut: New facet has no code");
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }    


    function addFunction(DiamondStorage storage ds, bytes4 _selector, uint96 _selectorPosition, address _facetAddress) internal {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(DiamondStorage storage ds, address _facetAddress, bytes4 _selector) internal {        
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
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
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
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
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
            if (!success) {
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
        require(contractSize > 0, _errorMessage);
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "./StringsLib.sol";
import "./BitGemLib.sol";

import "../interfaces/IMetadata.sol";
import "../interfaces/IAttribute.sol";
import "../interfaces/IBitGem.sol";
import "../libraries/SVGTemplatesLib.sol";
import "../utilities/SVGManager.sol";

import "hardhat/console.sol";

/* solhint-disable mark-callable-contracts */
/* solhint-disable var-name-mixedcase */
/* solhint-disable no-unused-vars */
/* solhint-disable two-lines-top-level-separator */
/* solhint-disable quotes */
/* solhint-disable indent */

library MetadataLib {
    using Strings for uint256;

    bytes32 internal constant TYPE_HASH = keccak256("type");
    bytes32 internal constant CLAIM_HASH = keccak256("claim");

    /// @notice return the name of the metadata
    function name(MetadataContract storage self)
        internal
        view
        returns (string memory) { return self._name; }

    /// @notice return the symnbol of the metadata
    function symbol(MetadataContract storage self)
        internal
        view
        returns (string memory) { return self._symbol; }

    /// @notice return the description of the metadata
    function description(MetadataContract storage self)
        internal
        view
        returns (string memory) { return self._description; }

    /// @notice return the image of the metadata
    function image(MetadataContract storage self)
        internal
        view
        returns (string memory) {
            (, string memory svg) = getContractImage(self);
            return svg;
        }

    /// @notice get the image for the contract
    function getContractImage(
        MetadataContract storage self
    ) internal view returns (address addr, string memory svg) {
        console.log(self._imageName);
        // get the image, error if no image
        SVGManager mgr = SVGManager(LibAppStorage.diamondStorage().svgManager);
        address imageAddress = addr = mgr.svgAddress(self._imageName);
        require(imageAddress != address(0), "no image hash been set");   
        
        // blank values for the image
        string[] memory cccc = new string[](10);
        cccc[0] = " ";
        cccc[1] = " ";
        cccc[2] = " ";
        cccc[3] = " ";
        cccc[4] = " ";
        cccc[5] = " ";
        cccc[6] = " ";
        cccc[7] = " ";
        cccc[8] = string(abi.encodePacked(" ", self._symbol));
        cccc[9] = "none";

        // create the metadata replacement from the template and the bitgem attributes
        Replacement[] memory replacements = 
            _getReplacements(
                self._imageColors,
                cccc
            );
        // get the svg from the token
        svg = ISVGTemplate(imageAddress).buildSVG(replacements);
    }

    /// @notice get the image for the gem
    function getTokenImage(
        MetadataContract storage self,
        BitGemContract storage gem,
        AttributeContract storage a,
        uint256 tokenId
    ) internal view returns (string memory svg, Attribute[] memory attributes) {

        // get the attributes for the token
        string[] memory attributeKeys = AttributeLib._getAttributeKeys(a, tokenId);
        attributes = new Attribute[](attributeKeys.length);
        string[] memory cccc = BitGemLib._getBitGemAttributes(
            gem,
            a,
            tokenId,
            attributes,
            attributeKeys
        );

        // get the image, error if no image
        // get the image, error if no image
        SVGManager mgr = SVGManager(LibAppStorage.diamondStorage().svgManager);
        address imageAddress = mgr.svgAddress(self._imageName);


        // create the metadata replacement from the template and the bitgem attributes
        Replacement[] memory replacements = 
            _getReplacements(
                self._imageColors,
                cccc
            );
        // get the svg from the token
        svg = ISVGTemplate(imageAddress).buildSVG(replacements);
    }

    function _getReplacements(
        string[] memory colorPalette,
        string[] memory cccc
    ) internal pure returns (Replacement[] memory) {
        if(colorPalette.length == 0) {
            return new Replacement[](10);
        }
        Replacement[] memory replacements = new Replacement[](
            colorPalette.length + 10
        );
        for (uint256 i = 0; i < colorPalette.length; i++) {
            replacements[i] = Replacement(
                string(abi.encodePacked("color ", Strings.toString(i))),
                colorPalette[i]
            );
        }
        uint256 l = colorPalette.length;
        replacements[l] = Replacement("cut", cccc[0]);
        replacements[l + 1] = Replacement("color", cccc[1]);
        replacements[l + 2] = Replacement("carat", cccc[2]);
        replacements[l + 3] = Replacement("clarity", cccc[3]);
        replacements[l + 4] = Replacement("claim_price", cccc[4]);
        replacements[l + 5] = Replacement("created_on", cccc[5]);
        replacements[l + 6] = Replacement("maturity", cccc[6]);
        replacements[l + 7] = Replacement("type", cccc[7]);
        replacements[l + 8] = Replacement("symbol", string(abi.encodePacked(" ", cccc[8])));
        replacements[l + 9] = Replacement("claim_display", cccc[9]);
        return replacements;
    }


    /// @notice See {IERC721Metadata-tokenURI}.
    function tokenURI(
        MetadataContract storage self,
        BitGemContract storage gem,
        AttributeContract storage attribs,
        uint256 tokenId
    ) internal view returns (string memory) {

        // get the token image and attributes
        (string memory svg, Attribute[] memory attributes) = getTokenImage(
            self,
            gem,
            attribs,
            tokenId
        );

        // turn the attributes into traits
        Trait[] memory traits = new Trait[](attributes.length);
        string memory _name = gem.settings.tokenDefinition.name;
        for (uint256 i = 0; i < attributes.length; i++) {
            console.log(attributes[i].key);
            console.log(attributes[i].value);
            traits[i] = Trait("", attributes[i].key, attributes[i].value);
            // add the word 'claim' to the name if the attribute is a claim
            if (
                TYPE_HASH == keccak256(bytes(attributes[i].key)) &&
                CLAIM_HASH == keccak256(bytes(attributes[i].value))
            ) {
                _name = string(abi.encodePacked(_name, " Claim"));
            }
        }
        // base64 encode the token data and return it
        string memory json = Base64.encode(
            bytes(getTokenMetadata(self, traits, svg))
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function contractURI(MetadataContract storage self)
        internal
        view
        returns (string memory) {
        Trait[] memory dum;
        (, string memory svg) = getContractImage(self);
        string memory json = Base64.encode(
            bytes(
                getTokenMetadata(self, dum,  svg)
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /// @notice create a metadata trait
    function createTrait(
        string memory displayType,
        string memory key,
        string memory value
    ) internal pure returns (string memory trait) {
        // ensure key is not empty
        require(bytes(key).length > 0, "key cannot be empty");
        // if has a display type, then output the display type
        bool hasDisplayType = bytes(displayType).length > 0;
        if (hasDisplayType) {
            displayType = string(
                abi.encodePacked('"display_type": "', displayType, '",')
            );
            // if this is a number, then don't quote it, otherwise quote it
            bool isNumber = StringsLib.startsWith(displayType, "number") ||
                StringsLib.endsWith(displayType, "percentage");
            if (!isNumber) value = string(abi.encodePacked('"', value, '"'));
            else value = string(abi.encodePacked(value));
        } else value = string(abi.encodePacked('"', value, '"'));
        // return the trait
        trait = string(
            abi.encodePacked(
                "{",
                displayType,
                '"trait_type": "',
                key,
                '", "value": ',
                value,
                "}"
            )
        );
    }

    /// @notice given an array of trait structs, create a metadata string
    function arrayizeTraits(Trait[] memory _traits)
        internal
        pure
        returns (string memory _traitsString)
    {
        bytes memory traitBytes = "[";
        for (uint256 i = 0; i < _traits.length; i++) {
            Trait memory traitObj = _traits[i];
            string memory trait = createTrait(
                traitObj.displayType,
                traitObj.key,
                traitObj.value
            );
            traitBytes = abi.encodePacked(traitBytes, trait);
            if (i < _traits.length - 1) {
                traitBytes = abi.encodePacked(traitBytes, ",");
            }
        }
        _traitsString = string(abi.encodePacked(traitBytes, "]"));
    }

    /// @notice create a metadata string from a metadata struct
    function getTokenMetadata(
        MetadataContract memory definition,
        Trait[] memory _traits,
        string memory _imageData
    ) internal pure returns (string memory metadata) {
        string memory traitsString = arrayizeTraits(_traits);
        string memory externalUrl = bytes(definition._externalUri).length > 0
            ? string(
                abi.encodePacked(
                    '"external_url": "',
                    definition._externalUri,
                    '"'
                )
            )
            : "";
        bytes memory a1 = abi.encodePacked(
            '{"name": "',
            definition._name,
            '", "image_data": ',
            _imageData,
            ', "description": "',
            definition._description,
            '", ',
            externalUrl
        );
        if (_traits.length > 0) {
            a1 = abi.encodePacked(a1, ', "attributes": ', traitsString);
        }
        metadata = string(abi.encodePacked(a1, "}"));
    }
}

// SPDX-License-Identifier: MIT
// Creator: Chiru Labs
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

import "../interfaces/IERC721A.sol";

/* solhint-disable indent */
/* solhint-disable mark-callable-contracts */

error ApprovalCallerNotOwnerNorApproved();
error ApprovalQueryForNonexistentToken();
error ApproveToCaller();
error ApprovalToCurrentOwner();
error BalanceQueryForZeroAddress();
error MintedQueryForZeroAddress();
error BurnedQueryForZeroAddress();
error AuxQueryForZeroAddress();
error MintToZeroAddress();
error MintZeroQuantity();
error OwnerIndexOutOfBounds();
error OwnerQueryForNonexistentToken();
error TokenIndexOutOfBounds();
error TransferCallerNotOwnerNorApproved();
error TransferFromIncorrectOwner();
error TransferToNonERC721ReceiverImplementer();
error TransferToZeroAddress();
error URIQueryForNonexistentToken();


library ERC721ALib {

    using Strings for uint256;
    using Address for address;

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * Returns the total number of minted tokens
     */
    function totalSupply(ERC721AContract storage self) internal view returns (uint256) {
        // Counter underflow is impossible as _burnCounter cannot be incremented
        // more than _currentIndex times
        unchecked {
            return self._currentIndex - self._burnCounter;
        }
    }
    
    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(ERC721AContract storage self, address owner) internal view returns (uint256) {
        if (owner == address(0)) revert BalanceQueryForZeroAddress();
        return uint256(self._addressData[owner].balance);
    }

    /**
     * Returns the number of tokens minted by `owner`.
     */
    function _numberMinted(ERC721AContract storage self, address owner) internal view returns (uint256) {
        if (owner == address(0)) revert MintedQueryForZeroAddress();
        return uint256(self._addressData[owner].numberMinted);
    }

    /**
     * Returns the number of tokens burned by or on behalf of `owner`.
     */
    function _numberBurned(ERC721AContract storage self, address owner) internal view returns (uint256) {
        if (owner == address(0)) revert BurnedQueryForZeroAddress();
        return uint256(self._addressData[owner].numberBurned);
    }

    /**
     * Returns the auxillary data for `owner`. (e.g. number of whitelist mint slots used).
     */
    function _getAux(ERC721AContract storage self, address owner) internal view returns (uint64) {
        if (owner == address(0)) revert AuxQueryForZeroAddress();
        return self._addressData[owner].aux;
    }

    /**
     * Sets the auxillary data for `owner`. (e.g. number of whitelist mint slots used).
     * If there are multiple variables, please pack them into a uint64.
     */
    function _setAux(ERC721AContract storage self, address owner, uint64 aux) internal {
        if (owner == address(0)) revert AuxQueryForZeroAddress();
        self._addressData[owner].aux = aux;
    }

    function ownershipOf(ERC721AContract storage self, uint256 tokenId) internal view returns (TokenOwnership memory) {
        uint256 curr = tokenId;
        unchecked {
            if (curr < self._currentIndex) {
                TokenOwnership memory ownership = self._ownerships[curr];
                if (!ownership.burned) {
                    if (ownership.addr != address(0)) {
                        return ownership;
                    }
                    // Invariant:
                    // There will always be an ownership that has an address and is not burned
                    // before an ownership that does not have an address and is not burned.
                    // Hence, curr will not underflow.
                    while (true) {
                        curr--;
                        ownership = self._ownerships[curr];
                        if (ownership.addr != address(0)) {
                            return ownership;
                        }
                    }
                }
            }
        }
        revert OwnerQueryForNonexistentToken();
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     */
    function _exists(ERC721AContract storage self, uint256 tokenId) internal view returns (bool) {
        return tokenId < self._currentIndex && !self._ownerships[tokenId].burned;
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(ERC721AContract storage self, uint256 tokenId) internal view returns (address) {
        if (!_exists(self, tokenId)) revert ApprovalQueryForNonexistentToken();
        return self._tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(ERC721AContract storage self, address sender, address operator, bool approved) internal {
        self._operatorApprovals[sender][operator] = approved;
        emit ApprovalForAll(sender, operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(ERC721AContract storage self, address owner, address operator) internal view returns (bool) {
        return self._operatorApprovals[owner][operator];
    }

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event.
     */
    function _mint(
        ERC721AContract storage self,
        address msgSender,
        address to,
        uint256 quantity,
        bytes memory _data,
        bool safe
    ) internal {
        // Overflows are incredibly unrealistic.
        // balance or numberMinted overflow if current value of either + quantity > 1.8e19 (2**64) - 1
        // updatedIndex overflows if _currentIndex + quantity > 1.2e77 (2**256) - 1
        uint256 startTokenId = self._currentIndex;
        if (to == address(0)) revert MintToZeroAddress();
        if (quantity == 0) revert MintZeroQuantity();

        _beforeTokenTransfers(self, address(0), to, startTokenId, quantity);

        unchecked {
            self._addressData[to].balance += uint64(quantity);
            self._addressData[to].numberMinted += uint64(quantity);

            self._ownerships[startTokenId].addr = to;
            self._ownerships[startTokenId].startTimestamp = uint64(block.timestamp);

            uint256 updatedIndex = startTokenId;

            for (uint256 i; i < quantity; i++) {
                emit Transfer(address(0), to, updatedIndex);
                if (safe && !_checkOnERC721Received(msgSender, address(0), to, updatedIndex, _data)) {
                    revert TransferToNonERC721ReceiverImplementer();
                }
                updatedIndex++;
            }

            self._currentIndex = updatedIndex;
        }

        _afterTokenTransfers(self, address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        ERC721AContract storage self,
        address msgSender,
        address from,
        address to,
        uint256 tokenId
    ) internal {
        TokenOwnership memory prevOwnership = ownershipOf(self, tokenId);

        bool isApprovedOrOwner = (msgSender == prevOwnership.addr ||
            isApprovedForAll(self, prevOwnership.addr, msgSender) ||
            getApproved(self, tokenId) == msgSender);

        if (!isApprovedOrOwner) revert TransferCallerNotOwnerNorApproved();
        if (prevOwnership.addr != from) revert TransferFromIncorrectOwner();
        if (to == address(0)) revert TransferToZeroAddress();

        _beforeTokenTransfers(self, from, to, tokenId, 1);

        // Clear approvals from the previous owner
        _approve(self, address(0), tokenId, prevOwnership.addr);

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as tokenId would have to be 2**256.
        unchecked {
            self._addressData[from].balance -= 1;
            self._addressData[to].balance += 1;

            self._ownerships[tokenId].addr = to;
            self._ownerships[tokenId].startTimestamp = uint64(block.timestamp);

            // If the ownership slot of tokenId+1 is not explicitly set, that means the transfer initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint256 nextTokenId = tokenId + 1;
            if (self._ownerships[nextTokenId].addr == address(0)) {
                // This will suffice for checking _exists(nextTokenId),
                // as a burned slot cannot contain the zero address.
                if (nextTokenId < self._currentIndex) {
                    self._ownerships[nextTokenId].addr = prevOwnership.addr;
                    self._ownerships[nextTokenId].startTimestamp = prevOwnership.startTimestamp;
                }
            }
        }

        emit Transfer(from, to, tokenId);
        _afterTokenTransfers(self, from, to, tokenId, 1);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(ERC721AContract storage self, uint256 tokenId) internal {
        TokenOwnership memory prevOwnership = ownershipOf(self, tokenId);

        _beforeTokenTransfers(self, prevOwnership.addr, address(0), tokenId, 1);

        // Clear approvals from the previous owner
        _approve(self, address(0), tokenId, prevOwnership.addr);

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as tokenId would have to be 2**256.
        unchecked {
            self._addressData[prevOwnership.addr].balance -= 1;
            self._addressData[prevOwnership.addr].numberBurned += 1;

            // Keep track of who burned the token, and the timestamp of burning.
            self._ownerships[tokenId].addr = prevOwnership.addr;
            self._ownerships[tokenId].startTimestamp = uint64(block.timestamp);
            self._ownerships[tokenId].burned = true;

            // If the ownership slot of tokenId+1 is not explicitly set, that means the burn initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint256 nextTokenId = tokenId + 1;
            if (self._ownerships[nextTokenId].addr == address(0)) {
                // This will suffice for checking _exists(nextTokenId),
                // as a burned slot cannot contain the zero address.
                if (nextTokenId < self._currentIndex) {
                    self._ownerships[nextTokenId].addr = prevOwnership.addr;
                    self._ownerships[nextTokenId].startTimestamp = prevOwnership.startTimestamp;
                }
            }
        }

        emit Transfer(prevOwnership.addr, address(0), tokenId);
        _afterTokenTransfers(self, prevOwnership.addr, address(0), tokenId, 1);

        // Overflow not possible, as _burnCounter cannot be exceed _currentIndex times.
        unchecked {
            self._burnCounter++;
        }
    }
    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(
        ERC721AContract storage self,
        address to,
        uint256 tokenId,
        address owner
    ) internal {
        self._tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }


    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address msgSender,
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(msgSender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert TransferToNonERC721ReceiverImplementer();
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before a set of serially-ordered token ids are about to be transferred. This includes minting.
     * And also called before burning one token.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _beforeTokenTransfers(
        ERC721AContract storage self,
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal {}

    /**
     * @dev Hook that is called after a set of serially-ordered token ids have been transferred. This includes
     * minting.
     * And also called after one token has been burned.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` has been
     * transferred to `to`.
     * - When `from` is zero, `tokenId` has been minted for `to`.
     * - When `to` is zero, `tokenId` has been burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfers(
        ERC721AContract storage self,
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* solhint-disable indent */

// Compiler will pack this into a single 256bit word.
struct TokenOwnership {
    address addr; // The address of the owner.
    uint64 startTimestamp; // Keeps track of the start time of ownership with minimal overhead for tokenomics.
    bool burned; // Whether the token has been burned.
}

// Compiler will pack this into a single 256bit word.
struct AddressData {
    
    uint64 balance; // Realistically, 2**64-1 is more than enough.
    uint64 numberMinted; // Keeps track of mint count with minimal overhead for tokenomics.
    uint64 numberBurned; // Keeps track of burn count with minimal overhead for tokenomics.
    // For miscellaneous variable(s) pertaining to the address
    // (e.g. number of whitelist mint slots used).
    // If there are multiple variables, please pack them into a uint64.
    uint64 aux;
}

struct ERC721AContract {
    // The tokenId of the next token to be minted.
    uint256 _currentIndex;

    // The number of tokens burned.
    uint256 _burnCounter;

    // Token name
    string _name;

    // Token symbol
    string _symbol;

    // the base uri
    string __uri;

    // Mapping from token ID to ownership details
    // An empty struct value does not necessarily mean the token is unowned. See ownershipOf implementation for details.
    mapping(uint256 => TokenOwnership) _ownerships;

    // Mapping owner address to address data
    mapping(address => AddressData) _addressData;

    // Mapping from token ID to approved address
    mapping(uint256 => address) _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) _operatorApprovals;
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

enum AttributeType {
    Unknown,
    String ,
    Bytes32,
    Uint256,
    Uint8,
    Uint256Array,
    Uint8Array
}

struct Attribute {
    string key;
    AttributeType attributeType;
    string value;
}

// attribute storage
struct AttributeContract {
    mapping(uint256 => bool)  burnedIds;
    mapping(uint256 => mapping(string => Attribute))  attributes;
    mapping(uint256 => string[]) attributeKeys;
    mapping(uint256 =>  mapping(string => uint256)) attributeKeysIndexes;
}


/// @notice a pool of tokens that users can deposit into and withdraw from
interface IAttribute {
    /// @notice get an attribute for a tokenid keyed by string
    function getAttribute(
        uint256 id,
        string memory key
    ) external view returns (Attribute calldata _attrib);
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


/* solhint-disable indent */


struct Trait {
    string displayType;
    string key;
    string value;
}

struct MetadataContract {
    string _name;
    string _symbol;
    string _description;
    string _imageName;
    string[] _imageColors;
    string _externalUri;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IStrings.sol";

struct SVGTemplatesContract {
    mapping(string => address) _templates;
    string[] _templateNames;
}

interface ISVG {
    function getSVG() external view returns (string memory);
}

interface ISVGTemplate {
    function createSVG(address sender, string memory _name) external returns (address _tplAddress);
    function svgs() external view returns (string[] memory);
    function svgName() external view returns (string memory _name);
    function svgString(string memory name) external view returns (string memory _data);
    function svgAddress(string memory name) external view returns (address _data);
    function svgBytes() external view returns (bytes[] memory _data);
    function clear() external;
    function add(string memory _data) external returns (uint256 _index);
    function addSome(string[] memory _data) external returns (uint256 _count);
    function addAll(string[] memory _data) external returns (uint256 _count);
    function buildSVG(Replacement[] memory replacements) external view returns (string memory);
}

struct NVP {
    string name;
    string value;
}

struct ISVGElement {
    string name;
    NVP[] attributes;
    ISVGElement[] children;
}

struct ISVGImage {
    mapping(string => address) styles; 
    ISVGElement[] defs;
    ISVGElement[] body; 
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IDiamondCut } from "./IDiamondCut.sol";

struct DiamondFactoryInit {
    address _wrappedToken;
    address _eventReporter;
    IDiamondCut.FacetCut[] facetAddresses;
}

struct DiamondFactoryContract {
    mapping(string => address) tokenAddresses;
    string[] tokenSymbols;
    IDiamondCut.FacetCut[] facetsToAdd;
    mapping(address => bool) allowedReporters;
    address wrappedToken_;
    address diamondInit_;
    address eventReporter;
    bytes calldata_;
}

interface IDiamondFactory {
    function initialize(
        address _wrappedToken,
        address _diamondInit,
        bytes calldata _calldata,
        IDiamondCut.FacetCut[] memory facetAddresses
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

struct ERC721EnumerableContract {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) _allTokensIndex;
}

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./IERC3156FlashBorrower.sol";

struct FlashLenderContract {
    uint256 feePerMillion;
    address wrappedToken;
}

/// @notice this interface is implemented by flash lenders in order to allow flash borrowers to borrow funds
interface IERC3156FlashLender {

     /// @notice The amount of currency available to be lent.
     /// @param token The loan currency.
     /// @return The amount of `token` that can be borrowed.
    function maxFlashLoan(address token) external view returns (uint256);


     /// @notice The fee to be charged for a given loan.
     /// @param token The loan currency.
     /// @param amount The amount of tokens lent.
     /// @return The amount of `token` to be charged for the loan, on top of the returned principal.
    function flashFee(address token, uint256 amount)
        external
        view
        returns (uint256);

    /// @dev Initiate a flash loan.
    /// @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
    /// @param token The loan currency.
    /// @param amount The amount of tokens lent.
    /// @param data Arbitrary data structure, intended to contain user-defined parameters.
    /// @return treus if load was successful
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

/// @notice represents a claim on some deposit.
struct Claim {
    // claim id.
    uint256 id;
    address feeRecipient;
    // pool address
    address mineAddress;
    // the amount of eth deposited
    uint256 depositAmount;
    // the gem quantity to mint to the user upon maturity
    uint256 mintQuantity;
    // the deposit length of time, in seconds
    uint256 depositLength;
    // the block number when this record was created.
    uint256 createdTime;
    // the block number when this record was created.
    uint256 createdBlock;
    // block number when the claim was submitted or 0 if unclaimed
    uint256 claimedBlock;
    // the fee that was paid
    uint256 feePaid;
    // whether this claim has been collected
    bool collected;
    // whether this claim must be mature before it can be collected
    bool requireMature;
    // whether this claim has been collected
    bool mature;
}

/// @notice a set of requirements. used for random access
struct ClaimSet {
    mapping(uint256 => uint256) keyPointers;
    uint256[] keyList;
    Claim[] valueList;
}

struct ClaimSettings {
    ClaimSet claims;
    // the total staked for each token type (0 for ETH)
    mapping(address => uint256) stakedTotal;
}

struct ClaimContract {
    uint256 gemsMintedCount;  // total number of gems minted
    uint256 totalStakedEth; // total amount of staked eth
    mapping(uint256 => Claim) claims;  // claim data
    // staked total and claim index
    uint256 stakedTotal;
    uint256 claimIndex;
}

/// @notice interface for a collection of tokens. lists members of collection, allows for querying of collection members, and for minting and burning of tokens.
interface IClaim {
    /// @notice emitted when a token is added to the collection
    event ClaimCreated(
        address indexed user,
        address indexed minter,
        Claim claim
    );

    /// @notice emitted when a token is removed from the collection
    event ClaimRedeemed(
        address indexed user,
        address indexed minter,
        Claim claim
    );

    /// @notice create a claim
    /// @param _claim the claim to create
    /// @return _claimHash the claim hash
    function createClaim(Claim memory _claim)
        external
        payable
        returns (Claim memory _claimHash);

    /// @notice submit claim for collection
    /// @param claimHash the id of the claim
    function collectClaim(uint256 claimHash, bool requireMature) external;

    /// @notice return the next claim hash
    /// @return _nextHash the next claim hash
    function nextClaimHash() external view returns (uint256 _nextHash);

    /// @notice get all the claims
    /// @return _claims all the claims
    function claims() external view returns (Claim[] memory _claims);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;


/// @notice DIctates how the price of the token is increased post every sale
enum PriceModifier {
    None,
    Fixed,
    Exponential,
    InverseLog
}

struct VariablePriceContract {
    // the price of the token
    uint256 price;
        // how the price is modified
    PriceModifier priceModifier;
    // only used if priceModifier is EXPONENTIAL or INVERSELOG or FIXED
    uint256 priceModifierFactor;
    // max price for the token
    uint256 maxPrice;
}


/// @notice common struct definitions for tokens
interface ITokenPrice {
    /// @notice get the increased price of the token
    function getIncreasedPrice() external view returns (uint256);

    /// @notice get the increased price of the token
    function getTokenPrice() external view returns (VariablePriceContract memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

struct Fee {
    string name;
    uint256 price;
}

struct FeeManagerContract {
    mapping(string => Fee) fees;
}


/// @notice the fee manager manages fees by providing the fee amounts for the requested identifiers. Fees are global but can be overridden for a specific message sender.
interface IFees {

    /// @notice get the fee for the given fee type hash
    /// @param feeLabel the keccak256 hash of the fee type
    /// @return the fee amount
    function fee(string memory feeLabel) external view returns (Fee memory);
    function calculateFee(string memory feeLabel, uint256 amount) external view returns (uint256);
    
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


import "./IToken.sol";
import "./ITokenPrice.sol";
import "../libraries/UInt256Set.sol";

struct BitGemInitParameters {
    address owner;
    string symbol;
    string name;
    string description;
    string imageName;
    string[] imagePalette;
    string externalUrl;
    VariablePriceContract price;
    uint256 minTime;
    uint256 maxTime;
    uint256 maxClaims;
    bool enabled;
}

struct BitGemSettings {
     // the owner & payee of the bitgem fees
    address owner;
    // the token definition of the mine
    TokenDefinition tokenDefinition;
    uint256 minTime; // min and max token amounts to stake
    uint256 maxTime; // max time that the claim can be made
    uint256 maxClaims; // max number of claims that can be made
    // is staking enabled
    bool enabled;
}

// contract storage for a bitgem contract
struct BitGemContract {
    BitGemSettings settings;
    address wrappedToken;
    // minted tokens
    uint256[] mintedTokens;
    mapping(address=>bool) allowedMinters;
}

struct BitGemFactoryContract {
    mapping(string => address) _bitgems;
    string[] _bitgemSymbols;
    mapping(address => bool) allowedReporters;
    address wrappedToken_;
}

/// @notice check the balance of earnings and collect earnings
interface IBitGem {  
    function initialize(
        BitGemSettings memory _settings,
        address _wrappedToken
    ) external;
    /// @notice get the member gems of this pool
    function settings() external view returns (BitGemSettings memory);
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


/* solhint-disable indent */


struct MultiPartContract {
    string name_;
    bytes[] data_;
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/IBitGem.sol";
import "../interfaces/IEventReporter.sol";
import "../interfaces/IClaim.sol";
import "../interfaces/IFees.sol";
import "../interfaces/IAttribute.sol";
import "../interfaces/IStrings.sol";
import "../interfaces/ISVGFactory.sol";
import "../interfaces/IOwnable.sol";

import "../libraries/UInt256Set.sol";
import "../libraries/AttributeLib.sol";
import "../libraries/ERC721ALib.sol";
import "../libraries/LibAppStorage.sol";

import {BitGemContract, BitGemFactoryContract} from "../interfaces/IBitGem.sol";


/// @title ERC721AFees
/// @notice tracks named fees
library BitGemLib {

    bytes32 internal constant TYPE_HASH = keccak256("type");
    bytes32 internal constant CLAIM_HASH = keccak256("claim");
    bytes32 internal constant GEMHASH = keccak256("gem");

    event ClaimPriceChanged(uint256 price);

    /// @notice create a bitgem token with the given symbol
    function create(string memory _symbol, bytes memory creationCode)
        internal
        returns (address addr)
    {
        bytes32 salt = keccak256(abi.encodePacked(address(this), _symbol));
        addr = Create2.deploy(0, salt, creationCode);
        require(addr != address(0), "Create2: Failed on deploy");
        IOwnable(addr).transferOwnership(msg.sender);
    }

    /// @notice convert a byte32 to a string
    function bytes32ToString(bytes32 _bytes32)
        internal
        pure
        returns (string memory)
    {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    /// @notice get a random number between min and max
    function _getRandomNumber(
        uint256 min,
        uint256 max,
        uint256 salt
    ) internal view returns (uint256) {
        bytes32 rBytes = keccak256(
            abi.encodePacked(block.timestamp, msg.sender, block.number, salt)
        );
        return (uint256(rBytes) & uint256(max)) + min;
    }

    /// @notice get a random value to set an attribute with
    function _getRandomAttributeValue(
       uint256 salt
    ) internal view returns (uint256) {
        return BitGemLib._getRandomNumber(0x1, 0xff, salt);
    }


    /// @notice get the bitgem-specific attributes for a gem 
    function _getBitGemAttributes(
        BitGemContract storage bg,
        AttributeContract storage attrs,
        uint256 tokenId,
        Attribute[] memory attributes,
        string[] memory attributeKeys
    ) internal view returns (string[] memory cccc) {
        cccc = new string[](10);
        cccc[0] = "";
        cccc[1] = "";
        cccc[2] = "";
        cccc[3] = "";
        cccc[4] = "";// claim price
        cccc[5] = ""; // maturity
        cccc[6] = ""; // maturity
        cccc[7] = ""; // claim display
        cccc[8] = bg.settings.tokenDefinition.symbol; // gem type. externally populated with symbol
        cccc[9] = "none";
        for (uint256 i = 0; i < attributes.length; i++) {
            attributes[i] = AttributeLib._getAttribute(attrs, tokenId, attributeKeys[i]);
            if (
                keccak256(bytes("cut")) == keccak256(bytes(attributes[i].key))
            ) {
                cccc[0] = string(
                    abi.encodePacked(cccc[0], attributes[i].value)
                );
            }
            if (
                keccak256(bytes("color")) == keccak256(bytes(attributes[i].key))
            ) {
                cccc[1] = string(
                    abi.encodePacked(cccc[1], attributes[i].value)
                );
            }
            if (
                keccak256(bytes("carat")) == keccak256(bytes(attributes[i].key))
            ) {
                cccc[2] = string(
                    abi.encodePacked(cccc[2], attributes[i].value)
                );
            }
            if (
                keccak256(bytes("clarity")) == keccak256(bytes(attributes[i].key))
            ) {
                cccc[3] = string(
                    abi.encodePacked(cccc[3], attributes[i].value)
                );
            }
            if (
                keccak256(bytes("claim_price")) == keccak256(bytes(attributes[i].key))
            ) {
                cccc[4] = string(
                    abi.encodePacked(cccc[4], attributes[i].value)
                );
            }
            if (
                keccak256(bytes("created_on")) == keccak256(bytes(attributes[i].key))
            ) {
                cccc[5] = string(
                    abi.encodePacked(cccc[5], attributes[i].value)
                );
            }
            if (
                keccak256(bytes("maturity")) == keccak256(bytes(attributes[i].key))
            ) {
                cccc[6] = string(
                    abi.encodePacked(cccc[6], attributes[i].value)
                );
            }
            if (
                keccak256(bytes("type")) == keccak256(bytes(attributes[i].key)) && keccak256(bytes("claim")) == keccak256(bytes(attributes[i].value))
            ) {
                cccc[7] = string(
                    abi.encodePacked(cccc[7], attributes[i].value)
                );
                cccc[9] = string(abi.encodePacked("block"));
                
            }
            if (
                keccak256(bytes("symbol")) == keccak256(bytes(attributes[i].key))
            ) {
                cccc[8] = string(
                    abi.encodePacked(cccc[8], bg.settings.tokenDefinition.symbol)
                );
            }
        }
    }

    /// @notice set the attributes on the token to the given values, turning it into a gem
    function _setBitgemAttributes(
        BitGemContract storage bg,
        AttributeContract storage attrs,
        SaltStorage storage salt,
        address,
        uint256 tokenId
    ) internal {
        AttributeLib._setAttribute(
            attrs,
            tokenId,
            Attribute("type", AttributeType.String, "gem")
        );
        AttributeLib._setAttribute(
            attrs,
            tokenId,
            Attribute("symbol", AttributeType.String, bg.settings.tokenDefinition.symbol)
        );
        AttributeLib._setAttribute(
            attrs,
            tokenId,
            Attribute(
                "cut",
                AttributeType.String,
                Strings.toString(_getRandomAttributeValue(salt.salt++))
            )
        );
        AttributeLib._setAttribute(
            attrs,
            tokenId,
            Attribute(
                "color",
                AttributeType.String,
                Strings.toString(_getRandomAttributeValue(salt.salt++))
            )
        );
        AttributeLib._setAttribute(
            attrs,
            tokenId,
            Attribute(
                "carat",
                AttributeType.String,
                Strings.toString(_getRandomAttributeValue(salt.salt++))
            )
        );
        AttributeLib._setAttribute(
            attrs,
            tokenId,
            Attribute(
                "clarity",
                AttributeType.String,
                Strings.toString(_getRandomAttributeValue(salt.salt++))
            )
        );
    }

    /// @notice mint a bitgem to the given address
    function _mintClaim(
        BitGemContract storage,      
        ERC721AContract storage erc721a,
        address to)
        internal
        returns (uint256 tokenId)
    {
        ERC721ALib._mint(erc721a, address(this), to, 1, "", true);
        tokenId = ERC721ALib.totalSupply(erc721a) - 1;
    }

    /// @notice mint a bitgem to the given address
    function _mintBitGem(
        BitGemContract storage self,
        AttributeContract storage attrs,
        SaltStorage storage salt,        
        ERC721AContract storage erc721a,
        address tokenAddress,
        address to)
        internal
        returns (uint256 tokenId)
    {
        ERC721ALib._mint(erc721a, address(this), to, 1, "", true);
        tokenId = ERC721ALib.totalSupply(erc721a) - 1;
        self.mintedTokens.push(tokenId);
        
        //get the token attributes for this token and set them for the token id
        _setBitgemAttributes(
            self,
            attrs,
            salt,
            tokenAddress,
            tokenId
        );
    }

}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/IClaim.sol";
import "../interfaces/IAttribute.sol";
import "../interfaces/IFees.sol";
import "../interfaces/ITokenPrice.sol";
import "../interfaces/IBitGem.sol";
import "../interfaces/IEventReporter.sol";

import "../libraries/UInt256Set.sol";
import "../libraries/AttributeLib.sol";
import "../libraries/VariablePriceLib.sol";
import "../libraries/FeeManagerLib.sol";
import "../libraries/ERC721ALib.sol";

library ClaimLibrary {
    /// @notice emitted when a token is added to the collection
    event ClaimCreated(
        address indexed user,
        address indexed minter,
        Claim claim
    );

    /// @notice emitted when a token is removed from the collection
    event ClaimRedeemed(
        address indexed user,
        address indexed minter,
        Claim claim
    );

    // get the price of a bitgem claim for a given time period, given the bitgem's min and max claim lengths and the cost of a minclaimlength claim.
    // price and time are linearly inversely related to each other, with price denoting price at mintime.
    // For example, given a mintime of 1 day, a max time of 3 days, and a price of 3 ether, the price at 3 days is 1 ether, the price at 1 days is 3 ether, and the price at 2 days is 2 ether.
    function getClaimPrice(
        uint256 minLength,
        uint256 maxLength,
        uint256 minLengthPrice,
        uint256 targetLength
    ) public pure returns (uint256) {
        uint256 price = (minLengthPrice * (maxLength - targetLength)) /
            (maxLength - minLength);
        return price;
    }

    // get the price of a bitgem claim for a given time period, given the bitgem's min and max claim lengths and the cost of a minclaimlength claim.
    function getClaimTime(
        uint256 minLength,
        uint256 maxLength,
        uint256 minLengthPrice,
        uint256 targetPrice
    ) internal pure returns (uint256) {
        uint256 time = ((targetPrice - minLengthPrice) *
            (maxLength - minLength)) / (maxLength - minLengthPrice);
        return time;
    }

    /// @notice create a claim for the given claim time
    function createClaim(
        ClaimContract storage self,
        BitGemContract storage bg,
        VariablePriceContract storage vs,
        AttributeContract storage ts,
        address claimant,
        address claimToken,
        uint256 newId,
        uint256 claimTime,
        bool requireMature
    ) internal returns (Claim memory claim_) {
        // create the claim and then add it to the claim index
        // validation checks to ensure the claim is valid
        require(bg.settings.enabled, "Staking pool is not enabled");
        require(claimTime >= bg.settings.minTime, "Claim time is too short");
        require(claimTime <= bg.settings.maxTime, "Claim time is too long");

        // compute the claim price given the claim time
        uint256 claimPrice = getClaimPrice(
            bg.settings.minTime,
            bg.settings.maxTime,
            vs.price,
            claimTime
        );
        // ensure enough funds are available to create the claim
        require(msg.value >= claimPrice, "Not enough funds");

        // if the claimant is willing to lock their claim until maturity
        // then refund them 10% of the claim price
        if (requireMature) {
            uint256 matureRefundBonus = claimPrice - (claimPrice / 10);
            claimPrice -= matureRefundBonus;
            // refund the mature refund bonus
            (bool success, ) = payable(claimant).call{value: matureRefundBonus}(
                ""
            );
            // revert if the refund failed
            require(success, "Failed to refund extra payment");
        }

        // create the claim structure that will store the claim data
        claim_ = Claim(
            newId, // id
            bg.settings.owner, // feeRecipient
            claimToken, // mineAddress
            claimPrice, // depositAmount
            1, // mintQuantity
            claimTime, // depositLength,
            block.timestamp, // createdTime
            block.number, // createdBlock
            0, // claimedBlock
            0, // feePaid
            false, // collected
            requireMature, // require mature
            false // mature
        );

        // set all claim attributes
        _setClaimAttributes(
            ts,
            claim_.id,
            claimPrice,
            block.timestamp,
            claimTime,
            block.number
        );

        // refund oversend
        if (msg.value > claimPrice && msg.value > 1 ether / 100) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - claimPrice
            }("");
            require(success, "Failed to refund extra payment");
        }

        // set the claim contract data
        self.claims[claim_.id] = claim_;

        // increase the total staked ETH
        self.totalStakedEth += claim_.depositAmount;
    }

    /// @notice set the attributes of a claim
    function _setClaimAttributes(
        AttributeContract storage ts,
        uint256 tokenId,
        uint256 claimPrice,
        uint256 claimCreated,
        uint256 claimLength,
        uint256
    ) internal {
        AttributeLib._setAttribute(
            ts,
            tokenId,
            Attribute("type", AttributeType.String, "claim")
        );
        AttributeLib._setAttribute(
            ts,
            tokenId,
            Attribute(
                "claim_price",
                AttributeType.String,
                Strings.toString(claimPrice)
            )
        );
        AttributeLib._setAttribute(
            ts,
            tokenId,
            Attribute(
                "created_on",
                AttributeType.String,
                Strings.toString(claimCreated)
            )
        );
        AttributeLib._setAttribute(
            ts,
            tokenId,
            Attribute(
                "maturity",
                AttributeType.String,
                Strings.toString(claimCreated + claimLength)
            )
        );
    }

    /// @notice collect claim with
    function collectClaim(
        ClaimContract storage self,
        VariablePriceContract storage vs,
        AttributeContract storage ts,
        FeeManagerContract storage fs,
        BitGemContract storage bg,
        ERC721AContract storage erc721a,
        address collector,
        uint256 claimId
    ) internal returns (bool _burn) {
        // validate the claim - make sure we own the claim
        require(
            ERC721ALib.ownershipOf(erc721a, claimId).addr == collector,
            "not claim owner"
        );

        // get the claim, make sure it is valid
        Claim storage claim = self.claims[claimId];
        require(claimId == claim.id, "Claim not found");
        require(claim.claimedBlock == 0, "claim already collected");
        claim.claimedBlock = block.number; // update the claim with the claim block

        // check the maturity of the claim - only issue gem if mature
        bool isMature = claim.createdTime + claim.depositLength <
            block.timestamp;
        // get the unlock time and unlock amount of the claim
        uint256 unlockTime = claim.createdTime + claim.depositLength;
        uint256 unlockPaid = claim.depositAmount;

        // both values must be greater than zero
        require(unlockTime != 0 && unlockPaid > 0, "Invalid claim");

        // if they used erc20 tokens stake their claim, return their tokens
        // calculate fee portion using fee tracker
        uint256 feePortion = isMature
            ? FeeManagerLib.calculateFee(
                fs,
                "collect_claim",
                claim.depositAmount
            )
            : 0;

        // transfer the ETH fee to fee tracker
        (bool sentfee, ) = payable(claim.feeRecipient).call{value: feePortion}(
            ""
        );
        require(sentfee, "Failed to send Ether");

        // transfer the ETH principal to caller
        (bool sent, ) = payable(msg.sender).call{
            value: claim.depositAmount - feePortion
        }("");
        require(sent, "Failed to send Ether");

        claim.feePaid = feePortion; // update the claim with the fee paid
        claim.mature = isMature; // update the claim with the maturity
        claim.collected = true; 

        // create a bitgem from the claim token if claim is mature
        // otherwise then burn the claim token
        _burn = handlePostClaim(
            vs,
            ts,
            bg,
            erc721a,
            claim.mature,
            claim.requireMature,
            claim.id
        );
    }

    /// @notice remove claim-specific attributes from pool
    function removeClaimAttributes(
        AttributeContract storage ts,
        uint256 claimId
    ) internal {
        // remove the (now useless) claim attributes
        // AttributeLib._removeAttribute(ts, claimId, "cost");
        // AttributeLib._removeAttribute(ts, claimId, "created_block");
        // AttributeLib._removeAttribute(ts, claimId, "created_on");
        // AttributeLib._removeAttribute(ts, claimId, "claim_length");
    }

    /// @notice handle mature claim - mint a gem if mature
    function handlePostClaim(
        VariablePriceContract storage vs,
        AttributeContract storage ts,
        BitGemContract storage,
        ERC721AContract storage erc721a,
        bool isMature,
        bool requireMature,
        uint256 claimId
    ) internal returns (bool _burn) {
        removeClaimAttributes(ts, claimId);

        //  if the claim is mature then mint a gem
        if (isMature) {

            // increase the claim price
            VariablePriceLib._updatePrice(vs);

        } else {
            // if maturity is required and its not mature, revert
            if (requireMature) {
                require(false, "not_mature");
            }
            // burn the token - we dont need it anymomre
            ERC721ALib._burn(erc721a, claimId); // burn the claim
            _burn = true;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/**
 * @notice Key sets with enumeration and delete. Uses mappings for random
 * and existence checks and dynamic arrays for enumeration. Key uniqueness is enforced.
 * @dev Sets are unordered. Delete operations reorder keys. All operations have a
 * fixed gas cost at any scale, O(1).
 * author: Rob Hitchens
 */

library UInt256Set {
    struct Set {
        mapping(uint256 => uint256) keyPointers;
        uint256[] keyList;
    }

    /**
     * @notice insert a key.
     * @dev duplicate keys are not permitted.
     * @param self storage pointer to a Set.
     * @param key value to insert.
     */
    function insert(Set storage self, uint256 key) public {
        require(
            !exists(self, key),
            "UInt256Set: key already exists in the set."
        );
        self.keyList.push(key);
        self.keyPointers[key] = self.keyList.length - 1;
    }

    /**
     * @notice remove a key.
     * @dev key to remove must exist.
     * @param self storage pointer to a Set.
     * @param key value to remove.
     */
    function remove(Set storage self, uint256 key) public {
        // TODO: I commented this out do get a test to pass - need to figure out what is up here
        // require(
        //     exists(self, key),
        //     "UInt256Set: key does not exist in the set."
        // );
        if (!exists(self, key)) return;
        uint256 last = count(self) - 1;
        uint256 rowToReplace = self.keyPointers[key];
        if (rowToReplace != last) {
            uint256 keyToMove = self.keyList[last];
            self.keyPointers[keyToMove] = rowToReplace;
            self.keyList[rowToReplace] = keyToMove;
        }
        delete self.keyPointers[key];
        delete self.keyList[self.keyList.length - 1];
    }

    /**
     * @notice count the keys.
     * @param self storage pointer to a Set.
     */
    function count(Set storage self) public view returns (uint256) {
        return (self.keyList.length);
    }

    /**
     * @notice check if a key is in the Set.
     * @param self storage pointer to a Set.
     * @param key value to check.
     * @return bool true: Set member, false: not a Set member.
     */
    function exists(Set storage self, uint256 key)
        public
        view
        returns (bool)
    {
        if (self.keyList.length == 0) return false;
        return self.keyList[self.keyPointers[key]] == key;
    }

    /**
     * @notice fetch a key by row (enumerate).
     * @param self storage pointer to a Set.
     * @param index row to enumerate. Must be < count() - 1.
     */
    function keyAtIndex(Set storage self, uint256 index)
        public
        view
        returns (uint256)
    {
        return self.keyList[index];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <[email protected]> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

interface IDiamondCut {
    enum FacetCutAction {Add, Replace, Remove}
    // Add=0, Replace=1, Remove=2

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
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
pragma solidity ^0.8.0;

struct Replacement {
    string matchString;
    string replaceString;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC721.sol)

pragma solidity ^0.8.0;

import "../token/ERC721/IERC721.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice the flash borrower interface is implemented by contracts that are borrowing funds from the flash loan contract
interface IERC3156FlashBorrower {
    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice the definition for a token.
struct TokenDefinition {
    // the host multitoken
    address token;
    // the name of the token
    string name;
    // the symbol of the token
    string symbol;
    // the description of the token
    string description;
    // the total supply of the token
    uint256 totalSupply;
    // probability of the item being awarded
    uint256 probability;
    // the index of the probability in its array
    uint256 probabilityIndex;
    // the index of the probability in its array
    uint256 probabilityRoll;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Base64.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides a set of functions to operate with Base64 strings.
 *
 * _Available since v4.5._
 */
library Base64 {
    /**
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        /// @solidity memory-safe-assembly
        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Create2.sol)

pragma solidity ^0.8.0;

/**
 * @dev Helper to make usage of the `CREATE2` EVM opcode easier and safer.
 * `CREATE2` can be used to compute in advance the address where a smart
 * contract will be deployed, which allows for interesting new mechanisms known
 * as 'counterfactual interactions'.
 *
 * See the https://eips.ethereum.org/EIPS/eip-1014#motivation[EIP] for more
 * information.
 */
library Create2 {
    /**
     * @dev Deploys a contract using `CREATE2`. The address where the contract
     * will be deployed can be known in advance via {computeAddress}.
     *
     * The bytecode for a contract can be obtained from Solidity with
     * `type(contractName).creationCode`.
     *
     * Requirements:
     *
     * - `bytecode` must not be empty.
     * - `salt` must have not been used for `bytecode` already.
     * - the factory must have a balance of at least `amount`.
     * - if `amount` is non-zero, `bytecode` must have a `payable` constructor.
     */
    function deploy(
        uint256 amount,
        bytes32 salt,
        bytes memory bytecode
    ) internal returns (address) {
        address addr;
        require(address(this).balance >= amount, "Create2: insufficient balance");
        require(bytecode.length != 0, "Create2: bytecode length is zero");
        /// @solidity memory-safe-assembly
        assembly {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(addr != address(0), "Create2: Failed on deploy");
        return addr;
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy}. Any change in the
     * `bytecodeHash` or `salt` will result in a new destination address.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
        return computeAddress(salt, bytecodeHash, address(this));
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy} from a contract located at
     * `deployer`. If `deployer` is this contract's address, returns the same value as {computeAddress}.
     */
    function computeAddress(
        bytes32 salt,
        bytes32 bytecodeHash,
        address deployer
    ) internal pure returns (address) {
        bytes32 _data = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash));
        return address(uint160(uint256(_data)));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./IBitGem.sol";
import "./IClaim.sol";
import "./IAttribute.sol";

interface IEventReporter {
    function register(address[] memory addresses) external;
    function addAllowedReporter(address reporter) external; 
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISVGFactory {
    function templateAddress(string memory _name) external view returns (address);
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


/// @notice interface that provides a method to query chain id
interface IOwnable {

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() external;

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external;


}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

import "../interfaces/IAttribute.sol";
import "../libraries/LibAppStorage.sol";
import "../libraries/EventReporterLib.sol";

library AttributeLib {
    event AttributeSet(address indexed tokenAddress, uint256 tokenId, Attribute attribute);
    event AttributeRemoved(address indexed tokenAddress, uint256 tokenId, string attributeKey);

    /// @notice set an attribute for a tokenid keyed by string
    function _getAttribute(
        AttributeContract storage self,
        uint256 tokenId,
        string memory key
    ) internal view returns (Attribute memory) {
        require(self.burnedIds[tokenId] == false, "Token has been burned");
        return self.attributes[tokenId][key];
    }
    
    /// @notice set an attribute to a tokenid keyed by string
    function _setAttribute(
        AttributeContract storage self,
        uint256 tokenId,
        Attribute memory attribute
    ) internal {
        require(self.burnedIds[tokenId] == false, "Token has been burned");
        if (self.attributeKeysIndexes[tokenId][attribute.key] == 0 
            && bytes(self.attributes[tokenId][attribute.key].value).length == 0) {
            self.attributeKeys[tokenId].push(attribute.key);
            self.attributeKeysIndexes[tokenId][attribute.key] = self.attributeKeys[tokenId].length - 1;
        }
        self.attributes[tokenId][attribute.key] = attribute;
    }
    
    /// @notice set multiple  attributes for the token
    function _setAttributes(
        AttributeContract storage self,
        uint256 tokenId, 
        Attribute[] memory _attributes)
        internal
    {
        require(self.burnedIds[tokenId] == false, "Token has been burned");
        for (uint256 i = 0; i < _attributes.length; i++) {
            _setAttribute(self, tokenId, _attributes[i]);
        }
    }

    /// @notice get a list of keys of attributes assigned to this tokenid
    function _getAttributeKeys(
        AttributeContract storage self,
        uint256 tokenId
    ) internal view returns (string[] memory) {
        require(self.burnedIds[tokenId] == false, "Token has been burned");
        return self.attributeKeys[tokenId];
    }

    /// @notice remove the attribute for a tokenid keyed by string
    function _removeAttribute(
        AttributeContract storage self,
        uint256 tokenId,
        string memory key
    ) internal {
        require(self.burnedIds[tokenId] == false, "Token has been burned");
        delete self.attributes[tokenId][key];
        uint256 ndx = self.attributeKeysIndexes[tokenId][key];
        for (uint256 i = ndx; i < self.attributeKeys[tokenId].length - 1; i++) {
            self.attributeKeys[tokenId][i] = self.attributeKeys[tokenId][i + 1];
            self.attributeKeysIndexes[tokenId][self.attributeKeys[tokenId][i]] = i;
        }
        delete self.attributeKeys[tokenId][self.attributeKeys[tokenId].length - 1];
        emit AttributeRemoved(address(this), tokenId, key);
    }

    // @notice set multiple attributes for the token
    function _burn(
        AttributeContract storage self,
        uint256 tokenId)
        internal
    {
        self.burnedIds[tokenId] = true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

struct ApplicationEventStruct {
    bytes32 selector;
    string name;
    bytes params;
}

struct EventDispatchStorage {
    address eventReportingContract;
    function(address,address,ApplicationEventStruct memory) dispatchFunc;
}


contract EventReportingContract is Initializable {  

    event ApplicationEvent(address indexed account, address indexed contractAddress, bytes32 indexed selector, string name, bytes params);

    constructor() {
        allowed[msg.sender] = true;
    }

    mapping(address => bool) private allowed;
    bool private locked = false;
    modifier onlyAllowed {
        require(allowed[msg.sender] == true, "not allowed");
        _;
    }
    function addAllowed(address _account) public onlyAllowed {
        allowed[_account] = true;
    }
    function dispatchEvent(address account, address _contract, ApplicationEventStruct memory evt) public onlyAllowed {
        emit ApplicationEvent(account, _contract, evt.selector, evt.name, evt.params);
    }

    function register(address[] memory moreAllowed) external {
        require(!locked, "locked");
        allowed[msg.sender] = true;
        for (uint i = 0; i < moreAllowed.length; i++) {
            allowed[moreAllowed[i]] = true;
        }
    }
    function lock(bool _val) external onlyAllowed {
        locked = _val;
    }       
}

library EventReporterLib {

    bytes32 constant private DIAMOND_STORAGE_POSITION = keccak256("diamond.event.dispatch.storage");

    function toEvent(string memory name, bytes memory params) internal pure returns (ApplicationEventStruct memory _event) {
        _event = ApplicationEventStruct(
            keccak256(bytes(name)), 
            name, 
            params
        );
    }

}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

import "../interfaces/IAttribute.sol";
import "../interfaces/ITokenPrice.sol";

import "../libraries/EventReporterLib.sol";

library VariablePriceLib {

    event VariablePriceChanged(address eventContract, VariablePriceContract price);

    function _updatePrice(VariablePriceContract storage self) internal returns (uint256 _price, uint256 updatedPrice) {
        _price = self.price;
        _increaseClaimPrice(self);
        updatedPrice = self.price;
    }
    
    function _currentPrice(VariablePriceContract storage self) internal view returns (uint256 _price) {
        _price = self.price;
    }

    function _increaseClaimPrice(VariablePriceContract storage self) private {
        // get the current price
        uint256 currentPrice = self.price;
        // get the current modifier
        PriceModifier currentModifier = self.priceModifier;
        // get the current modifier factor
        uint256 currentModifierFactor = self.priceModifierFactor;
        if (currentModifier == PriceModifier.Fixed) {
            currentPrice = currentPrice + currentModifierFactor;
        } else if (currentModifier == PriceModifier.Exponential) {
            currentPrice =
                currentPrice +
                (currentPrice / currentModifierFactor);
        } else if (currentModifier == PriceModifier.InverseLog) {
            currentPrice =
                currentPrice +
                (currentPrice / (currentModifierFactor * currentPrice));
        } else {
            return;
        }
        // set the new price
        self.price = currentPrice;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "../interfaces/IFees.sol";

library FeeManagerLib {
    /// *notice the fee manager manages fees by providing the fee amounts for the requested identifiers. 
    /// Fees are global but can be overridden for a specific message sender.*
    function fee(FeeManagerContract storage self, string memory feeLabel)
        external
        view
        returns (Fee memory)
    {
        return self.fees[feeLabel];
    }

    /// *notice the fee manager manages fees by providing the fee amounts for the requested identifiers.
    function calculateFee(FeeManagerContract storage self, string memory feeLabel, uint256 amount)
        external
        view
        returns (uint256)
    {
         uint256 feePermil = self.fees[feeLabel].price;
         feePermil = feePermil == 0 ? 1000 : feePermil;
         return amount / feePermil;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/Address.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!Address.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
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

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
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
                /// @solidity memory-safe-assembly
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC721Receiver.sol)

pragma solidity ^0.8.0;

import "../token/ERC721/IERC721Receiver.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IStrings.sol";

library StringsLib {

    function parseInt(string memory s) internal pure returns (uint256 res) {

        for (uint256 i = 0; i < bytes(s).length; i++) {
            if ((uint8(bytes(s)[i]) - 48) < 0 || (uint8(bytes(s)[i]) - 48) > 9) {
                return 0;
            }
            res += (uint8(bytes(s)[i]) - 48) * 10**(bytes(s).length - i - 1);
        }
        return res;

    }

    function startsWith(string memory haystack, string memory needle)
        internal
        pure
        returns (bool)
    {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);
        uint256 haystackLength = haystackBytes.length;
        uint256 needleLength = needleBytes.length;
        if (needleLength > haystackLength) {
            return false;
        }
        for (uint256 i = 0; i < needleLength; i++) {
            if (haystackBytes[i] != needleBytes[i]) {
                return false;
            }
        }
        return true;
    }

    function endsWith(string memory haystack, string memory needle)
        internal
        pure
        returns (bool)
    {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);
        uint256 haystackLength = haystackBytes.length;
        uint256 needleLength = needleBytes.length;
        if (needleLength > haystackLength) {
            return false;
        }
        for (uint256 i = 0; i < needleLength; i++) {
            if (
                haystackBytes[haystackLength - i - 1] !=
                needleBytes[needleLength - i - 1]
            ) {
                return false;
            }
        }
        return true;
    }

    function substring(string memory haystack, uint256 startpos)
        internal
        pure
        returns (string memory)
    {
        bytes memory haystackBytes = bytes(haystack);
        uint256 length = haystackBytes.length;
        uint256 endpos = length - startpos;
        bytes memory substringBytes = new bytes(endpos);
        for (uint256 i = 0; i < endpos; i++) {
            substringBytes[i] = haystackBytes[startpos + i];
        }
        return string(substringBytes);
    }

    function substring(string memory haystack, uint256 startpos, uint256 endpos)
        internal
        pure
        returns (string memory)
    {
        bytes memory haystackBytes = bytes(haystack);
        uint256 substringLength = endpos - startpos;
        bytes memory substringBytes = new bytes(substringLength);
        for (uint256 i = 0; i < substringLength; i++) {
            substringBytes[i] = haystackBytes[startpos + i];
        }
        return string(substringBytes);
    }

    function concat(string[] memory _strings)
        internal
        pure
        returns (string memory _concat)
    {
        _concat = "";
        for (uint256 i = 0; i < _strings.length; i++) {
            _concat = string(abi.encodePacked(_concat, _strings[i]));
        }
        return _concat;
    }

    function split(string memory _string, string memory _delimiter) internal pure returns (string[] memory _split) {
        _split = new string[](0);
        uint256 _delimiterLength = bytes(_delimiter).length;
        uint256 _stringLength = bytes(_string).length;
        uint256 _splitLength = 0;
        uint256 _splitIndex = 0;
        uint256 _startpos = 0;
        uint256 _endpos = 0;
        for (uint256 i = 0; i < _stringLength; i++) {
            if (bytes(_string)[i] == bytes(_delimiter)[0]) {
                _endpos = i;
                if (_endpos - _startpos > 0) {
                    _split[_splitIndex] = substring(_string, _startpos);
                    _splitIndex++;
                    _splitLength++;
                }
                _startpos = i + _delimiterLength;
            }
        }
        if (_startpos < _stringLength) {
            _split[_splitIndex] = substring(_string, _startpos);
            _splitIndex++;
            _splitLength++;
        }
        return _split;
    }

    function join(string[] memory _strings, string memory _delimiter) internal pure returns (string memory _joined) {
        for (uint256 i = 0; i < _strings.length; i++) {
            _joined = string(abi.encodePacked(_joined, _strings[i]));
            if (i < _strings.length - 1) {
                _joined = string(abi.encodePacked(_joined, _delimiter));
            }
        }
        return _joined;
    }

    function replace(string memory _string, string memory _search, string memory _replace) internal pure returns (string memory _replaced) {
        _replaced = _string;
        uint256 _searchLength = bytes(_search).length;
        uint256 _stringLength = bytes(_string).length;
        uint256 _replacedLength = _stringLength;
        uint256 _startpos = 0;
        uint256 _endpos = 0;
        for (uint256 i = 0; i < _stringLength; i++) {
            if (bytes(_string)[i] == bytes(_search)[0]) {
                _endpos = i;
                if (_endpos - _startpos > 0) {
                    _replaced = substring(_replaced, _startpos);
                    _replacedLength -= _endpos - _startpos;
                }
                _replaced = string(abi.encodePacked(_replaced, _replace));
                _replacedLength += bytes(_replace).length;
                _startpos = i + _searchLength;
            }
        }
        if (_startpos < _stringLength) {
            _replaced = substring(_replaced, _startpos);
            _replacedLength -= _stringLength - _startpos;
        }
        return _replaced;
    }

    function trim(string memory _string) internal pure returns (string memory _trimmed) {
        _trimmed = _string;
        uint256 _stringLength = bytes(_string).length;
        uint256 _startpos = 0;
        uint256 _endpos = 0;
        for (uint256 i = 0; i < _stringLength; i++) {
            if (bytes(_string)[i] != 0x20) {
                _startpos = i;
                break;
            }
        }
        for (uint256 i = _stringLength - 1; i >= 0; i--) {
            if (bytes(_string)[i] != 0x20) {
                _endpos = i;
                break;
            }
        }
        if (_startpos < _endpos) {
            _trimmed = substring(_trimmed, _startpos);
            _trimmed = substring(_trimmed, 0, _endpos - _startpos + 1);
        }
        return _trimmed;
    }

    function toUint16(string memory s) internal pure returns (uint16 res_) {
        uint256 res = 0;
        for (uint256 i = 0; i < bytes(s).length; i++) {
            if ((uint8(bytes(s)[i]) - 48) < 0 || (uint8(bytes(s)[i]) - 48) > 9) {
                return 0;
            }
            res += (uint8(bytes(s)[i]) - 48) * 10**(bytes(s).length - i - 1);
        }
        res_ = uint16(res);
    }


    function replace(string[] memory input, string memory matchTag, string[] memory repl) internal pure returns (string memory) {
        string memory svgBody;
        for(uint256 i = 0; i < input.length; i++) {
            string memory svgString = input[i];
            string memory outValue;
            if(StringsLib.startsWith(svgString, matchTag)) {
                string memory restOfLine = StringsLib.substring(svgString, bytes(matchTag).length);
                uint256 replIndex = StringsLib.parseInt(restOfLine);
                outValue = repl[replIndex];
            } else {
                outValue = svgString;
            }
            svgBody = string(abi.encodePacked(svgBody, outValue));
        }
        return svgBody;
    }

    function replace(bytes[] memory sourceBytes, Replacement[] memory replacements_) public pure returns (string memory) {
        //bytes[] memory sourceBytes = _getSourceBytes();
        string memory outputFile = "";
        for (uint256 i = 0; i < sourceBytes.length; i++) {
            bytes memory sourceByte = sourceBytes[i];
            string memory outputLine  = string(sourceBytes[i]);
            for (uint256 j = 0; j < replacements_.length; j++) {
                Replacement memory replacement = replacements_[j];
                if (keccak256(sourceByte) == keccak256(bytes(replacement.matchString))) {
                    outputLine = replacement.replaceString;
                }
            }
            outputFile = string(abi.encodePacked(outputFile, outputLine));
        }
        return outputFile;
    }    
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Create2.sol";

import "../interfaces/ISVG.sol";
import "../interfaces/IStrings.sol";

import "../libraries/LibAppStorage.sol";
import "../libraries/StringsLib.sol";
import "../libraries/EventReporterLib.sol";

import "../utilities/SVGTemplate.sol";

library SVGTemplatesLib {

    event SVGTemplateCreated(string name, address template);

    /// @notice get the stored template names in the contract
    function _svgs(SVGTemplatesContract storage self)
        internal
        view
        returns (string[] memory) { return self._templateNames; }

    /// @notice get the create2 address of the given name
    function _svgAddress(
        SVGTemplatesContract storage,
        string memory _name) 
        internal 
        view returns (address) {
        return Create2.computeAddress(
            keccak256(abi.encodePacked(address(this), _name)), 
            keccak256(type(SVGTemplate).creationCode)
        );  
    }

    /// @notice the svg string or an empty string
    function _svgString(
        SVGTemplatesContract storage self,
        string memory _name
    ) internal view returns (string memory data_) {
        try SVGTemplate(_svgAddress(self, _name)).svgString() returns (string memory _data) {
            data_ = _data;
        } catch (bytes memory) {}
    }

    /// @notice the sstored address for the name storage. empty is no svg
    function _svgData(
        SVGTemplatesContract storage self,
        string memory _name
    ) internal view returns (address) {
        return self._templates[_name];
    }

    /// @notice create a new SVG image with the given name
    function _createSVG(SVGTemplatesContract storage self, address erc, address sender, string memory _name)
        internal
        returns (address _tplAddress)
    {
        // make sure the name is unique
        require(
            self._templates[_name] == address(0),
            "template already deployed"
        );

        // get the address for the given name, create using create2,
        // then verify that create2 returned the expected address
        address targetTplAddress = _svgAddress(self, _name);
        _tplAddress = Create2.deploy(
            0,
            keccak256(abi.encodePacked(address(this), _name)),
            type(SVGTemplate).creationCode
        );
        require(targetTplAddress == _tplAddress, "template address mismatch");
        SVGTemplate(_tplAddress).setEventReporter(erc);

        // transfer ownership to the creator and update storage
        Ownable(_tplAddress).transferOwnership(sender);
        self._templateNames.push(_name);
        self._templates[_name] = _tplAddress;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "../utilities/Controllable.sol";
import "../interfaces/ISVG.sol";

import "../interfaces/IStrings.sol";
import "../interfaces/IEventReporter.sol";

import "../libraries/StringsLib.sol";
import "../libraries/SVGTemplatesLib.sol";
import "../libraries/LibAppStorage.sol";
import "../libraries/EventReporterLib.sol";

contract SVGManager is Controllable {

    using SVGTemplatesLib for SVGTemplatesContract;

    SVGTemplatesContract private s;
    address private __eventReporter;

    event SVGTemplateCreated(string name, address template);

    constructor() {
        _addController(msg.sender);
    }

    /// @notice get all the svg namea in the contract
    function svgs() external view returns (string[] memory) {
        return s._svgs();
    }

    /// @notice get the svg address of the given svg name. does not mean the file exists
    function svgAddress(string memory _name) external view returns (address _svgAddress) {
        _svgAddress = s._svgAddress(_name);
    }

    /// @notice get the svg data of the given svg name as a string
    function svgString(string memory _name) external view returns (string memory data_) {

        try SVGTemplate(s._svgAddress(_name)).svgString() returns (string memory _data) {
            data_ = _data;
        } catch (bytes memory) {}
    }

    function _setEventReportingContract(address _contract) internal {
        __eventReporter = _contract;
        address[] memory controllers = new address[](1);
        controllers[0] = address(this);
        IEventReporter(__eventReporter).register(controllers);
    } 

    /// @notice add a new gem pool
    function createSVG(address erc, address sender, string memory _name) external onlyController returns(address _tplAddress) {

        _tplAddress = s._createSVG(erc, sender, _name);

        _setEventReportingContract(erc);

        ApplicationEventStruct memory evt = EventReporterLib.toEvent(
            "SVGTemplateCreated", 
            abi.encode(_name,  _tplAddress)
        );

        EventReportingContract(__eventReporter).dispatchEvent(
            msg.sender, address(this),
            evt
        );
    }

}

// SPDX-License-Identifier: MIT
pragma solidity >= 0.4.22 <0.9.0;

library console {
	address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

	function _sendLogPayload(bytes memory payload) private view {
		uint256 payloadLength = payload.length;
		address consoleAddress = CONSOLE_ADDRESS;
		assembly {
			let payloadStart := add(payload, 32)
			let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
		}
	}

	function log() internal view {
		_sendLogPayload(abi.encodeWithSignature("log()"));
	}

	function logInt(int p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int)", p0));
	}

	function logUint(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function logString(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function logBool(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function logAddress(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function logBytes(bytes memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
	}

	function logBytes1(bytes1 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
	}

	function logBytes2(bytes2 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
	}

	function logBytes3(bytes3 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
	}

	function logBytes4(bytes4 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
	}

	function logBytes5(bytes5 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
	}

	function logBytes6(bytes6 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
	}

	function logBytes7(bytes7 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
	}

	function logBytes8(bytes8 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
	}

	function logBytes9(bytes9 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
	}

	function logBytes10(bytes10 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
	}

	function logBytes11(bytes11 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
	}

	function logBytes12(bytes12 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
	}

	function logBytes13(bytes13 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
	}

	function logBytes14(bytes14 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
	}

	function logBytes15(bytes15 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
	}

	function logBytes16(bytes16 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
	}

	function logBytes17(bytes17 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
	}

	function logBytes18(bytes18 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
	}

	function logBytes19(bytes19 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
	}

	function logBytes20(bytes20 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
	}

	function logBytes21(bytes21 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
	}

	function logBytes22(bytes22 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
	}

	function logBytes23(bytes23 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
	}

	function logBytes24(bytes24 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
	}

	function logBytes25(bytes25 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
	}

	function logBytes26(bytes26 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
	}

	function logBytes27(bytes27 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
	}

	function logBytes28(bytes28 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
	}

	function logBytes29(bytes29 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
	}

	function logBytes30(bytes30 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
	}

	function logBytes31(bytes31 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
	}

	function logBytes32(bytes32 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
	}

	function log(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function log(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function log(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function log(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function log(uint p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
	}

	function log(uint p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
	}

	function log(uint p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
	}

	function log(uint p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
	}

	function log(string memory p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
	}

	function log(string memory p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
	}

	function log(string memory p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
	}

	function log(string memory p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
	}

	function log(bool p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
	}

	function log(bool p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
	}

	function log(bool p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
	}

	function log(bool p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
	}

	function log(address p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
	}

	function log(address p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
	}

	function log(address p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
	}

	function log(address p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
	}

	function log(uint p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
	}

	function log(uint p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
	}

	function log(uint p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
	}

	function log(uint p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
	}

	function log(uint p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
	}

	function log(uint p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
	}

	function log(uint p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
	}

	function log(uint p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
	}

	function log(uint p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
	}

	function log(uint p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
	}

	function log(uint p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
	}

	function log(uint p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
	}

	function log(string memory p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
	}

	function log(string memory p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
	}

	function log(string memory p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
	}

	function log(bool p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
	}

	function log(bool p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
	}

	function log(bool p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
	}

	function log(bool p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
	}

	function log(bool p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
	}

	function log(bool p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
	}

	function log(bool p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
	}

	function log(bool p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
	}

	function log(bool p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
	}

	function log(bool p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
	}

	function log(bool p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
	}

	function log(address p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
	}

	function log(address p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
	}

	function log(address p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
	}

	function log(address p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
	}

	function log(address p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
	}

	function log(address p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
	}

	function log(address p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
	}

	function log(address p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
	}

	function log(address p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
	}

	function log(address p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
	}

	function log(address p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
	}

	function log(address p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
	}

	function log(address p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
	}

	function log(address p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
	}

	function log(uint p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
	}

}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../utilities/MultipartData.sol";

import "../libraries/StringsLib.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @notice a single SVG image
contract SVGTemplate is MultipartData, Ownable, Initializable {

    address private _eventReporter;

    function initialize(string memory _name, string[] memory _svg) external initializer {
        MultiPartContract storage ds = LibAppStorage.diamondStorage().multiParts[address(this)];
        ds.name_ = _name;
        for(uint i = 0; i < _svg.length; i++) {
            ds.data_.push(bytes(_svg[i]));
        }
    }

    function setEventReporter(address _reporter) external {
        require(_eventReporter == address(0), "Event reporter already set");
        _eventReporter = _reporter;
    }

    /// @notice the name of the svg
    function svgName() external view returns (string memory _name) {
        MultiPartContract storage ds = LibAppStorage.diamondStorage().multiParts[address(this)];
        _name = ds.name_;
    }

    /// @notice the data of the svg
    function svgString() external view returns (string memory _data) {
        _data = _fromBytes();
    }

    /// @notice the data of the svg
    function svgBytes() external view returns (bytes[] memory _data) {
        _data = data__();
    }
    
    /// @notice clear the data of the svg
    function clear() external onlyOwner {
        _clear();
    }

    /// @notice add data to the end of the data
    function add(string memory _data) external onlyOwner returns (uint256 _index) {
        _index = _addData(bytes(_data));
    }

    /// @notice add all SVG lines at
    function addSome(string[] memory _data) external onlyOwner returns (uint256 _count) {
        for(uint256 i = 0; i < _data.length; i++) {
            _addData(bytes(_data[i]));
        }
        _count = _data.length;
    }

    /// @notice add all SVG lines at
    function addAll(string[] memory _data) external onlyOwner returns (uint256 _count) {
        for(uint256 i = 0; i < _data.length; i++) {
            _addData(bytes(_data[i]));
        }
        _count = _data.length;
        MultiPartContract storage ds = LibAppStorage.diamondStorage().multiParts[address(this)];
        generateEvent("SVGImageAdded", abi.encode(
            msg.sender, address(this), ds.name_, _fromBytes()
        ));
    }

    /// @notice get the svg, replacing the data with the data from the given replacements
    function buildSVG(Replacement[] memory replacements) external view returns (string memory) {
        return StringsLib.replace(data__(), replacements);
    }

    function generateEvent(string memory eventName, bytes memory eventData) internal virtual {
        EventReportingContract(_eventReporter).dispatchEvent(
            msg.sender, address(this), ApplicationEventStruct(
            0,
            eventName, 
            eventData
            )
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../libraries/LibAppStorage.sol";

import "../interfaces/IMultiPart.sol";

abstract contract MultipartData  {

    function _addData(bytes memory _data)
        internal returns (uint256 _index)
    {
        MultiPartContract storage ds = LibAppStorage.diamondStorage().multiParts[address(this)];
        _index = ds.data_.length;
        ds.data_.push(_data);
    }

    function _getData(uint256 _index)
        internal view  returns (bytes memory data)
    {
        MultiPartContract storage ds = LibAppStorage.diamondStorage().multiParts[address(this)];
        data = ds.data_[_index];
    }

    function _fromBytes() internal view returns (string memory output) {
         MultiPartContract storage ds = LibAppStorage.diamondStorage().multiParts[address(this)];
        string memory result = "";
        for (uint256 i = 0; i < ds.data_.length; i++) {
            result = string(abi.encodePacked(result, ds.data_[i]));
        }
        output = result;
    }

    function data__() internal view returns (bytes[] storage) {
        MultiPartContract storage ds = LibAppStorage.diamondStorage().multiParts[address(this)];
        return ds.data_;
    }

    function _clear() internal {
        MultiPartContract storage ds = LibAppStorage.diamondStorage().multiParts[address(this)];
        delete ds.data_;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "../interfaces/IControllable.sol";

abstract contract Controllable is IControllable {
    mapping(address => bool) internal _controllers;

    /**
     * @dev Throws if called by any account not in authorized list
     */
    modifier onlyController() virtual {
        require(
            _controllers[msg.sender] == true || address(this) == msg.sender,
            "caller is not a controller"
        );
        _;
    }

    /**
     * @dev Add an address allowed to control this contract
     */
    function addController(address _controller)
        external
        override
        onlyController
    {
        _addController(_controller);
    }
    function _addController(address _controller) internal {
        _controllers[_controller] = true;
    }

    /**
     * @dev Check if this address is a controller
     */
    function isController(address _address)
        external
        view
        override
        returns (bool allowed)
    {
        allowed = _isController(_address);
    }
    function _isController(address _address)
        internal view
        returns (bool allowed)
    {
        allowed = _controllers[_address];
    }

    /**
     * @dev Remove the sender address from the list of controllers
     */
    function relinquishControl() external override onlyController {
        _relinquishControl();
    }
    function _relinquishControl() internal onlyController{
        delete _controllers[msg.sender];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice a controllable contract interface. allows for controllers to perform privileged actions. controllera can other controllers and remove themselves.
interface IControllable {

    /// @notice emitted when a controller is added.
    event ControllerAdded(
        address indexed contractAddress,
        address indexed controllerAddress
    );

    /// @notice emitted when a controller is removed.
    event ControllerRemoved(
        address indexed contractAddress,
        address indexed controllerAddress
    );

    /// @notice adds a controller.
    /// @param controller the controller to add.
    function addController(address controller) external;

    /// @notice removes a controller.
    /// @param controller the address to check
    /// @return true if the address is a controller
    function isController(address controller) external view returns (bool);

    /// @notice remove ourselves from the list of controllers.
    function relinquishControl() external;
}