// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

// Adapted from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/53516bc555a454862470e7860a9b5254db4d00f5/contracts/token/ERC20/ERC20Permit.sol

// Inspired on token.sol from DappHub. Natspec adpated from OpenZeppelin.

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
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

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

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Calls to {transferFrom} do not check for allowance if the caller is the owner
 * of the funds. This allows to reduce the number of approvals that are necessary.
 *
 * Finally, {transferFrom} does not decrease the allowance if it is set to
 * type(uint256).max. This reduces the gas costs without any likely impact.
 */
contract ERC20 is IERC20Metadata {
    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balanceOf;
    mapping(address => mapping(address => uint256)) internal _allowance;
    string public override name = '???';
    string public override symbol = '???';
    uint8 public override decimals = 18;

    /**
     *  @dev Sets the values for {name}, {symbol} and {decimals}.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() external view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address guy)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _balanceOf[guy];
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _allowance[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     */
    function approve(address spender, uint256 wad)
        external
        virtual
        override
        returns (bool)
    {
        return _setAllowance(msg.sender, spender, wad);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - the caller must have a balance of at least `wad`.
     */
    function transfer(address dst, uint256 wad)
        external
        virtual
        override
        returns (bool)
    {
        return _transfer(msg.sender, dst, wad);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `src` must have a balance of at least `wad`.
     * - the caller is not `src`, it must have allowance for ``src``'s tokens of at least
     * `wad`.
     */
    /// if_succeeds {:msg "TransferFrom - decrease allowance"} msg.sender != src ==> old(_allowance[src][msg.sender]) >= wad;
    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external virtual override returns (bool) {
        _decreaseAllowance(src, wad);

        return _transfer(src, dst, wad);
    }

    /**
     * @dev Moves tokens `wad` from `src` to `dst`.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `src` must have a balance of at least `amount`.
     */
    /// if_succeeds {:msg "Transfer - src decrease"} old(_balanceOf[src]) >= _balanceOf[src];
    /// if_succeeds {:msg "Transfer - dst increase"} _balanceOf[dst] >= old(_balanceOf[dst]);
    /// if_succeeds {:msg "Transfer - supply"} old(_balanceOf[src]) + old(_balanceOf[dst]) == _balanceOf[src] + _balanceOf[dst];
    function _transfer(
        address src,
        address dst,
        uint256 wad
    ) internal virtual returns (bool) {
        require(_balanceOf[src] >= wad, 'ERC20: Insufficient balance');
        unchecked {
            _balanceOf[src] = _balanceOf[src] - wad;
        }
        _balanceOf[dst] = _balanceOf[dst] + wad;

        emit Transfer(src, dst, wad);

        return true;
    }

    /**
     * @dev Sets the allowance granted to `spender` by `owner`.
     *
     * Emits an {Approval} event indicating the updated allowance.
     */
    function _setAllowance(
        address owner,
        address spender,
        uint256 wad
    ) internal virtual returns (bool) {
        _allowance[owner][spender] = wad;
        emit Approval(owner, spender, wad);

        return true;
    }

    /**
     * @dev Decreases the allowance granted to the caller by `src`, unless src == msg.sender or _allowance[src][msg.sender] == MAX
     *
     * Emits an {Approval} event indicating the updated allowance, if the allowance is updated.
     *
     * Requirements:
     *
     * - `spender` must have allowance for the caller of at least
     * `wad`, unless src == msg.sender
     */
    /// if_succeeds {:msg "Decrease allowance - underflow"} old(_allowance[src][msg.sender]) <= _allowance[src][msg.sender];
    function _decreaseAllowance(address src, uint256 wad)
        internal
        virtual
        returns (bool)
    {
        if (src != msg.sender) {
            uint256 allowed = _allowance[src][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= wad, 'ERC20: Insufficient approval');
                unchecked {
                    _setAllowance(src, msg.sender, allowed - wad);
                }
            }
        }

        return true;
    }

    /** @dev Creates `wad` tokens and assigns them to `dst`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     */
    /// if_succeeds {:msg "Mint - balance overflow"} old(_balanceOf[dst]) >= _balanceOf[dst];
    /// if_succeeds {:msg "Mint - supply overflow"} old(_totalSupply) >= _totalSupply;
    function _mint(address dst, uint256 wad) internal virtual returns (bool) {
        _balanceOf[dst] = _balanceOf[dst] + wad;
        _totalSupply = _totalSupply + wad;
        emit Transfer(address(0), dst, wad);

        return true;
    }

    /**
     * @dev Destroys `wad` tokens from `src`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `src` must have at least `wad` tokens.
     */
    /// if_succeeds {:msg "Burn - balance underflow"} old(_balanceOf[src]) <= _balanceOf[src];
    /// if_succeeds {:msg "Burn - supply underflow"} old(_totalSupply) <= _totalSupply;
    function _burn(address src, uint256 wad) internal virtual returns (bool) {
        unchecked {
            require(_balanceOf[src] >= wad, 'ERC20: Insufficient balance');
            _balanceOf[src] = _balanceOf[src] - wad;
            _totalSupply = _totalSupply - wad;
            emit Transfer(src, address(0), wad);
        }

        return true;
    }
}

/**
 * @dev Interface of the ERC2612 standard as defined in the EIP.
 *
 * Adds the {permit} method, which can be used to change one's
 * {IERC20-allowance} without having to send a transaction, by signing a
 * message. This allows users to spend tokens without having to hold Ether.
 *
 * See https://eips.ethereum.org/EIPS/eip-2612.
 */
interface IERC2612 is IERC20Metadata {
    /**
     * @dev Sets `amount` as the allowance of `spender` over `owner`'s tokens,
     * given `owner`'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current ERC2612 nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);
}

/**
 * @dev Extension of {ERC20} that allows token holders to use their tokens
 * without sending any transactions by setting {IERC20-allowance} with a
 * signature using the {permit} method, and then spend them via
 * {IERC20-transferFrom}.
 *
 * The {permit} signature mechanism conforms to the {IERC2612} interface.
 */
abstract contract ERC20Permit is ERC20, IERC2612 {
    mapping(address => uint256) public override nonces;

    bytes32 public immutable PERMIT_TYPEHASH =
        keccak256(
            'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
        );
    bytes32 private immutable _DOMAIN_SEPARATOR;
    uint256 public immutable deploymentChainId;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_, decimals_) {
        deploymentChainId = block.chainid;
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(block.chainid);
    }

    /// @dev Calculate the DOMAIN_SEPARATOR.
    function _calculateDomainSeparator(uint256 chainId)
        private
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
                    ),
                    keccak256(bytes(name)),
                    keccak256(bytes(version())),
                    chainId,
                    address(this)
                )
            );
    }

    /// @dev Return the DOMAIN_SEPARATOR.
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return
            block.chainid == deploymentChainId
                ? _DOMAIN_SEPARATOR
                : _calculateDomainSeparator(block.chainid);
    }

    /// @dev Setting the version as a function so that it can be overriden
    function version() public pure virtual returns (string memory) {
        return '1';
    }

    /**
     * @dev See {IERC2612-permit}.
     *
     * In cases where the free option is not a concern, deadline can simply be
     * set to uint(-1), so it should be seen as an optional parameter
     */
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override {
        require(deadline >= block.timestamp, 'ERC20Permit: expired deadline');

        bytes32 hashStruct = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                amount,
                nonces[owner]++,
                deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                '\x19\x01',
                block.chainid == deploymentChainId
                    ? _DOMAIN_SEPARATOR
                    : _calculateDomainSeparator(block.chainid),
                hashStruct
            )
        );

        address signer = ecrecover(hash, v, r, s);
        require(
            signer != address(0) && signer == owner,
            'ERC20Permit: invalid signature'
        );

        _setAllowance(owner, spender, amount);
    }
}

interface IERC5095 is IERC2612 {
    function maturity() external view returns (uint256);

    function underlying() external view returns (address);

    function convertToUnderlying(uint256) external view returns (uint256);

    function convertToShares(uint256) external view returns (uint256);

    function maxRedeem(address) external view returns (uint256);

    function previewRedeem(uint256) external view returns (uint256);

    function maxWithdraw(address) external view returns (uint256);

    function previewWithdraw(uint256) external view returns (uint256);

    function previewDeposit(uint256) external view returns (uint256);

    function withdraw(
        uint256,
        address,
        address
    ) external returns (uint256);

    function redeem(
        uint256,
        address,
        address
    ) external returns (uint256);

    function deposit(address, uint256) external returns (uint256);

    function mint(address, uint256) external returns (uint256);

    function authMint(address, uint256) external returns (bool);

    function authBurn(address, uint256) external returns (bool);
}

interface IRedeemer {
    function authRedeem(
        address underlying,
        uint256 maturity,
        address from,
        address to,
        uint256 amount
    ) external returns (uint256);

    function approve(address p) external;
}

interface IMarketPlace {
    function token(
        address,
        uint256,
        uint256
    ) external returns (address);

    function pools(address, uint256) external view returns (address);

    function sellPrincipalToken(
        address,
        uint256,
        uint128,
        uint128
    ) external returns (uint128);

    function buyPrincipalToken(
        address,
        uint256,
        uint128,
        uint128
    ) external returns (uint128);

    function sellUnderlying(
        address,
        uint256,
        uint128,
        uint128
    ) external returns (uint128);

    function buyUnderlying(
        address,
        uint256,
        uint128,
        uint128
    ) external returns (uint128);
}

interface IYield {
    function maturity() external view returns (uint32);

    function sellBase(address, uint128) external returns (uint128);

    function sellBasePreview(uint128) external view returns (uint128);

    function fyToken() external returns (address);

    function sellFYToken(address, uint128) external returns (uint128);

    function sellFYTokenPreview(uint128) external view returns (uint128);

    function buyBase(
        address,
        uint128,
        uint128
    ) external returns (uint128);

    function buyBasePreview(uint128) external view returns (uint128);

    function buyFYToken(
        address,
        uint128,
        uint128
    ) external returns (uint128);

    function buyFYTokenPreview(uint128) external view returns (uint128);
}

/// @dev A single custom error capable of indicating a wide range of detected errors by providing
/// an error code value whose string representation is documented <here>, and any possible other values
/// that are pertinent to the error.
error Exception(uint8, uint256, uint256, address, address);

library Cast {
    /// @dev Safely cast an uint256 to an uint128
    /// @param n the u256 to cast to u128
    function u128(uint256 n) internal pure returns (uint128) {
        if (n > type(uint128).max) {
            revert();
        }
        return uint128(n);
    }
}

contract ERC5095 is ERC20Permit, IERC5095 {
    /// @dev unix timestamp when the ERC5095 token can be redeemed
    uint256 public immutable override maturity;
    /// @dev address of the ERC20 token that is returned on ERC5095 redemption
    address public immutable override underlying;
    /// @dev address of the minting authority
    address public immutable lender;
    /// @dev address of the "marketplace" YieldSpace AMM router
    address public immutable marketplace;
    ///@dev Interface to interact with the pool
    address public immutable pool;

    /// @dev address and interface for an external custody contract (necessary for some project's backwards compatability)
    address public immutable redeemer;

    /// @notice ensures that only a certain address can call the function
    /// @param a address that msg.sender must be to be authorized
    modifier authorized(address a) {
        if (msg.sender != a) {
            revert Exception(0, 0, 0, msg.sender, a);
        }
        _;
    }

    constructor(
        address _underlying,
        uint256 _maturity,
        address _redeemer,
        address _lender,
        address _marketplace,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20Permit(name_, symbol_, decimals_) {
        underlying = _underlying;
        maturity = _maturity;
        redeemer = _redeemer;
        lender = _lender;
        marketplace = _marketplace;
        pool = IMarketPlace(marketplace).pools(underlying, maturity);
    }

    /// @notice Post or at maturity converts an amount of principal tokens to an amount of underlying that would be returned.
    /// @param s The amount of principal tokens to convert
    /// @return uint256 The amount of underlying tokens returned by the conversion
    function convertToUnderlying(uint256 s)
        external
        view
        override
        returns (uint256)
    {
        if (block.timestamp < maturity) {
            return previewRedeem(s);
        }
        return s;
    }

    /// @notice Post or at maturity converts a desired amount of underlying tokens returned to principal tokens needed.
    /// @param a The amount of underlying tokens to convert
    /// @return uint256 The amount of principal tokens returned by the conversion
    function convertToShares(uint256 a)
        external
        view
        override
        returns (uint256)
    {
        if (block.timestamp < maturity) {
            return previewWithdraw(a);
        }
        return a;
    }

    /// @notice Post or at maturity returns user's PT balance. Pre maturity, returns a previewRedeem for owner's PT balance.
    /// @param o The address of the owner for which redemption is calculated
    /// @return uint256 The maximum amount of principal tokens that `owner` can redeem.
    function maxRedeem(address o) external view override returns (uint256) {
        if (block.timestamp < maturity) {
            return previewRedeem(_balanceOf[o]);
        }
        return _balanceOf[o];
    }

    /// @notice Post or at maturity returns user's PT balance. Pre maturity, returns a previewWithdraw for owner's PT balance.
    /// @param  o The address of the owner for which withdrawal is calculated
    /// @return uint256 maximum amount of underlying tokens that `owner` can withdraw.
    function maxWithdraw(address o) external view override returns (uint256) {
        if (block.timestamp < maturity) {
            return previewWithdraw(_balanceOf[address(this)]);
        }
        return _balanceOf[o];
    }

    /// @notice Post or at maturity returns 0. Pre maturity returns the amount of `shares` when spending `assets` in underlying on a YieldSpace AMM.
    /// @param a The amount of underlying spent
    /// @return uint256 The amount of PT purchased by spending `assets` of underlying
    function previewDeposit(uint256 a) public view returns (uint256) {
        if (block.timestamp < maturity) {
            return IYield(pool).sellBasePreview(Cast.u128(a));
        }
        return 0;
    }

    /// @notice Post or at maturity returns 0. Pre maturity returns the amount of `assets` in underlying spent on a purchase of `shares` in PT on a YieldSpace AMM.
    /// @param s the amount of principal tokens bought in the simulation
    /// @return uint256 The amount of underlying spent to purchase `shares` of PT
    function previewMint(uint256 s) public view returns (uint256) {
        if (block.timestamp < maturity) {
            return IYield(pool).buyFYTokenPreview(Cast.u128(s));
        }
        return 0;
    }

    /// @notice Post or at maturity simulates the effects of redeemption at the current block. Pre maturity returns the amount of `assets from a sale of `shares` in PT from a sale of PT on a YieldSpace AMM.
    /// @param s the amount of principal tokens redeemed in the simulation
    /// @return uint256 The amount of underlying returned by `shares` of PT redemption
    function previewRedeem(uint256 s) public view override returns (uint256) {
        if (block.timestamp > maturity) {
            return s;
        }
        return IYield(pool).sellFYTokenPreview(Cast.u128(s));
    }

    /// @notice Post or at maturity simulates the effects of withdrawal at the current block. Pre maturity simulates the amount of `shares` in PT necessary to receive `assets` in underlying from a sale of PT on a YieldSpace AMM.
    /// @param a the amount of underlying tokens withdrawn in the simulation
    /// @return uint256 The amount of principal tokens required for the withdrawal of `assets`
    function previewWithdraw(uint256 a) public view override returns (uint256) {
        if (block.timestamp > maturity) {
            return a;
        }
        return IYield(pool).buyBasePreview(Cast.u128(a));
    }

    /// @notice Before maturity spends `assets` of underlying, and sends `shares` of PTs to `receiver`. Post or at maturity, reverts.
    /// @param r The receiver of the underlying tokens being withdrawn
    /// @param a The amount of underlying tokens withdrawn
    /// @return uint256 The amount of principal tokens burnt by the withdrawal
    function deposit(address r, uint256 a) external override returns (uint256) {
        if (block.timestamp > maturity) {
            revert Exception(
                21,
                block.timestamp,
                maturity,
                address(0),
                address(0)
            );
        }
        uint128 shares = Cast.u128(previewDeposit(a));
        IERC20(underlying).transferFrom(msg.sender, address(this), a);
        // consider the hardcoded slippage limit, 4626 compliance requires no minimum param.
        uint128 returned = IMarketPlace(marketplace).sellUnderlying(
            underlying,
            maturity,
            Cast.u128(a),
            shares - (shares / 100)
        );
        _transfer(address(this), r, returned);
        return returned;
    }

    /// @notice Before maturity mints `shares` of PTs to `receiver` and spending `assets` of underlying. Post or at maturity, reverts.
    /// @param r The receiver of the underlying tokens being withdrawn
    /// @param s The amount of underlying tokens withdrawn
    /// @return uint256 The amount of principal tokens burnt by the withdrawal
    function mint(address r, uint256 s) external override returns (uint256) {
        if (block.timestamp > maturity) {
            revert Exception(
                21,
                block.timestamp,
                maturity,
                address(0),
                address(0)
            );
        }
        uint128 assets = Cast.u128(previewMint(s));
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        // consider the hardcoded slippage limit, 4626 compliance requires no minimum param.
        uint128 returned = IMarketPlace(marketplace).sellUnderlying(
            underlying,
            maturity,
            assets,
            assets - (assets / 100)
        );
        _transfer(address(this), r, returned);
        return returned;
    }

    /// @notice At or after maturity, Burns `shares` from `owner` and sends exactly `assets` of underlying tokens to `receiver`. Before maturity, sends `assets` by selling shares of PT on a YieldSpace AMM.
    /// @param a The amount of underlying tokens withdrawn
    /// @param r The receiver of the underlying tokens being withdrawn
    /// @param o The owner of the underlying tokens
    /// @return uint256 The amount of principal tokens burnt by the withdrawal
    function withdraw(
        uint256 a,
        address r,
        address o
    ) external override returns (uint256) {
        // Pre maturity
        if (block.timestamp < maturity) {
            uint128 shares = Cast.u128(previewWithdraw(a));
            // If owner is the sender, sell PT without allowance check
            if (o == msg.sender) {
                uint128 returned = IMarketPlace(marketplace).sellPrincipalToken(
                    underlying,
                    maturity,
                    shares,
                    Cast.u128(a - (a / 100))
                );
                IERC20(underlying).transfer(r, returned);
                return returned;
                // Else, sell PT with allowance check
            } else {
                uint256 allowance = _allowance[o][msg.sender];
                if (allowance < shares) {
                    revert Exception(
                        20,
                        allowance,
                        shares,
                        address(0),
                        address(0)
                    );
                }
                _allowance[o][msg.sender] = allowance - shares;
                uint128 returned = IMarketPlace(marketplace).sellPrincipalToken(
                    underlying,
                    maturity,
                    Cast.u128(shares),
                    Cast.u128(a - (a / 100))
                );
                IERC20(underlying).transfer(r, returned);
                return returned;
            }
        }
        // Post maturity
        else {
            if (o == msg.sender) {
                return
                    IRedeemer(redeemer).authRedeem(
                        underlying,
                        maturity,
                        msg.sender,
                        r,
                        a
                    );
            } else {
                uint256 allowance = _allowance[o][msg.sender];
                if (allowance < a) {
                    revert Exception(20, allowance, a, address(0), address(0));
                }
                _allowance[o][msg.sender] = allowance - a;
                return
                    IRedeemer(redeemer).authRedeem(
                        underlying,
                        maturity,
                        o,
                        r,
                        a
                    );
            }
        }
    }

    /// @notice At or after maturity, burns exactly `shares` of Principal Tokens from `owner` and sends `assets` of underlying tokens to `receiver`. Before maturity, sends `assets` by selling `shares` of PT on a YieldSpace AMM.
    /// @param s The number of shares to be burned in exchange for the underlying asset
    /// @param r The receiver of the underlying tokens being withdrawn
    /// @param o Address of the owner of the shares being burned
    /// @return uint256 The amount of underlying tokens distributed by the redemption
    function redeem(
        uint256 s,
        address r,
        address o
    ) external override returns (uint256) {
        // Pre-maturity
        if (block.timestamp < maturity) {
            uint128 assets = Cast.u128(previewRedeem(s));
            // If owner is the sender, sell PT without allowance check
            if (o == msg.sender) {
                uint128 returned = IMarketPlace(marketplace).sellPrincipalToken(
                    underlying,
                    maturity,
                    Cast.u128(s),
                    assets - (assets / 100)
                );
                IERC20(underlying).transfer(r, returned);
                return returned;
                // Else, sell PT with allowance check
            } else {
                uint256 allowance = _allowance[o][msg.sender];
                if (allowance < s) {
                    revert Exception(20, allowance, s, address(0), address(0));
                }
                _allowance[o][msg.sender] = allowance - s;
                uint128 returned = IMarketPlace(marketplace).sellPrincipalToken(
                    underlying,
                    maturity,
                    Cast.u128(s),
                    assets - (assets / 100)
                );
                IERC20(underlying).transfer(r, returned);
                return returned;
            }
            // Post-maturity
        } else {
            if (o == msg.sender) {
                return
                    IRedeemer(redeemer).authRedeem(
                        underlying,
                        maturity,
                        msg.sender,
                        r,
                        s
                    );
            } else {
                uint256 allowance = _allowance[o][msg.sender];
                if (allowance < s) {
                    revert Exception(20, allowance, s, address(0), address(0));
                }
                _allowance[o][msg.sender] = allowance - s;
                return
                    IRedeemer(redeemer).authRedeem(
                        underlying,
                        maturity,
                        o,
                        r,
                        s
                    );
            }
        }
    }

    /// @param f Address to burn from
    /// @param a Amount to burn
    /// @return bool true if successful
    function authBurn(address f, uint256 a)
        external
        authorized(redeemer)
        returns (bool)
    {
        _burn(f, a);
        return true;
    }

    /// @param t Address recieving the minted amount
    /// @param a The amount to mint
    /// @return bool true if successful
    function authMint(address t, uint256 a)
        external
        authorized(lender)
        returns (bool)
    {
        _mint(t, a);
        return true;
    }
}

// Adapted from: https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol

/**
  @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
  @author Modified from Gnosis (https://github.com/gnosis/gp-v2-contracts/blob/main/src/contracts/libraries/GPv2SafeERC20.sol)
  @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
*/

library Safe {
    /// @param e Erc20 token to execute the call with
    /// @param t To address
    /// @param a Amount being transferred
    function transfer(
        IERC20 e,
        address t,
        uint256 a
    ) internal {
        bool result;

        assembly {
            // Get a pointer to some free memory.
            let pointer := mload(0x40)

            // Write the abi-encoded calldata to memory piece by piece:
            mstore(
                pointer,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            ) // Begin with the function selector.
            mstore(
                add(pointer, 4),
                and(t, 0xffffffffffffffffffffffffffffffffffffffff)
            ) // Mask and append the "to" argument.
            mstore(add(pointer, 36), a) // Finally append the "amount" argument. No mask as it's a full 32 byte value.

            // Call the token and store if it succeeded or not.
            // We use 68 because the calldata length is 4 + 32 * 2.
            result := call(gas(), e, 0, pointer, 68, 0, 0)
        }

        require(success(result), 'transfer failed');
    }

    /// @param e Erc20 token to execute the call with
    /// @param f From address
    /// @param t To address
    /// @param a Amount being transferred
    function transferFrom(
        IERC20 e,
        address f,
        address t,
        uint256 a
    ) internal {
        bool result;

        assembly {
            // Get a pointer to some free memory.
            let pointer := mload(0x40)

            // Write the abi-encoded calldata to memory piece by piece:
            mstore(
                pointer,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            ) // Begin with the function selector.
            mstore(
                add(pointer, 4),
                and(f, 0xffffffffffffffffffffffffffffffffffffffff)
            ) // Mask and append the "from" argument.
            mstore(
                add(pointer, 36),
                and(t, 0xffffffffffffffffffffffffffffffffffffffff)
            ) // Mask and append the "to" argument.
            mstore(add(pointer, 68), a) // Finally append the "amount" argument. No mask as it's a full 32 byte value.

            // Call the token and store if it succeeded or not.
            // We use 100 because the calldata length is 4 + 32 * 3.
            result := call(gas(), e, 0, pointer, 100, 0, 0)
        }

        require(success(result), 'transfer from failed');
    }

    /// @notice normalize the acceptable values of true or null vs the unacceptable value of false (or something malformed)
    /// @param r Return value from the assembly `call()` to Erc20['selector']
    function success(bool r) private pure returns (bool) {
        bool result;

        assembly {
            // Get how many bytes the call returned.
            let returnDataSize := returndatasize()

            // If the call reverted:
            if iszero(r) {
                // Copy the revert message into memory.
                returndatacopy(0, 0, returnDataSize)

                // Revert with the same message.
                revert(0, returnDataSize)
            }

            switch returnDataSize
            case 32 {
                // Copy the return data into memory.
                returndatacopy(0, 0, returnDataSize)

                // Set success to whether it returned true.
                result := iszero(iszero(mload(0)))
            }
            case 0 {
                // There was no return data.
                result := 1
            }
            default {
                // It returned some malformed input.
                result := 0
            }
        }

        return result;
    }

    function approve(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool callStatus;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata to memory piece by piece:
            mstore(
                freeMemoryPointer,
                0x095ea7b300000000000000000000000000000000000000000000000000000000
            ) // Begin with the function selector.
            mstore(
                add(freeMemoryPointer, 4),
                and(to, 0xffffffffffffffffffffffffffffffffffffffff)
            ) // Mask and append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Finally append the "amount" argument. No mask as it's a full 32 byte value.

            // Call the token and store if it succeeded or not.
            // We use 68 because the calldata length is 4 + 32 * 2.
            callStatus := call(gas(), token, 0, freeMemoryPointer, 68, 0, 0)
        }

        require(didLastOptionalReturnCallSucceed(callStatus), 'APPROVE_FAILED');
    }

    /*///////////////////////////////////////////////////////////////
                         INTERNAL HELPER LOGIC
    //////////////////////////////////////////////////////////////*/

    function didLastOptionalReturnCallSucceed(bool callStatus)
        private
        pure
        returns (bool)
    {
        bool result;
        assembly {
            // Get how many bytes the call returned.
            let returnDataSize := returndatasize()

            // If the call reverted:
            if iszero(callStatus) {
                // Copy the revert message into memory.
                returndatacopy(0, 0, returnDataSize)

                // Revert with the same message.
                revert(0, returnDataSize)
            }

            switch returnDataSize
            case 32 {
                // Copy the return data into memory.
                returndatacopy(0, 0, returnDataSize)

                // Set success to whether it returned true.
                result := iszero(iszero(mload(0)))
            }
            case 0 {
                // There was no return data.
                result := 1
            }
            default {
                // It returned some malformed input.
                result := 0
            }
        }

        return result;
    }
}

interface ILender {
    function approve(
        address,
        address,
        address,
        address
    ) external;

    function approve(address, address) external;
}

interface IPool {
    function ts() external view returns (int128);

    function g1() external view returns (int128);

    function g2() external view returns (int128);

    function maturity() external view returns (uint32);

    function scaleFactor() external view returns (uint96);

    function getCache()
        external
        view
        returns (
            uint112,
            uint112,
            uint32
        );

    // NOTE This will be deprecated
    function base() external view returns (IERC20);

    function baseToken() external view returns (address);

    function fyToken() external view returns (IERC5095);

    function getBaseBalance() external view returns (uint112);

    function getFYTokenBalance() external view returns (uint112);

    function retrieveBase(address) external returns (uint128 retrieved);

    function retrieveFYToken(address) external returns (uint128 retrieved);

    function sellBase(address, uint128) external returns (uint128);

    function buyBase(
        address,
        uint128,
        uint128
    ) external returns (uint128);

    function sellFYToken(address, uint128) external returns (uint128);

    function buyFYToken(
        address,
        uint128,
        uint128
    ) external returns (uint128);

    function sellBasePreview(uint128) external view returns (uint128);

    function buyBasePreview(uint128) external view returns (uint128);

    function sellFYTokenPreview(uint128) external view returns (uint128);

    function buyFYTokenPreview(uint128) external view returns (uint128);

    function mint(
        address,
        address,
        uint256,
        uint256
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        );

    function mintWithBase(
        address,
        address,
        uint256,
        uint256,
        uint256
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        );

    function burn(
        address,
        address,
        uint256,
        uint256
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        );

    function burnForBase(
        address,
        uint256,
        uint256
    ) external returns (uint256, uint256);

    function cumulativeBalancesRatio() external view returns (uint256);
}

/// @title MarketPlace
/// @author Sourabh Marathe, Julian Traversa, Rob Robbins
/// @notice This contract is in charge of managing the available principals for each loan market.
/// @notice In addition, this contract routes swap orders between metaprincipal tokens and their respective underlying to YieldSpace pools.
contract MarketPlace {
    /// @notice the available principals
    /// @dev the order of this enum is used to select principals from the markets
    /// mapping (e.g. Illuminate => 0, Swivel => 1, and so on)
    enum Principals {
        Illuminate, // 0
        Swivel, // 1
        Yield, // 2
        Element, // 3
        Pendle, // 4
        Tempus, // 5
        Sense, // 6
        Apwine, // 7
        Notional // 8
    }

    /// @notice markets are defined by a tuple that points to a fixed length array of principal token addresses.
    /// @notice The principal tokens whose addresses correspond to their Principals enum value, thus the array should be ordered in that way
    mapping(address => mapping(uint256 => address[9])) public markets;

    /// @notice pools map markets to their respective YieldSpace pools for the MetaPrincipal token
    mapping(address => mapping(uint256 => address)) public pools;

    /// @notice address that is allowed to create markets, set fees, etc. It is commonly used in the authorized modifier.
    address public admin;
    /// @notice address of the deployed redeemer contract
    address public immutable redeemer;
    /// @notice address of the deployed lender contract
    address public immutable lender;

    /// @notice emitted upon the creation of a new market
    event CreateMarket(
        address indexed underlying,
        uint256 indexed maturity,
        address[9] tokens
    );
    /// @notice emitted upon change of principal token
    event SetPrincipal(address indexed principal);
    /// @notice emitted on change of admin
    event SetAdmin(address indexed admin);
    /// @notice emitted on change of pool
    event SetPool(address indexed pool);

    /// @notice ensures that only a certain address can call the function
    /// @param a address that msg.sender must be to be authorized
    modifier authorized(address a) {
        if (msg.sender != a) {
            revert Exception(0, 0, 0, msg.sender, a);
        }
        _;
    }

    /// @notice initializes the MarketPlace contract
    /// @param r address of the deployed redeemer contract
    /// @param l address of the deployed lender contract
    constructor(address r, address l) {
        admin = msg.sender;
        redeemer = r;
        lender = l;
    }

    /// @notice creates a new market for the given underlying token and maturity
    /// @param u address of an underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param t principal token addresses for this market minus the illuminate principal
    /// @param n name for the illuminate token
    /// @param s symbol for the illuminate token
    /// @param d decimals for the illuminate token
    /// @param e address of the element vault that corresponds to this market
    /// @param a address of the apwine router that corresponds to this market
    /// @return bool true if successful
    function createMarket(
        address u,
        uint256 m,
        address[8] calldata t,
        string calldata n,
        string calldata s,
        uint8 d,
        address e,
        address a
    ) external authorized(admin) returns (bool) {
        {
            address illuminate = markets[u][m][
                (uint256(Principals.Illuminate))
            ];
            if (illuminate != address(0)) {
                revert Exception(9, 0, 0, illuminate, address(0));
            }
        }

        address illuminateToken;
        {
            illuminateToken = address(
                new ERC5095(u, m, redeemer, lender, address(this), n, s, d)
            );
        }

        {
            // the market will have the illuminate principal as its zeroth item,
            // thus t should have Principals[1] as [0]
            address[9] memory market = [
                illuminateToken, // illuminate
                t[0], // swivel
                t[1], // yield
                t[2], // element
                t[3], // pendle
                t[4], // tempus
                t[5], // sense
                t[6], // apwine
                t[7] // notional
            ];

            // necessary to get around stack too deep
            address underlying = u;
            uint256 maturity = m;

            // set the market
            markets[underlying][maturity] = market;
        }

        // todo also call the next two in the setPrincipal call?
        // Max approve lender spending on the element and apwine contracts
        ILender(lender).approve(u, e, a, t[7]);

        // Max approve converters's ability to convert redeemer's pendle PTs
        IRedeemer(redeemer).approve(t[3]);

        {
            address[9] memory tokens = markets[u][m];
            emit CreateMarket(u, m, tokens);
        }
        return true;
    }

    /// @notice allows the admin to set an individual market
    /// @param p enum value of the principal token
    /// @param u underlying token address
    /// @param m maturity timestamp for the market
    /// @param a address of the new principal token
    /// @return bool true if the principal set, false otherwise
    function setPrincipal(
        uint8 p,
        address u,
        uint256 m,
        address a
    ) external authorized(admin) returns (bool) {
        address market = markets[u][m][p];
        if (market != address(0)) {
            revert Exception(9, 0, 0, market, address(0));
        }
        markets[u][m][p] = a;

        // todo: should we handle special protocol based approvals here?

        emit SetPrincipal(a);
        return true;
    }

    /// @notice sets the admin address
    /// @param a Address of a new admin
    /// @return bool true if the admin set, false otherwise
    function setAdmin(address a) external authorized(admin) returns (bool) {
        admin = a;
        emit SetAdmin(a);
        return true;
    }

    /// @notice sets the address for a pool
    /// @param u address of the underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a address of the pool
    /// @return bool true if the pool set, false otherwise
    function setPool(
        address u,
        uint256 m,
        address a
    ) external authorized(admin) returns (bool) {
        address pool = pools[u][m];
        if (pool != address(0)) {
            revert Exception(10, 0, 0, pool, address(0));
        }
        pools[u][m] = a;
        emit SetPool(a);
        return true;
    }

    /// @notice sells the PT for the PT via the pool
    /// @param u address of the underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount of PT to swap
    /// @param s slippage cap, minimum number of tokens that must be received
    /// @return uint128 amount of underlying bought
    function sellPrincipalToken(
        address u,
        uint256 m,
        uint128 a,
        uint128 s
    ) external returns (uint128) {
        IPool pool = IPool(pools[u][m]);
        Safe.transferFrom(
            IERC20(address(pool.fyToken())),
            msg.sender,
            address(pool),
            a
        );
        uint128 preview = pool.sellFYTokenPreview(a);
        if (preview < s) {
            revert Exception(16, preview, 0, address(0), address(0));
        }

        return pool.sellFYToken(msg.sender, preview);
    }

    /// @notice buys the PUT for the underlying via the pool
    /// @param u address of the underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount of underlying tokens to sell
    /// @param s slippage cap, minimum number to tokens to receive after swap
    /// @return uint128 amount of underlying sold
    function buyPrincipalToken(
        address u,
        uint256 m,
        uint128 a,
        uint128 s
    ) external returns (uint128) {
        IPool pool = IPool(pools[u][m]);
        Safe.transferFrom(IERC20(pool.base()), msg.sender, address(pool), a);
        uint128 preview = pool.buyFYTokenPreview(a);
        if (preview < s) {
            revert Exception(16, preview, 0, address(0), address(0));
        }
        return pool.buyFYToken(msg.sender, preview, 0);
    }

    /// @notice sells the underlying for the PT via the pool
    /// @param u address of the underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount of underlying to swap
    /// @param s slippage cap, minimum number of tokens that must be received
    /// @return uint128 amount of PT purchased
    function sellUnderlying(
        address u,
        uint256 m,
        uint128 a,
        uint128 s
    ) external returns (uint128) {
        IPool pool = IPool(pools[u][m]);
        Safe.transferFrom(IERC20(pool.base()), msg.sender, address(pool), a);
        uint128 preview = pool.sellBasePreview(a);
        if (preview < s) {
            revert Exception(16, preview, 0, address(0), address(0));
        }
        return pool.sellBase(msg.sender, preview);
    }

    /// @notice buys the underlying for the PT via the pool
    /// @param u address of the underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount of PT to swap
    /// @param s slippage cap, minimum number of tokens to be received after swap
    /// @return uint128 amount of PTs sold
    function buyUnderlying(
        address u,
        uint256 m,
        uint128 a,
        uint128 s
    ) external returns (uint128) {
        IPool pool = IPool(pools[u][m]);
        Safe.transferFrom(
            IERC20(address(pool.fyToken())),
            msg.sender,
            address(pool),
            a
        );
        uint128 preview = pool.buyBasePreview(a);
        if (preview < s) {
            revert Exception(16, preview, 0, address(0), address(0));
        }
        return pool.buyBase(msg.sender, preview, 0);
    }

    /// @notice mint liquidity tokens in exchange for adding underlying and PT
    /// @dev amount of liquidity tokens to mint is calculated from the amount of unaccounted for PT in this contract.
    /// @dev A proportional amount of underlying tokens need to be present in this contract, also unaccounted for.
    /// @param u the address of the underlying token
    /// @param m the maturity of the principal token
    /// @param b number of base tokens
    /// @param p the principal token amount being sent
    /// @param minRatio minimum ratio of underlying to PT in the pool.
    /// @param maxRatio maximum ratio of underlying to PT in the pool.
    /// @return uint256 number of base tokens passed to the method
    /// @return uint256 number of yield tokens passed to the method
    /// @return uint256 the amount of tokens minted.
    function mint(
        address u,
        uint256 m,
        uint256 b,
        uint256 p,
        uint256 minRatio,
        uint256 maxRatio
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        IPool pool = IPool(pools[u][m]);
        Safe.transferFrom(IERC20(pool.base()), msg.sender, address(pool), b);
        Safe.transferFrom(
            IERC20(address(pool.fyToken())),
            msg.sender,
            address(pool),
            p
        );
        return pool.mint(msg.sender, msg.sender, minRatio, maxRatio);
    }

    /// @notice Mint liquidity tokens in exchange for adding only underlying
    /// @dev amount of liquidity tokens is calculated from the amount of PT to buy from the pool,
    /// plus the amount of unaccounted for PT in this contract.
    /// @param u the address of the underlying token
    /// @param m the maturity of the principal token
    /// @param a the underlying amount being sent
    /// @param p amount of `PT` being bought in the Pool, from this we calculate how much underlying it will be taken in.
    /// @param minRatio minimum ratio of underlying to PT in the pool.
    /// @param maxRatio maximum ratio of underlying to PT in the pool.
    /// @return uint256 number of base tokens passed to the method
    /// @return uint256 number of yield tokens passed to the method
    /// @return uint256 the amount of tokens minted.
    function mintWithUnderlying(
        address u,
        uint256 m,
        uint256 a,
        uint256 p,
        uint256 minRatio,
        uint256 maxRatio
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        IPool pool = IPool(pools[u][m]);
        Safe.transferFrom(IERC20(pool.base()), msg.sender, address(pool), a);
        return pool.mintWithBase(msg.sender, msg.sender, p, minRatio, maxRatio);
    }

    /// @notice burn liquidity tokens in exchange for underlying and PT.
    /// @param u the address of the underlying token
    /// @param m the maturity of the principal token
    /// @param minRatio minimum ratio of underlying to PT in the pool
    /// @param maxRatio maximum ratio of underlying to PT in the pool
    /// @return uint256 amount of LP tokens burned
    /// @return uint256 amount of base tokens received
    /// @return uint256 amount of fyTokens received
    function burn(
        address u,
        uint256 m,
        uint256 minRatio,
        uint256 maxRatio
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return
            IPool(pools[u][m]).burn(msg.sender, msg.sender, minRatio, maxRatio);
    }

    /// @notice burn liquidity tokens in exchange for underlying.
    /// @param u the address of the underlying token
    /// @param m the maturity of the principal token
    /// @param minRatio minimum ratio of underlying to PT in the pool.
    /// @param maxRatio minimum ratio of underlying to PT in the pool.
    /// @return uint256 amount of PT tokens sent to the pool
    /// @return uint256 amount of underlying tokens returned
    function burnForUnderlying(
        address u,
        uint256 m,
        uint256 minRatio,
        uint256 maxRatio
    ) external returns (uint256, uint256) {
        return IPool(pools[u][m]).burnForBase(msg.sender, minRatio, maxRatio);
    }

    /// @notice provides an interface to receive principal token addresses from markets
    /// @param u underlying asset contract address
    /// @param m maturity timestamp for the market
    /// @param p principal index mapping to the Principals enum
    function token(
        address u,
        uint256 m,
        uint256 p
    ) external view returns (address) {
        return markets[u][m][p];
    }
}

interface IAny {}

interface ITempus {
    function depositAndFix(
        address,
        uint256,
        bool,
        uint256,
        uint256
    ) external;

    function redeemToBacking(
        address,
        uint256,
        uint256,
        address
    ) external;
}

interface ITempusPool {
    function maturityTime() external view returns (uint256);

    function backingToken() external view returns (IERC20Metadata);

    // Used for integration testing
    function principalShare() external view returns (address);

    function currentInterestRate() external view returns (uint256);

    function initialInterestRate() external view returns (uint256);
}

interface ITempusToken {
    function balanceOf(address) external returns (uint256);

    function pool() external view returns (address);
}

interface IAPWine {
    function withdraw(address, uint256) external;
}

interface IAPWineController {
    function getNextPeriodStart(uint256) external view returns (uint256);
}

interface IAPWineFutureVault {
    function PERIOD_DURATION() external view returns (uint256);

    function getControllerAddress() external view returns (address);
}

interface IAPWineToken {
    // Todo will be used to get the maturity
    function futureVault() external view returns (address);
}

interface IAPWineAMMPool {
    function getUnderlyingOfIBTAddress() external view returns (address);

    function getPTAddress() external view returns (address);
}

library Swivel {
    // the components of a ECDSA signature
    struct Components {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct Order {
        bytes32 key;
        uint8 protocol;
        address maker;
        address underlying;
        bool vault;
        bool exit;
        uint256 principal;
        uint256 premium;
        uint256 maturity;
        uint256 expiry;
    }
}

interface ISwivel {
    function initiate(
        Swivel.Order[] calldata,
        uint256[] calldata,
        Swivel.Components[] calldata
    ) external returns (bool);

    function redeemZcToken(
        address u,
        uint256 m,
        uint256 a
    ) external returns (bool);
}

interface ISwivelToken {
    function maturity() external returns (uint256);
}

interface IElementToken {
    function unlockTimestamp() external returns (uint256);

    function underlying() external returns (address);

    function withdrawPrincipal(uint256 amount, address destination)
        external
        returns (uint256);
}

interface IYieldToken {
    function redeem(address, uint256) external returns (uint256);

    function underlying() external returns (address);

    function maturity() external returns (uint256);
}

interface INotional {
    function getUnderlyingToken() external view returns (IERC20, int256);

    function getMaturity() external view returns (uint40);

    function deposit(uint256, address) external returns (uint256);

    function maxRedeem(address) external returns (uint256);

    function redeem(
        uint256,
        address,
        address
    ) external returns (uint256);
}

interface IPendle {
    function swapExactTokensForTokens(
        uint256,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external returns (uint256[] memory amounts);

    function redeemAfterExpiry(
        bytes32,
        address,
        uint256
    ) external;
}

interface IPendleForge {
    function forgeId() external returns (bytes32);
}

interface IPendleToken {
    function underlyingAsset() external returns (address);

    function underlyingYieldToken() external returns (address);

    function expiry() external returns (uint256);

    function forge() external returns (address);
}

interface ISenseDivider {
    function redeem(
        address,
        uint256,
        uint256
    ) external returns (uint256);

    function pt(address, uint256) external view returns (address);

    // only used by integration tests
    function settleSeries(address, uint256) external;
}

interface ISenseAdapter {
    function underlying() external view returns (address);

    function divider() external view returns (address);

    function target() external view returns (address);

    function maxm() external view returns (uint256);
}

interface IConverter {
    function convert(
        address,
        address,
        uint256,
        uint256
    ) external;
}

/// @title Redeemer
/// @author Sourabh Marathe, Julian Traversa, Rob Robbins
/// @notice The Redeemer contract is used to redeem the underlying lent capital of a loan.
/// @notice Users may redeem their ERC-5095 tokens for the underlying asset represented by that token after maturity.
contract Redeemer {
    /// @notice address that is allowed to set the lender and marketplace
    address public admin;
    /// @notice address used to access the MarketPlace's markets mapping
    address public marketPlace;
    /// @notice address that custodies principal tokens for all markets
    address public lender;
    /// @notice address that converts compounding tokens to their underlying (used by pendle's redeem)
    address public converter;

    /// @notice third party contract needed to lend on Swivel
    address public immutable swivelAddr;
    /// @notice third party contract needed to lend on Pendle
    address public immutable pendleAddr;
    /// @notice third party contract needed to lend on Tempus
    address public immutable tempusAddr;
    /// @notice third party contract needed to lend on APWine
    address public immutable apwineAddr;

    /// @notice mapping that indicates how much underlying has been redeemed by a market
    mapping(address => mapping(uint256 => uint256)) public holdings;
    /// @notice mapping that determines if a market's iPT can be redeemed
    mapping(address => mapping(uint256 => bool)) public paused;

    /// @notice emitted upon redemption of a loan
    event Redeem(
        uint8 principal,
        address indexed underlying,
        uint256 indexed maturity,
        uint256 amount,
        address sender
    );
    /// @notice emitted on change of admin
    event SetAdmin(address indexed admin);
    /// @notice emitted on change of converter
    event SetConverter(address indexed converter);

    /// @notice ensures that only a certain address can call the function
    /// @param a address that msg.sender must be to be authorized
    modifier authorized(address a) {
        if (msg.sender != a) {
            revert Exception(0, 0, 0, msg.sender, a);
        }
        _;
    }

    /// @notice reverts on all markets where the paused mapping returns true
    /// @param u underlying asset
    /// @param m maturity
    modifier unpaused(address u, uint256 m) {
        if (paused[u][m]) {
            revert Exception(17, m, 0, u, address(0));
        }
        _;
    }

    /// @notice Initializes the Redeemer contract
    /// @param l the lender contract
    /// @param s the Swivel contract
    /// @param p the Pendle contract
    /// @param t the Tempus contract
    /// @param a the APWine contract
    constructor(
        address l,
        address s,
        address p,
        address t,
        address a
    ) {
        admin = msg.sender;
        lender = l;
        swivelAddr = s;
        pendleAddr = p;
        tempusAddr = t;
        apwineAddr = a;
    }

    /// @notice sets the admin address
    /// @param a Address of a new admin
    /// @return bool true if successful
    function setAdmin(address a) external authorized(admin) returns (bool) {
        admin = a;
        emit SetAdmin(a);
        return true;
    }

    /// @notice sets the address of the marketplace contract which contains the addresses of all the fixed rate markets
    /// @param m the address of the marketplace contract
    /// @return bool true if the address was set
    function setMarketPlace(address m)
        external
        authorized(admin)
        returns (bool)
    {
        if (marketPlace != address(0)) {
            revert Exception(5, 0, 0, marketPlace, address(0));
        }
        marketPlace = m;
        return true;
    }

    /// @notice sets the converter address
    /// @param c address of the new converter
    /// @return bool true if successful
    function setConverter(address c) external authorized(admin) returns (bool) {
        converter = c;
        emit SetConverter(c);
        return true;
    }

    /// @notice sets the address of the lender contract which contains the addresses of all the fixed rate markets
    /// @param l the address of the lender contract
    /// @return bool true if the address was set
    function setLender(address l) external authorized(admin) returns (bool) {
        if (lender != address(0)) {
            revert Exception(8, 0, 0, address(lender), address(0));
        }
        lender = l;
        return true;
    }

    /// @notice allows admin to stop redemptions of illuminate PTs for a given market
    /// @param u address of underlying asset
    /// @param m maturity of the market
    /// @param b true to pause, false to unpause
    function pauseRedemptions(
        address u,
        uint256 m,
        bool b
    ) external authorized(admin) {
        paused[u][m] = b;
    }

    /// @notice approves the converter to spend the compounding asset
    /// todo does this need to be restricted?
    function approve(address p) external {
        if (p != address(0)) {
            address yield = IPendleToken(p).underlyingYieldToken();

            IERC20(yield).approve(address(converter), type(uint256).max);
        }
    }

    /// @notice redeem method for Swivel, Yield, Element, Pendle, APWine, Tempus and Notional protocols
    /// @param p value of a specific principal according to the Illuminate Principals Enum
    /// @param u underlying token being redeemed
    /// @param m maturity of the market being redeemed
    /// @return bool true if the redemption was successful
    function redeem(
        uint8 p,
        address u,
        uint256 m
    ) external returns (bool) {
        // Get the principal token that is being redeemed by the user
        address principal = IMarketPlace(marketPlace).token(u, m, p);
        uint256 maturity;

        // Confirm that this market has matured
        if (p == uint8(MarketPlace.Principals.Element)) {
            maturity = IElementToken(principal).unlockTimestamp();
            if (maturity > block.timestamp) {
                revert Exception(7, maturity, 0, address(0), address(0));
            }
        } else if (p == uint8(MarketPlace.Principals.Notional)) {
            maturity = INotional(principal).getMaturity();
            if (maturity > block.timestamp) {
                revert Exception(7, maturity, 0, address(0), address(0));
            }
        } else if (p == uint8(MarketPlace.Principals.Apwine)) {
            maturity = apwineMaturity(principal);
            if (maturity > block.timestamp) {
                revert Exception(7, maturity, 0, address(0), address(0));
            }
            principal = IAPWineAMMPool(principal).getPTAddress();
        } else if (p == uint8(MarketPlace.Principals.Tempus)) {
            address pool = ITempusToken(principal).pool();
            maturity = ITempusPool(pool).maturityTime();

            if (maturity > block.timestamp) {
                revert Exception(7, maturity, 0, address(0), address(0));
            }
        } else if (
            p != uint8(MarketPlace.Principals.Yield) &&
            p != uint8(MarketPlace.Principals.Swivel) &&
            p != uint8(MarketPlace.Principals.Pendle)
        ) {
            revert Exception(6, p, 0, address(0), address(0));
        }

        // Cache the lender to save gas on sload
        address cachedLender = lender;

        // The amount redeemed should be the balance of the principal token held by the Illuminate contract
        uint256 amount = IERC20(principal).balanceOf(cachedLender);

        // Transfer the principal token from the lender contract to here
        Safe.transferFrom(
            IERC20(principal),
            cachedLender,
            address(this),
            amount
        );

        // Starting balance of the underlying held by the redeemer
        uint256 starting = IERC20(u).balanceOf(address(this));

        if (p == uint8(MarketPlace.Principals.Swivel)) {
            // Get the maturity for thisprincipal token
            maturity = ISwivelToken(principal).maturity();
            // Redeems zc tokens to the sender's address
            if (!ISwivel(swivelAddr).redeemZcToken(u, maturity, amount)) {
                revert Exception(15, 0, 0, address(0), address(0));
            }
        } else if (p == uint8(MarketPlace.Principals.Element)) {
            // Redeems principal tokens from element
            IElementToken(principal).withdrawPrincipal(amount, address(this));
        } else if (p == uint8(MarketPlace.Principals.Yield)) {
            // Redeems principal tokens from yield
            IYieldToken(principal).redeem(address(this), amount);
        } else if (p == uint8(MarketPlace.Principals.Notional)) {
            // Redeems the principal token from notional
            // TODO: Should this just use the balance of the principal token (instead of maxRedeem)?
            INotional(principal).redeem(
                INotional(principal).maxRedeem(address(this)),
                address(this),
                address(this)
            );
        } else if (p == uint8(MarketPlace.Principals.Pendle)) {
            // Get the maturity for this principal token
            maturity = IPendleToken(principal).expiry();
            // Get the forge contract for the principal token
            address forge = IPendleToken(principal).forge();
            // Get the forge ID of the principal token
            bytes32 forgeId = IPendleForge(forge).forgeId();
            // Redeem the tokens from the Pendle contract
            IPendle(pendleAddr).redeemAfterExpiry(forgeId, u, maturity);
            // Get the compounding asset for this market
            address compounding = IPendleToken(principal)
                .underlyingYieldToken();
            // Redeem the compounding to token to the underlying
            IConverter(converter).convert(
                compounding,
                u,
                IERC20(compounding).balanceOf(address(this)),
                0
            );
        } else if (p == uint8(MarketPlace.Principals.Apwine)) {
            address futureVault = IAPWineToken(principal).futureVault();
            // Redeem the underlying token from APWine to Illuminate
            IAPWine(apwineAddr).withdraw(futureVault, amount);
        } else if (p == uint8(MarketPlace.Principals.Tempus)) {
            // Retrieve the pool for the principal token
            address pool = ITempusToken(principal).pool();
            // Redeem the tokens from the Tempus contract to Illuminate
            ITempus(tempusAddr).redeemToBacking(pool, amount, 0, address(this));
        }

        // Update the holding for this market
        holdings[u][m] =
            holdings[u][m] +
            (IERC20(u).balanceOf(address(this)) - starting);

        emit Redeem(p, u, m, amount, msg.sender);
        return true;
    }

    /// @notice redeem method signature for Sense
    /// @param p value of a specific principal according to the Illuminate Principals Enum
    /// @param u underlying token being redeemed
    /// @param m maturity of the market being redeemed
    /// @param s Sense's maturity is needed to extract the pt address
    /// @return bool true if the redemption was successful
    function redeem(
        uint8 p,
        address u,
        uint256 m,
        uint256 s
    ) external returns (bool) {
        // Check the principal is Sense
        if (p != uint8(MarketPlace.Principals.Sense)) {
            revert Exception(6, p, 0, address(0), address(0));
        }

        // Get the adapter for sense
        address adapter = IMarketPlace(marketPlace).token(u, m, p);

        // Get the divider from the adapter
        ISenseDivider divider = ISenseDivider(ISenseAdapter(adapter).divider());

        // Retrieve the principal token from the adapter
        IERC20 token = IERC20(divider.pt(adapter, s));

        // Cache the lender to save on sloads
        address cachedLender = lender;

        // Get the balance of tokens to be redeemed by the user
        uint256 amount = token.balanceOf(cachedLender);

        // Transfer the user's tokens to the redeem contract
        Safe.transferFrom(token, cachedLender, address(this), amount);

        // Get the starting balance to verify the amount received afterwards
        uint256 starting = IERC20(u).balanceOf(address(this));

        // Redeem the tokens from the Sense contract
        ISenseDivider(divider).redeem(adapter, s, amount);

        // Get the compounding token that is redeemed by Sense
        address target = ISenseAdapter(adapter).target();

        // Redeem the compounding token back to the underlying
        IConverter(converter).convert(
            target,
            u,
            IERC20(target).balanceOf(address(this)),
            0
        );

        // Get the amount received
        uint256 received = IERC20(u).balanceOf(address(this)) - starting;

        // Verify that we received expected underlying
        if (received < amount) {
            revert Exception(13, 0, 0, address(0), address(0));
        }

        // Update the holdings for this market
        holdings[u][m] = holdings[u][m] + received;

        emit Redeem(p, u, m, amount, msg.sender);
        return true;
    }

    /// @notice burns illuminate principal tokens and sends underlying to user
    /// @param u address of the underlying asset
    /// @param m maturity of the market
    function redeem(address u, uint256 m) external unpaused(u, m) {
        // Verify the market has matured
        if (block.timestamp < m) {
            revert Exception(7, block.timestamp, m, address(0), address(0));
        }
        // Get Illuminate's principal token for this market
        IERC5095 token = IERC5095(
            IMarketPlace(marketPlace).token(
                u,
                m,
                uint8(MarketPlace.Principals.Illuminate)
            )
        );
        // Get the amount of tokens to be redeemed from the sender
        uint256 amount = token.balanceOf(msg.sender);
        // Calculate how many tokens the user should receive
        uint256 redeemed = (amount * holdings[u][m]) / token.totalSupply();
        // Update holdings of underlying
        holdings[u][m] = holdings[u][m] - redeemed;
        // Burn the user's principal tokens
        token.authBurn(msg.sender, amount);
        // Transfer the original underlying token back to the user
        Safe.transfer(IERC20(u), msg.sender, redeemed);
        emit Redeem(0, u, m, amount, msg.sender);
    }

    /// @notice implements the redeem method for the contract to fulfill the ERC-5095 interface
    /// @param u address of the underlying asset
    /// @param m maturity of the market
    /// @param f address from where the underlying asset will be burned
    /// @param t address to where the underlying asset will be transferred
    /// @param a amount of the underlying asset to be burned and redeemed
    /// @return uint256 amount of the underlying asset that was burned
    function authRedeem(
        address u,
        uint256 m,
        address f,
        address t,
        uint256 a
    )
        external
        authorized(IMarketPlace(marketPlace).token(u, m, 0))
        returns (uint256)
    {
        // Get the principal token for the given market
        IERC5095 pt = IERC5095(IMarketPlace(marketPlace).token(u, m, 0));

        // Make sure the market has matured
        uint256 maturity = pt.maturity();
        if (block.timestamp < maturity) {
            revert Exception(7, maturity, 0, address(0), address(0));
        }

        // Burn the user's principal tokens
        pt.authBurn(f, a);

        // Transfer the original underlying token back to the user
        Safe.transfer(IERC20(u), t, a);
        return a;
    }

    /// @notice gets the maturity for a given APWine amm pool
    /// @param p address of the amm pool
    /// @return uint256 maturity timestamp for the amm pool
    function apwineMaturity(address p) internal view returns (uint256) {
        // Retrieve principal token for this amm pool
        address pt = IAPWineAMMPool(p).getPTAddress();

        // Retrieve corresponding future vault for this amm pool
        address futureVault = IAPWineToken(pt).futureVault();

        // Retrieve the period duration for this future vault
        uint256 duration = IAPWineFutureVault(futureVault).PERIOD_DURATION();

        // Return the next period (implicitly current maturity) for this amm pool
        return
            IAPWineController(
                IAPWineFutureVault(futureVault).getControllerAddress()
            ).getNextPeriodStart(duration);
    }
}