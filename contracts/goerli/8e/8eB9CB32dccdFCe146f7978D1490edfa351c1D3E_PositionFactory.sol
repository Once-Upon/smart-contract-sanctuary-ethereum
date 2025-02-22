import 'contracts/interfaces/position_trading/IPositionsController.sol';
import 'contracts/lib/ownable/OwnableSimple.sol';
import 'contracts/interfaces/assets/typed/IEthAssetFactory.sol';
import 'contracts/interfaces/assets/typed/IErc20AssetFactory.sol';
import 'contracts/interfaces/assets/typed/IErc721ItemAssetFactory.sol';
import 'contracts/lib/factories/ContractData.sol';
import 'contracts/interfaces/position_trading/algorithms/IPositionLockerAlgorithmInstaller.sol';
import 'contracts/interfaces/position_trading/algorithms/ISaleAlgorithm.sol';
import 'contracts/interfaces/position_trading/algorithms/IPositionTradingAlgorithm.sol';

/// @dev данные о создании ассета
struct AssetCreationData {
    /// @dev коды ассетов:
    /// 0 - ассет отсуствует
    /// 1 - EthAsset
    /// 2 - Erc20Asset
    /// 3 - Erc721ItemAsset
    uint256 assetTypeCode;
    address contractAddress;
    uint256 tokenId;
}

contract PositionFactory is OwnableSimple {
    IPositionsController public positionsController;
    IEthAssetFactory public ethAssetFactory; // assetType 1
    IErc20AssetFactory public erc20AssetFactory; // assetType 2
    IErc721ItemAssetFactory public erc721AssetFactory; // assetType 3
    IPositionLockerAlgorithmInstaller public positionLockerAlgorithm;
    ISaleAlgorithm public saleAlgorithm;

    constructor(
        address positionsController_,
        address ethAssetFactory_,
        address erc20AssetFactory_,
        address erc721AssetFactory_,
        address positionLockerAlgorithm_,
        address saleAlgorithm_
    ) OwnableSimple(msg.sender) {
        positionsController = IPositionsController(positionsController_);
        ethAssetFactory = IEthAssetFactory(ethAssetFactory_);
        erc20AssetFactory = IErc20AssetFactory(erc20AssetFactory_);
        erc721AssetFactory = IErc721ItemAssetFactory(erc721AssetFactory_);
        positionLockerAlgorithm = IPositionLockerAlgorithmInstaller(
            positionLockerAlgorithm_
        );
        saleAlgorithm = ISaleAlgorithm(saleAlgorithm_);
    }

    function setPositionsController(address positionsController_)
        external
        onlyOwner
    {
        positionsController = IPositionsController(positionsController_);
    }

    function setethAssetFactory(address ethAssetFactory_) external onlyOwner {
        ethAssetFactory = IEthAssetFactory(ethAssetFactory_);
    }

    function createPositionWithAssets(
        AssetCreationData calldata data1,
        AssetCreationData calldata data2
    ) external {
        // создаем позицию
        positionsController.createPosition();
        uint256 positionId = positionsController.ownedPositionsCount(
            address(this)
        );

        // задаем ассеты
        _setAsset(positionId, 1, data1);
        _setAsset(positionId, 2, data2);

        // передаем владение позиции
        positionsController.transferPositionOwnership(positionId, msg.sender);
    }

    function createPositionLockAlgorithm(AssetCreationData calldata data)
        external
    {
        // создаем позицию
        positionsController.createPosition();
        uint256 positionId = positionsController.ownedPositionsCount(
            address(this)
        );

        // задаем ассет
        _setAsset(positionId, 1, data);

        // задаем алгоритм
        positionLockerAlgorithm.setAlgorithm(positionId);

        // передаем владение позиции
        positionsController.transferPositionOwnership(positionId, msg.sender);
    }

    function createSaleAlgorithm(
        AssetCreationData calldata data1,
        AssetCreationData calldata data2,
        Price calldata price
    ) external {
        // создаем позицию
        positionsController.createPosition();
        uint256 positionId = positionsController.ownedPositionsCount(
            address(this)
        );

        // задаем ассеты
        _setAsset(positionId, 1, data1);
        _setAsset(positionId, 2, data2);

        // задаем алгоритм
        saleAlgorithm.setAlgorithm(positionId);

        // устанавливаем цену
        saleAlgorithm.setPrice(positionId, price);

        // передаем владение позиции
        positionsController.transferPositionOwnership(positionId, msg.sender);
    }

    function _setAsset(
        uint256 positionId,
        uint256 assetCode,
        AssetCreationData calldata data
    ) internal {
        if (data.assetTypeCode == 1)
            ethAssetFactory.setAsset(positionId, assetCode);
        else if (data.assetTypeCode == 2)
            erc20AssetFactory.setAsset(
                positionId,
                assetCode,
                data.contractAddress
            );
        else if (data.assetTypeCode == 3)
            erc721AssetFactory.setAsset(
                positionId,
                assetCode,
                data.contractAddress,
                data.tokenId
            );
    }
}

import 'contracts/lib/factories/ContractData.sol';

interface IPositionsController {
    /// @dev возвращает владельца позиции
    function ownerOf(uint256 positionId) external view returns (address);

    /// @dev меняет владельца позиции
    function transferPositionOwnership(uint256 positionId, address newOwner)
        external;

    /// @dev возаращает позицию ассета его адресу
    function getAssetPositionId(address assetAddress)
        external
        view
        returns (uint256);

    /// @dev возвращает актив по его коду в позиции 1 или 2
    function getAsset(uint256 positionId, uint256 assetCode)
        external
        view
        returns (ContractData memory);

    /// @dev создает позицию
    function createPosition() external;

    /// @dev задает ассет на позицию
    /// @param positionId ID позиции
    /// @param assetCode код ассета 1 - овнер ассет 2 - выходной ассет
    /// @param data данные контракта ассета
    function setAsset(
        uint256 positionId,
        uint256 assetCode,
        ContractData calldata data
    ) external;

    /// @dev задает алгоритм позиции
    function setAlgorithm(uint256 positionId, ContractData calldata data)
        external;

    /// @dev возвращает алгоритм позиции
    function getAlgorithm(uint256 positionId)
        external
        view
        returns (ContractData memory data);

    /// @dev запрещает редактировать позицию
    function disableEdit(uint256 positionId) external;

    /// @dev возвращает позицию из списка позиций аккаунта
    function positionOfOwnerByIndex(address account, uint256 index)
        external
        view
        returns (uint256);

    /// @dev возвращает количество позиций, которыми владеет аккаунт
    function ownedPositionsCount(address account)
        external
        view
        returns (uint256);
}

import 'contracts/interfaces/IOwnable.sol';

/// @dev овнабл, оптимизированый, для динамически порождаемых контрактов
contract OwnableSimple is IOwnable {
    address internal _owner;

    constructor(address owner_) {
        _owner = owner_;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, 'caller is not the owner');
        _;
    }

    function owner() external virtual override returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external override onlyOwner {
        _owner = newOwner;
    }
}

interface IEthAssetFactory {
    function setAsset(uint256 positionId, uint256 assetCode) external;
}

interface IErc20AssetFactory {
    function setAsset(
        uint256 positionId,
        uint256 assetCode,
        address contractAddress
    ) external;
}

interface IErc721ItemAssetFactory {
    function setAsset(
        uint256 positionId,
        uint256 assetCode,
        address contractAddress,
        uint256 tokenId
    ) external;
}

/// @dev данные порождаемого фабрикой контракта
struct ContractData {
    address factory; // фабрика
    address contractAddr; // контракт
}

interface IPositionLockerAlgorithmInstaller {
    /// @dev задает алгоритм лока позиции
    function setAlgorithm(uint256 positionId) external;
}

/// @dev цена
struct Price {
    uint256 nom; // числитель
    uint256 denom; // знаменатель
}

interface ISaleAlgorithm {
    function setAlgorithm(uint256 positionId) external;

    function setPrice(uint256 positionId, Price calldata price) external;
}



interface IOwnable {
    function owner() external returns (address);

    function transferOwnership(address newOwner) external;
}