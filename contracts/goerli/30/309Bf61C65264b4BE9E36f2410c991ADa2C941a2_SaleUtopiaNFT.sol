// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./AggregatorV3Interface.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./SafeMath.sol";

interface IUtopia {
    function mint(address to, uint256 qty) external;
}

contract SaleUtopiaNFT is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // treasuryAddr
    address public treasuryAddr;
    // Utopia SC collection
    IUtopia public immutable utopia;
    // Price Feed
    AggregatorV3Interface internal priceFeed;
    // Current Phase
    uint8 public currentPhaseId;
    // Info of each phase.
    struct PhaseInfo {
        uint256 priceInUSDPerNFT;
        uint256 priceInUSDPerNFTWithoutWhiteList;
        uint256 maxTotalSales;
        uint256 maxSalesPerWallet;
        bool whiteListRequired;
    }
    // Phases Info
    PhaseInfo[] public phasesInfo;
    // Phases Total Sales
    mapping(uint256 => uint256) public phasesTotalSales;
    // Phases Wallet Sales
    mapping(uint256 => mapping(address => uint256)) public phasesWalletSales;
    // AllowList
    mapping(address => uint256) public allowList;

    event AddPhase(uint256 indexed _priceInUSDPerNFT, uint256 indexed _priceInUSDPerNFTWithoutWhiteList, uint256 _maxTotalSales, uint256 _maxSalesPerWallet, bool _whiteListRequired);
    event EditPhase(uint8 indexed _phaseId, uint256 indexed _priceInUSDPerNFT, uint256 _priceInUSDPerNFTWithoutWhiteList, uint256 _maxTotalSales, uint256 _maxSalesPerWallet, bool _whiteListRequired);
    event ChangeCurrentPhase(uint8 indexed _phaseId);
    event ChangePriceFeedAddress(address indexed _priceFeedAddress);
    event Buy(uint256 indexed quantity, address indexed to);

    constructor(
        IUtopia _utopia,
        address _treasuryAddr,
        address _priceFeedAddress,
        uint8 _currentPhaseId
    ) {
        utopia = _utopia;
        treasuryAddr = _treasuryAddr;
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        currentPhaseId = _currentPhaseId;
    }

    function setCurrentPhase(uint8 _currentPhaseId) external onlyOwner {
        currentPhaseId = _currentPhaseId;
        emit ChangeCurrentPhase(_currentPhaseId);
    }

    function changePriceFeedAddress(address _priceFeedAddress) external onlyOwner {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        emit ChangePriceFeedAddress(_priceFeedAddress);
    }

    function addPhase(uint256 _priceInUSDPerNFT, uint256 _priceInUSDPerNFTWithoutWhiteList, uint256 _maxTotalSales, uint256 _maxSalesPerWallet, bool _whiteListRequired) external onlyOwner {
        phasesInfo.push(PhaseInfo({
            priceInUSDPerNFT: _priceInUSDPerNFT,
            priceInUSDPerNFTWithoutWhiteList: _priceInUSDPerNFTWithoutWhiteList,
            maxTotalSales: _maxTotalSales,
            maxSalesPerWallet: _maxSalesPerWallet,
            whiteListRequired: _whiteListRequired
        }));

        emit AddPhase(_priceInUSDPerNFT, _priceInUSDPerNFTWithoutWhiteList, _maxTotalSales, _maxSalesPerWallet, _whiteListRequired);
    }

    function editPhase(uint8 _phaseId, uint256 _priceInUSDPerNFT, uint256 _priceInUSDPerNFTWithoutWhiteList, uint256 _maxTotalSales, uint256 _maxSalesPerWallet, bool _whiteListRequired) external onlyOwner {
        phasesInfo[_phaseId].priceInUSDPerNFT = _priceInUSDPerNFT;
        phasesInfo[_phaseId].priceInUSDPerNFTWithoutWhiteList = _priceInUSDPerNFTWithoutWhiteList;
        phasesInfo[_phaseId].maxTotalSales = _maxTotalSales;
        phasesInfo[_phaseId].maxSalesPerWallet = _maxSalesPerWallet;
        phasesInfo[_phaseId].whiteListRequired = _whiteListRequired;

        emit EditPhase(_phaseId, _priceInUSDPerNFT, _priceInUSDPerNFTWithoutWhiteList, _maxTotalSales, _maxSalesPerWallet, _whiteListRequired);
    }

    function getLatestPrice() public view returns (uint80, int, uint, uint, uint80) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        return (
            roundID,
            price,
            startedAt,
            timeStamp,
            answeredInRound
        );
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function seedAllowlist(address[] memory addresses, uint256[] memory numMaxSales) external onlyOwner
    {
        require(
            addresses.length == numMaxSales.length,
            "addresses does not match numSlots length"
        );
        for (uint256 i = 0; i < addresses.length; i++) {
            allowList[addresses[i]] = numMaxSales[i];
        }
    }

    function buy(uint256 quantity, address to) external payable callerIsUser nonReentrant {
        uint256 totalPrice = 0;
        uint256 priceInUSD = 0;
        (
            ,
            int ethPrice,
            ,
            ,

        ) = getLatestPrice();

        uint256 ethPrice256 = uint256(ethPrice);

        PhaseInfo storage phase = phasesInfo[currentPhaseId];
        
        if (phase.whiteListRequired) {
            require(allowList[to] > 0, "not eligible for allowList mint");
        }

        require(phase.maxTotalSales >= phasesTotalSales[currentPhaseId].add(quantity), "this phase does not allow this purchase");

        require(phase.maxSalesPerWallet >= phasesWalletSales[currentPhaseId][to].add(quantity), "you can not buy as many NFTs in this phase");

        if (allowList[to] > 0) {
            //Poner require de allowList
            allowList[to] = allowList[to] - quantity;
            priceInUSD = phase.priceInUSDPerNFT;
        } else {
            priceInUSD = phase.priceInUSDPerNFTWithoutWhiteList;
        }

        uint256 totalPriceInUSD = priceInUSD.mul(quantity).mul(1e8).mul(1e18);
        totalPrice = totalPriceInUSD.div(ethPrice256);

        if (msg.sender == owner()) {
            totalPrice = 0;
        }

        phasesTotalSales[currentPhaseId] = phasesTotalSales[currentPhaseId].add(quantity);
        phasesWalletSales[currentPhaseId][to] = phasesWalletSales[currentPhaseId][to].add(quantity);

        utopia.mint(to, quantity);
        refundIfOver(totalPrice);

        //payable(treasuryAddr).transfer(address(this).balance);
        //(bool sent, ) = treasuryAddr.call{value: address(this).balance}("");
        treasuryAddr.call{value: address(this).balance}("");

        emit Buy(quantity, to);
    }

    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "Need to send more ETH.");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function setTreasury(address _treasuryAddr) external onlyOwner {
        treasuryAddr = _treasuryAddr;
    }

    function withdrawMoney() external onlyOwner nonReentrant {
        (bool success, ) = treasuryAddr.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}