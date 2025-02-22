// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'rocketpool/contracts/interface/RocketStorageInterface.sol';
import 'rocketpool/contracts/interface/token/RocketTokenRETHInterface.sol';
import 'rocketpool/contracts/interface/deposit/RocketDepositPoolInterface.sol';

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol';
// import "base64-sol/base64.sol"; //vaultURI

/**
 * @title SmartVault (version 0.3.7)
 * @dev This contract allows to safeguard your Digital Assets... 
 *
 * Roles:
 *  - Owner: the account who owns the assets to be protected, and can create and modify vaults.
 *  - Beneficiaries: the accounts, and respective percentages, who will receive the Inheritance.
 *  - Trustees: the accounts that can activate or validate Inheritance process.
 *  - Assets: contract token addresses that the owner can protect (Fungible and Non-fungible).
 *
 * Error Messages:
 *  - NDF: Not possible to send funds directly to this contract
 *  - OO: Only Owner can execute this action
 *  - OT: Only a Trustee can execute this action
 *  - VC: Vault state must be Created (or Canceled if modifying)
 *  - MP: You must send minimum price per Vault
 *  - 0BT: At least one Beneficiary and one Trustee must be configured
 *  - DUP: At least one asset is already configured in another Smart Vault (fungible or non-fungible)
 *  - TP: Total percentage must be 100%
 *  - NF: Not enough funds in this vault. Cannot withdraw minimum vault price
 *  - CP: Contract Paused
 */
contract SmartVault is ERC721PresetMinterPauserAutoId, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    enum status{Created, Paused, Canceled, Executed}                     //cast to 0, 1, 2, 3
    event vaultEvent(uint256 _vaultId, address _owner, uint256 _status);
    event vaultBalanceChanges(uint256 _vaultId, address _from, address _to, uint256 _amount, uint256 _actualBalance);

    struct smartVaultDef {
        address owner;                                              
        IERC20[] fungibleAssets;                                            //contract address
        mapping (uint256 => beneficiary) beneficiaries;                     //map to beneficiary struct
        uint256 numBeneficiaries;
        mapping (uint256 => nonfungibleAsset) nonfungibleAssets;            //map to nonfungibleAsset struct
        uint256 numNonFungibleAssets;
        address[] trustees;
        mapping (address => bool) isTrustee;                                //whitelist Trustee    
        SmartVault.status vaultState;
        uint256 requestExecTS;
        uint256 pauseDays;
    }

    struct beneficiary {
        address beneficiary;
        uint256 percentage;
    }

    struct nonfungibleAsset {
        IERC721 nonfungibleAddress;                                         //contract address
        uint256 tokenid;                                                    //External Non Fungible Asset
        address beneficiary;                                                //Specific beneficiary 1:1
    }

    mapping(uint256 => smartVaultDef) private smartVaults;
    mapping(address => mapping(IERC20 => bool)) private fungibleAssetsOfOwner;
    mapping(address => mapping(IERC721 => mapping(uint256 => bool))) private nonfungibleAssetsOfOwner;
    mapping(address => uint256[]) private vaultsOfTrustee;
    mapping(address => mapping(uint256 => uint256)) private vaultIsAtIndex; //Aux vaultsOfTrustee
    mapping(address => mapping(uint256 => uint256)) private vaultBalance;
    // mapping(uint256 => string) private vaultURI;                         //vaultURI
    uint256 private minVaultPrice;                                          //wei
    uint256 private processingFee;
    uint256 private trusteeIncentive;

    //UNISWAP
    address public constant _swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    //Rocketpool
    address public constant rocketStorageAddress = 0xd8Cd47263414aFEca62d6e2a3917d6600abDceB3;
    // Goerli
    address public constant wETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address public constant rETH = 0x178E141a0E3b34152f73Ff610437A7bf9B83267A;
    uint24 public constant poolFee = 3000;

    constructor(uint256 _minVaultPrice, uint256 _processingFee, uint256 _trusteeIncentive) ERC721PresetMinterPauserAutoId("Carapace Smart Vault", "CSV", "https://metadata.carapace.io/") {
        minVaultPrice = _minVaultPrice;
        processingFee = _processingFee;
        trusteeIncentive = _trusteeIncentive;
        mint(msg.sender);
        burn(0);
    }

    // fallback () external {
    //     revert("NDF");   
    // }

    modifier onlyVaultOwner(uint256 _vaultId) {
        require(smartVaults[_vaultId].owner == msg.sender, "OO");
        _;
    }

    modifier onlyVaultTrustees(uint256 _vaultId) {
        require(smartVaults[_vaultId].isTrustee[msg.sender], "OT");
        _;
    }

    // modifier onlyVaultReadyAndTrustees(uint256 _vaultId) {
    // //    require(!paused(), "CP");
    //     require(smartVaults[_vaultId].vaultState == status.Paused, "VC");
    //     require(smartVaults[_vaultId].isTrustee[msg.sender], "OT");
    // //    require((block.timestamp - smartVaults[_vaultId].requestExecTS) > smartVaults[_vaultId].pauseDays * 1 days ); 
    //     require((block.timestamp - smartVaults[_vaultId].requestExecTS) > smartVaults[_vaultId].pauseDays );  // uses seconds only for testing, remove to mainnet
    //     _;
    // }

    modifier onlyVaultReady(uint256 _vaultId) {
        require(!paused(), "CP");
        require(smartVaults[_vaultId].vaultState == status.Created, "VC");
        _;
    }

    //vaultURI
    //  function tokenURI(uint256 _vaultId) public view override returns (string memory) {
    //     require(_exists(_vaultId), "ERC721Metadata: URI query for nonexistent token");

    //     string memory baseURI = vaultURI[_vaultId];
    //     return bytes(baseURI).length > 0 ? baseURI : "";
    // }
    function approve(address to, uint256 tokenId) public virtual override {
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
    }

    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
    }

    // function getRoleMember(bytes32 role, uint256 index) public view override returns (address) {
    // }

    // function getRoleMemberCount(bytes32 role) public view override returns (uint256) {
    // }

    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
    }

    function renounceOwnership() public virtual override onlyOwner {
    }

    function renounceRole(bytes32 role, address account) public virtual override {
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
    }

    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
    }

    /**
     * @dev Create Smart Vault, creates and mint a new token ID (vault).
     * @param _fungibleAssets The addresses of the ERC20 contracts 
     * @param _beneficiaries The addresses of beneficiaries and respective percentages
     * @param _nonfungibleAssets The addresses of ERC721 contracts, token ID and specific beneficiary
     * @param _trustees The addresses of Trustees
     *
     * Requirements:
     *  - At least 1 beneficiary and 1 trustee must be configured;
     *  - One fungible or non-fungible asset can only be configured in one Vault (avoit executionSmartVault problems - % allowance);
     *  - Total percentage must be equal to 100
     *  - Minimum Vault Price
     */
    function createSmartVault(
        IERC20[] memory _fungibleAssets,
        beneficiary[] memory _beneficiaries,
        nonfungibleAsset[] memory _nonfungibleAssets,
        address[] memory _trustees
    ) public payable {
        uint256 _totalPercentage;
        uint256 i;
        uint256 _vaultId = ERC721PresetMinterPauserAutoId.getCurrentTokenId();

        require(msg.value >= minVaultPrice, "MP");
        require(_beneficiaries.length > 0 && _trustees.length > 0, "0BT");

        smartVaults[_vaultId].owner = msg.sender;
        smartVaults[_vaultId].requestExecTS = 0;
        smartVaults[_vaultId].pauseDays = 30; // receive value from request

        if (_fungibleAssets.length > 0 ) {        
            for (i=0;i<_fungibleAssets.length;i++){
                require(!fungibleAssetsOfOwner[msg.sender][_fungibleAssets[i]], "DUP");
                fungibleAssetsOfOwner[msg.sender][_fungibleAssets[i]] = true;
            }
            smartVaults[_vaultId].fungibleAssets = _fungibleAssets;
        }

        for (i=0;i<_beneficiaries.length;i++){
            smartVaults[_vaultId].beneficiaries[i] = _beneficiaries[i];
            smartVaults[_vaultId].numBeneficiaries++;
            _totalPercentage += _beneficiaries[i].percentage;
        }
        require(_totalPercentage == 100, "TP");

        if (_nonfungibleAssets.length > 0 ) {
            for (i=0;i<_nonfungibleAssets.length;i++){
                require(!nonfungibleAssetsOfOwner[msg.sender][_nonfungibleAssets[i].nonfungibleAddress][_nonfungibleAssets[i].tokenid], "DUP");
                nonfungibleAssetsOfOwner[msg.sender][_nonfungibleAssets[i].nonfungibleAddress][_nonfungibleAssets[i].tokenid] = true;
                smartVaults[_vaultId].nonfungibleAssets[i] = _nonfungibleAssets[i];
                smartVaults[_vaultId].numNonFungibleAssets++;
            }
        }

        for (i=0;i<_trustees.length;i++){
            smartVaults[_vaultId].isTrustee[_trustees[i]] = true;
            vaultIsAtIndex[_trustees[i]][_vaultId] = vaultsOfTrustee[_trustees[i]].length;
            vaultsOfTrustee[_trustees[i]].push(_vaultId);
        }
        smartVaults[_vaultId].trustees = _trustees;
        smartVaults[_vaultId].vaultState = status.Created;
        vaultBalance[msg.sender][_vaultId] += swapWETHtoRETH();

        // ROCKET POOL **************************************************************************************

        // // Check deposit amount
        // require(msg.value > 0, "Invalid deposit amount");
        // // Load contracts
        // address rocketDepositPoolAddress = RocketStorageInterface(rocketStorageAddress).getAddress(keccak256(abi.encodePacked("contract.address", "rocketDepositPool")));
        // RocketDepositPoolInterface rocketDepositPool = RocketDepositPoolInterface(rocketDepositPoolAddress);
        // address rocketETHTokenAddress = RocketStorageInterface(rocketStorageAddress).getAddress(keccak256(abi.encodePacked("contract.address", "rocketTokenRETH")));
        // RocketTokenRETHInterface rocketETHToken = RocketTokenRETHInterface(rocketETHTokenAddress);
        // // Forward deposit to RP & get amount of rETH minted
        // uint256 rethBalance1 = rocketETHToken.balanceOf(address(this));
        // rocketDepositPool.deposit{value: msg.value}();
        // uint256 rethBalance2 = rocketETHToken.balanceOf(address(this));
        // require(rethBalance2 > rethBalance1, "No rETH was minted");
        // uint256 rethMinted = rethBalance2 - rethBalance1;

        // END ROCKET POOL **************************************************************************************

        //vaultBalance[msg.sender][_vaultId] += rethMinted;

        //vaultURI
        // vaultURI[_vaultId] = string(
        //         abi.encodePacked(
        //             'data:application/json;base64,',
        //             Base64.encode(
        //                 bytes(
        //                     abi.encodePacked(
        //                         '{"name":"',
        //                         name(),
        //                         '", "description":"',
        //                         symbol(), _vaultId,
        //                         '", "image": "',
        //                         'data:image/svg+xml;base64,',
        //                         "iVBORw0KGgoAAAANSUhEUgAAAMgAAADICAYAAACtWK6eAAAAAXNSR0IArs4c6QAACQJJREFUeF7tnSFuHFsUBd+QoNAAM4eE2avIErIFA0OvxsBbmCUMjWTkBYSMuaUswMSRccOqka7S9fl5/06dd/rcjjKTw/PVzcca/N+Xbz/V6d7fTup5P45n9Tz7sD+/vqtHTvdD/bBrrUMBYUgLCONnP7DYNFt1AYFECwgDWEAYvzW90gsIM7iAMH4FBPLrHYQBbMVi/FYNwgDWIIxfDQL51SAMYA3C+NUgkF8NAgH2ks4A1iCMXw3C+NUgkF8NAgHWIAxgDcL41SCMXw0C+dUgEGANwgDWIIxfDcL41SCQXw0CAdYgDGANwvjVIIxfDQL51SAQYA3CANYgjF8NwvjVIJBfDQIB1iAMYA3C+NUgjF8NAvmNb5CX2wf1O+n2B97bXyeH920j3xs/e+M4FBB2Je0Vhk2zVRcQRrSAMH6rgDCANr8ahPmhq22D7QFrEEa0BmH8apBh/GoQaIgtr0EYUZtfAWF+6GrbYHvAVixGtBWL8WvFGsavBoGG2PIahBG1+RUQ5oeutg22B2zFYkRbsRi/Vqxh/GoQaIgtr0EYUZtfAWF+6GrbYHvAVixGtBWL8WvFGsavBoGG2PIahBG1+RUQ5oeutg22B2zFYkRbsRi/Vqxh/GoQaIgtr0EYUZtfAWF+6GrbYHvAVixGtBWL8WvFGsZPb5C/v7+q30mf/kSFfm7ke3tC2/zs82w/DgWEWWQbwqbZqntgMaIFhPHb3c/+QFwXl9sPrAICLbMNgeNs5DUII1pAGL8aBPKz5fYDq4BAh2xD4Dg1yPGsIiwgEGcBgQBlue1HAYEG2YbAcWqQGsS+Quy8AsL42WrbjxoEOmQbAsepQWoQ+wqx8woI42erbT9qEOiQbQgcpwapQewrxM4rIIyfrbb9qEGgQ7YhcJwapAaxrxA7r4Awfrba9qMGgQ7ZhsBxapAaxL5C7LwCwvjZatuPGgQ6ZBsCx6lBahD7CrHzCgjjZ6ttP2oQ6JBtCBynBrEbpH8Gml3J6V9I2luA9R9tKCAFhBFgavsBU0CYH7raNtgesAZhRPtdLMav38Uaxq8GgYbY8hqEEbX5FRDmh662DbYHbMViRFuxGL9WrGH8ahBoiC2vQRhRm18BYX7oattge8BWLEa0FYvxa8Uaxq8GgYbY8hqEEbX5FRDmh662DbYHbMViRFuxGL9WrGH8ahBoiC2vQRhRm18BYX7oattge8BWLEa0FYvxa8Uaxq8GgYbY8hqEEbX5FRDmh662DbYHbMViRFuxGL9WrGH8ahBoiC2vQRhRm58eEPufgWa4turX+zv1yPe3k3qebYg63Fpr+ue9fnyyP7J6nv6rJup0a60CwogWEMavgDB+qwZhAGsQxq8GgfxqEAawBmH8ahDIrwaBAHsHYQBrEMavBmH8ahDIrwaBAGsQBrAGYfxqEMavBoH8ahAIsAZhAGsQxq8GYfxqEMivBoEAaxAGsAZh/GoQxq8GgfxqEAiwBmEAaxDGrwZh/GoQyK8GgQBrEAawBmH8ahDGrwaB/GoQCLAGYQBrEMavBmH8ahDIrwaBAGsQBrAGYfz0BrG/hM8+3uXVe/tZncsTZf8H248CwvxYtiFwnI28BxYjWkAYvwIC+dly+4FVQKBDtiFwnBrkeFYRFhCIs4BAgLLc9qOAQINsQ+A4NUgNYl8hdl4BYfxste1HDQIdsg2B49QgNYh9hdh5BYTxs9W2HzUIdMg2BI5Tg9Qg9hVi5xUQxs9W237UINAh2xA4Tg1Sg9hXiJ1XQBg/W237UYNAh2xD4Dg1SA1iXyF2XgFh/Gy17UcNAh2yDYHj1CA1iH2F2HkFhPGz1bYfNQh0yDYEjlOD1CD2FWLnFRDGz1bbftQg0CHbEDhODWI3yPPVzYdpyt4uzN7+ldu9+XsoIOzxUEAYP1ttfwe/gECHCggEKMsLCARqAywg0BBZbvtbg0CDCggEKMsLCARqAywg0BBZbvtbg0CDCggEKMsLCARqAywg0BBZbvtbg0CDCggEKMsLCARqAywg0BBZbvtbg0CDCggEKMsLCARqAywg0BBZbvtbg0CDCggEKMsLCARqAywg0BBZbvtbg0CDCggEKMsLCARqAywg0BBZbvtbg0CDCggEKMsLCARqAywg0BBZbvtbg0CDCggEKMsLCARqAywg0BBZbvu7ux9tsC/09eOTbLF73Ov9nXrg+9tJPc8+zP7OfAGBDhUQCFCWFxAItAZhAGsQxm/ZOyAcZyMvIIxoAWH8CgjkZ8t7B2FEewdh/FbvIBCgLO8dBAJtxWIAW7EYv1YsyM+Wt2Ixoq1YjF8rFuRny1uxINFWLAawFYvxa8WC/Gx5KxYj2orF+LViQX62vBULEm3FYgBbsRi/VizIz5a3YjGirViMXysW5GfLW7Eg0VYsBrAVi/FrxYL8bHkrFiPaisX4tWJBfra8FQsSbcViAFuxGL9WLMjPlrdiMaLjVyy7MhmurXr6F8T2xs/+vAUEJqaAMIA2vwLC/NDVtsH2gPaFseez+dmftwaBjtsGw3E2cvvC2PPZ/OzPW0Cg47bBcJwCcjyrCAsIxFlAGECbXw3C/NDVtsH2gPaFseez+dmftwaBjtsGw3FasVqx7CvEzisgs/jVIMwPXV1AGFKbXwFhfuhq22B7QPvC2PPZ/OzP2zsIdNw2GI7TO0jvIPYVYucVkFn8ahDmh64uIAypza+AMD90tW2wPaB9Yez5bH725+0dBDpuGwzH6R2kdxD7CrHzCsgsfjUI80NXFxCG1OZXQJgfuto22B7QvjD2fDY/+/P2DgIdtw2G4/QOYr+DvNw+fJim2L96Yf8KiT2f/cQyvfg8yw7wdD/s+Q4FhF3JAsL42Q+sAsL8WLYhBYQZYvtRQJgfBQTysy9gAfnPDalBmMEFhPFb059YBYQZXEAYvwIC+fWnWAxgf4rF+K0ahAGsQRi/GgTyq0EYwBqE8atBIL8aBALsJZ0BrEEYvxqE8atBIL8aBAKsQRjAGoTxq0EYvxoE8qtBIMAahAGsQRi/GoTxq0EgvxoEAqxBGMAahPGrQRi/GgTyq0EgwBqEAaxBGL8ahPGrQSC/6Q3yDwJ+wtGhFq6FAAAAAElFTkSuQmCC",
        //                         '"}'
        //                     )
        //                 )
        //             )
        //         )
        //     );
        
        _setupRole(MINTER_ROLE, msg.sender);
        mint(msg.sender);         
        //revokeRole(MINTER_ROLE, msg.sender);
        emit vaultBalanceChanges(_vaultId, msg.sender, address(this), msg.value, vaultBalance[msg.sender][_vaultId]);
        emit vaultEvent(_vaultId, msg.sender, uint256(smartVaults[_vaultId].vaultState));
    }


    /**
     * @dev Add Balance, permit to add ETH balance to a vault.
     * @param _vaultId ID of the Vault
     *
     * Requirements:
     *  - Only the owner can cancel a vault;
     *  - Vault state must be Created;
     */
    function addBalance(uint256 _vaultId) public payable onlyVaultOwner(_vaultId) onlyVaultReady(_vaultId) {
        vaultBalance[msg.sender][_vaultId] += swapWETHtoRETH();
        emit vaultBalanceChanges(_vaultId, msg.sender, address(this), msg.value, vaultBalance[msg.sender][_vaultId]);
    }

    /**
     * @dev Withdraw, permits to transfer funds from a Vault to Owner.
     * @param _vaultId ID of the Vault
     * @param _amount amount to be transfered
     *
     * Requirements:
     *  - Only the owner can cancel a vault;
     *  - Vault state must be Created;
     *  - Amount must be equal or less than Owner's Vault Balance - minVaultPrice.
     */
    function withdraw(uint256 _vaultId, uint256 _amount) public onlyVaultOwner(_vaultId) onlyVaultReady(_vaultId) {
        uint256 _processingFee = _amount*processingFee/100;
        uint256 _returnDeposit = _amount-_processingFee;

        // Load contract
        address rocketETHTokenAddress = RocketStorageInterface(rocketStorageAddress).getAddress(keccak256(abi.encodePacked("contract.address", "rocketTokenRETH")));
        RocketTokenRETHInterface rocketETHToken = RocketTokenRETHInterface(rocketETHTokenAddress);

        require(rocketETHToken.getEthValue(vaultBalance[msg.sender][_vaultId]) - minVaultPrice >= rocketETHToken.getEthValue(_amount), "NF");

        vaultBalance[msg.sender][_vaultId] -= _amount;
        IERC20(rETH).safeTransfer(owner(), _processingFee);
        IERC20(rETH).safeTransfer(msg.sender, _returnDeposit);
        emit vaultBalanceChanges(_vaultId, address(this), msg.sender, _amount, vaultBalance[msg.sender][_vaultId]);
    }

    /**
     * @dev Reset Vault, internal function to clean all values associated to a Vault, keeping the original Owner and Deposit Balance
     * @param _vaultId ID of the Vault
     */
    function vaultReset(uint256 _vaultId) private {
        uint256 i;

        if (smartVaults[_vaultId].fungibleAssets.length > 0 ) {
            for (i=0;i<smartVaults[_vaultId].fungibleAssets.length;i++){
                fungibleAssetsOfOwner[smartVaults[_vaultId].owner][smartVaults[_vaultId].fungibleAssets[i]] = false;
            }
            smartVaults[_vaultId].fungibleAssets = new IERC20[](0);
        }

        for (i=0;i<smartVaults[_vaultId].numBeneficiaries;i++){
            delete smartVaults[_vaultId].beneficiaries[i];
        }
        smartVaults[_vaultId].numBeneficiaries = 0;

        if (smartVaults[_vaultId].numNonFungibleAssets > 0) {
            for (i=0;i<smartVaults[_vaultId].numNonFungibleAssets;i++) {
                nonfungibleAssetsOfOwner[smartVaults[_vaultId].owner][smartVaults[_vaultId].nonfungibleAssets[i].nonfungibleAddress][smartVaults[_vaultId].nonfungibleAssets[i].tokenid] = false;
                delete smartVaults[_vaultId].nonfungibleAssets[i];
            }
            smartVaults[_vaultId].numNonFungibleAssets = 0;
        }

        for (i=0;i<smartVaults[_vaultId].trustees.length;i++){
            smartVaults[_vaultId].isTrustee[smartVaults[_vaultId].trustees[i]] = false;
            delete vaultsOfTrustee[smartVaults[_vaultId].trustees[i]][vaultIsAtIndex[smartVaults[_vaultId].trustees[i]][_vaultId]];
        }
        smartVaults[_vaultId].trustees = new address[](0);    
    }

    /**
     * @dev Modify Smart Vault, changes the settings for one vault.
     * @param _vaultId ID of the Vault
     * @param _fungibleAssets The addresses of the ERC20 contracts
     * @param _beneficiaries The addresses of beneficiaries and respective percentages
     * @param _nonfungibleAssets The addresses of ERC721 contracts, token ID and specific beneficiary
     * @param _trustees The addresses of Trustees
     *
     * Requirements:
     *  - Only the owner can modifty settings;
     *  - Only possible to modify Vaults with status Created or Canceled;
     *  - At least 1 beneficiary and 1 trustee must be configured;
     *  - One fungible asset can only be configured in one Vault (avoit executionSmartVault problems - % allowance);
     *  - Total percentage must be equal to 100;
     */
    function modifySmartVault(
        uint256 _vaultId,
        IERC20[] memory _fungibleAssets,
        beneficiary[] memory _beneficiaries,
        nonfungibleAsset[] memory _nonfungibleAssets,
        address[] memory _trustees
    ) public onlyVaultOwner(_vaultId) onlyVaultReady(_vaultId) {
        uint256 _totalPercentage;
        uint256 i;
        
        require(_beneficiaries.length > 0 && _trustees.length > 0, "0BT");

        vaultReset(_vaultId);

        if (_fungibleAssets.length > 0) {
            for (i=0;i<_fungibleAssets.length;i++){
                require(!fungibleAssetsOfOwner[msg.sender][_fungibleAssets[i]], "DUP");
                fungibleAssetsOfOwner[msg.sender][_fungibleAssets[i]] = true;
            }
            smartVaults[_vaultId].fungibleAssets = _fungibleAssets;
        }

        for (i=0;i<_beneficiaries.length;i++){
            smartVaults[_vaultId].beneficiaries[i] = _beneficiaries[i];
            smartVaults[_vaultId].numBeneficiaries++;
            _totalPercentage += _beneficiaries[i].percentage;
        }
        require(_totalPercentage == 100, "TP");

        if (_nonfungibleAssets.length > 0 ) {
            for (i=0;i<_nonfungibleAssets.length;i++){
                require(!nonfungibleAssetsOfOwner[msg.sender][_nonfungibleAssets[i].nonfungibleAddress][_nonfungibleAssets[i].tokenid], "DUP");
                nonfungibleAssetsOfOwner[msg.sender][_nonfungibleAssets[i].nonfungibleAddress][_nonfungibleAssets[i].tokenid] = true;
                smartVaults[_vaultId].nonfungibleAssets[i] = _nonfungibleAssets[i];
                smartVaults[_vaultId].numNonFungibleAssets++;
            }
        }

        for (i=0;i<_trustees.length;i++){
            smartVaults[_vaultId].isTrustee[_trustees[i]] = true;
            vaultIsAtIndex[_trustees[i]][_vaultId] = vaultsOfTrustee[_trustees[i]].length;
            vaultsOfTrustee[_trustees[i]].push(_vaultId);
        }
        smartVaults[_vaultId].trustees = _trustees;
        smartVaults[_vaultId].vaultState = status.Created;
        
        emit vaultEvent(_vaultId, msg.sender, uint256(smartVaults[_vaultId].vaultState));
    }

    /**
     * @dev Cancel Smart Vault, cleans all configuration and burns the Vault ID.
     * @param _vaultId ID of the Vault
     *
     * Requirements:
     *  - Only the owner can cancel a vault;
     *  - Vault state must be Created;
     */
    // function cancelSmartVault(uint256 _vaultId) public onlyVaultOwner(_vaultId) onlyVaultReady(_vaultId) { 

    //     uint256 _processingFee = vaultBalance[msg.sender][_vaultId]*processingFee/100;
    //     uint256 _returnDeposit = vaultBalance[msg.sender][_vaultId]-_processingFee;
        
    //     vaultBalance[msg.sender][_vaultId] = 0;
    //     vaultReset(_vaultId);
    //     smartVaults[_vaultId].vaultState = status.Canceled;


    //    IERC20(rETH).safeTransfer(owner(), _processingFee);
    //    IERC20(rETH).safeTransfer(smartVaults[_vaultId].owner, _returnDeposit);
       
    //    //payable(smartVaults[_vaultId].owner).transfer(_returnDeposit);
    //     //payable(owner()).transfer(_processingFee);

    //     emit vaultBalanceChanges(_vaultId, address(this), msg.sender, _returnDeposit, vaultBalance[msg.sender][_vaultId]);
    //     //emit vaultBalanceChanges(_vaultId, address(this), owner(), _processingFee, vaultBalance[msg.sender][_vaultId]);
    //     emit vaultEvent(_vaultId, msg.sender, uint256(smartVaults[_vaultId].vaultState));
    // }

    /**
     * @dev Distribute Fungible Assets, internal function that verifies the minimum of "Allowance" and "BalanceOf" each token,
     * and distributes the value for each Beneficiary based on their configured percentages.
     * @param _vaultId ID of the Vault
     */
    function distributeFungibleAssets(uint256 _vaultId) private {
        uint256 i;
        uint256 j;
        uint256 _valueToDistribute;
        
        if (smartVaults[_vaultId].fungibleAssets.length > 0) {
            for (i=0;i<smartVaults[_vaultId].fungibleAssets.length;i++) {
                _valueToDistribute = smartVaults[_vaultId].fungibleAssets[i].balanceOf(smartVaults[_vaultId].owner)
                                .min(smartVaults[_vaultId].fungibleAssets[i].allowance(smartVaults[_vaultId].owner, address(this)));
                if (_valueToDistribute > 0) {
                    for (j=0;j<smartVaults[_vaultId].numBeneficiaries;j++) {    
                        smartVaults[_vaultId].fungibleAssets[i].safeTransferFrom(
                            smartVaults[_vaultId].owner,
                            smartVaults[_vaultId].beneficiaries[j].beneficiary,
                            _valueToDistribute*smartVaults[_vaultId].beneficiaries[j].percentage/100
                        );
                    }
                }
                fungibleAssetsOfOwner[smartVaults[_vaultId].owner][smartVaults[_vaultId].fungibleAssets[i]] = false;
            }
        }
    }

    /**
     * @dev Distribute Non-Fungible Assets, internal function that distributes each non-fungible asset to the specific
     * Beneficiary configured.
     * @param _vaultId ID of the Vault
     */
    function distributeNonFungibleAssets(uint256 _vaultId) private {
        uint256 i;

        if (smartVaults[_vaultId].numNonFungibleAssets > 0) {
            for (i=0;i<smartVaults[_vaultId].numNonFungibleAssets;i++) {
                if (smartVaults[_vaultId].nonfungibleAssets[i].nonfungibleAddress.getApproved(smartVaults[_vaultId].nonfungibleAssets[i].tokenid) == address(this) ||
                    smartVaults[_vaultId].nonfungibleAssets[i].nonfungibleAddress.isApprovedForAll(smartVaults[_vaultId].owner, address(this))) {
                        smartVaults[_vaultId].nonfungibleAssets[i].nonfungibleAddress.safeTransferFrom(
                        smartVaults[_vaultId].owner,
                        smartVaults[_vaultId].nonfungibleAssets[i].beneficiary,
                        smartVaults[_vaultId].nonfungibleAssets[i].tokenid);
                }
            nonfungibleAssetsOfOwner[smartVaults[_vaultId].owner][smartVaults[_vaultId].nonfungibleAssets[i].nonfungibleAddress][smartVaults[_vaultId].nonfungibleAssets[i].tokenid] = false;
            }
        }
    }
    /**
     * @dev Request Smart Vault execution, register request timestamp
     * @param _vaultId ID of the Vault
     *
     * Requirements:
     *  - Vault state must be Created; 
     *  - Only the Trustees can request a vault execution;
     */
    function requestExecution(uint256 _vaultId) public onlyVaultTrustees(_vaultId) {
        require(smartVaults[_vaultId].vaultState == status.Created, "VC");
        smartVaults[_vaultId].vaultState = status.Paused;
        smartVaults[_vaultId].requestExecTS = block.timestamp;
    }
    /**
     * @dev Stop request. Cancels the request for Smart Vault execution, returns to origin state
     * @param _vaultId ID of the Vault
     *
     * Requirements:
     *  - Vault state must be Paused; 
     *  - Only the Owner can request a stop execution;
     */
    function stopRequest(uint256 _vaultId) public onlyVaultOwner(_vaultId) {
        require(smartVaults[_vaultId].vaultState == status.Paused, "VP");
        smartVaults[_vaultId].vaultState = status.Created;
        smartVaults[_vaultId].requestExecTS = 0;
    }

    /**
     * @dev Execute Smart Vault, distributes Fungible, Non-Fugible assets, and vault´s deposit Balance.
     * @param _vaultId ID of the Vault
     *
     * Requirements:
     *  - Vault state must be Created; 
     *  - Only the Trustees can execute a vault;
     */
    function executeSmartVault(uint256 _vaultId) public onlyVaultTrustees(_vaultId) {
        require(smartVaults[_vaultId].vaultState == status.Paused, "VP");
    //    require((block.timestamp - smartVaults[_vaultId].requestExecTS) > smartVaults[_vaultId].pauseDays * 1 days ); 
        require((block.timestamp - smartVaults[_vaultId].requestExecTS) > smartVaults[_vaultId].pauseDays );  // uses seconds only for testing, remove to mainnet

        uint256 j;
        uint256 _processingFee = vaultBalance[smartVaults[_vaultId].owner][_vaultId]*processingFee/100;
        uint256 _trusteeIncentiveValue = vaultBalance[smartVaults[_vaultId].owner][_vaultId]*trusteeIncentive/100;
        uint256 _totalBalanceToDistribute = vaultBalance[smartVaults[_vaultId].owner][_vaultId]-(_processingFee+_trusteeIncentiveValue);
        uint256 _partialBalanceToDistribute;

        distributeFungibleAssets(_vaultId);
        
        distributeNonFungibleAssets(_vaultId);
        
        //distribute Balance
        //payable(owner()).transfer(_processingFee);
        //payable(msg.sender).transfer(_trusteeIncentiveValue);

        IERC20(rETH).safeTransfer(owner(), _processingFee);
        IERC20(rETH).safeTransfer(msg.sender, _trusteeIncentiveValue);

        vaultBalance[smartVaults[_vaultId].owner][_vaultId] -= (_processingFee+_trusteeIncentiveValue);

        for (j=0;j<smartVaults[_vaultId].numBeneficiaries-1;j++){    
            _partialBalanceToDistribute = _totalBalanceToDistribute*smartVaults[_vaultId].beneficiaries[j].percentage/100;
            vaultBalance[smartVaults[_vaultId].owner][_vaultId] -= _partialBalanceToDistribute;
            IERC20(rETH).safeTransfer(smartVaults[_vaultId].beneficiaries[j].beneficiary, _partialBalanceToDistribute);
            //payable(smartVaults[_vaultId].beneficiaries[j].beneficiary).transfer(_partialBalanceToDistribute);
            //emit vaultBalanceChange??
        }
        //no dust
        IERC20(rETH).safeTransfer(smartVaults[_vaultId].beneficiaries[smartVaults[_vaultId].numBeneficiaries-1].beneficiary, vaultBalance[smartVaults[_vaultId].owner][_vaultId]);
        //payable(smartVaults[_vaultId].beneficiaries[smartVaults[_vaultId].numBeneficiaries-1].beneficiary).transfer(vaultBalance[smartVaults[_vaultId].owner][_vaultId]);
        //emit vaultBalanceChange??
        vaultBalance[smartVaults[_vaultId].owner][_vaultId] = 0;

        smartVaults[_vaultId].vaultState = status.Executed;
        emit vaultEvent(_vaultId, msg.sender, uint256(smartVaults[_vaultId].vaultState));
    }

    /**
     * @dev Getter for the owner, fungible assets, trustees and state of a given Vault ID.
     */
    function getSmartVaultInfo(uint256 _vaultId) public view returns (
        address,
        IERC20[] memory,
        address[] memory,
        uint256,
        uint256,
        uint256,
        uint256) {
        return (
            smartVaults[_vaultId].owner,
            smartVaults[_vaultId].fungibleAssets,
            smartVaults[_vaultId].trustees,
            vaultBalance[smartVaults[_vaultId].owner][_vaultId],
            uint256(smartVaults[_vaultId].vaultState),
            smartVaults[_vaultId].requestExecTS,
            smartVaults[_vaultId].pauseDays
        );
    }

    /**
     * @dev Getter for the beneficiaries and respective percentages of a given Vault ID.
     */
    function getBeneficiaries(uint256 _vaultId) public view returns (address[] memory, uint256[] memory) {
        address[] memory _beneficiaries = new address[](smartVaults[_vaultId].numBeneficiaries);
        uint256[] memory _percentages = new uint256[](smartVaults[_vaultId].numBeneficiaries);
        uint256 i;

        for (i=0;i<smartVaults[_vaultId].numBeneficiaries;i++){
            _beneficiaries[i] = smartVaults[_vaultId].beneficiaries[i].beneficiary;
            _percentages[i] = smartVaults[_vaultId].beneficiaries[i].percentage;
        }
        return (_beneficiaries, _percentages);
    }

    /**
     * @dev Getter for Non-fungible assets, token ID and specific Beneficiary of a given Vault ID.
     */
    function getNonFungibleAssets(uint256 _vaultId) public view returns (IERC721[] memory, uint256[] memory, address[] memory) {
        IERC721[] memory _nonfungibleAddresses = new IERC721[](smartVaults[_vaultId].numNonFungibleAssets);
        uint256[] memory _tokenids = new uint256[](smartVaults[_vaultId].numNonFungibleAssets);
        address[] memory _beneficiaries = new address[](smartVaults[_vaultId].numNonFungibleAssets);
        uint256 i;

        for (i=0;i<smartVaults[_vaultId].numNonFungibleAssets;i++){
            _nonfungibleAddresses[i] = smartVaults[_vaultId].nonfungibleAssets[i].nonfungibleAddress;
            _tokenids[i] = smartVaults[_vaultId].nonfungibleAssets[i].tokenid;
            _beneficiaries[i] = smartVaults[_vaultId].nonfungibleAssets[i].beneficiary;
        }
        return (_nonfungibleAddresses, _tokenids, _beneficiaries);
    }

    /**
     * @dev Getter to retrive all Owner's Vaults.
     */
    function getVaultsOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256[] memory _vaultsOfOwner = new uint256[](ERC721.balanceOf(_owner));
        uint256 i;

        for (i=0;i<ERC721.balanceOf(_owner);i++){
            _vaultsOfOwner[i] = ERC721Enumerable.tokenOfOwnerByIndex(_owner, i);
        }
        return (_vaultsOfOwner);
    }

    /**
     * @dev Getter to retrive all Trustee's Vaults.
     */
    function getVaultsOfTrustee(address _trustee) public view returns (uint256[] memory) {
        uint256[] memory _vaultsOfTrustee = new uint256[](vaultsOfTrustee[_trustee].length);
        // uint256 i;

        // for (i=0;i<vaultsOfTrustee[_trustee].length;i++){
            _vaultsOfTrustee = vaultsOfTrustee[_trustee];
        // }
        return (_vaultsOfTrustee);
    }
    function swapWETHtoRETH() private returns (uint256) {
        // wrap ETH
        IWETH9(wETH).deposit{value: msg.value}();
        // transfer wETH to contract
        IWETH9(wETH).transfer(address(this), msg.value);
        // Approve the router to spend wETH.
        TransferHelper.safeApprove(wETH, address(ISwapRouter(_swapRouter)), msg.value);
        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: wETH,
                tokenOut: rETH,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: msg.value,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        //Swap from Uniswap Liquidity Pool
        return ISwapRouter(_swapRouter).exactInputSingle(params);
    }
 }

// SPDX-License-Identifier: MIT

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
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "../extensions/ERC721Enumerable.sol";
import "../extensions/ERC721Burnable.sol";
import "../extensions/ERC721Pausable.sol";
import "../../../access/AccessControlEnumerable.sol";
import "../../../utils/Context.sol";
import "../../../utils/Counters.sol";

/**
 * @dev {ERC721} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *  - token ID and URI autogeneration
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract ERC721PresetMinterPauserAutoId is
    Context,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721Pausable
{
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    Counters.Counter private _tokenIdTracker;

    string private _baseTokenURI;

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     * Token URIs will be autogenerated based on `baseURI` and their token IDs.
     * See {ERC721-tokenURI}.
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Creates a new token for `to`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");

        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        _mint(to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have pauser role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    /**
     * @dev Getter to reuse Token ID
     */
    function getCurrentTokenId() internal view returns (uint256 _tokenId) {
        return _tokenIdTracker.current();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

pragma solidity >=0.7.6;

// SPDX-License-Identifier: GPL-3.0-only

interface RocketStorageInterface {

    // Deploy status
    function getDeployedStatus() external view returns (bool);

    // Guardian
    function getGuardian() external view returns(address);
    function setGuardian(address _newAddress) external;
    function confirmGuardian() external;

    // Getters
    function getAddress(bytes32 _key) external view returns (address);
    function getUint(bytes32 _key) external view returns (uint);
    function getString(bytes32 _key) external view returns (string memory);
    function getBytes(bytes32 _key) external view returns (bytes memory);
    function getBool(bytes32 _key) external view returns (bool);
    function getInt(bytes32 _key) external view returns (int);
    function getBytes32(bytes32 _key) external view returns (bytes32);

    // Setters
    function setAddress(bytes32 _key, address _value) external;
    function setUint(bytes32 _key, uint _value) external;
    function setString(bytes32 _key, string calldata _value) external;
    function setBytes(bytes32 _key, bytes calldata _value) external;
    function setBool(bytes32 _key, bool _value) external;
    function setInt(bytes32 _key, int _value) external;
    function setBytes32(bytes32 _key, bytes32 _value) external;

    // Deleters
    function deleteAddress(bytes32 _key) external;
    function deleteUint(bytes32 _key) external;
    function deleteString(bytes32 _key) external;
    function deleteBytes(bytes32 _key) external;
    function deleteBool(bytes32 _key) external;
    function deleteInt(bytes32 _key) external;
    function deleteBytes32(bytes32 _key) external;

    // Arithmetic
    function addUint(bytes32 _key, uint256 _amount) external;
    function subUint(bytes32 _key, uint256 _amount) external;

    // Protected storage
    function getNodeWithdrawalAddress(address _nodeAddress) external view returns (address);
    function getNodePendingWithdrawalAddress(address _nodeAddress) external view returns (address);
    function setWithdrawalAddress(address _nodeAddress, address _newWithdrawalAddress, bool _confirm) external;
    function confirmWithdrawalAddress(address _nodeAddress) external;
}

pragma solidity >=0.7.6;

// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface RocketTokenRETHInterface is IERC20 {
    function getEthValue(uint256 _rethAmount) external view returns (uint256);
    function getRethValue(uint256 _ethAmount) external view returns (uint256);
    function getExchangeRate() external view returns (uint256);
    function getTotalCollateral() external view returns (uint256);
    function getCollateralRate() external view returns (uint256);
    function depositExcess() external payable;
    function depositExcessCollateral() external;
    function mint(uint256 _ethAmount, address _to) external;
    function burn(uint256 _rethAmount) external;
}

pragma solidity >=0.7.6;

// SPDX-License-Identifier: GPL-3.0-only

interface RocketDepositPoolInterface {
    function getBalance() external view returns (uint256);
    function getExcessBalance() external view returns (uint256);
    function deposit() external payable;
    function recycleDissolvedDeposit() external payable;
    function recycleExcessCollateral() external payable;
    function recycleLiquidatedStake() external payable;
    function assignDeposits() external;
    function withdrawExcessBalance(uint256 _amount) external;
    function getUserLastDepositBlock(address _address) external view returns (uint256);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

library TransferHelper {
    /// @notice Transfers tokens from the targeted address to the given destination
    /// @notice Errors with 'STF' if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with ST if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    /// @notice Approves the stipulated contract to spend the given allowance in the given token
    /// @dev Errors with 'SA' if transfer fails
    /// @param token The contract address of the token to be approved
    /// @param to The target of the approval
    /// @param value The amount of the given token the target will be allowed to spend
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Fails with `STE`
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title Interface for WETH9
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
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
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
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
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "../../../utils/Context.sol";

/**
 * @title ERC721 Burnable Token
 * @dev ERC721 Token that can be irreversibly burned (destroyed).
 */
abstract contract ERC721Burnable is Context, ERC721 {
    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "../../../security/Pausable.sol";

/**
 * @dev ERC721 token with pausable token transfers, minting and burning.
 *
 * Useful for scenarios such as preventing trades until the end of an evaluation
 * period, or having an emergency switch for freezing all token transfers in the
 * event of a large bug.
 */
abstract contract ERC721Pausable is ERC721, Pausable {
    /**
     * @dev See {ERC721-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        require(!paused(), "ERC721Pausable: token transfer while paused");
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IAccessControlEnumerable.sol";
import "./AccessControl.sol";
import "../utils/structs/EnumerableSet.sol";

/**
 * @dev Extension of {AccessControl} that allows enumerating the members of each role.
 */
abstract contract AccessControlEnumerable is IAccessControlEnumerable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(bytes32 => EnumerableSet.AddressSet) private _roleMembers;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view override returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view override returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Overload {grantRole} to track enumerable memberships
     */
    function grantRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) {
        super.grantRole(role, account);
        _roleMembers[role].add(account);
    }

    /**
     * @dev Overload {revokeRole} to track enumerable memberships
     */
    function revokeRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) {
        super.revokeRole(role, account);
        _roleMembers[role].remove(account);
    }

    /**
     * @dev Overload {renounceRole} to track enumerable memberships
     */
    function renounceRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) {
        super.renounceRole(role, account);
        _roleMembers[role].remove(account);
    }

    /**
     * @dev Overload {_setupRole} to track enumerable memberships
     */
    function _setupRole(bytes32 role, address account) internal virtual override {
        super._setupRole(role, account);
        _roleMembers[role].add(account);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT

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
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

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
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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
}

// SPDX-License-Identifier: MIT

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
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
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

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

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
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

import "../IERC721.sol";

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
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IAccessControl.sol";

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerable is IAccessControl {
    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PoolActions#swap
/// @notice Any contract that calls IUniswapV3PoolActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}