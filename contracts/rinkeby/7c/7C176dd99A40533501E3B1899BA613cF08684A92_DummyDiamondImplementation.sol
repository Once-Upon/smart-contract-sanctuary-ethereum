// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * This is a generated dummy diamond implementation for compatibility with
 * etherscan. For full contract implementation, check out the diamond on louper:
 * https://louper.dev/diamond/0x63C0Fd8Df1Ffe21eC9e9EbcD11Fb3e2e659f1977?network=goerli
 */

contract DummyDiamondImplementation {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function diamondCut(
        FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) external {}

    function facetAddress(bytes4 _functionSelector)
        external
        view
        returns (address facetAddress_)
    {}

    function facetAddresses()
        external
        view
        returns (address[] memory facetAddresses_)
    {}

    function facetFunctionSelectors(address _facet)
        external
        view
        returns (bytes4[] memory _facetFunctionSelectors)
    {}

    function facets() external view returns (Facet[] memory facets_) {}

    function supportsInterface(bytes4 _interfaceId)
        external
        view
        returns (bool)
    {}

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32) {}

    function OWNER_ROLE() external view returns (bytes32) {}

    function getRoleAdmin(bytes32 role) external view returns (bytes32) {}

    function grantRole(bytes32 role, address account) external {}

    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool)
    {}

    function owner() external view returns (address owner_) {}

    function renounceRole(bytes32 role, address account) external {}

    function revokeRole(bytes32 role, address account) external {}

    function transferOwnership(address _newOwner) external {}

    function allowListEnabled() external view returns (bool) {}

    function disableAllowList() external {}

    function enableAllowList() external {}

    function updateAllowList(bytes32 allowListRoot) external {}

    function airdrop() external view returns (bool) {}

    function approve(address to, uint256 tokenId) external {}

    function balanceOf(address owner) external view returns (uint256) {}

    function burn(uint256 tokenId) external {}

    function getApproved(uint256 tokenId) external view returns (address) {}

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool)
    {}

    function maxMintPerAddress() external view returns (uint256) {}

    function maxMintPerTx() external view returns (uint256) {}

    function maxSupply() external view returns (uint256) {}

    function mint(address to, uint256 quantity) external payable {}

    function mint(
        address to,
        uint256 quantity,
        bytes32[] memory merkleProof
    ) external payable {}

    function mint(address to) external payable {}

    function name() external view returns (string memory) {}

    function ownerOf(uint256 tokenId) external view returns (address) {}

    function price() external view returns (uint256) {}

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {}

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) external {}

    function setAirdrop(bool _airdrop) external {}

    function setApprovalForAll(address operator, bool approved) external {}

    function setAutomaticUSDConversion(bool _automaticUSDConversion) external {}

    function setIsPriceUSD(bool _isPriceUSD) external {}

    function setMaxMintPerAddress(uint256 _maxMintPerAddress) external {}

    function setMaxMintPerTx(uint256 _maxMintPerTx) external {}

    function setMaxSupply(uint256 _maxSupply) external {}

    function setName(string memory _name) external {}

    function setPrice(uint256 _price) external {}

    function setSymbol(string memory _symbol) external {}

    function setTokenURI(string memory tokenURI) external {}

    function symbol() external view returns (string memory) {}

    function tokenURI(uint256 tokenId) external view returns (string memory) {}

    function totalSupply() external view returns (uint256) {}

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {}

    function dummyImplementation() external view returns (address) {}

    function setDummyImplementation(address implementation) external {}

    function pause() external {}

    function paused() external view returns (bool) {}

    function unpause() external {}

    function addPayee(address account, uint256 shares_) external {}

    function payee(uint256 index) external view returns (address) {}

    function releasable(address account) external view returns (uint256) {}

    function releasable(address token, address account)
        external
        view
        returns (uint256)
    {}

    function release(address account) external {}

    function release(address token, address account) external {}

    function released(address token, address account)
        external
        view
        returns (uint256)
    {}

    function released(address account) external view returns (uint256) {}

    function shares(address account) external view returns (uint256) {}

    function totalReleased(address token) external view returns (uint256) {}

    function totalReleased() external view returns (uint256) {}

    function totalShares() external view returns (uint256) {}

    function contractURI() external view returns (string memory) {}

    function royaltyBurn(uint256 tokenId) external {}

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address, uint256)
    {}

    function setRoyalties(address recipient, uint96 feeNumerator) external {}

    function createEdition(
        string memory _name,
        uint256 _maxSupply,
        uint256 _price
    ) external {}

    function enableEditions() external {}

    function maxSupplyForEdition(uint256 _editionIndex)
        external
        view
        returns (uint256)
    {}

    function mintEdition(
        address _to,
        uint256 _quantity,
        uint256 _editionIndex
    ) external payable {}

    function priceForEdition(uint256 _editionIndex)
        external
        view
        returns (uint256)
    {}

    function setMaxSupplyEdition(uint256 _editionIndex, uint256 _maxSupply)
        external
    {}

    function setPriceEdition(uint256 _editionIndex, uint256 _price) external {}

    function totalSupplyForEdition(uint256 _editionIndex)
        external
        view
        returns (uint256)
    {}
}