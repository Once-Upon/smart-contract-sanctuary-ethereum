// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'src/MarketPlace.sol'; // library of marketplace specific constructs
import 'src/lib/Swivel.sol'; // library of swivel specific constructs
import 'src/lib/Element.sol'; // library of element specific constructs
import 'src/lib/Safe.sol';
import 'src/lib/Cast.sol';
import 'src/errors/Exception.sol';

import 'src/interfaces/ITempus.sol';
import 'src/interfaces/ITempusAMM.sol';
import 'src/interfaces/ITempusPool.sol';
import 'src/interfaces/ITempusToken.sol';
import 'src/interfaces/IERC20.sol';
import 'src/interfaces/IERC5095.sol';
import 'src/interfaces/ISensePeriphery.sol';
import 'src/interfaces/ISenseAdapter.sol';
import 'src/interfaces/ISenseDivider.sol';
import 'src/interfaces/IERC20.sol';
import 'src/interfaces/IYield.sol';
import 'src/interfaces/IYieldToken.sol';
import 'src/interfaces/ISwivel.sol';
import 'src/interfaces/IElementToken.sol';
import 'src/interfaces/IElementVault.sol';
import 'src/interfaces/ISwivel.sol';
import 'src/interfaces/IAPWineAMMPool.sol';
import 'src/interfaces/IAPWineRouter.sol';
import 'src/interfaces/IAPWineToken.sol';
import 'src/interfaces/IAPWineFutureVault.sol';
import 'src/interfaces/IAPWineController.sol';
import 'src/interfaces/INotional.sol';
import 'src/interfaces/IPendle.sol';
import 'src/interfaces/IPendleToken.sol';

/// @title Lender.sol
/// @author Sourabh Marathe, Julian Traversa, Rob Robbins
/// @notice The lender contract executes loans on behalf of users.
/// @notice The contract holds the principal tokens for each market and mints an ERC-5095 position to users to represent their lent positions.
contract Lender {
    /// @notice minimum amount of time the admin must wait before executing a withdrawal
    uint256 public constant HOLD = 1 hours; // todo make 3 days again

    /// @notice address that is allowed to create markets, set fees, etc. It is commonly used in the authorized modifier.
    address public admin;
    /// @notice address of the MarketPlace.sol contract, used to access the markets mapping
    address public marketPlace;
    /// @notice mapping that determines if a principal may be used by a lender
    mapping(uint8 => bool) public paused;

    /// @notice third party contract needed to lend on Swivel
    address public immutable swivelAddr;
    /// @notice third party contract needed to lend on Pendle
    address public immutable pendleAddr;
    /// @notice third party contract needed to lend on Tempus
    address public immutable tempusAddr; // TODO: Remove, can be retrieved via tempus token

    /// @notice this value determines the amount of fees paid on loans
    uint256 public feenominator;

    /// @notice maps underlying tokens to the amount of fees accumulated for that token
    mapping(address => uint256) public fees;
    /// @notice maps a token address to a point in time, a hold, after which a withdrawal can be made
    mapping(address => uint256) public withdrawals;

    /// @notice emitted upon executed lend
    event Lend(
        uint8 principal,
        address indexed underlying,
        uint256 indexed maturity,
        uint256 returned,
        uint256 spent,
        address sender
    );
    /// @notice emitted upon minted ERC5095 to user
    event Mint(
        uint8 principal,
        address indexed underlying,
        uint256 indexed maturity,
        uint256 amount
    );
    /// @notice emitted on token withdrawal scheduling
    event ScheduleWithdrawal(address indexed token, uint256 hold);
    /// @notice emitted on token withdrawal blocking
    event BlockWithdrawal(address indexed token);
    /// @notice emitted on change of admin
    event SetAdmin(address indexed admin);
    /// @notice emitted upon change of fee
    event SetFee(uint256 indexed fee);

    /// @notice ensures that only a certain address can call the function
    /// @param a address that msg.sender must be to be authorized
    modifier authorized(address a) {
        if (msg.sender != a) {
            revert Exception(0, 0, 0, msg.sender, a);
        }
        _;
    }

    /// @notice reverts on all markets where the paused mapping returns true
    /// @param p principal enum value
    modifier unpaused(uint8 p) {
        if (paused[p]) {
            revert Exception(1, p, 0, address(0), address(0));
        }
        _;
    }

    /// @notice initializes the Lender contract
    /// @param s the swivel contract
    /// @param p the pendle contract
    /// @param t the tempus contract
    constructor(
        address s,
        address p,
        address t
    ) {
        admin = msg.sender;
        swivelAddr = s;
        pendleAddr = p;
        tempusAddr = t;
        feenominator = 1000;
    }

    /// @notice approves the redeemer contract to spend the principal tokens held by the lender contract.
    /// @param u underlying token's address, used to define the market being approved
    /// @param m maturity of the underlying token, used to define the market being approved
    /// @param r the address being approved, in this case the redeemer contract
    /// @return bool true if the approval was successful
    function approve(
        address u,
        uint256 m,
        address r
    ) external authorized(admin) returns (bool) {
        // approve the underlying for max per given principal
        for (uint8 i; i != 9; ) {
            // get the principal token's address
            address token = IMarketPlace(marketPlace).token(u, m, i);
            // check that the token is defined for this particular market
            if (token != address(0)) {
                // max approve the token
                Safe.approve(IERC20(token), r, type(uint256).max);
            }
            unchecked {
                ++i;
            }
        }
        return true;
    }

    /// @notice bulk approves the usage of addresses at the given ERC20 addresses.
    /// @dev the lengths of the inputs must match because the arrays are paired by index
    /// @param u array of ERC20 token addresses that will be approved on
    /// @param a array of addresses that will be approved
    /// @return true if successful
    function approve(address[] calldata u, address[] calldata a)
        external
        authorized(admin)
        returns (bool)
    {
        for (uint256 i; i != u.length; ) {
            IERC20 uToken = IERC20(u[i]);
            if (address(0) != (address(uToken))) {
                Safe.approve(uToken, a[i], type(uint256).max);
            }
            unchecked {
                ++i;
            }
        }
        return true;
    }

    /// @notice approves market contracts that require lender approval
    /// @param u address of underlying asset
    /// @param a apwine's router contract
    /// @param e element's vault contract
    /// @param n notional's token contract
    function approve(
        address u,
        address a,
        address e,
        address n
    ) external authorized(marketPlace) {
        uint256 max = type(uint256).max;
        IERC20(u).approve(a, max);
        IERC20(u).approve(e, max);
        IERC20(u).approve(n, max);
    }

    /// @notice sets the admin address
    /// @param a address of a new admin
    /// @return bool true if successful
    function setAdmin(address a) external authorized(admin) returns (bool) {
        admin = a;
        emit SetAdmin(a);
        return true;
    }

    /// @notice sets the feenominator to the given value
    /// @param f the new value of the feenominator, fees are not collected when the feenominator is 0
    /// @return bool true if successful
    function setFee(uint256 f) external authorized(admin) returns (bool) {
        feenominator = f;
        emit SetFee(f);
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

    /// @notice mint swaps the sender's principal tokens for illuminate's ERC5095 tokens in effect, this opens a new fixed rate position for the sender on illuminate
    /// @param p value of a specific principal according to the MarketPlace Principals Enum
    /// @param u address of an underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount being minted
    /// @return bool true if the mint was successful
    function mint(
        uint8 p,
        address u,
        uint256 m,
        uint256 a
    ) external unpaused(p) returns (bool) {
        // fetch the desired principal token
        address principal = IMarketPlace(marketPlace).token(u, m, p);
        // transfer the users principal tokens to the lender contract
        Safe.transferFrom(IERC20(principal), msg.sender, address(this), a);
        // mint the tokens received from the user
        IERC5095(principalToken(u, m)).authMint(msg.sender, a);

        emit Mint(p, u, m, a);

        return true;
    }

    /// @notice lend method signature for both illuminate and yield
    /// @param p value of a specific principal according to the MarketPlace Principals Enum
    /// @param u address of an underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount of underlying tokens to lend
    /// @param y yieldspace pool that will execute the swap for the principal token
    /// @param minimum minimum PTs to buy from the yieldspace pool
    /// @return uint256 the amount of principal tokens lent out
    function lend(
        uint8 p,
        address u,
        uint256 m,
        uint256 a,
        address y,
        uint256 minimum
    ) external unpaused(p) returns (uint256) {
        // check the principal is illuminate or yield
        if (
            p != uint8(MarketPlace.Principals.Illuminate) &&
            p != uint8(MarketPlace.Principals.Yield)
        ) {
            revert Exception(6, 0, 0, address(0), address(0));
        }
        // get principal token for this market
        address principal = IMarketPlace(marketPlace).token(u, m, p);

        // Extract fee
        fees[u] = fees[u] + calculateFee(a);

        // transfer from user to illuminate
        Safe.transferFrom(IERC20(u), msg.sender, address(this), a);

        if (p == uint8(MarketPlace.Principals.Yield)) {
            // make sure fytoken matches principal token for this market
            address fyToken = IYield(y).fyToken();
            if (IYield(y).fyToken() != principal) {
                revert Exception(12, 0, 0, fyToken, principal);
            }
        }

        // Swap underlying for PTs to lender
        uint256 returned = yield(
            u,
            y,
            a - calculateFee(a),
            address(this),
            principal,
            minimum
        );

        // Mint illuminate PTs to msg.sender
        IERC5095(principalToken(u, m)).authMint(msg.sender, returned);

        emit Lend(p, u, m, returned, a, msg.sender);

        return returned;
    }

    /// @notice lend method signature for swivel
    /// @dev lends to yield pool. remaining balance is sent to the yield pool
    /// @param p value of a specific principal according to the Illuminate Principals Enum
    /// @param u address of an underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a array of amounts of underlying tokens lent to each order in the orders array
    /// @param y yield pool
    /// @param o array of swivel orders being filled
    /// @param s array of signatures for each order in the orders array
    /// @param f fee that the user will pay in the underlying
    /// @param e flag to indicate if returned funds should be swapped in yieldpool
    /// @param premiumSlippage only used if e is true, the minimum amount for the yield pool swap on the premium
    /// @return uint256 the amount of principal tokens lent out
    function lend(
        uint8 p,
        address u,
        uint256 m,
        uint256[] memory a,
        address y,
        Swivel.Order[] calldata o,
        Swivel.Components[] calldata s,
        uint256 f,
        bool e,
        uint256 premiumSlippage
    ) external unpaused(p) returns (uint256) {
        if (p != uint8(MarketPlace.Principals.Swivel)) {
            revert Exception(
                6,
                p,
                uint8(MarketPlace.Principals.Swivel),
                address(0),
                address(0)
            );
        }
        {
            // lent represents the amount of underlying to initiate
            uint256 lent = swivelAmount(a);
            // Avoid stack too deep by reinitializing arguments
            address underlying = u;
            uint256 maturity = m;
            uint256[] memory amounts = a;
            address pool = y;
            Swivel.Order[] memory orders = o;
            Swivel.Components[] memory components = s;

            // Verify and collect the fee
            swivelCheckFee(f, lent, underlying);
            uint256 premium;
            {
                // Get the underlying balance prior to initiate
                uint256 starting = IERC20(underlying).balanceOf(address(this));
                // Fill the orders on swivel protocol
                ISwivel(swivelAddr).initiate(orders, amounts, components);
                // Calculate the premium
                premium =
                    IERC20(underlying).balanceOf(address(this)) -
                    starting;
            }
            if (e) {
                swivelLendPremium(
                    underlying,
                    maturity,
                    pool,
                    premium,
                    premiumSlippage
                );
            }
            // Mint illuminate principal tokens to the user
            IERC5095(principalToken(underlying, maturity)).authMint(
                msg.sender,
                lent
            );
            {
                uint256 spent = lent + f;
                // Necessary to get around stack too deep
                emit Lend(
                    uint8(MarketPlace.Principals.Swivel),
                    underlying,
                    maturity,
                    lent,
                    spent,
                    msg.sender
                );
            }
            return lent;
        }
    }

    /// @notice lend method signature for element
    /// @param p value of a specific principal according to the Illuminate Principals Enum
    /// @param u address of an underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount of principal tokens to lend
    /// @param r minimum amount to return, this puts a cap on allowed slippage
    /// @param d deadline is a timestamp by which the swap must be executed
    /// @param e element pool that is lent to
    /// @param i the id of the pool
    /// @return uint256 the amount of principal tokens lent out
    function lend(
        uint8 p,
        address u,
        uint256 m,
        uint256 a,
        uint256 r,
        uint256 d,
        address e,
        bytes32 i
    ) external unpaused(p) returns (uint256) {
        // Get the principal token for this market for element
        address principal = IMarketPlace(marketPlace).token(u, m, p);

        // Transfer underlying token from user to illuminate
        Safe.transferFrom(IERC20(u), msg.sender, address(this), a);

        // Track the accumulated fees
        fees[u] = fees[u] + calculateFee(a);

        uint256 purchased;
        {
            // Calculate the amount to be lent
            uint256 lent = a - calculateFee(a);

            // Create the variables needed to execute an element swap
            Element.FundManagement memory fund = Element.FundManagement({
                sender: address(this),
                recipient: payable(address(this)),
                fromInternalBalance: false,
                toInternalBalance: false
            });

            Element.SingleSwap memory swap = Element.SingleSwap({
                poolId: i,
                amount: lent,
                kind: Element.SwapKind.GIVEN_IN,
                assetIn: IAny(u),
                assetOut: IAny(principal),
                userData: '0x00000000000000000000000000000000000000000000000000000000000000'
            });

            // Conduct the swap on element
            purchased = swapElement(e, swap, fund, r, d);
        }

        // Mint tokens to the user
        IERC5095(principalToken(u, m)).authMint(msg.sender, purchased);

        emit Lend(p, u, m, purchased, a, msg.sender);
        return purchased;
    }

    /// @notice lend method signature for pendle
    /// @param p value of a specific principal according to the Illuminate Principals Enum
    /// @param u address of an underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount of principal tokens to lend
    /// @param r minimum amount to return, this puts a cap on allowed slippage
    /// @param d deadline is a timestamp by which the swap must be executed
    /// @return uint256 the amount of principal tokens lent out
    function lend(
        uint8 p,
        address u,
        uint256 m,
        uint256 a,
        uint256 r,
        uint256 d
    ) external unpaused(p) returns (uint256) {
        // Instantiate market and tokens
        address principal = IMarketPlace(marketPlace).token(u, m, p);

        // Transfer funds from user to Illuminate
        Safe.transferFrom(IERC20(u), msg.sender, address(this), a);

        uint256 returned;
        {
            // Add the accumulated fees to the total
            uint256 fee = calculateFee(a);
            fees[u] = fees[u] + fee;

            address[] memory path = new address[](2);
            path[0] = u;
            path[1] = principal;

            // Swap on the Pendle Router using the provided market and params
            returned = IPendle(pendleAddr).swapExactTokensForTokens(
                a - fee,
                r,
                path,
                address(this),
                d
            )[1];
        }

        // Mint Illuminate zero coupons
        IERC5095(principalToken(u, m)).authMint(msg.sender, returned);

        emit Lend(p, u, m, returned, a, msg.sender);
        return returned;
    }

    /// @notice lend method signature for tempus and apwine
    /// @param p value of a specific principal according to the Illuminate Principals Enum
    /// @param u address of an underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount of principal tokens to lend
    /// @param r minimum amount to return when executing the swap (sets a limit to slippage)
    /// @param d deadline is a timestamp by which the swap must be executed
    /// @param x tempus amm that executes the swap
    /// @return uint256 the amount of principal tokens lent out
    function lend(
        uint8 p,
        address u,
        uint256 m,
        uint256 a,
        uint256 r,
        uint256 d,
        address x
    ) external unpaused(p) returns (uint256) {
        address principal = IMarketPlace(marketPlace).token(u, m, p);

        // Transfer funds from user to Illuminate
        Safe.transferFrom(IERC20(u), msg.sender, address(this), a);

        uint256 lent;
        {
            // Add the accumulated fees to the total
            uint256 fee = calculateFee(a);
            fees[u] = fees[u] + fee;

            // Calculate amount to be lent out
            lent = a - fee;
        }

        // Returned holds the amount to mint
        uint256 returned;

        if (p == uint8(MarketPlace.Principals.Tempus)) {
            // Get the starting balance of the principal token
            uint256 start = IERC20(principal).balanceOf(address(this));

            // Swap on the Tempus Router using the provided market and params
            ITempus(tempusAddr).depositAndFix(x, lent, true, r, d);

            // Calculate the amount of tokens received after depositing the user's tokens
            returned = IERC20(principal).balanceOf(address(this)) - start;
        } else if (p == uint8(MarketPlace.Principals.Apwine)) {
            // Get the starting APWine token balance
            uint256 starting = IERC20(IAPWineAMMPool(principal).getPTAddress())
                .balanceOf(address(this));
            // Swap on the APWine Pool using the provided market and params
            returned = IAPWineRouter(x).swapExactAmountIn(
                principal,
                apwinePairPath(),
                apwineTokenPath(),
                lent,
                r,
                address(this),
                d,
                address(0)
            );
            if (
                IERC20(IAPWineAMMPool(principal).getPTAddress()).balanceOf(
                    address(this)
                ) -
                    starting !=
                returned
            ) {
                revert Exception(11, 0, 0, address(0), address(0));
            }
        }

        // Mint Illuminate zero coupons
        IERC5095(principalToken(u, m)).authMint(msg.sender, returned);

        emit Lend(p, u, m, returned, a, msg.sender);
        return returned;
    }

    /// @notice lend method signature for sense
    /// @dev this method can be called before maturity to lend to Sense while minting Illuminate tokens
    /// @dev sense provides a [divider] contract that splits [target] assets (underlying) into PTs and YTs. Each [target] asset has a [series] of contracts, each identifiable by their [maturity].
    /// @param p value of a specific principal according to the Illuminate Principals Enum
    /// @param u address of an underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount of underlying tokens to lend
    /// @param r minimum number of tokens to lend (sets a limit on the order)
    /// @param x amm that is used to conduct the swap
    /// @param s sense's maturity for the given market
    /// @param adapter sense's adapter necessary to facilitate the swap
    /// @return uint256 the amount of principal tokens lent out
    function lend(
        uint8 p,
        address u,
        uint256 m,
        uint128 a,
        uint256 r,
        address x,
        uint256 s,
        address adapter
    ) external unpaused(p) returns (uint256) {
        // Get the adapter for this market for this market
        IERC20 token = IERC20(IMarketPlace(marketPlace).token(u, m, p));

        uint256 lent;
        {
            // Determine the fee
            uint256 fee = calculateFee(a);

            // Add the accumulated fees to the total
            fees[u] = fees[u] + fee;

            // Determine lent amount after fees
            lent = a - fee;
        }

        // Transfer funds from user to Illuminate
        Safe.transferFrom(IERC20(u), msg.sender, address(this), a);

        // Stores the amount of principal tokens received in swap for underlying
        uint256 returned;
        {
            // Get the starting balance of the principal token
            uint256 starting = token.balanceOf(address(this));

            // Swap those tokens for the principal tokens
            returned = ISensePeriphery(x).swapUnderlyingForPTs(
                adapter,
                s,
                lent,
                r
            );

            // Verify that we received the principal tokens
            if (token.balanceOf(address(this)) < starting + returned) {
                revert Exception(11, 0, 0, address(0), address(0));
            }
        }

        // Mint the illuminate tokens based on the returned amount
        IERC5095(principalToken(u, m)).authMint(msg.sender, returned);

        emit Lend(p, u, m, returned, a, msg.sender);
        return returned;
    }

    /// @dev lend method signature for Notional
    /// @param p value of a specific principal according to the Illuminate Principals Enum
    /// @param u address of an underlying asset
    /// @param m maturity (timestamp) of the market
    /// @param a amount of underlying tokens to lend
    /// @param r minimum number of principal tokens to receive
    /// @return uint256 the amount of principal tokens lent out
    function lend(
        uint8 p,
        address u,
        uint256 m,
        uint256 a,
        uint256 r
    ) external unpaused(p) returns (uint256) {
        // Instantiate notional princpal token
        INotional token = INotional(IMarketPlace(marketPlace).token(u, m, p));

        // Transfer funds from user to Illuminate
        Safe.transferFrom(IERC20(u), msg.sender, address(this), a);

        // Add the accumulated fees to the total
        uint256 fee = calculateFee(a);
        fees[u] = fees[u] + fee;

        // Swap on the Notional Token wrapper
        uint256 returned = token.deposit(a - fee, address(this));

        if (returned < r) {
            revert Exception(16, returned, r, address(0), address(0));
        }

        // Mint Illuminate zero coupons
        IERC5095(principalToken(u, m)).authMint(msg.sender, returned);

        emit Lend(p, u, m, returned, a, msg.sender);
        return returned;
    }

    /// @notice allows the admin to schedule the withdrawal of tokens
    /// @param e address of (erc20) token to withdraw
    /// @return bool true if successful
    function scheduleWithdrawal(address e)
        external
        authorized(admin)
        returns (bool)
    {
        uint256 when = block.timestamp + HOLD;
        withdrawals[e] = when;

        emit ScheduleWithdrawal(e, when);
        return true;
    }

    /// @notice emergency function to block unplanned withdrawals
    /// @param e address of token withdrawal to block
    /// @return bool true if successful
    function blockWithdrawal(address e)
        external
        authorized(admin)
        returns (bool)
    {
        delete withdrawals[e];

        emit BlockWithdrawal(e);
        return true;
    }

    /// @notice allows the admin to withdraw the given token, provided the holding period has been observed
    /// @param e Address of token to withdraw
    /// @return bool true if successful
    function withdraw(address e) external authorized(admin) returns (bool) {
        uint256 when = withdrawals[e];
        if (when == 0) {
            revert Exception(18, 0, 0, address(0), address(0));
        }
        if (block.timestamp < when) {
            revert Exception(19, 0, 0, address(0), address(0));
        }

        delete withdrawals[e];
        delete fees[e];

        IERC20 token = IERC20(e);
        Safe.transfer(token, admin, token.balanceOf(address(this)));

        return true;
    }

    /// @notice pauses a market and prevents execution of all lending for that market
    /// @param p principal enum value
    /// @param b bool representing whether to pause or unpause
    /// @return bool true if successful
    function pause(uint8 p, bool b) external authorized(admin) returns (bool) {
        paused[p] = b;
        return true;
    }

    /// @notice transfers excess funds to yield pool after principal tokens have been lent out
    /// @dev this method is only used by the yield, illuminate and swivel protocols
    /// @param u address of an underlying asset
    /// @param y the yield pool to lend to
    /// @param a the amount of underlying tokens to lend
    /// @param r the receiving address for PTs
    /// @param p the principal token for the yield pool
    /// @param m the minimum amount to purchase
    /// @return uint256 the amount of tokens sent to the yield pool
    /// TODO there is a problem with the last check ending - starting (m is passed by user)
    function yield(
        address u,
        address y,
        uint256 a,
        address r,
        address p,
        uint256 m
    ) internal returns (uint256) {
        // get the starting balance (to verify receipt of tokens)
        uint256 starting = IERC20(p).balanceOf(r);
        // preview exact swap slippage on yield
        uint128 returned = IYield(y).sellBasePreview(Cast.u128(a));
        // send the remaining amount to the given yield pool
        Safe.transfer(IERC20(u), y, a);
        // lend out the remaining tokens in the yield pool
        IYield(y).sellBase(r, returned);
        // get thee ending balance (must be starting + returned)
        uint256 ending = IERC20(p).balanceOf(r);
        // verify receipt of PTs from yield space pool
        if (ending - starting < m) {
            revert Exception(12, ending, starting, address(0), address(0));
        }

        return returned;
    }

    /// @notice withdraws accumulated lending fees of the underlying token
    /// @param e address of the underlying token to withdraw
    /// @return bool true if successful
    function withdrawFee(address e) external authorized(admin) returns (bool) {
        // Get the token to be withdrawn
        IERC20 token = IERC20(e);

        // Get the balance to be transferred
        uint256 balance = fees[e];

        // Reset accumulated fees of the token to 0
        fees[e] = 0;

        // Transfer the accumulated fees to the admin
        Safe.transfer(token, admin, balance);
        return true;
    }

    /// @notice this method returns the fee based on the amount passed to it. If the feenominator is 0, then there is no fee.
    /// @param a amount of underlying tokens
    /// @return uint256 The total for for the given amount
    function calculateFee(uint256 a) internal view returns (uint256) {
        uint256 feeRate = feenominator;
        return feeRate != 0 ? a / feeRate : 0;
    }

    /// @notice verifies fee amount and collects fee for swivel lend calls
    /// @param f fee that is to be held by the lender contract
    /// @param l the amount, in underlying, that is lent to be lent
    /// @param u the underlying asset
    function swivelCheckFee(
        uint256 f,
        uint256 l,
        address u
    ) internal {
        /// Get the minimum fee expected for this call
        uint256 minFee = calculateFee(l);
        // Verify the minimum fee is provided
        if (f < minFee) {
            revert Exception(14, minFee, f, address(0), address(0));
        }
        // Track accumulated fee
        fees[u] = fees[u] + f;
        // Transfer underlying tokens from user to illuminate
        Safe.transferFrom(IERC20(u), msg.sender, address(this), l + f);
    }

    /// @notice lends the leftover premium to a yieldspace pool
    function swivelLendPremium(
        address u,
        uint256 m,
        address y,
        uint256 p,
        uint256 slippageTolerance
    ) internal {
        // Lend remaining funds to yield pool
        uint256 swapped = yield(
            u,
            y,
            p,
            address(this),
            IMarketPlace(marketPlace).token(u, m, 2),
            slippageTolerance
        );
        // Mint the remaining tokens
        IERC5095(principalToken(u, m)).authMint(msg.sender, swapped);
    }

    /// @notice returns the amount of underlying tokens to be used in a swivel lend
    function swivelAmount(uint256[] memory a) internal pure returns (uint256) {
        uint256 lent;
        // iterate through each order a calculate the total lent and returned
        for (uint256 i; i != a.length; ) {
            {
                uint256 amount = a[i];
                // Sum the total amount lent to Swivel
                lent = lent + amount;
            }
            unchecked {
                ++i;
            }
        }
        return lent;
    }

    /// @notice executes a swap for and verifies receipt of element PTs
    function swapElement(
        address e,
        Element.SingleSwap memory s,
        Element.FundManagement memory f,
        uint256 r,
        uint256 d
    ) internal returns (uint256) {
        // Get the starting balance for the principal
        uint256 starting = IERC20(address(s.assetOut)).balanceOf(address(this));
        // Conduct the swap on element
        uint256 purchased = IElementVault(e).swap(s, f, r, d);
        // Calculate amount of PTs received by executing the swap
        uint256 received = IERC20(address(s.assetOut)).balanceOf(
            address(this)
        ) - starting;
        // Verify that a minimum amount was received
        if (received < r) {
            revert Exception(11, 0, 0, address(0), address(0));
        }
        return purchased;
    }

    /// @notice retrieves the ERC5095 token for the given market
    /// @param u address of the underlying
    /// @param m uint256 representing the maturity of the market
    /// @return address of the ERC5095 token for the market
    function principalToken(address u, uint256 m) internal returns (address) {
        return IMarketPlace(marketPlace).token(u, m, 0);
    }

    /// @notice returns array token path required for APWine's swap method
    /// @return array of uint256[] as laid out in APWine's docs
    function apwineTokenPath() internal pure returns (uint256[] memory) {
        uint256[] memory tokenPath = new uint256[](2);
        tokenPath[0] = 1;
        tokenPath[1] = 0;
        return tokenPath;
    }

    /// @notice returns array pair path required for APWine's swap method
    /// @return array of uint256[] as laid out in APWine's docs
    function apwinePairPath() internal pure returns (uint256[] memory) {
        uint256[] memory pairPath = new uint256[](1);
        pairPath[0] = 0;
        return pairPath;
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'src/tokens/ERC5095.sol';
import 'src/lib/Safe.sol';

import 'src/interfaces/ILender.sol';
import 'src/interfaces/IPool.sol';

import 'src/errors/Exception.sol';

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
    event CreateMarket(address indexed underlying, uint256 indexed maturity);
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

        // Max approve lender spending on the element and apwine contracts
        ILender(lender).approve(u, e, a, t[7]);

        // Max approve converters's ability to convert redeemer's pendle PTs
        IRedeemer(redeemer).approve(t[3]);

        emit CreateMarket(u, m);
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

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

library Swivel {
    // the components of a ECDSA signature
    struct Components {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct Order {
        bytes32 key;
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

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import 'src/interfaces/IAny.sol';

library Element {
    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        IAny assetIn;
        IAny assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }
}

// SPDX-License-Identifier: UNLICENSED
// Adapted from: https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol

pragma solidity ^0.8.13;

import 'src/interfaces/IERC20.sol';

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

/// @dev A single custom error capable of indicating a wide range of detected errors by providing
/// an error code value whose string representation is documented <here>, and any possible other values
/// that are pertinent to the error.
error Exception(uint8, uint256, uint256, address, address);

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'src/interfaces/IERC20Metadata.sol';
import 'src/interfaces/IAny.sol';

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface ITempusAMM {
    function balanceOf(address) external view returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'src/interfaces/IERC20Metadata.sol';

interface ITempusPool {
    function maturityTime() external view returns (uint256);

    function backingToken() external view returns (IERC20Metadata);

    // Used for integration testing
    function principalShare() external view returns (address);

    function currentInterestRate() external view returns (uint256);

    function initialInterestRate() external view returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface ITempusToken {
    function balanceOf(address) external returns (uint256);

    function pool() external view returns (address);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'src/interfaces/IERC2612.sol';

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface ISensePeriphery {
    function swapUnderlyingForPTs(
        address,
        uint256,
        uint256,
        uint256
    ) external returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface ISenseAdapter {
    function underlying() external view returns (address);

    function divider() external view returns (address);

    function target() external view returns (address);

    function maxm() external view returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'src/interfaces/IERC20.sol';

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IYieldToken {
    function redeem(address, uint256) external returns (uint256);

    function underlying() external returns (address);

    function maturity() external returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'src/lib/Swivel.sol';

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IElementToken {
    function unlockTimestamp() external returns (uint256);

    function underlying() external returns (address);

    function withdrawPrincipal(uint256 amount, address destination)
        external
        returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import 'src/lib/Element.sol';

interface IElementVault {
    function swap(
        Element.SingleSwap memory,
        Element.FundManagement memory,
        uint256,
        uint256
    ) external returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IAPWineAMMPool {
    function getUnderlyingOfIBTAddress() external view returns (address);

    function getPTAddress() external view returns (address);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IAPWineRouter {
    function swapExactAmountIn(
        address,
        uint256[] calldata,
        uint256[] calldata,
        uint256,
        uint256,
        address,
        uint256,
        address
    ) external returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IAPWineToken {
    // Todo will be used to get the maturity
    function futureVault() external view returns (address);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IAPWineFutureVault {
    function PERIOD_DURATION() external view returns (uint256);

    function getControllerAddress() external view returns (address);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IAPWineController {
    function getNextPeriodStart(uint256) external view returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'src/interfaces/IERC20.sol';

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IPendleToken {
    function underlyingAsset() external returns (address);

    function underlyingYieldToken() external returns (address);

    function expiry() external returns (uint256);

    function forge() external returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import 'src/tokens/ERC20Permit.sol';
import 'src/interfaces/IERC5095.sol';
import 'src/interfaces/IRedeemer.sol';
import 'src/interfaces/IMarketPlace.sol';
import 'src/interfaces/IYield.sol';
import 'src/errors/Exception.sol';
import 'src/lib/Cast.sol';

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface ILender {
    function approve(
        address,
        address,
        address,
        address
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'src/interfaces/IERC20.sol';
import 'src/interfaces/IERC5095.sol';

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IAny {}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'src/interfaces/IERC20.sol';

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'src/interfaces/IERC20Metadata.sol';

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

// SPDX-License-Identifier: MIT
// Adapted from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/53516bc555a454862470e7860a9b5254db4d00f5/contracts/token/ERC20/ERC20Permit.sol
pragma solidity 0.8.16;

import 'src/tokens/ERC20.sol';
import 'src/interfaces/IERC2612.sol';

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

// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

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

// SPDX-License-Identifier: MIT
// Inspired on token.sol from DappHub. Natspec adpated from OpenZeppelin.
pragma solidity 0.8.16;

import 'src/interfaces/IERC20Metadata.sol';

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