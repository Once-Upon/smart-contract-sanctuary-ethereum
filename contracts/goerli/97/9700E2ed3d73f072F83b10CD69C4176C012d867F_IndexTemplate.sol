pragma solidity 0.8.12;

/**
 * @author InsureDAO
 * @title InsureDAO market template contract
 * SPDX-License-Identifier: GPL-3.0
 */

import "./InsureDAOERC20.sol";
import "../interfaces/IIndexTemplate.sol";
import "../interfaces/IUniversalMarket.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IRegistry.sol";
import "../interfaces/IParameters.sol";
import "../interfaces/IPoolTemplate.sol";
import "../interfaces/ICDSTemplate.sol";

/**
 * An index pool can index a certain number of pools with leverage.
 *
 * Index A
 * 　├ Pool A
 * 　├ Pool B
 * 　├ Pool C
 * 　...
 *
 */

contract IndexTemplate is InsureDAOERC20, IIndexTemplate, IUniversalMarket {
    /**
     * EVENTS
     */
    event Deposit(address indexed depositor, uint256 amount, uint256 mint);
    event WithdrawRequested(address indexed withdrawer, uint256 amount, uint256 unlockTime);
    event Withdraw(address indexed withdrawer, uint256 amount, uint256 retVal);
    event Compensated(address indexed index, uint256 amount);
    event Paused(bool paused);
    event Resumed();
    event Locked();
    event MetadataChanged(string metadata);
    event LeverageSet(uint256 target);
    event AllocationSet(uint256 indexed _indexA, uint256 indexed _indexB, address indexed pool, uint256 allocPoint);

    /**
     * Storage
     */
    /// @notice Market setting
    bool public initialized;
    bool public paused;
    bool public locked;
    string public metadata;

    /// @notice External contract call addresses
    IParameters public parameters;
    IVault public vault;
    IRegistry public registry;

    /// @notice Market variables for margin account
    uint256 public totalAllocatedCredit; //total allocated credit(liquidity)
    mapping(address => uint256) public allocPoints; //allocation point for each pool
    uint256 public totalAllocPoint; //total allocation point
    address[] public poolList; //list of all pools
    uint256 public targetLev; //1x = MAGIC_SCALE_1E6
    //The allocated credits are deemed as liquidity in each underlying pool
    //Credit amount(liquidity) will be determined by the following math
    //credit for a pool = total liquidity of this pool * leverage rate * allocation point for a pool / total allocation point

    ///@notice user status management
    struct Withdrawal {
        uint64 timestamp;
        uint192 amount;
    }
    mapping(address => Withdrawal) public withdrawalReq;

    struct PoolStatus {
        uint256 current;
        uint256 available;
        uint256 allocation;
        uint256 shortage;
        uint256 _freeableCredits;
        address addr;
    }

    ///@notice magic numbers
    uint256 private constant MAGIC_SCALE_1E6 = 1e6; //internal multiplication scale 1e6 to reduce decimal truncation

    /**
     * @notice Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == parameters.getOwner(), "Caller is not allowed to operate");
        _;
    }

    constructor() {
        initialized = true;
    }

    /**
     * Initialize interaction
     */

    /**
     * @notice Initialize market
     * This function registers market conditions.
     * references[0] = underlying token address
     * references[1] = registry
     * references[2] = parameter
     * @param _metaData arbitrary string to store market information
     * @param _conditions array of conditions
     * @param _references array of references
     */
    function initialize(
        address _depositor,
        string calldata _metaData,
        uint256[] calldata _conditions,
        address[] calldata _references
    ) external override {
        require(
            !initialized &&
                bytes(_metaData).length != 0 &&
                _references[0] != address(0) &&
                _references[1] != address(0) &&
                _references[2] != address(0),
            "INITIALIZATION_BAD_CONDITIONS"
        );

        initialized = true;

        string memory _name = "InsureDAO-Index";
        string memory _symbol = "iIndex";
        uint8 _decimals = IERC20Metadata(_references[0]).decimals();

        initializeToken(_name, _symbol, _decimals);

        parameters = IParameters(_references[2]);
        vault = IVault(parameters.getVault(_references[0]));
        registry = IRegistry(_references[1]);

        metadata = _metaData;
    }

    /**
     * Pool interactions
     */

    /**
     * @notice A liquidity provider supplies collateral to the pool and receives iTokens
     * @param _amount amount of token to deposit
     * @return _mintAmount the amount of iToken minted from the transaction
     */
    function deposit(uint256 _amount) external returns (uint256 _mintAmount) {
        require(!locked && !paused, "ERROR: DEPOSIT_DISABLED");
        require(_amount != 0, "ERROR: DEPOSIT_ZERO");

        uint256 _supply = totalSupply();
        uint256 _totalLiquidity = totalLiquidity();
        vault.addValue(_amount, msg.sender, address(this));

        if (_supply == 0) {
            _mintAmount = _amount;
        } else if (_totalLiquidity == 0) {
            _mintAmount = _amount * _supply;
        } else {
            _mintAmount = (_amount * _supply) / _totalLiquidity;
        }

        emit Deposit(msg.sender, _amount, _mintAmount);
        //mint iToken
        _mint(msg.sender, _mintAmount);
        uint256 _liquidityAfter = _totalLiquidity + _amount;
        uint256 _leverage = (totalAllocatedCredit * MAGIC_SCALE_1E6) / _liquidityAfter;
        //execut adjustAlloc only when the leverage became below target - lower-slack
        if (targetLev - parameters.getLowerSlack(address(this)) > _leverage) {
            _adjustAlloc(_liquidityAfter);
        }
    }

    /**
     * @notice A liquidity provider requests withdrawal of collateral
     * @param _amount amount of iToken to burn
     */
    function requestWithdraw(uint256 _amount) external {
        require(_amount != 0, "ERROR: REQUEST_ZERO");
        require(balanceOf(msg.sender) >= _amount, "ERROR: REQUEST_EXCEED_BALANCE");

        uint64 _unlocksAt = (uint64)(block.timestamp + parameters.getLockup(address(this)));

        withdrawalReq[msg.sender].timestamp = _unlocksAt;
        withdrawalReq[msg.sender].amount = (uint192)(_amount);

        emit WithdrawRequested(msg.sender, _amount, _unlocksAt);
    }

    /**
     * @notice A liquidity provider burns iToken and receives collateral from the pool
     * @param _amount amount of iToken to burn
     * @return _retVal the amount underlying token returned
     */
    function withdraw(uint256 _amount) external returns (uint256 _retVal) {
        require(_amount != 0, "ERROR: WITHDRAWAL_ZERO");
        require(!locked, "ERROR: WITHDRAWAL_MARKET_PAUSED");

        Withdrawal memory request = withdrawalReq[msg.sender];

        require(request.timestamp < block.timestamp, "ERROR: WITHDRAWAL_QUEUE");
        require(
            request.timestamp + parameters.getWithdrawable(address(this)) > block.timestamp,
            "WITHDRAWAL_NO_ACTIVE_REQUEST"
        );
        require(request.amount >= _amount, "WITHDRAWAL_EXCEEDED_REQUEST");

        //Calculate underlying value
        uint256 _liquidty = totalLiquidity();
        _retVal = (_liquidty * _amount) / totalSupply();
        require(_retVal <= withdrawable(), "WITHDRAW_INSUFFICIENT_LIQUIDITY");

        //reduce requested amount
        withdrawalReq[msg.sender].amount -= (uint192)(_amount);
        //Burn iToken
        _burn(msg.sender, _amount);

        //Check current leverage rate and get updated target total credit allocation
        uint256 _liquidityAfter = _liquidty - _retVal;

        if (_liquidityAfter != 0) {
            uint256 _leverage = (totalAllocatedCredit * MAGIC_SCALE_1E6) / _liquidityAfter;
            //execute adjustAlloc only when the leverage became above target + upper-slack
            if (targetLev + parameters.getUpperSlack(address(this)) < _leverage) {
                _adjustAlloc(_liquidityAfter);
            }
        } else {
            _adjustAlloc(0);
        }

        //Withdraw liquidity
        vault.withdrawValue(_retVal, msg.sender);

        emit Withdraw(msg.sender, _amount, _retVal);
    }

    /**
     * @notice Get how much can be withdrawn from this index by users
     * Withdrawable amount = Index liquidity - necessary amount to support credit liquidity
     * necessary amount = totalLockedCredits / leverageRate
     * eg. if leverageRate = 2, then necessary amount = totalLockedCredits / 2
     * we should also reserve 100% the lockedCredits for the pool with most locked
     * @return withdrawable amount
     */
    function withdrawable() public view returns (uint256) {
        uint256 _totalLiquidity = totalLiquidity();

        if (_totalLiquidity == 0) return 0;

        uint256 _length = poolList.length;
        uint256 _totalLockedCredits;
        uint256 _maxLockedCredits;

        for (uint256 i; i < _length; ++i) {
            (uint256 _allocated, uint256 _available) = IPoolTemplate(poolList[i]).pairValues(address(this));
            if (_allocated > _available) {
                uint256 _locked = _allocated - _available;
                _totalLockedCredits += _locked;
                if (_locked > _maxLockedCredits) {
                    _maxLockedCredits = _locked;
                }
            }
        }

        if (_totalLockedCredits == 0) {
            return _totalLiquidity;
        }

        uint256 _necessaryAmount = (_totalLockedCredits * MAGIC_SCALE_1E6) / targetLev;
        if (_maxLockedCredits > _necessaryAmount) {
            _necessaryAmount = _maxLockedCredits;
        }
        if (_necessaryAmount < _totalLiquidity) {
            unchecked {
                return _totalLiquidity - _necessaryAmount;
            }
        }
    }

    /**
     * @notice Adjust allocation of credit based on the target leverage rate
     */
    function adjustAlloc() public {
        _adjustAlloc(totalLiquidity());
    }

    /**
     * @notice adjust credit allocation
     * @param _liquidity available liquidity of the index.
     * @dev credit adjustment is done based on _liquidity and targetLeverage
     *
     * 1) calculate goal amount of totalCredits
     * 2) perform calculation for un-usual pools (get _totalFreeableCredits)
     * 3) if _targetTotalCredits <= (_totalAllocatedCredit - _totalFreeableCredits), go with withdraw-only mode
     * 4) else allocate the allocatable credits to the pools proportionally to the shortage of each pool
     */
    function _adjustAlloc(uint256 _liquidity) internal {
        uint256 _targetTotalCredits = (targetLev * _liquidity) / MAGIC_SCALE_1E6; //ゴール

        uint256 _allocatablePoints = totalAllocPoint;
        uint256 _totalAllocatedCredit = totalAllocatedCredit;
        uint256 _poolLength = poolList.length;

        uint256 _totalFreeableCredits;
        uint256 _totalFrozenCredits;

        PoolStatus[] memory _pools = new PoolStatus[](_poolLength);

        for (uint256 i; i < _poolLength; ++i) {
            address _poolAddr = poolList[i];
            uint256 _current;
            uint256 _available;
            (_current, _available) = IPoolTemplate(_poolAddr).pairValues(address(this));
            uint256 _allocation = allocPoints[_poolAddr];

            uint256 _freeableCredits = (_available > _current ? _current : _available);
            if (IPoolTemplate(_poolAddr).marketStatus() == IPoolTemplate.MarketStatus.Payingout) {
                _allocatablePoints -= _allocation;
                _allocation = 0;
                _freeableCredits = 0;
                _totalFrozenCredits += _current;
            } else if (_allocation == 0 || IPoolTemplate(_poolAddr).paused()) {
                _allocatablePoints -= _allocation;
                _allocation = 0;
                IPoolTemplate(_poolAddr).withdrawCredit(_freeableCredits);
                _totalAllocatedCredit -= _freeableCredits;
                _current -= _freeableCredits;
                _freeableCredits = 0;
                _totalFrozenCredits += _current;
            }

            _totalFreeableCredits += _freeableCredits;

            _pools[i].addr = _poolAddr;
            _pools[i].current = _current;
            _pools[i].available = _available;
            _pools[i]._freeableCredits = _freeableCredits;
            _pools[i].allocation = _allocation;
        }

        if (_targetTotalCredits <= _totalFrozenCredits) {
            _targetTotalCredits = 0;
        } else {
            _targetTotalCredits -= _totalFrozenCredits;
        }
        uint256 _totalFixedCredits = _totalAllocatedCredit - _totalFreeableCredits - _totalFrozenCredits;
        // if target credit is less than _totalFixedCredits, we go withdraw-only mode
        if (_totalFixedCredits >= _targetTotalCredits) {
            for (uint256 i; i < _poolLength; ++i) {
                if (_pools[i]._freeableCredits > 0) {
                    IPoolTemplate(_pools[i].addr).withdrawCredit(_pools[i]._freeableCredits);
                }
            }
            totalAllocatedCredit = _totalAllocatedCredit - _totalFreeableCredits;
        } else {
            uint256 _totalAllocatableCredits = _targetTotalCredits - _totalFixedCredits;
            uint256 _totalShortage;
            for (uint256 i; i < _poolLength; ++i) {
                if (_pools[i].allocation == 0) continue;
                uint256 _target = (_targetTotalCredits * _pools[i].allocation) / _allocatablePoints;
                uint256 _fixedCredits = _pools[i].current - _pools[i]._freeableCredits;
                // when _fixedCredits > target, we should withdraw all freeable credits
                if (_fixedCredits > _target) {
                    IPoolTemplate(_pools[i].addr).withdrawCredit(_pools[i]._freeableCredits);
                    _totalAllocatedCredit -= _pools[i]._freeableCredits;
                } else {
                    uint256 _shortage = _target - _fixedCredits;
                    _totalShortage += _shortage;
                    _pools[i].shortage = _shortage;
                }
            }
            for (uint256 i; i < _poolLength; ++i) {
                if (_pools[i].shortage == 0) continue;
                uint256 _reallocate = (_totalAllocatableCredits * _pools[i].shortage) / _totalShortage;
                // when _reallocate >= _freeableCredits, we deposit
                if (_reallocate >= _pools[i]._freeableCredits) {
                    // _freeableCredits is part of the `_reallocate`
                    uint256 _allocate = _reallocate - _pools[i]._freeableCredits;
                    IPoolTemplate(_pools[i].addr).allocateCredit(_allocate);
                    _totalAllocatedCredit += _allocate;
                } else {
                    uint256 _removal = _pools[i]._freeableCredits - _reallocate;
                    IPoolTemplate(_pools[i].addr).withdrawCredit(_removal);
                    _totalAllocatedCredit -= _removal;
                }
            }

            totalAllocatedCredit = _totalAllocatedCredit;
        }
    }

    /**
     * Insurance interactions
     */

    /**
     * @notice Make a payout if an accident occured in a underlying pool
     * @param _amount amount of liquidity to compensate for the called pool
     * We compensate underlying pools by the following steps
     * 1) Compensate underlying pools from the liquidity of this pool
     * 2) If this pool is unable to cover a compensation, can get compensated from the CDS pool
     */
    function compensate(uint256 _amount) external override returns (uint256 _compensated) {
        require(allocPoints[msg.sender] != 0, "COMPENSATE_UNAUTHORIZED_CALLER");
        uint256 _value = vault.underlyingValue(address(this));
        if (_value >= _amount) {
            //When the deposited value without earned premium is enough to cover
            _compensated = _amount;
        } else {
            //Withdraw credit to cashout the earnings
            unchecked {
                ICDSTemplate(registry.getCDS(address(this))).compensate(_amount - _value);
            }
            _compensated = vault.underlyingValue(address(this));
        }

        vault.offsetDebt(_compensated, msg.sender);

        // totalLiquity has been changed, adjustAlloc() will be called by the pool contract

        emit Compensated(msg.sender, _compensated);
    }

    /**
     * Reporting interactions
     */

    /**
     * @notice Resume market
     */
    function resume() external override {
        require(locked, "ERROR: MARKET_IS_NOT_LOCKED");
        uint256 _poolLength = poolList.length;

        for (uint256 i; i < _poolLength; ) {
            require(
                IPoolTemplate(poolList[i]).marketStatus() == IPoolTemplate.MarketStatus.Trading,
                "ERROR: POOL_IS_PAYINGOUT"
            );
            unchecked {
                ++i;
            }
        }
        adjustAlloc();
        locked = false;
        emit Resumed();
    }

    /**
     * @notice lock market withdrawal
     */
    function lock() external override {
        require(allocPoints[msg.sender] != 0);

        locked = true;
        emit Locked();
    }

    /**
     * Utilities
     */

    /**
     * @notice get the current leverage rate 1e6x
     * @return leverage rate
     */

    function leverage() external view returns (uint256) {
        uint256 _totalLiquidity = totalLiquidity();
        //check current leverage rate
        if (_totalLiquidity != 0) {
            return (totalAllocatedCredit * MAGIC_SCALE_1E6) / _totalLiquidity;
        }
    }

    /**
     * @notice total Liquidity of the pool (how much can the pool sell cover)
     * @return total liquidity of the pool
     */
    function totalLiquidity() public view returns (uint256) {
        return vault.underlyingValue(address(this)) + _accruedPremiums();
    }

    /**
     * @notice Get the exchange rate of LP token against underlying asset(scaled by MAGIC_SCALE_1E6)
     * @return The value against the underlying token balance.
     */
    function rate() external view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply != 0) {
            return (totalLiquidity() * MAGIC_SCALE_1E6) / _totalSupply;
        }
    }

    /**
     * @notice Get the underlying balance of the `owner`
     * @param _owner the target address to look up value
     * @return The balance of underlying token for the specified address
     */
    function valueOfUnderlying(address _owner) external view returns (uint256) {
        uint256 _balance = balanceOf(_owner);
        uint256 _totalSupply = totalSupply();
        if (_balance != 0 && _totalSupply != 0) {
            return (_balance * totalLiquidity()) / _totalSupply;
        }
    }

    /**
     * @notice Get all underlying pools
     * @return pool array
     */
    function getAllPools() external view returns (address[] memory) {
        return poolList;
    }

    /**
     * Admin functions
     */

    /**
     * @notice Used for changing settlementFeeRecipient
     * @param _state true to set paused and vice versa
     */
    function setPaused(bool _state) external override onlyOwner {
        if (paused != _state) {
            paused = _state;
            emit Paused(_state);
        }
    }

    /**
     * @notice Change metadata string
     * @param _metadata new metadata string
     */
    function changeMetadata(string calldata _metadata) external override onlyOwner {
        metadata = _metadata;
        emit MetadataChanged(_metadata);
    }

    /**
     * @notice Change target leverate rate for this index x 1e6
     * @param _target new leverage rate
     */
    function setLeverage(uint256 _target) external override onlyOwner {
        require(_target >= MAGIC_SCALE_1E6, "leverage must be x1 or higher");
        targetLev = _target;
        adjustAlloc();
        emit LeverageSet(_target);
    }

    /**
     * @notice Change allocation point for each pool
     * @param _indexA target index id of the underlying pool
     * @param _indexB target index id of the index address within the underlying pool
     * @param _pool address of pool
     * @param _allocPoint new allocation point
     */
    function set(
        uint256 _indexA,
        uint256 _indexB,
        address _pool,
        uint256 _allocPoint
    ) external override onlyOwner {
        require(registry.isListed(_pool), "ERROR:UNREGISTERED_POOL");
        require(_indexA <= parameters.getMaxList(address(this)), "ERROR: EXCEEEDED_MAX_INDEX");
        uint256 _length = poolList.length;

        uint256 _totalAllocPoint = totalAllocPoint;

        //create a new pool or replace existing
        if (_length <= _indexA) {
            require(_length == _indexA, "ERROR: BAD_INDEX");
            IPoolTemplate(_pool).registerIndex(_indexB);
            poolList.push(_pool);
        } else {
            //action for existing slot
            address _poolAddress = poolList[_indexA];
            if (_poolAddress != address(0) && _poolAddress != _pool) {
                (uint256 _current, uint256 _available) = IPoolTemplate(_poolAddress).pairValues(address(this));

                require(
                    IPoolTemplate(_poolAddress).marketStatus() == IPoolTemplate.MarketStatus.Trading &&
                        _available >= _current,
                    "ERROR: CANNOT_EXIT_POOL"
                );
                IPoolTemplate(_poolAddress).withdrawCredit(_current);
            }
            _totalAllocPoint -= allocPoints[_poolAddress];
            IPoolTemplate(_pool).registerIndex(_indexB);
            poolList[_indexA] = _pool;
        }

        totalAllocPoint = _totalAllocPoint + _allocPoint;
        allocPoints[_pool] = _allocPoint;
        adjustAlloc();
        emit AllocationSet(_indexA, _indexB, _pool, _allocPoint);
    }

    /**
     * Internal functions
     */

    /**
     * @notice Internal function to offset withdraw request and latest balance
     * @param from the account who send
     * @param to a
     * @param amount the amount of token to offset
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from != address(0)) {
            uint256 _after = balanceOf(from) - amount;
            if (_after < withdrawalReq[from].amount) {
                withdrawalReq[from].amount = (uint192)(_after);
            }
        }
    }

    /**
     * @notice Get the total equivalent value of credit to token
     * @return _totalValue accrued but yet claimed premium within underlying pools
     */
    function _accruedPremiums() internal view returns (uint256 _totalValue) {
        uint256 poolLength = poolList.length;
        for (uint256 i; i < poolLength; ) {
            if (allocPoints[poolList[i]] != 0) {
                _totalValue = _totalValue + IPoolTemplate(poolList[i]).pendingPremium(address(this));
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Overflow free minus function that returns zero
     * @return _result result of the subtraction operation
     */
    function _safeMinus(uint256 _a, uint256 _b) internal pure returns (uint256 _result) {
        if (_a >= _b) {
            _result = _a - _b;
        } else {
            _result = 0;
        }
    }
}

pragma solidity 0.8.12;

/**
 * @author InsureDAO
 * @title LP Token Contract for Pools
 * SPDX-License-Identifier: GPL-3.0
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract InsureDAOERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    bool tokenInitialized;
    string private _name = "InsureDAO LP Token";
    string private _symbol = "iLP";
    uint8 private _decimals = 18;

    function initializeToken(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) internal {
        /***
         *@notice initialize token. Only called internally.
         *
         */
        require(!tokenInitialized, "Token is already initialized");
        tokenInitialized = true;
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() external view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() external view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) external virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) external view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) external virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual override returns (bool) {
        if (amount != 0) {
            uint256 currentAllowance = _allowances[sender][msg.sender];
            if (currentAllowance != type(uint256).max) {
                require(currentAllowance >= amount, "Transfer amount > allowance");
                unchecked {
                    _approve(sender, msg.sender, currentAllowance - amount);
                }
            }

            _transfer(sender, recipient, amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        if (addedValue != 0) {
            _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        }
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        if (subtractedValue != 0) {
            uint256 currentAllowance = _allowances[msg.sender][spender];
            require(currentAllowance >= subtractedValue, "Decreased allowance below zero");

            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        if (amount != 0) {
            require(sender != address(0), "Transfer from the zero address");
            require(recipient != address(0), "Transfer to the zero address");

            _beforeTokenTransfer(sender, recipient, amount);

            uint256 senderBalance = _balances[sender];
            require(senderBalance >= amount, "Transfer amount exceeds balance");

            unchecked {
                _balances[sender] = senderBalance - amount;
            }

            _balances[recipient] += amount;

            emit Transfer(sender, recipient, amount);

            _afterTokenTransfer(sender, recipient, amount);
        }
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        if (amount != 0) {
            require(account != address(0), "Mint to the zero address");

            _beforeTokenTransfer(address(0), account, amount);

            _totalSupply += amount;
            _balances[account] += amount;
            emit Transfer(address(0), account, amount);

            _afterTokenTransfer(address(0), account, amount);
        }
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        if (amount != 0) {
            require(account != address(0), "Burn from the zero address");

            _beforeTokenTransfer(account, address(0), amount);

            uint256 accountBalance = _balances[account];
            require(accountBalance >= amount, "Burn amount exceeds balance");
            unchecked {
                _balances[account] = accountBalance - amount;
            }

            _totalSupply -= amount;

            emit Transfer(account, address(0), amount);

            _afterTokenTransfer(account, address(0), amount);
        }
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

pragma solidity 0.8.12;

interface IIndexTemplate {
    function compensate(uint256) external returns (uint256 _compensated);

    function lock() external;

    function resume() external;

    function adjustAlloc() external;

    //onlyOwner
    function setLeverage(uint256 _target) external;

    function set(
        uint256 _indexA,
        uint256 _indexB,
        address _pool,
        uint256 _allocPoint
    ) external;
}

pragma solidity 0.8.12;

interface IUniversalMarket {
    function initialize(
        address _depositor,
        string calldata _metaData,
        uint256[] calldata _conditions,
        address[] calldata _references
    ) external;

    //onlyOwner
    function setPaused(bool state) external;

    function changeMetadata(string calldata _metadata) external;
}

pragma solidity 0.8.12;

interface IVault {
    function addValueBatch(
        uint256 _amount,
        address _from,
        address[2] memory _beneficiaries,
        uint256[2] memory _shares
    ) external returns (uint256[2] memory _allocations);

    function addValue(
        uint256 _amount,
        address _from,
        address _attribution
    ) external returns (uint256 _attributions);

    function withdrawValue(uint256 _amount, address _to) external returns (uint256 _attributions);

    function transferValue(uint256 _amount, address _destination) external returns (uint256 _attributions);

    function withdrawAttribution(uint256 _attribution, address _to) external returns (uint256 _retVal);

    function withdrawAllAttribution(address _to) external returns (uint256 _retVal);

    function transferAttribution(uint256 _amount, address _destination) external;

    function attributionOf(address _target) external view returns (uint256);

    function underlyingValue(address _target) external view returns (uint256);

    function attributionValue(uint256 _attribution) external view returns (uint256);

    function utilize() external returns (uint256 _amount);

    function valueAll() external view returns (uint256);

    function token() external returns (address);

    function borrowValue(uint256 _amount, address _to) external;

    /*
    function borrowAndTransfer(uint256 _amount, address _to)
        external
        returns (uint256 _attributions);
    */

    function offsetDebt(uint256 _amount, address _target) external returns (uint256 _attributions);

    function repayDebt(uint256 _amount, address _target) external;

    function debts(address _debtor) external view returns (uint256);

    function transferDebt(uint256 _amount) external;

    //onlyOwner
    function withdrawRedundant(address _token, address _to) external;

    function setController(address _controller) external;

    function setKeeper(address _keeper) external;
}

pragma solidity 0.8.12;

interface IRegistry {
    function isListed(address _market) external view returns (bool);

    function getCDS(address _address) external view returns (address);

    function confirmExistence(address _template, address _target) external view returns (bool);

    //onlyOwner
    function setFactory(address _factory) external;

    function supportMarket(address _market) external;

    function setExistence(address _template, address _target) external;

    function setCDS(address _address, address _cds) external;
}

pragma solidity 0.8.12;

interface IParameters {
    function setVault(address _token, address _vault) external;

    function setLockup(address _address, uint256 _target) external;

    function setGrace(address _address, uint256 _target) external;

    function setMaxDate(address _address, uint256 _target) external;

    function setMinDate(address _address, uint256 _target) external;

    function setUpperSlack(address _address, uint256 _target) external;

    function setLowerSlack(address _address, uint256 _target) external;

    function setWithdrawable(address _address, uint256 _target) external;

    function setPremiumModel(address _address, address _target) external;

    function setFeeRate(address _address, uint256 _target) external;

    function setMaxList(address _address, uint256 _target) external;

    function setCondition(bytes32 _reference, bytes32 _target) external;

    function getOwner() external view returns (address);

    function getVault(address _token) external view returns (address);

    function getPremium(
        uint256 _amount,
        uint256 _term,
        uint256 _totalLiquidity,
        uint256 _lockedAmount,
        address _target
    ) external view returns (uint256);

    function getFeeRate(address _target) external view returns (uint256);

    function getUpperSlack(address _target) external view returns (uint256);

    function getLowerSlack(address _target) external view returns (uint256);

    function getLockup(address _target) external view returns (uint256);

    function getWithdrawable(address _target) external view returns (uint256);

    function getGrace(address _target) external view returns (uint256);

    function getMaxDate(address _target) external view returns (uint256);

    function getMinDate(address _target) external view returns (uint256);

    function getMaxList(address _target) external view returns (uint256);

    function getCondition(bytes32 _reference) external view returns (bytes32);
}

pragma solidity 0.8.12;

interface IPoolTemplate {
    enum MarketStatus {
        Trading,
        Payingout
    }

    function deposit(uint256 _amount) external returns (uint256 _mintAmount);

    function requestWithdraw(uint256 _amount) external;

    function withdraw(uint256 _amount) external returns (uint256 _retVal);

    function insure(
        uint256,
        uint256,
        uint256,
        bytes32,
        address,
        address
    ) external returns (uint256);

    function redeem(
        uint256 _id,
        uint256 _loss,
        bytes32[] calldata _merkleProof
    ) external;

    function getPremium(uint256 _amount, uint256 _span) external view returns (uint256);

    function unlockBatch(uint256[] calldata _ids) external;

    function unlock(uint256 _id) external;

    function registerIndex(uint256 _index) external;

    function allocateCredit(uint256 _credit) external returns (uint256 _mintAmount);

    function pairValues(address _index) external view returns (uint256, uint256);

    function resume() external;

    function rate() external view returns (uint256);

    function withdrawCredit(uint256 _credit) external returns (uint256 _retVal);

    function marketStatus() external view returns (MarketStatus);

    function availableBalance() external view returns (uint256 _balance);

    function utilizationRate() external view returns (uint256 _rate);

    function totalLiquidity() external view returns (uint256 _balance);

    function totalCredit() external view returns (uint256);

    function lockedAmount() external view returns (uint256);

    function valueOfUnderlying(address _owner) external view returns (uint256);

    function pendingPremium(address _index) external view returns (uint256);

    function paused() external view returns (bool);

    //onlyOwner
    function applyCover(
        uint256 _pending,
        uint256 _payoutNumerator,
        uint256 _payoutDenominator,
        uint256 _incidentTimestamp,
        bytes32 _merkleRoot,
        string calldata _rawdata,
        string calldata _memo
    ) external;

    function applyBounty(
        uint256 _amount,
        address _contributor,
        uint256[] calldata _ids
    ) external;
}

pragma solidity 0.8.12;

interface ICDSTemplate {
    function compensate(uint256) external returns (uint256 _compensated);

    //onlyOwner
    function defund(address _to, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

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