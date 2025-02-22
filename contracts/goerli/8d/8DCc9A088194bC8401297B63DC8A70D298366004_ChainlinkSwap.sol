// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "./BaseSwap.sol";

contract ChainlinkSwap is BaseSwap {

    /// @param _tokenA the commodity token
    /// @param _tokenB the stable token
    /// @param _commdexName Name for the dex
    /// @param _tradeFee Fee per swap
    /// @param _commodityChainlinkAddress chainlink price feed address for commodity
    /// @param _dexAdmin Comm-dex admin 
    constructor(
        address _tokenA,
        address _tokenB,
        string memory _commdexName,
        uint256 _tradeFee,
        address _commodityChainlinkAddress,
        address _dexAdmin
    ) {
        require(
            _dexAdmin != address(0),
            "Invalid address"
        );
        dexData.tokenA = _tokenA;
        dexData.tokenB = _tokenB;
        dexSettings.comdexName = _commdexName;
        dexSettings.tradeFee = _tradeFee;
        dexSettings.dexAdmin = _dexAdmin;

        priceFeed = AggregatorV3Interface(_commodityChainlinkAddress);
    }

    /// @notice Allows Swaps from commodity token to another token and vice versa,
    /// @param _amountIn Amount of tokens user want to give for swap (in decimals of _from token)
    /// @param _from token that user wants to spend
    /// @param _to token that user wants in result of swap

    function swap(
        uint256 _amountIn,
        address _from,
        address _to
    ) external virtual whenNotPaused {
        require(_amountIn > 0, "wrong amount");
        require(
            (_from == dexData.tokenA && _to == dexData.tokenB) ||
                (_to == dexData.tokenA && _from == dexData.tokenB),
            "wrong pair"
        );

        uint256 amountFee = (_amountIn * dexSettings.tradeFee) / (10**8);

        if (_from == dexData.tokenA) {
            uint256 amountA = _amountIn - amountFee;
            uint256 amountB = (amountA * getChainLinkFeedPrice()) / (10**8);
            amountB = SwapLib.normalizeAmount(amountB, _from, _to);

            if (dexData.reserveB < amountB)
                emit LowTokenBalance(dexData.tokenB, dexData.reserveB);
            require(dexData.reserveB >= amountB, "not enough balance");
            
            TransferHelper.safeTransferFrom(
                dexData.tokenA,
                msg.sender,
                address(this),
                _amountIn
            );
            TransferHelper.safeTransfer(dexData.tokenB, msg.sender, amountB);

            dexData.reserveA = dexData.reserveA + amountA;
            dexData.reserveB = dexData.reserveB - amountB;
            dexData.feeA_Storage = dexData.feeA_Storage + amountFee;
            emit Swapped(msg.sender, _amountIn, amountB, SwapLib.SELL_INDEX);
        } else {
            uint256 amountB = _amountIn - amountFee;
            uint256 amountA = (amountB * (10**8)) / getChainLinkFeedPrice();
            amountA = SwapLib.normalizeAmount(amountA, _from, _to);

            if (dexData.reserveA < amountA)
                emit LowTokenBalance(dexData.tokenA, dexData.reserveA);
            require(dexData.reserveA >= amountA, "not enough balance");

            TransferHelper.safeTransferFrom(
                dexData.tokenB,
                msg.sender,
                address(this),
                _amountIn
            );
            TransferHelper.safeTransfer(dexData.tokenA, msg.sender, amountA);

            dexData.reserveA = dexData.reserveA - amountA;
            dexData.reserveB = dexData.reserveB + amountB;
            dexData.feeB_Storage = dexData.feeB_Storage + amountFee;
            emit Swapped(msg.sender, _amountIn, amountA, SwapLib.BUY_INDEX);
        }
    }


    /// @notice adds liquidity for both assets
    /// @dev amountB should be = amountA * price
    /// @param amountA amount of tokens for commodity asset
    /// @param amountB amount of tokens for stable asset

    function addLiquidity(uint256 amountA, uint256 amountB)
        external
        virtual
        onlyOwner
    {
        uint amount = (amountA * getChainLinkFeedPrice()) / (10**8);
        require(
            SwapLib.normalizeAmount(amount,dexData.tokenA, dexData.tokenB) == amountB,
            "amounts should be equal"
        );
        super._addLiquidity(amountA, amountB);
        emit LiquidityAdded(_msgSender(), amountA, amountB);
    }

    /// @notice removes liquidity for both assets
    /// @dev amountB should be = amountA * price
    /// @param amountA amount of tokens for commodity asset
    /// @param amountB amount of tokens for stable asset

    function removeLiquidity(uint256 amountA, uint256 amountB)
        external
        virtual
        onlyOwner
    {
        uint amount = (amountA * getChainLinkFeedPrice()) / (10**8);
        require(
            SwapLib.normalizeAmount(amount, dexData.tokenA, dexData.tokenB) == amountB,
            "amountA should be equal"
        );
        super._removeLiquidity(amountA, amountB);
        emit LiquidityRemoved(_msgSender(), amountA, amountB);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../utils/TransferHelper.sol";
import "../interfaces/ISwap.sol";
import "./../utils/Pausable.sol";
import "./../interfaces/IERC20.sol";

import {SwapLib} from "../lib/Lib.sol";

abstract contract BaseSwap is Ownable, ISwap, Pausable {
    using SwapLib for *;

    SwapLib.DexData public dexData;
    SwapLib.DexSetting public dexSettings;
    AggregatorV3Interface internal priceFeed;

    modifier onlyComdexAdmin() {
        _onlyCommdexOwner();
        _;
    }

    function _onlyCommdexOwner() internal view{
       require(
            msg.sender == dexSettings.dexAdmin,
            "Caller is not comm-dex owner"
        );
    }

    /// @notice Adds liquidity for both assets
    /// @param amountA amount of tokens for commodity asset
    /// @param amountB amount of tokens for stable asset

    function _addLiquidity(uint256 amountA, uint256 amountB) internal {
        TransferHelper.safeTransferFrom(
            dexData.tokenA,
            msg.sender,
            address(this),
            amountA
        );
        TransferHelper.safeTransferFrom(
            dexData.tokenB,
            msg.sender,
            address(this),
            amountB
        );
        dexData.reserveA = dexData.reserveA + amountA;
        dexData.reserveB = dexData.reserveB + amountB;
        emit LiquidityAdded(_msgSender(), amountA, amountB);
    }

    /// @notice Removes liquidity for both assets
    /// @param amountA amount of tokens for commodity asset
    /// @param amountB amount of tokens for stable asset

    function _removeLiquidity(uint256 amountA, uint256 amountB) internal {
        TransferHelper.safeTransfer(dexData.tokenA, _msgSender(), amountA);
        TransferHelper.safeTransfer(dexData.tokenB, _msgSender(), amountB);
        dexData.reserveA = dexData.reserveA - amountA;
        dexData.reserveB = dexData.reserveB - amountB;
        emit LiquidityRemoved(_msgSender(), amountA, amountB);
    }

    /// @notice Allows to set trade fee for swap
    /// @param _newTradeFee updated trade fee, should be < 10 ** 8


    function setTradeFee(uint256 _newTradeFee) external onlyComdexAdmin {
        require(_newTradeFee < 10**8, "Wrong Fee!");
        dexSettings.tradeFee = _newTradeFee;
        emit TradeFeeChanged(_newTradeFee);
    }

    /// @notice Allows comm-dex admin to withdraw fee

    function withdrawFee() external onlyComdexAdmin {

        withdrawFeeHelper();

        emit FeeWithdraw(
            msg.sender,
            dexData.feeA_Storage,
            dexData.feeB_Storage
        );

        resetFees();
    }

    /// @notice Allows to set Chainlink feed address
    /// @param _chainlinkPriceFeed the updated chainlink price feed address

    function setChainlinkFeedAddress(address _chainlinkPriceFeed)
        external
        onlyComdexAdmin
    {
        priceFeed = AggregatorV3Interface(_chainlinkPriceFeed);
        emit ChainlinkFeedAddressChanged(_chainlinkPriceFeed);
    }

    /// @notice Allows to set comm-dex admin
    /// @param _updatedAdmin the new admin

    function setCommdexAdmin(address _updatedAdmin) external onlyComdexAdmin {
        require(
            _updatedAdmin != address(0) &&
                _updatedAdmin != dexSettings.dexAdmin,
            "Invalid Address"
        );
        dexSettings.dexAdmin = _updatedAdmin;
        emit ComDexAdminChanged(_updatedAdmin);
    }

    /// @notice allows Swap admin to withdraw reserves in case of emergency

    function emergencyWithdraw() external onlyOwner {

        withDrawReserveHelper();

        emit EmergencyWithdrawComplete(
            msg.sender,
            dexData.reserveA,
            dexData.reserveB
        );

        resetReserves();
    }

    /// @notice Allows comm-dex admin to empty dex, sends reserves to comm-dex admin and fee to comm-dex admin

    function withDrawAndDestory(address _to) external onlyComdexAdmin {

        // withdraw the reserves
        withDrawReserveHelper();
        // withdraw fees
        withdrawFeeHelper();

        emit withDrawAndDestroyed(
            msg.sender,
            dexData.reserveA,
            dexData.reserveB,
            dexData.feeA_Storage,
            dexData.feeB_Storage
        );

        selfdestruct(payable(_to));
    }

    function getChainLinkFeedPrice() internal view returns (uint256) {
        (
            ,
            /*uint80 roundID*/
            int256 price, /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/
            ,
            ,

        ) = priceFeed.latestRoundData();
        require(price >= 0, "ChainLink price error");
        return uint256(price);
    }

    function withdrawFeeHelper() internal{
        address dexAdmin = dexSettings.dexAdmin;

        TransferHelper.safeTransfer(
            dexData.tokenA,
            dexAdmin,
            dexData.feeA_Storage
        );
        TransferHelper.safeTransfer(
            dexData.tokenB,
            dexAdmin,
            dexData.feeB_Storage
        );
    }

    function withDrawReserveHelper() internal {
        address dexOwner = owner();
        TransferHelper.safeTransfer(
            dexData.tokenA,
            dexOwner,
            dexData.reserveA
        );
        TransferHelper.safeTransfer(
            dexData.tokenB,
            dexOwner,
            dexData.reserveB
        );
    }

    function resetReserves() internal{
        dexData.reserveA = 0;
        dexData.reserveB = 0;
    }

    function resetFees() internal {
        dexData.feeA_Storage = 0;
        dexData.feeB_Storage = 0;
    }

    /// @notice pauses the Swap function

    function unpause() external onlyComdexAdmin {
        _unpause();
    }

    /// @notice unpause the Swap function

    function pause() external onlyComdexAdmin{
        _pause();
    }    
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper::safeApprove: approve failed"
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper::safeTransfer: transfer failed"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper::safeTransferFrom: transferFrom failed"
        );
    }

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IERC20{
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface ISwap {
    event LowTokenBalance(address Token, uint256 balanceLeft);
    event Swapped(
        address indexed sender,
        uint256 amountIn,
        uint256 amountOut,
        uint256 isSale
    );
    event LiquidityAdded(
        address indexed sender,
        uint256 amountA,
        uint256 amountB
    );
    event LiquidityRemoved(
        address indexed sender,
        uint256 amountA,
        uint256 amountB
    );
    event TradeFeeChanged(uint256 newTradeFee);
    event ComDexAdminChanged(address newAdmin);
    event EmergencyWithdrawComplete(
        address indexed sender,
        uint256 amountA,
        uint256 amountB
    );
    event FeeWithdraw(address indexed sender, uint256 amountA, uint256 amountB);
    event ChainlinkFeedAddressChanged(address newFeedAddress);
    event withDrawAndDestroyed(
        address indexed sender,
        uint256 reserveA,
        uint256 reserveB,
        uint256 feeA,
        uint256 feeB
    );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


abstract contract Pausable {
  
    event Paused(address account);


    event Unpaused(address account);

    bool private _paused;

 
    constructor() {
        _paused = false;
    }


    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }


    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }


    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }


    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

  
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./../interfaces/IERC20.sol";
library ChainlinkLib {
    struct ApiInfo {
        string _apiUrl;
        string[2] _chainlinkRequestPath; //0 index contains buy and 1 contains sell
    }
    struct ChainlinkInfo {
        address chainlinkToken;
        address chainlinkOracle;
        address chianlinkPriceFeed;
        bool chainlinkFeedEnabled;
    }
}

library SwapLib {
    uint256 constant BUY_INDEX = 0;
    uint256 constant SELL_INDEX = 1;
    struct DexSetting {
        string comdexName;
        uint256 tradeFee;
        address dexAdmin;
        uint256 rateTimeOut;
    }

    struct DexData {
        uint256 reserveA;
        uint256 reserveB;
        uint256 feeA_Storage; // storage that the fee of token A can be stored
        uint256 feeB_Storage; // storage that the fee of token B can be stored
        address tokenA;
        address tokenB;
    }

    function normalizeAmount(uint _amountIn, address _from, address _to) internal view returns(uint256){
        uint fromDecimals = IERC20(_from).decimals();
        uint toDecimals = IERC20(_to).decimals();
        if(fromDecimals == toDecimals) return _amountIn;
        return fromDecimals > toDecimals ? _amountIn / (10**(fromDecimals-toDecimals)) : _amountIn * (10**(toDecimals - fromDecimals));
    }

    function checkFee(uint _fee) internal pure{
        require(_fee <10**8, "wrong fee amount");
    }

    function checkTokenAddress(address _tokenA, address _tokenB) internal pure{
        require(_tokenA != address(0) && _tokenB != address(0),"invalid token");
    }
}

library PriceLib {
    struct PriceInfo {
        uint256[] rates; //= new uint256[](2);//0 index contains buy and 1 contains sell
        bytes32[] chainlinkRequestId; // = new bytes32[](2);//0 index contains buy and 1 contains sell
        uint256[] lastTimeStamp; //= new uint256[](2);//0 index contains buy and 1 contains sell
        uint256[] lastPriceFeed; //= new uint256[](2);//0 index contains buy and 1 contains sell
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
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
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