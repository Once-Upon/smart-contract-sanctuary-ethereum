// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./interfaces/IERC721.sol";
import "./interfaces/IAssetTrading.sol";

import "./libraries/Counters.sol";
import "./libraries/Assets.sol";
import "./libraries/SafeERC20.sol";

// Author: @dangvhh
contract AssetTrading is IAssetTrading {

    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    
    Counters.Counter private counterPairActive;

    uint256 public constant PRICE_DECIMAL = 10**6;

    Assets.Pair[] public pairs;

    mapping(address => uint256[]) public pairIdsByOwners; // address owner => uint256[] pairIds

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "AssetTrading: LOCK");
        unlocked = 0;
        _;
        unlocked = 1;
    }
    modifier askIsActive(uint256 id){
        require(id < pairs.length, "AssetTrading: ID_OUT_RANGE");
        require(pairs[id]._is_finished == false, "AssetTrading: ASK_FINISHED");
        _;
    }
    modifier validAmount(uint256 amount) {
        require(amount > 0 && amount % PRICE_DECIMAL == 0, "AssetTrading: INVALID_AMOUNT");
        _;
    }

    event AskCreated(address indexed owner, uint256 indexed id, address assetOut, uint256 valueOut, Assets.Type assetOutType);
    event AskRemoved(address indexed owner, uint256 indexed id, address assetOut, uint256 valueOut, Assets.Type assetOutType);
    event DoBid(address indexed bidder, uint256 indexed id, address AssetBidIn, uint256 valueBidIn);

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4){
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    //TODO: get metadata pair in contract AssetTrading
    function getAllPairActive() external view override returns(Assets.Pair[] memory){
        Assets.Pair[] memory result = new Assets.Pair[](counterPairActive.current());
        uint256 cnt = 0;
        for (uint256 i = 0; i < pairs.length; i++){
            if (pairs[i]._is_finished) {
                continue;
            }
            result[cnt] = pairs[i];
            unchecked {
                cnt++;
            }
        }
        return result;
    }
    function getPairsByOwner(address owner) external view override returns(Assets.Pair[] memory){
        Assets.Pair[] memory result = new Assets.Pair[](pairIdsByOwners[owner].length);
        for (uint256 i = 0; i < pairIdsByOwners[owner].length; i++){
            result[i] = pairs[pairIdsByOwners[owner][i]];        
        }
        return result;
    }
    function getPairById(uint256 id) external view returns(Assets.Pair memory) {
        return pairs[id];
    }
    //TODO: handle logic core function
    function _getPrice(uint256 amountOut, uint256 amountIn) internal pure returns(uint256){
        return amountOut*PRICE_DECIMAL/amountIn;
    }
    function _createAsk(
        address assetOut,
        uint256 amountOut,
        address assetIn,
        uint256 amountIn
        ) internal returns(uint256){
        Assets.Pair memory pair;

        pair._id = pairs.length;

        pair._owner = msg.sender;
        pairIdsByOwners[msg.sender].push(pair._id);

        pair._asset_out._asset_address = assetOut;
        pair._asset_out._amount = amountOut;

        pair._asset_in._asset_address = assetIn;
        pair._asset_in._amount = amountIn;

        pairs.push(pair);
        counterPairActive.increment();

        return pair._id;
    }
    //TODO: handle create ask Tokens to Tokens, ETH, NFTs
    function createAskTokensToTokens(
        address tokenOut,
        uint256 amountOut,
        address tokenIn,
        uint256 amountIn
    ) external lock validAmount(amountOut) validAmount(amountIn) override {
        require(tokenOut != tokenIn, "AssetTrading: IDENTICAL_ADDRESSES");
        uint256 price = _getPrice(amountOut, amountIn);
        require(price > 0, "AssetTrading: INVALID_PRICE"); 

        IERC20(tokenOut).safeTransferFrom(msg.sender, address(this), amountOut);
        uint256 id = _createAsk(tokenOut, amountOut, tokenIn, amountIn);
        
        pairs[id]._price = price;
        pairs[id]._asset_out._type = Assets.Type.ERC20;
        pairs[id]._asset_in._type = Assets.Type.ERC20;

        emit AskCreated(msg.sender, id, tokenOut, amountOut, pairs[id]._asset_out._type);
    }
    function createAskTokensToETH(
        address tokenOut,
        uint256 amountOut,
        uint256 amountIn
    ) external lock validAmount(amountOut) validAmount(amountIn) override {
        uint256 price = _getPrice(amountOut, amountIn);
        require(price > 0, "AssetTrading: INVALID_PRICE");                

        IERC20(tokenOut).safeTransferFrom(msg.sender, address(this), amountOut);
        uint256 id = _createAsk(tokenOut, amountOut, address(0), amountIn);

        pairs[id]._price = price;
        pairs[id]._asset_out._type = Assets.Type.ERC20;
        pairs[id]._asset_in._type = Assets.Type.ETH;

        emit AskCreated(msg.sender, id, tokenOut, amountOut, pairs[id]._asset_out._type);
    }
    function createAskTokensToNFT(address tokenOut, uint256 amountOut, address tokenIn, uint256 tokenIdIn) external lock validAmount(amountOut) override {
        IERC20(tokenOut).safeTransferFrom(msg.sender, address(this), amountOut);
        uint256 id = _createAsk(tokenOut, amountOut, tokenIn, 1);

        pairs[id]._price = amountOut;
        pairs[id]._asset_out._type = Assets.Type.ERC20;
        pairs[id]._asset_in._token_id = tokenIdIn;
        pairs[id]._asset_in._type = Assets.Type.ERC721;

        emit AskCreated(msg.sender, id, tokenOut, amountOut, pairs[id]._asset_out._type);
    }
    
    //TODO: handle create ask ETH to Tokens, NFTs
    function createAskETHToTokens(
        address tokenIn,
        uint256 amountIn
    ) external payable lock validAmount(msg.value) validAmount(amountIn) override {
        uint256 price = _getPrice(msg.value, amountIn);
        require(price > 0, "AssetTrading: INVALID_PRICE");
        
        uint256 id = _createAsk(address(0), msg.value, tokenIn, amountIn);

        pairs[id]._price = price;
        pairs[id]._asset_out._type = Assets.Type.ETH;
        pairs[id]._asset_in._type = Assets.Type.ERC20;

        emit AskCreated(msg.sender, id, address(0), msg.value, pairs[id]._asset_out._type);
    }
    function createAskETHToNFT(address tokenIn, uint256 tokenIdIn) external payable lock validAmount(msg.value) override {
        
        uint256 id = _createAsk(address(0), msg.value, tokenIn, 1);
        
        pairs[id]._price = msg.value;
        pairs[id]._asset_out._type = Assets.Type.ETH;
        pairs[id]._asset_in._token_id = tokenIdIn;
        pairs[id]._asset_in._type = Assets.Type.ERC721;
    
        emit AskCreated(msg.sender, id, address(0), msg.value, pairs[id]._asset_out._type);
    }

    //TODO: handle create ask NFTs to Tokens, ETH, NFTs
    function createAskNFTToTokens(address tokenOut, uint256 tokenIdOut, address tokenIn, uint256 amountIn) external lock validAmount(amountIn) override {

        IERC721(tokenOut).safeTransferFrom(msg.sender, address(this), tokenIdOut);
        uint256 id = _createAsk(tokenOut, 1, tokenIn, amountIn);

        pairs[id]._price = amountIn;
        pairs[id]._asset_out._type = Assets.Type.ERC721;
        pairs[id]._asset_out._token_id = tokenIdOut;
        pairs[id]._asset_in._type = Assets.Type.ERC20;

        
        emit AskCreated(msg.sender, id, tokenOut, tokenIdOut, pairs[id]._asset_out._type);
    }
    function createAskNFTToETH(address tokenOut, uint256 tokenIdOut, uint256 amountIn) external lock validAmount(amountIn) override {

        IERC721(tokenOut).safeTransferFrom(msg.sender, address(this), tokenIdOut);
        uint256 id = _createAsk(tokenOut, 1, address(0), amountIn);

        pairs[id]._price = amountIn;
        pairs[id]._asset_out._type = Assets.Type.ERC721;
        pairs[id]._asset_out._token_id = tokenIdOut;
        pairs[id]._asset_in._type = Assets.Type.ETH;

        emit AskCreated(msg.sender, id, tokenOut, tokenIdOut, pairs[id]._asset_out._type);
    }
    function createAskNFTToNFT(address tokenOut, uint256 tokenIdOut, address tokenIn, uint256 tokenIdIn) external lock override {

        IERC721(tokenOut).safeTransferFrom(msg.sender, address(this), tokenIdOut);
        uint256 id = _createAsk(tokenOut, 1, tokenIn, 1);

        pairs[id]._price = PRICE_DECIMAL;       
        pairs[id]._asset_out._type = Assets.Type.ERC721;
        pairs[id]._asset_out._token_id = tokenIdOut;
        pairs[id]._asset_in._type = Assets.Type.ERC721;
        pairs[id]._asset_in._token_id = tokenIdIn;

        emit AskCreated(msg.sender, id, tokenOut, tokenIdOut, pairs[id]._asset_out._type);
    }

    function removeAsk(uint256 id) external lock askIsActive(id) override {
        address owner = pairs[id]._owner;
        require(owner == msg.sender, "AssetTrading: NOT_ASK_OWNER");
    
        address assetAddress = pairs[id]._asset_out._asset_address;
        uint256 value = pairs[id]._asset_out._amount;
        Assets.Type assetType = pairs[id]._asset_out._type;

        pairs[id]._is_finished = true;
        counterPairActive.decrement();
        
        if (assetType == Assets.Type.ERC721)
        {
            value = pairs[id]._asset_out._token_id;
            IERC721(assetAddress).safeTransferFrom(address(this), owner, value);
        }
        else if (assetType == Assets.Type.ERC20)
        {
            IERC20(assetAddress).safeTransfer(owner, value);
        }else {
            payable(owner).transfer(value);
        }
        emit AskRemoved(msg.sender, id, assetAddress, value, assetType);
    }
    /*
    amountOut*decimals/AmountIn = price => amountOut*decimals = price*amountIn
    =>  amountBidIn = (price*amountBidOut)/decimals
    =>  newAmountOut = amountOut - amountBidIn = amountOut - (price*amountBidIn)/decimals
    => newAmountIn = amountIn - amountBibIn;
     */
    function _getAmountBidIn(uint256 id, uint256 amountBidOut) internal view returns(uint256){
        if (amountBidOut > pairs[id]._asset_in._amount) {
            return pairs[id]._asset_in._amount;
        }else {
            return pairs[id]._price * amountBidOut / PRICE_DECIMAL;
        }
    }
    function _updatePairAfterDoBid(uint256 id, uint256 amountBidOut, uint256 amountBidIn) internal {
        //  Update new amountIn and amountOut in pair
        if (amountBidOut == pairs[id]._asset_in._amount){
            pairs[id]._is_finished = true;
            counterPairActive.decrement();
        }
        pairs[id]._asset_out._amount = pairs[id]._asset_out._amount - amountBidIn;
        pairs[id]._asset_in._amount = pairs[id]._asset_in._amount - amountBidOut;      
    }
    //TODO: handle do bid pair TOKEN, ETH, NFT => TOKEN
    function doBidTokens(uint256 id, uint256 amountBidOut) external lock askIsActive(id) validAmount(amountBidOut) override {
        require(pairs[id]._asset_in._type == Assets.Type.ERC20, "AssetTrading: INVALID_PAIR_ID");
        require(amountBidOut <= pairs[id]._asset_in._amount, "AssetTrading: EXCESSIVE_AMOUNT");
        
        address ownerPair = pairs[id]._owner;
        Assets.Type assetInType = pairs[id]._asset_in._type;
        uint256 amountBidIn = 1;
        
        if (assetInType != Assets.Type.ERC721){
        
            amountBidIn = _getAmountBidIn(id, amountBidOut);
        
            IERC20(pairs[id]._asset_in._asset_address).safeTransferFrom(msg.sender, ownerPair, amountBidOut);

            if (assetInType == Assets.Type.ERC20)
            {
                // PAIR TOKEN => TOKEN
                IERC20(pairs[id]._asset_out._asset_address).safeTransfer(msg.sender, amountBidIn);
            }else {
                // PAIR ETH => TOKEN
                payable(msg.sender).transfer(amountBidIn);
            }
        }else {
            // PAIR NFT => TOKEN
            require(amountBidOut == pairs[id]._asset_in._amount, "AssetTrading: INCORRECT_AMOUNT");
        
            uint256 tokenIdBidIn = pairs[id]._asset_out._token_id;
            IERC20(pairs[id]._asset_in._asset_address).safeTransferFrom(msg.sender, ownerPair, amountBidOut);
            IERC721(pairs[id]._asset_out._asset_address).safeTransferFrom(address(this), msg.sender, tokenIdBidIn);
        }
        _updatePairAfterDoBid(id, amountBidOut, amountBidIn);
        emit DoBid(msg.sender, id, pairs[id]._asset_out._asset_address, amountBidIn);
    }
    //TODO: handle do bid pair TOKEN, NFT => ETH
    function doBidETH(uint256 id) external payable lock askIsActive(id) validAmount(msg.value) override {
        require(pairs[id]._asset_in._type == Assets.Type.ERC20, "AssetTrading: INVALID_PAIR_ID");
        require(msg.value <= pairs[id]._asset_in._amount, "AssetTrading: EXCESSIVE_AMOUNT");
        
        address ownerPair = pairs[id]._owner;
        Assets.Type assetInType = pairs[id]._asset_in._type;
        uint256 amountBidIn = 1;

        if (assetInType == Assets.Type.ERC20){
            // PAIR TOKEN => ETH            
            amountBidIn = _getAmountBidIn(id, msg.value);
        
            payable(ownerPair).transfer(msg.value);
            IERC20(pairs[id]._asset_out._asset_address).safeTransfer(msg.sender, amountBidIn);
        }else {
            // PAIR NFT => ETH
            require(msg.value == pairs[id]._asset_in._amount, "AssetTrading: INCORRECT_AMOUNT");
        
            uint256 tokenIdBidIn = pairs[id]._asset_out._token_id;
            payable(ownerPair).transfer(msg.value);
            IERC721(pairs[id]._asset_out._asset_address).safeTransferFrom(address(this), msg.sender, tokenIdBidIn);
        }
        _updatePairAfterDoBid(id, msg.value, amountBidIn);
        emit DoBid(msg.sender, id, pairs[id]._asset_out._asset_address, amountBidIn);
    }
    //TODO: handle do bid pair NFT => NFT
    function doBidNFT(uint256 id, uint256 tokenIdBidOut) external lock askIsActive(id) override {
        require(pairs[id]._asset_in._type == Assets.Type.ERC20, "AssetTrading: INVALID_PAIR_ID");
        require(tokenIdBidOut == pairs[id]._asset_in._token_id, "AssetTrading: INCORRECT_TOKEN_ID");

        address ownerPair = pairs[id]._owner;
        uint256 tokenIdBidIn = pairs[id]._asset_out._token_id;

        IERC721(pairs[id]._asset_in._asset_address).safeTransferFrom(msg.sender, ownerPair, tokenIdBidOut);        
        IERC721(pairs[id]._asset_out._asset_address).safeTransferFrom(address(this), msg.sender, tokenIdBidIn);

        _updatePairAfterDoBid(id, 1, 1);
        emit DoBid(msg.sender, id, pairs[id]._asset_out._asset_address, tokenIdBidIn);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./IERC721Receiver.sol";
import "./IAssetTradingMetadata.sol";
interface IAssetTrading is IAssetTradingMetadata, IERC721Receiver{
    // Token
    // function depositTokens(address token, uint256 amount) external;
    // function withdrawTokens(address token, uint256 amount) external;
    // ETH
    // function depositETH(uint256 amount) external payable;
    // function withdrawETH(uint256 amount) external;
    // NFT
    // function depositNFT(address token, uint256 tokenId) external;
    // function withdrawNFT(address token, uint256 tokenId) external;
    //TODO: Handle logic core function
    
    // Tokens To
    function createAskTokensToTokens(
        address tokenOut,
        uint256 amountOut,
        address tokenIn,
        uint256 amountIn
    ) external;
    function createAskTokensToETH(
        address tokenOut,
        uint256 amountOut,
        uint256 amountIn
    ) external;
    function createAskTokensToNFT(
        address tokenOut,
        uint256 amountOut,
        address tokenIn,
        uint256 tokenIdIn
    ) external;
    // ETH To
    function createAskETHToTokens(
        address tokenIn,
        uint256 amountIn
    ) external payable;
    function createAskETHToNFT(
        address tokenIn,
        uint256 tokenIdIn
    ) external payable;
    //NFTs To
    function createAskNFTToTokens(
        address tokenOut,
        uint256 tokenIdOut,
        address tokenIn,
        uint256 amountIn
    ) external;
    function createAskNFTToETH(
        address tokenOut,
        uint256 tokenIdOut,
        uint256 amountIn
    ) external;
    function createAskNFTToNFT(
        address tokenOut,
        uint256 tokenIdOut,
        address tokenIn,
        uint256 tokenIdIn
    ) external;


    function removeAsk(uint256 id) external;
    
    // function doBidNotToNFT(uint256 id, uint256 amount) external;
    // function doBidToNFT(uint256 id, uint256 tokenId) external;
    function doBidTokens(uint256 id, uint256 amountBidOut) external;
    function doBidETH(uint256 id) external payable;
    function doBidNFT(uint256 id, uint256 tokenIdBidOut) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../libraries/Assets.sol";

interface IAssetTradingMetadata {
    // function balanceTokenOf(address owner, address token) external view returns(uint256);
    // function balanceETHOf(address owner) external view returns(uint256);
    // function balanceNFTOf(address owner, address token) external view returns(uint256);
    // function tokenIdOf(address token, uint256 tokenId) external view returns(address);
    function getAllPairActive() external view returns(Assets.Pair[] memory);
    function getPairsByOwner(address owner) external view returns(Assets.Pair[] memory);
    function getPairById(uint256 id) external view returns(Assets.Pair memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;


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
pragma solidity >=0.7.0 <0.9.0;


interface IERC20 {

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./IERC165.sol";

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

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
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// import "./Strings.sol";

library Assets {
    // using Strings for *;
    enum Type {
        ETH,
        ERC20,
        ERC721
    }
    struct Detail {
        address _asset_address;
        uint256 _amount;
        uint256 _token_id;
        Type _type;
    }
    struct Pair {
        uint256 _id;
        address _owner;
        uint256 _price;
        Detail _asset_out;
        Detail _asset_in;
        bool _is_finished;
    }
    
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "./Address.sol";

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

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    // function safePermit(
    //     IERC20Permit token,
    //     address owner,
    //     address spender,
    //     uint256 value,
    //     uint256 deadline,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) internal {
    //     uint256 nonceBefore = token.nonces(owner);
    //     token.permit(owner, spender, value, deadline, v, r, s);
    //     uint256 nonceAfter = token.nonces(owner);
    //     require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    // }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}