// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.15;
import "../libraries/Authorizable.sol";
import "../libraries/ERC20Permit.sol";
import "../interfaces/IYearnVault.sol";

contract MockERC20YearnVault is IYearnVault, Authorizable, ERC20Permit {
    // total amount of vault shares in existence
    uint256 public totalShares;

    // a large number used to offset potential division precision errors
    uint256 public precisionFactor;

    // underlying token
    ERC20Permit public token;

    // variables for the profit time-lock
    uint256 public constant DEGRADATION_COEFFICIENT = 1e18;
    uint256 public lockedProfitDegradation;

    // last time someone deposited value through report()
    uint256 public lastReport;
    // the amount of tokens locked after a report()
    uint256 public lockedProfit;

    /**
    @param _token The ERC20 token the vault accepts
     */
    constructor(address _token)
        Authorizable()
        ERC20Permit("Mock Yearn Vault", "MYV")
    {
        _authorize(msg.sender);
        token = ERC20Permit(_token);
        decimals = token.decimals();
        precisionFactor = 10**(18 - decimals);
        // 6 hours in blocks
        // 6*60*60 ~= 1e6 / 46
        lockedProfitDegradation = (DEGRADATION_COEFFICIENT * 46) / 1e6;
    }

    function apiVersion() external pure returns (string memory) {
        return ("0.3.2");
    }

    /**
    @notice Add tokens to the vault. Increases totalAssets.
    @param _deposit The amount of tokens to deposit
    @dev There is no logic to rebalance lockedAmount.
    Repeat calls will just reset it.
    */
    function report(uint256 _deposit) external onlyAuthorized {
        lastReport = block.timestamp;
        // mock vault does not take performance or management fee
        // so the full deposit is locked profit.
        lockedProfit = _deposit;
        token.transferFrom(msg.sender, address(this), _deposit);
    }

    /**
    @notice Deposit `_amount` of tokens into the yearn vault.
    `_recipient` receives shares.
    @param _amount The amount of underlying tokens to deposit.
    @param _recipient The recipient of the vault shares.
    @return The vault shares received.

     */
    function deposit(uint256 _amount, address _recipient)
        external
        returns (uint256)
    {
        require(_amount > 0, "depositing 0 value");
        uint256 shares = _issueSharesForAmount(_recipient, _amount);
        token.transferFrom(msg.sender, address(this), _amount);
        return shares;
    }

    /**
    @notice Withdraw `_maxShares` of shares from caller `_recipient`
    receives underlying tokens.
    @param _maxShares The amount of shares to redeem for underlying.
    @param _recipient The recipient of the underlying tokens.
    @param _maxLoss The max permitted withdrawal loss. (1 = 0.01%, 10000 = 100%).
    @return The amount of underlying tokens that were redeemed from _maxShares shares.
     */
    function withdraw(
        uint256 _maxShares,
        address _recipient,
        uint256 _maxLoss
    ) external override returns (uint256) {
        // silence unused function parameter warning
        require(_maxLoss >= 0);
        require(_maxShares > 0, "Can't withdraw zero");
        require(balanceOf[msg.sender] >= _maxShares, "Shares exceed balance");
        uint256 value = _shareValue(_maxShares);

        totalShares -= _maxShares;
        balanceOf[msg.sender] -= _maxShares;

        token.transfer(_recipient, value);
        return value;
    }

    /**
    @notice Returns the amount of underlying per each unit [10^decimals] of yearn shares
     */
    function pricePerShare() public view override returns (uint256) {
        return _shareValue(10**decimals);
    }

    /**
    @notice Get the governance address. It will be address(0)
    it is not used for this mock.
     */
    function governance() public pure override returns (address) {
        return address(0);
    }

    /**
    @notice The deposit limit for this vault.
    @dev Can only be unlimited for this mock.
     */
    function setDepositLimit(uint256 _limit) public view override {
        // silence unused function parameter warning
        require(_limit >= 0);
        require(msg.sender == governance(), "!governance");
    }

    /**
    @notice Returns total assets held by the contract.
    @dev This is a mock and there is no debt. The total assets are just the
    underlying tokens held by the contract.
     */
    function totalAssets() public view override returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
    @param _to The address to receive the shares.
    @param _amount The amount of underlying tokens to convert to shares.
    @return The amount of shares _amount yields.
     */
    function _issueSharesForAmount(address _to, uint256 _amount)
        internal
        returns (uint256)
    {
        uint256 shares;
        if (totalShares > 0) {
            shares =
                (precisionFactor * _amount * totalShares) /
                totalAssets() /
                precisionFactor;
        } else {
            shares = _amount;
        }
        totalShares += shares;
        balanceOf[_to] += shares;
        return shares;
    }

    /**
    @notice Return the amount of underlying tokens an amount of `_shares`
    is worth at any given time.
    @param _shares The amount of shares to check.
    @return The amount of underlying tokens the `_shares` can be redeemed for.
     */
    function _shareValue(uint256 _shares) internal view returns (uint256) {
        if (totalShares == 0) {
            return _shares;
        }
        // determine the current value of the shares
        uint256 lockedFundsRatio = (block.timestamp - lastReport) *
            lockedProfitDegradation;
        uint256 freeFunds = totalAssets();
        if (lockedFundsRatio < DEGRADATION_COEFFICIENT) {
            freeFunds -= (lockedProfit -
                ((precisionFactor * lockedFundsRatio * lockedProfit) /
                    DEGRADATION_COEFFICIENT /
                    precisionFactor));
        }
        return ((precisionFactor * _shares * freeFunds) /
            totalShares /
            precisionFactor);
    }

    /**
    @notice Get the total number of vault shares.
    @return Total vault shares.
     */
    function totalSupply() external view override returns (uint256) {
        return totalShares;
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.7.0;

contract Authorizable {
    // This contract allows a flexible authorization scheme

    // The owner who can change authorization status
    address public owner;
    // A mapping from an address to its authorization status
    mapping(address => bool) public authorized;

    /// @dev We set the deployer to the owner
    constructor() {
        owner = msg.sender;
    }

    /// @dev This modifier checks if the msg.sender is the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Sender not owner");
        _;
    }

    /// @dev This modifier checks if an address is authorized
    modifier onlyAuthorized() {
        require(isAuthorized(msg.sender), "Sender not Authorized");
        _;
    }

    /// @dev Returns true if an address is authorized
    /// @param who the address to check
    /// @return true if authorized false if not
    function isAuthorized(address who) public view returns (bool) {
        return authorized[who];
    }

    /// @dev Privileged function authorize an address
    /// @param who the address to authorize
    function authorize(address who) external onlyOwner {
        _authorize(who);
    }

    /// @dev Privileged function to de authorize an address
    /// @param who The address to remove authorization from
    function deauthorize(address who) external onlyOwner {
        authorized[who] = false;
    }

    /// @dev Function to change owner
    /// @param who The new owner address
    function setOwner(address who) public onlyOwner {
        owner = who;
    }

    /// @dev Inheritable function which authorizes someone
    /// @param who the address to authorize
    function _authorize(address who) internal {
        authorized[who] = true;
    }
}

// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.15;

import "../interfaces/IERC20Permit.sol";

// This default erc20 library is designed for max efficiency and security.
// WARNING: By default it does not include totalSupply which breaks the ERC20 standard
//          to use a fully standard compliant ERC20 use 'ERC20PermitWithSupply"
abstract contract ERC20Permit is IERC20Permit {
    // --- ERC20 Data ---
    // The name of the erc20 token
    string public name;
    // The symbol of the erc20 token
    string public override symbol;
    // The decimals of the erc20 token, should default to 18 for new tokens
    uint8 public override decimals;

    // A mapping which tracks user token balances
    mapping(address => uint256) public override balanceOf;
    // A mapping which tracks which addresses a user allows to move their tokens
    mapping(address => mapping(address => uint256)) public override allowance;
    // A mapping which tracks the permit signature nonces for users
    mapping(address => uint256) public override nonces;

    // --- EIP712 niceties ---
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public override DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @notice Initializes the erc20 contract
    /// @param name_ the value 'name' will be set to
    /// @param symbol_ the value 'symbol' will be set to
    /// @dev decimals default to 18 and must be reset by an inheriting contract for
    ///      non standard decimal values
    constructor(string memory name_, string memory symbol_) {
        // Set the state variables
        name = name_;
        symbol = symbol_;
        decimals = 18;

        // By setting these addresses to 0 attempting to execute a transfer to
        // either of them will revert. This is a gas efficient way to prevent
        // a common user mistake where they transfer to the token address.
        // These values are not considered 'real' tokens and so are not included
        // in 'total supply' which only contains minted tokens.
        balanceOf[address(0)] = type(uint256).max;
        balanceOf[address(this)] = type(uint256).max;

        // Optional extra state manipulation
        _extraConstruction();

        // Computes the EIP 712 domain separator which prevents user signed messages for
        // this contract to be replayed in other contracts.
        // https://eips.ethereum.org/EIPS/eip-712
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice An optional override function to execute and change state before immutable assignment
    function _extraConstruction() internal virtual {}

    // --- Token ---
    /// @notice Allows a token owner to send tokens to another address
    /// @param recipient The address which will be credited with the tokens
    /// @param amount The amount user token to send
    /// @return returns true on success, reverts on failure so cannot return false.
    /// @dev transfers to this contract address or 0 will fail
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        // We forward this call to 'transferFrom'
        return transferFrom(msg.sender, recipient, amount);
    }

    /// @notice Transfers an amount of erc20 from a spender to a receipt
    /// @param spender The source of the ERC20 tokens
    /// @param recipient The destination of the ERC20 tokens
    /// @param amount the number of tokens to send
    /// @return returns true on success and reverts on failure
    /// @dev will fail transfers which send funds to this contract or 0
    function transferFrom(
        address spender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        // Load balance and allowance
        uint256 balance = balanceOf[spender];
        require(balance >= amount, "ERC20: insufficient-balance");
        // We potentially have to change allowances
        if (spender != msg.sender) {
            // Loading the allowance in the if block prevents vanilla transfers
            // from paying for the sload.
            uint256 allowed = allowance[spender][msg.sender];
            // If the allowance is max we do not reduce it
            // Note - This means that max allowances will be more gas efficient
            // by not requiring a sstore on 'transferFrom'
            if (allowed != type(uint256).max) {
                require(allowed >= amount, "ERC20: insufficient-allowance");
                allowance[spender][msg.sender] = allowed - amount;
            }
        }
        // Update the balances
        balanceOf[spender] = balance - amount;
        // Note - In the constructor we initialize the 'balanceOf' of address 0 and
        //        the token address to uint256.max and so in 8.0 transfers to those
        //        addresses revert on this step.
        balanceOf[recipient] = balanceOf[recipient] + amount;
        // Emit the needed event
        emit Transfer(spender, recipient, amount);
        // Return that this call succeeded
        return true;
    }

    /// @notice This internal minting function allows inheriting contracts
    ///         to mint tokens in the way they wish.
    /// @param account the address which will receive the token.
    /// @param amount the amount of token which they will receive
    /// @dev This function is virtual so that it can be overridden, if you
    ///      are reviewing this contract for security you should ensure to
    ///      check for overrides
    function _mint(address account, uint256 amount) internal virtual {
        // Add tokens to the account
        balanceOf[account] = balanceOf[account] + amount;
        // Emit an event to track the minting
        emit Transfer(address(0), account, amount);
    }

    /// @notice This internal burning function allows inheriting contracts to
    ///         burn tokens in the way they see fit.
    /// @param account the account to remove tokens from
    /// @param amount  the amount of tokens to remove
    /// @dev This function is virtual so that it can be overridden, if you
    ///      are reviewing this contract for security you should ensure to
    ///      check for overrides
    function _burn(address account, uint256 amount) internal virtual {
        // Reduce the balance of the account
        balanceOf[account] = balanceOf[account] - amount;
        // Emit an event tracking transfers
        emit Transfer(account, address(0), amount);
    }

    /// @notice This function allows a user to approve an account which can transfer
    ///         tokens on their behalf.
    /// @param account The account which will be approve to transfer tokens
    /// @param amount The approval amount, if set to uint256.max the allowance does not go down on transfers.
    /// @return returns true for compatibility with the ERC20 standard
    function approve(address account, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        // Set the senders allowance for account to amount
        allowance[msg.sender][account] = amount;
        // Emit an event to track approvals
        emit Approval(msg.sender, account, amount);
        return true;
    }

    /// @notice This function allows a caller who is not the owner of an account to execute the functionality of 'approve' with the owners signature.
    /// @param owner the owner of the account which is having the new approval set
    /// @param spender the address which will be allowed to spend owner's tokens
    /// @param value the new allowance value
    /// @param deadline the timestamp which the signature must be submitted by to be valid
    /// @param v Extra ECDSA data which allows public key recovery from signature assumed to be 27 or 28
    /// @param r The r component of the ECDSA signature
    /// @param s The s component of the ECDSA signature
    /// @dev The signature for this function follows EIP 712 standard and should be generated with the
    ///      eth_signTypedData JSON RPC call instead of the eth_sign JSON RPC call. If using out of date
    ///      parity signing libraries the v component may need to be adjusted. Also it is very rare but possible
    ///      for v to be other values, those values are not supported.
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        // The EIP 712 digest for this function
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces[owner],
                        deadline
                    )
                )
            )
        );
        // Require that the owner is not zero
        require(owner != address(0), "ERC20: invalid-address-0");
        // Require that we have a valid signature from the owner
        require(owner == ecrecover(digest, v, r, s), "ERC20: invalid-permit");
        // Require that the signature is not expired
        require(
            deadline == 0 || block.timestamp <= deadline,
            "ERC20: permit-expired"
        );
        // Format the signature to the default format
        require(
            uint256(s) <=
                0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "ERC20: invalid signature 's' value"
        );
        // Increment the signature nonce to prevent replay
        nonces[owner]++;
        // Set the allowance to the new value
        allowance[owner][spender] = value;
        // Emit an approval event to be able to track this happening
        emit Approval(owner, spender, value);
    }

    /// @notice Internal function which allows inheriting contract to set custom decimals
    /// @param decimals_ the new decimal value
    function _setupDecimals(uint8 decimals_) internal {
        // Set the decimals
        decimals = decimals_;
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.15;

import "./IERC20.sol";

interface IYearnVault is IERC20 {
    function deposit(uint256, address) external returns (uint256);

    function withdraw(
        uint256,
        address,
        uint256
    ) external returns (uint256);

    // Returns the amount of underlying per each unit [1e18] of yearn shares
    function pricePerShare() external view returns (uint256);

    function governance() external view returns (address);

    function setDepositLimit(uint256) external;

    function totalSupply() external view returns (uint256);

    function totalAssets() external view returns (uint256);

    function apiVersion() external view returns (string memory);
}

// Forked from openzepplin
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./IERC20.sol";

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit is IERC20 {
    /**
     * @dev Sets `value` as the allowance of `spender` over `owner`'s tokens,
     * given `owner`'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
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
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for `permit`, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.15;

interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function balanceOf(address account) external view returns (uint256);

    // Note this is non standard but nearly all ERC20 have exposed decimal functions
    function decimals() external view returns (uint8);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}