pragma solidity ^0.8.4;

import "./Farm.sol";
import "./Shop.sol";

contract CutaverseLens {

    struct FarmBasicMetadata{
        bool paused;
        uint256 landLeve;
        uint256 farmerCount;
        uint256 createFarmPrice;
        uint256 wateringPrice;
    }

    function getFarmBasicInfo(Farm farm) public view returns(FarmBasicMetadata memory){
        return FarmBasicMetadata({
            paused: farm.paused(),
            landLeve: farm.landLeve(),
            farmerCount: farm.farmerCount(),
            createFarmPrice: farm.createFarmPrice(),
            wateringPrice: farm.wateringPrice()
        });
    }

    struct FarmerMetadata{
        LandMetadata[] landInfos;
        uint256 landCount;
    }

    struct LandMetadata{
        uint256 pid;
        uint256 gain;
        uint256 harvestTime;
        ISeed seed;
    }

    function getFarmInfo(Farm farm, address farmer) public view returns(FarmerMetadata memory){
        uint256 _landCount = farm.accountLandCount(farmer);
        LandMetadata[] memory _landInfos = new LandMetadata[](_landCount);

        for(uint i=0; i<_landCount;i++){
            uint pid = i+1;
            (ISeed _seed,uint256 _gain, uint256 _harvestTime) = farm.accountPidLand(farmer,pid);
            LandMetadata memory landInfo = LandMetadata(pid,_gain,_harvestTime,_seed);
            _landInfos[i] = landInfo;
        }

        return FarmerMetadata({
            landInfos: _landInfos,
            landCount: _landCount
        });
    }

    struct ShopBasicMetadata{
        bool paused;
        uint256 seedCount;
    }

    function getShopBasicInfo(Shop shop) public view returns(ShopBasicMetadata memory){
        return ShopBasicMetadata({
            paused: shop.paused(),
            seedCount: shop.seedContainersLength()
        });
    }

    struct ShopSeedMetadata{
        SeedMetadata[] seeds;
        uint256 seedCount;
    }

    struct SeedMetadata{
        ISeed seed;
        bool onSale;
        uint256 price;
        uint256 shopBuyRoundLimit;
        uint256 userBuyRoundLimit;
    }

    function getShopSeedsInfo(Shop shop) public view returns(ShopSeedMetadata memory){
        uint256 _seedCount = shop.seedContainersLength();
        SeedMetadata[] memory _seeds = new SeedMetadata[](_seedCount);

        for(uint i=0; i<_seedCount;i++){
            (ISeed _seed,bool _onSale,uint256 _price,uint256 _shopBuyRoundLimit, uint256 _userBuyRoundLimit) = shop.seedContainers(i);
            SeedMetadata memory shopSeed = SeedMetadata(_seed,_onSale,_price,_shopBuyRoundLimit,_userBuyRoundLimit);
            _seeds[i] = shopSeed;
        }

        return ShopSeedMetadata({
            seeds: _seeds,
            seedCount: _seedCount
        });
    }

    struct SeedBuyLimitMetadata{
        bool isShopOversold;
        bool isUserOversold;
        uint256 shopSold;
        uint256 userSold;
        uint256 shopBuyRoundLimit;
        uint256 userBuyRoundLimit;
    }

    function getSeedBuyLimitInfo(Shop shop, ISeed seed, address user,uint256 count) public view returns(SeedBuyLimitMetadata memory){
        (bool _isSeedShopOverrun,) = shop.isSeedShopOversold(address(seed),count);
        (bool _isSeedUserOverrun,) = shop.isSeedUserOversold(address(seed),count);

        (,uint256 _shopSold) = shop.seedShopBuyLimit(address(seed));
        (,uint256 _userSold) = shop.seedUserBuyLimit(address(seed),user);

        uint256 pid = shop.seedContainersOfPid(address(seed));
        (ISeed _seed,bool _onSale,uint256 _price,uint256 _shopBuyRoundLimit, uint256 _userBuyRoundLimit) = shop.seedContainers(pid-1);

        return SeedBuyLimitMetadata({
            isShopOversold: _isSeedShopOverrun,
            isUserOversold: _isSeedUserOverrun,
            shopSold: _shopSold,
            userSold: _userSold,
            shopBuyRoundLimit: _shopBuyRoundLimit,
            userBuyRoundLimit: _userBuyRoundLimit
        });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IFarm.sol";

contract Farm is IFarm,Ownable,Pausable,ReentrancyGuard{
    using SafeMath for uint256;
    using Overrun for Overrun.Limit;

    constructor (address _feeTo,ICutaverse _cutaverse, IShop _shop) {
        require(_feeTo != address(0),"_feeTo is the zero address");
        require(address(_cutaverse) != address(0),"_cutaverse is the zero address");
        require(address(_shop) != address(0),"_shop is the zero address");

        feeTo = _feeTo;
        cutaverse = _cutaverse;
        shop = _shop;
    }

    function resetFeeTo(address payable _feeTo) external onlyOwner{
        require(_feeTo != address(0), "_FeeTo is the zero address");
        address oldFeeTo = feeTo;
        feeTo = _feeTo;

        emit ResetFeeTo(oldFeeTo, _feeTo);
    }

    function resetCreateFarmPrice(uint256 _createFarmPrice) external onlyOwner{
        uint256 oldCreateFarmPrice = createFarmPrice;
        createFarmPrice = _createFarmPrice;

        emit ResetCreateFarmPrice(oldCreateFarmPrice, _createFarmPrice);
    }

    function resetWeedShortenFactor(uint256 _weedingShortenFactor) external onlyOwner{
        uint256 oldWeedingShortenFactor = weedingShortenFactor;
        weedingShortenFactor = _weedingShortenFactor;

        emit ResetWeedShortenFactor(oldWeedingShortenFactor, _weedingShortenFactor);
    }

    function resetHarvestingGainFactor(uint256 _harvestingGainFactor) external onlyOwner{
        uint256 oldHarvestingGainFactor = harvestingGainFactor;
        harvestingGainFactor = _harvestingGainFactor;

        emit ResetHarvestGainFactor(oldHarvestingGainFactor, _harvestingGainFactor);
    }

    function resetLandBasePrice(uint256 _landBasePrice) external onlyOwner{
        uint256 oldLandBasePrice = landBasePrice;
        landBasePrice = _landBasePrice;

        emit ResetLandBasePrice(oldLandBasePrice, _landBasePrice);
    }

    function resetWateringShortenFactor(uint256 _wateringShortenFactor) external onlyOwner{
        require(_wateringShortenFactor > 0 && _wateringShortenFactor < 5000, "wateringShortenFactor is invalid");

        uint256 oldWateringShortenFactor = wateringShortenFactor;
        wateringShortenFactor = _wateringShortenFactor;

        emit ResetWateringShortenFactor(oldWateringShortenFactor, wateringShortenFactor);
    }

    function resetPerLandWateringRoundLimit(uint256 _perLandWateringRoundLimit) external onlyOwner{
        require(_perLandWateringRoundLimit > 0 && _perLandWateringRoundLimit < 5, "perLandWateringRoundLimit is invalid");

        uint256 oldPerLandWateringRoundLimit = perLandWateringRoundLimit;
        perLandWateringRoundLimit = _perLandWateringRoundLimit;

        emit ResetPerLandWateringRoundLimit(oldPerLandWateringRoundLimit, perLandWateringRoundLimit);
    }

    function resetLandLeve(uint256 _landLeve) external onlyOwner{
        require(_landLeve > 1 && _landLeve <= 4, "_landLeve is invalid");

        uint256 oldLandLeve = landLeve;
        landLeve = _landLeve;

        emit ResetLandLeve(oldLandLeve, _landLeve);
    }

    function createFarm() public payable nonReentrant whenNotPaused{
        require(accountLandCount[msg.sender] == 0,"You already own a farm");
        require(msg.value >= createFarmPrice, "The ether value sent is not correct");

        payable(feeTo).transfer(msg.value);

        uint256 ownedCount = accountLandCount[msg.sender];
        increasingLand(initialLandCount);
        uint256 toHaveCount = accountLandCount[msg.sender];
        farmerCount = farmerCount.add(1);

        emit IncreasingLand(msg.sender,ownedCount,toHaveCount);
    }

    function planting(PlantAct[] memory plantAct) public nonReentrant whenNotPaused{
        uint256 len = plantAct.length;
        require(len > 0 && len <= accountLandCount[msg.sender], "farmer or land is invalid");

        for(uint i =0 ;i < len;i++){
            PlantAct memory act = plantAct[i];
            uint256 pid = act.pid;
            ISeed seed = act.seed;

            require(pid > 0 && pid <= accountLandCount[msg.sender],"An invalid pid");
            require(shop.isShopSeed(address(seed)),"An invalid seed");

            Land storage land = accountPidLand[msg.sender][pid];
            require(address(land.seed) == address(0),"The land is already planted");

            land.seed = seed;
            land.harvestTime = seed.matureTime().add(block.timestamp);
            land.gain = calculateLanGain(pid);
            land.seed.burnFrom(msg.sender,1*10**seed.decimals());

            emit Planting(msg.sender,address(land.seed),pid);
        }
    }


    function watering(address farmer, uint256[] calldata pids) public payable nonReentrant whenNotPaused{
        uint256 len = pids.length;
        require(len > 0 && len <= accountLandCount[farmer], "The lands count sent is not correct");
        require(msg.value >= wateringPrice.mul(len), "The ether value sent is not correct");

        uint256 successTimes = 0;
        for(uint i =0 ;i < len;i++){
            uint pid = pids[i];
            Land storage land = accountPidLand[farmer][pid];
            if(address(land.seed) == address(0)){
                continue;
            }

            (bool isOverrun,bool isOvertime) = isWateringOverrun(farmer,pid);
            if(isOverrun){
                continue;
            }

            Overrun.Limit storage waterLimit = accountLimitWater[farmer][pid];
            if(isOvertime){
                waterLimit.times = 1;
                waterLimit.timeline = block.timestamp;
            }else{
                waterLimit.times += 1;
            }

            uint256 finalHarvestTime = land.harvestTime.mul(denominator - wateringShortenFactor).div(denominator);
            land.harvestTime = finalHarvestTime > block.timestamp ? finalHarvestTime : block.timestamp;
            successTimes += 1;

            emit Watering(msg.sender, farmer, address(land.seed), pid);
        }

        //TODO 待测试，未成功的是否留在合约
        payable(feeTo).transfer(wateringPrice.mul(successTimes));
    }

    function isWateringOverrun(address _user, uint256 _pid) public view returns(bool,bool){
        Overrun.Limit storage limit = accountLimitWater[_user][_pid];
        return Overrun.isOverrun(limit, 1, 24*60*60, perLandWateringRoundLimit);
    }

    function harvesting(address farmer) public nonReentrant{
        uint len = accountLandCount[farmer];
        require(len >0 ,"The farmer does not yet own the land");

        for(uint i = 1;i <= len; i++){
            Land storage land = accountPidLand[farmer][i];
            if(address(land.seed) == address(0)){
                continue;
            }

            if(block.timestamp < land.harvestTime){
                continue;
            }

            if(msg.sender != farmer && block.timestamp < land.harvestTime.add(24*60*60)){
                continue;
            }

            uint256 reaperGain = 0;
            uint256 farmerGain = land.gain;

            if(msg.sender != farmer){
                reaperGain = farmerGain.mul(harvestingGainFactor).div(denominator);
                farmerGain = farmerGain.sub(reaperGain);
            }

            if(reaperGain >0){
                cutaverse.mint(msg.sender,reaperGain);
                emit Harvesting(msg.sender, farmer, address(land.seed), i, reaperGain);
            }

            if(farmerGain >0){
                cutaverse.mint(farmer,farmerGain);
                emit Harvesting(msg.sender, farmer, address(land.seed), i, farmerGain);
            }

            land.seed = ISeed(address(0));
            land.gain = 0;
            land.harvestTime = 0;
        }
    }

    function buyLand(uint256 _count) public payable{
        require(landLeve > 1,"No land upgrades are allowed");
        uint256 ownedCount = accountLandCount[msg.sender];
        uint256 toHaveCount = ownedCount.add(_count);

        uint256 cost = calculateBuyLandCost(_count);
        require(msg.value >= cost, "The ether value sent is not correct");

        payable(feeTo).transfer(msg.value);

        increasingLand(_count);

        emit IncreasingLand(msg.sender,ownedCount,toHaveCount);
    }

    function increasingLand(uint256 _count) internal{
        Land memory empty = Land({
            seed: ISeed(address(0)),
            gain: 0,
            harvestTime: 0
        });

        uint256 ownedCount = accountLandCount[msg.sender];
        uint256 toHaveCount = ownedCount.add(_count);

        for (uint j= ownedCount.add(1); j <= toHaveCount; j ++) {
            accountPidLand[msg.sender][j] = empty;
        }

        accountLandCount[msg.sender] = toHaveCount;
    }

    function calculateLanGain(uint256 _pid) public view returns(uint256){
        require(_pid > 0 && _pid <= accountLandCount[msg.sender],"An invalid pid");

        Land storage land = accountPidLand[msg.sender][_pid];
        if(_pid <= initialLandCount){
            return land.gain;
        }

        uint256 exponent = _pid.sub(initialLandCount);
        return exponentialIncrease(land.gain,landGainRiseFactor,exponent);
    }

    function calculateBuyLandCost(uint256 _count) public view returns(uint256){
        require(_count > 0,"An invalid _count");

        uint256 ownedCount = accountLandCount[msg.sender];
        require(ownedCount >= initialLandCount,"Please create the farm first");

        uint256 toHaveCount = ownedCount.add(_count);
        uint256 curLeveMaxLandCount = calculateCurLeveMaxLandCount();
        require(toHaveCount <= curLeveMaxLandCount,"More than the current land class allows");
        require(toHaveCount <= maxLandCount,"The maximum amount of land cannot be exceeded");

        uint256 totalCost = 0;
        for(uint256 i = toHaveCount; i > ownedCount; i--){
            uint256 exponent = i.sub(initialLandCount);
            uint256 curCost = exponentialIncrease(landBasePrice,landPriceRiseFactor,exponent);
            totalCost = totalCost.add(curCost);
        }

        return totalCost;
    }

    function calculateCurLeveMaxLandCount() public view returns(uint256){
        return landLeve.mul(initialLandCount);
    }

    function exponentialIncrease(uint256 base, uint256 factor, uint exponent) internal pure returns(uint256){
        require(factor > 0 && factor < denominator,"");
        require(exponent > 0 && exponent < 8,"");

        uint256 a = factor.add(denominator);
        uint256 b = a**exponent;

        return base.mul(b).div(denominator**exponent);
    }

    function exponentialDecrease(uint256 base, uint256 factor, uint exponent) internal pure returns(uint256){
        require(factor > 0 && factor < denominator,"");
        require(exponent > 0 && exponent < 8,"");

        uint256 a = SafeMath.sub(denominator,factor);
        uint256 b = a**exponent;

        return base.mul(b).div(denominator**exponent);
    }

    //    function weeding(Land[] memory land) public{
    //        //需要质押 hoe（直到成熟解开质押）
    //        for(uint i =0 ;i < lands.length;i++){
    //            Land _land = lands[i];
    //            uint index = _land.index;
    //
    //            Land storage land = accountPidLand[msg.sender][index];
    //            require(land.seed == address(0) && land.harvestTime.add(1-wateringRate) < block.timestamp,"");
    //            land.harvestTime = land.harvestTime.add(1-wateringRate);
    //        }
    //    }

    //    function steal(address account, Land land) public{
    //        //需要花费 x eth (每块土地每天只能偷盗3次)
    //        //30% 偷盗者胜，成功 x*20% 给到管理员，x*80% 返还，收成归偷盗者
    //        //10% 双方都失败，x 都给到管理员，收成无
    //        //60% 农场主胜, x*20% 给到管理员，x*80% 给到农民
    //    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IShop.sol";

contract Shop is IShop,Ownable,Pausable,ReentrancyGuard{
    using SafeMath for uint256;
    using Overrun for Overrun.Limit;

    constructor (address _feeTo, ICutaverse _cutaverse){
        require(_feeTo != address(0), "_feeTo is the zero address");
        require(address(_cutaverse) != address(0), "_cutaverse is the zero address");

        feeTo = _feeTo;
        cutaverse = _cutaverse;
    }

    function resetFeeTo(address payable _feeTo) external override onlyOwner{
        require(_feeTo != address(0), "_FeeTo is the zero address");
        address oldFeeTo = feeTo;
        feeTo = _feeTo;

        emit ResetFeeTo(oldFeeTo, _feeTo);
    }

    function addSeed(SeedContainer memory seedContainer) public override onlyOwner {
        ISeed _seed = seedContainer.seed;
        bool _onSale = seedContainer.onSale;
        uint256 _price = seedContainer.price;
        uint256 _shopBuyRoundLimit = seedContainer.shopBuyRoundLimit;
        uint256 _userBuyRoundLimit = seedContainer.userBuyRoundLimit;

        require(address(_seed) != address(0), "_seed is the zero address");
        require(!isShopSeed(address(_seed)),"The seed is already there");

        seedContainers.push(SeedContainer({
            seed: ISeed(_seed),
            onSale: _onSale,
            price: _price,
            shopBuyRoundLimit: _shopBuyRoundLimit,
            userBuyRoundLimit: _userBuyRoundLimit
        }));
        seedContainersOfPid[address(_seed)] = seedContainersLength();

        emit AddSeed(address(_seed),_onSale,_price,_shopBuyRoundLimit,_userBuyRoundLimit);
    }

    function resetSeedContainer(SeedContainer memory _seedContainer) external override onlyOwner{
        address seed = address(_seedContainer.seed);
        bool onSale = _seedContainer.onSale;
        uint256 price = _seedContainer.price;
        uint256 shopBuyRoundLimit = _seedContainer.shopBuyRoundLimit;
        uint256 userBuyRoundLimit = _seedContainer.userBuyRoundLimit;

        uint256 pid = seedContainersOfPid[seed];
        require(pid >0, "Not the seed of the shop");

        SeedContainer storage seedContainer = seedContainers[pid-1];
        seedContainer.onSale = onSale;
        seedContainer.price = price;
        seedContainer.shopBuyRoundLimit = shopBuyRoundLimit;
        seedContainer.userBuyRoundLimit = userBuyRoundLimit;

        emit ResetSeedContainer(seed,onSale,price,shopBuyRoundLimit,userBuyRoundLimit);
    }

    function buySeed(address _seed, uint256 _count) public override nonReentrant whenNotPaused{
        uint256 pid = seedContainersOfPid[_seed];
        require(pid > 0, "Not the seed of the shop");

        SeedContainer storage seedContainer = seedContainers[pid-1];
        require(seedContainer.onSale,"Not on sale");

        (bool isSeedShopOverrun, bool isSeedShopOvertime) = isSeedShopOversold(_seed,_count);
        (bool isSeedUserOverrun, bool isSeedUserOvertime) = isSeedUserOversold(_seed,_count);
        require(!isSeedShopOverrun && !isSeedUserOverrun,"Exceeding the seed purchase limit");

        Overrun.Limit storage _seedShopBuyLimit = seedShopBuyLimit[_seed];
        if(isSeedShopOvertime){
            _seedShopBuyLimit.times = _count;
            _seedShopBuyLimit.timeline = block.timestamp;
        }else{
            _seedShopBuyLimit.times = _seedShopBuyLimit.times.add(_count);
        }

        Overrun.Limit storage _seedUserBuyLimit = seedUserBuyLimit[_seed][msg.sender];
        if(isSeedUserOvertime){
            _seedUserBuyLimit.times = _count;
            _seedUserBuyLimit.timeline = block.timestamp;
        }else{
            _seedUserBuyLimit.times = _seedUserBuyLimit.times.add(_count);
        }

        ISeed seed = ISeed(_seed);
        uint amount = seedContainer.price.mul(_count.div(10**seed.decimals()));
        cutaverse.transferFrom(msg.sender, feeTo, amount);

        seed.mint(msg.sender, _count);

        emit BuySeed(msg.sender,_seed,_count);
    }

    function seedContainersLength() public view override returns(uint256){
        return seedContainers.length;
    }

    function isShopSeed(address _seed) public view override returns (bool) {
        return seedContainersOfPid[_seed] > 0 ;
    }

    function isSeedOversold(address _seed, uint256 _count) public view override returns(bool){
        (bool isSeedShopOverrun,) = isSeedShopOversold(_seed,_count);
        (bool isSeedUserOverrun,) = isSeedUserOversold(_seed,_count);

        return isSeedShopOverrun || isSeedUserOverrun;
    }

    function isSeedShopOversold(address _seed, uint256 _count) public view override returns(bool,bool){
        uint256 pid = seedContainersOfPid[_seed];
        require(pid > 0,"Not the seed of the shop");

        SeedContainer storage seedContainer = seedContainers[pid-1];
        uint256 seedShopBuyRoundLimit = seedContainer.shopBuyRoundLimit;

        Overrun.Limit storage limit = seedShopBuyLimit[_seed];
        return Overrun.isOverrun(limit, _count, 24*60*60, seedShopBuyRoundLimit);
    }

    function isSeedUserOversold(address _seed, uint256 _count) public view override returns(bool,bool){
        uint256 pid = seedContainersOfPid[_seed];
        require(pid > 0,"Not the seed of the shop");

        SeedContainer storage seedContainer = seedContainers[pid-1];
        uint256 seedUserBuyRoundLimit = seedContainer.userBuyRoundLimit;

        Overrun.Limit storage limit = seedUserBuyLimit[_seed][msg.sender];
        return Overrun.isOverrun(limit, _count, 24*60*60, seedUserBuyRoundLimit);
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
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

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
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
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
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
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
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

pragma solidity ^0.8.4;

import "../storage/FarmStorage.sol";

abstract contract IFarm is FarmStorage{

    event ResetFeeTo(address indexed oldFeeTo, address indexed newFeeTo);
    event ResetCreateFarmPrice(uint256 oldCreateFarmPrice, uint256 newCreateFarmPrice);
    event ResetWeedShortenFactor(uint256 oldWeedShortenFactor, uint256 newWeedShortenFactor);
    event ResetHarvestGainFactor(uint256 oldHarvestGainFactor, uint256 newHarvestGainFactor);
    event ResetLandBasePrice(uint256 oldLandBasePrice, uint256 newLandBasePrice);
    event ResetWateringShortenFactor(uint256 oldWateringShortenFactor, uint256 newWateringShortenFactor);
    event ResetPerLandWateringRoundLimit(uint256 oldPerLandWateringRoundLimit, uint256 newPerLandWateringRoundLimit);
    event ResetLandLeve(uint256 oldLandLeve, uint256 newLandLeve);

    event IncreasingLand(address indexed farmer,uint256 ownedCount,uint256 toHaveCount);
    event Planting(address indexed farmer,address indexed seed,uint256 pid);
    event Watering(address indexed operator,address indexed farmer,address indexed seed,uint256 pid);
    event Harvesting(address indexed operator,address indexed farmer,address indexed seed,uint256 pid, uint256 gain);

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

pragma solidity ^0.8.4;

import "../interfaces/ICutaverse.sol";
import "../interfaces/ISeed.sol";
import "../interfaces/IShop.sol";
import "../utils/Overrun.sol";

contract FarmStorage {

    struct Land {
        ISeed seed;
        uint256 gain;
        uint256 harvestTime;
    }

    struct PlantAct {
        uint256 pid;
        ISeed seed;
    }

    uint256 public constant initialLandCount = 4;
    uint256 public constant maxLandCount = 16;
    uint256 public constant denominator = 1000;

    uint256 public createFarmPrice = 0.004 ether;
    uint256 public wateringPrice = 0.001 ether;
    uint256 public landBasePrice = 0.002 ether;

    uint256 public wateringShortenFactor = 50;
    uint256 public weedingShortenFactor = 100;
    uint256 public harvestingGainFactor = 100;
    uint256 public landPriceRiseFactor = 300;
    uint256 public landGainRiseFactor = 200;
    uint256 public perLandWateringRoundLimit = 3;
    uint256 public landLeve = 1;

    IShop public shop;
    ICutaverse public cutaverse;
    address public feeTo;
    uint256 public farmerCount;

    mapping(address => uint256) public accountLandCount;
    mapping(address => mapping(uint256 => Land)) public accountPidLand;

    mapping(address => mapping(uint256 => Overrun.Limit)) accountLimitWater;
}

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ICutaverse is IERC20Metadata{

    function farm() external view returns(address);
    function cap() external view returns (uint256);

    function restFarm(address farm) external;
    function mint(address account, uint256 amount) external;
}

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


interface ISeed is IERC20Metadata{

    function restShop(address shop) external virtual;
    function restFarm(address farm) external virtual;
    function mint(address account, uint256 amount) external virtual;
    function burnFrom(address account, uint256 amount) external virtual;

    function shop() external view virtual returns(address);
    function farm() external view virtual returns(address);
    function yield() external view virtual returns(uint256);
    function matureTime() external view virtual returns(uint256);

}

pragma solidity ^0.8.4;

import "../storage/ShopStorage.sol";

abstract contract IShop is ShopStorage{

    event ResetFeeTo(address indexed oldFeeTo,address indexed newFeeTo);
    event ResetSeedContainer(address indexed seed, bool onSale,uint256 price,uint256 shopBuyRoundLimit,uint256 userBuyRoundLimit);
    event AddSeed(address indexed seed,bool onSale,uint256 price,uint256 shopBuyRoundLimit,uint256 userBuyRoundLimit);
    event BuySeed(address indexed user,address indexed seed,uint256 amount);

    function resetFeeTo(address payable feeTo) external virtual;
    function resetSeedContainer(SeedContainer memory _seedContainer) external virtual;
    function addSeed(SeedContainer memory seedContainer) external virtual;
    function buySeed(address seed, uint256 count) external virtual;
    function seedContainersLength() external view virtual returns(uint256);
    function isShopSeed(address seed) external view virtual returns (bool);
    function isSeedOversold(address seed, uint256 count) external view virtual returns(bool);
    function isSeedShopOversold(address seed, uint256 count) external view virtual returns(bool,bool);
    function isSeedUserOversold(address seed, uint256 count) external view virtual returns(bool,bool);
}

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library Overrun {
    using SafeMath for uint256;

    struct Limit{
        uint256 timeline;
        uint256 times;
    }

    function isOverrun(Limit memory limit, uint256 curTimes, uint256 roundTime, uint256 limitValue) internal view returns(bool,bool){
        uint256 timeline  = limit.timeline;
        uint256 times  = limit.times;

        bool isOverrun = times.add(curTimes) > limitValue;
        bool isOvertime = timeline.add(roundTime) < block.timestamp;

        if(isOvertime && curTimes > limitValue){
            return (true,true);
        }

        if(!isOvertime && isOverrun){
            return (true,false);
        }

        return (false, isOvertime);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

pragma solidity ^0.8.4;

import "../interfaces/ISeed.sol";
import "../interfaces/ICutaverse.sol";
import "../utils/Overrun.sol";

contract ShopStorage {

    struct SeedContainer{
        ISeed seed;
        bool onSale;
        uint256 price;
        uint256 shopBuyRoundLimit;
        uint256 userBuyRoundLimit;
    }

    address public feeTo;
    ICutaverse public cutaverse;

    SeedContainer[] public seedContainers;
    mapping(address => uint256) public seedContainersOfPid;

    mapping(address => Overrun.Limit) public seedShopBuyLimit;
    mapping(address => mapping(address => Overrun.Limit)) public seedUserBuyLimit;

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/structs/EnumerableSet.sol)

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
 *
 * [WARNING]
 * ====
 *  Trying to delete such a structure from storage will likely result in data corruption, rendering the structure unusable.
 *  See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 *  In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an array of EnumerableSet.
 * ====
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
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
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

        /// @solidity memory-safe-assembly
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

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}