/// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../interfaces/IBonds.sol";

import {IERC20PaymentStandard} from "../interfaces/newInterfaces/payment/IERC20PaymentStandard.sol";
import {ONE_HUNDRED_PERCENT} from "../Globals.sol";
import {Errors} from "../libraries/Errors.sol";

/**
 * @title Bonds
 * @author Carson Case
 * @notice Bonds mints ERC1155 tokens that represent ownership of a loan specified by a Payment Contract. These bonds can accrue interest and be exchanged for payments made in the payment contract
 */
contract Bonds is ERC1155, IBonds {
    using ECDSA for bytes32;

    //Stores ID-> payment contract relationships
    mapping(uint256 => address) public override IDToContract;

    /// @notice A linked list is used to keep track of staking for each user. This is so we can delete (ustake) nodes in constant time while still being able to itterate easily
    /// @dev may one day use this in payment standard as well to itterate through loans per person.
    //Data held per person to keep track of staking
    struct IOU {
        uint256 ID;
        uint256 amount;
        uint256 timeStaked;
    }

    //Node for a linked list
    struct node {
        uint256 last;
        uint256 next;
        IOU value;
    }

    //In the linked list the head is always 0. Head actually represents null. There will never be a value stored there
    uint256 public constant override head = 0;

    //Used to keep track of this info for each user's linked list of staking data
    mapping(address => uint256) public override llTail;

    /// @notice this is the staking linked list. Access the node to find the next/last.The 0 node is the HEAD and cannot hold values. If HEAD points to
    /// itself then it's empty
    mapping(address => mapping(uint256 => node)) staking;

    //Constructor. Empty for now except the metadata url
    constructor() ERC1155("https://test.com/api/{id}.json") {}

    /**
     * @notice Staking mapping is no longer public. Must call this to get staking info
     * @param _who is address in first mapping
     * @param _index is LL index in nested mapping
     * @return the Linked List Node last pointer
     * @return the Linked List Node next pointer
     * @return the IOU struct Loan ID value
     * @return the IOU struct amount value
     * @return the IOU struct timestamp for staking
     * in that order
     */
    function getStakingAt(address _who, uint256 _index)
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        node memory n = staking[_who][_index];
        return (n.last, n.next, n.value.ID, n.value.amount, n.value.timeStaked);
    }

    /**
     * @notice function creates the tokens for a new loan so they can be sold to generate funding
     * @param _paymentContractAddress is the address of the loan's contract. "Borrower" in this
     * @param _id is the ID of the loan you're minting
     * @param _hash is the hash of the previous two parameters in order
     * @param _signature is the signature of that data. Must be signed by the borrower
     *
     * NOTE: the check to make sure the data provided matches the hash provided is commented out.
     *   THIS IS FOR TESTING ONLY. And only because of the limitations brought about by RemixIDE. this is
     *   100% necessary for production and will need to be re-included when messages can be signed with the
     *   correct encoding
     *
     */
    function newLoan(
        address _paymentContractAddress,
        uint256 _id,
        bytes32 _hash,
        bytes memory _signature
    ) external override {
        // compute the hash of the data and verify it matches the hash provided

        require(
            keccak256(abi.encode(_paymentContractAddress, _id)) == _hash,
            Errors.BONDS_HASH_AND_ENCODING
        );
        //
        // use the signature to recover the user who signed this message
        address user = _hash.toEthSignedMessageHash().recover(_signature);

        IERC20PaymentStandard pc = IERC20PaymentStandard(
            _paymentContractAddress
        );
        uint256 amm;
        address creator;
        (amm, creator) = pc.issueBonds(_id);
        require(
            user == creator,
            Errors.BONDS_BORROWER_SIGNATURE
        );
        IDToContract[_id] = _paymentContractAddress;
        _mint(msg.sender, _id, amm, ""); // Mints to sender not creator. Since we have this signature feature so bonds can be minted on someone elses behalf
    }

    /**
     * @notice function stakes an amount of ERC-1155's with id from sender. MUST Approve contract first
     * @param _id is the token's id
     * @param _amm is the amount to stake
     */
    function stake(uint256 _id, uint256 _amm)
        external
        override
        returns (uint256)
    {
        safeTransferFrom(msg.sender, address(this), _id, _amm, "");
        _push(IOU(_id, _amm, block.timestamp), msg.sender);
        return llTail[msg.sender];
    }

    /**
     * @notice function unstakes bonds
     * @param _index is the index in the linked list mentioned above with state varaibles
     * @return if successful. May not be if loan has been completed since staking
     */
    function unstake(uint256 _index) external override returns (bool) {
        require(!_isEmpty(msg.sender), Errors.BONDS_NOT_STACKING);
        //Get some important variables
        uint256 id = staking[msg.sender][_index].value.ID;
        uint256 amm = staking[msg.sender][_index].value.amount;
        address paymentContract = IDToContract[id];

        // must get amout to mint BEFORE you _del the staking
        IERC20PaymentStandard pc = IERC20PaymentStandard(paymentContract);
        uint256 interest = pc.loanLookup(id).interestRate;
        uint256 toMint = getInterest(msg.sender, _index, amm, interest);
        
        //Remove staking from the ll
        _del(_index, msg.sender);

        bool r; //Store return so we can call other contract before mint funciton. Don't want callback attacks
        //Update the balance with new interest. Store return value based on response.
        if (pc.addInterest(toMint, id)) {
            r = true;
        } else {
            r = false;
        }
        _safeTransferFrom(address(this), msg.sender, id, amm, "");
        _mint(msg.sender, id, toMint, "");
        return r;
    }

    /**
     * @dev getter function for a loan's interest
     */
    function getInterest(
        address _staker,
        uint256 _index,
        uint256 _stakingAmount,
        uint256 _interest
    ) public view override returns (uint256) {
        uint256 periodsStaked = getAccruances(_staker, _index);
        return (periodsStaked *
            ((_stakingAmount * _interest) / ONE_HUNDRED_PERCENT));
    }

    /**
     * @notice function get's how many accruance periods a person has staked through
     * @param _who is who to check
     * @param _index in the linked list
     * @return the number of periods
     */
    function getAccruances(address _who, uint256 _index)
        public
        view
        override
        returns (uint256)
    {
        IOU memory iou = staking[_who][_index].value;
        require(iou.ID != 0, Errors.BONDS_NOT_STACKING_INDEX);
        address paymentContract = IDToContract[iou.ID];
        IERC20PaymentStandard pc = IERC20PaymentStandard(paymentContract);
        uint256 accrualPeriod = pc.loanLookup(iou.ID).accrualPeriod;
        return ((block.timestamp - iou.timeStaked) / accrualPeriod);
    }

    /// @notice ERC1155 receiver function
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /// @notice ERC1155 batch receiver function
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /*=============================================================
    *LINKED LIST FUNCTIONS
    *BELLOW
    ==============================================================*/

    /**
     * @notice helper function
     * @param _who to lookup the linked list of
     * @return if ll is empty
     */
    function _isEmpty(address _who) private view returns (bool) {
        return (staking[_who][head].next == 0);
    }

    /** @notice push to tail of linkedList
     * @param _val is the value to insert at tail
     * @param _who is who to push in ll mapping
     */
    function _push(IOU memory _val, address _who) private {
        uint256 tail = llTail[_who];
        if (_isEmpty(_who)) {
            staking[_who][head].next = 1;
            staking[_who][1] = node(0, 0, _val);
            llTail[_who] = 1;
        } else {
            staking[_who][tail].next = tail + 1;
            staking[_who][tail + 1] = node(tail, 0, _val);
            llTail[_who]++;
        }
    }

    /** @notice delete at a given index
     * @param _index is the pointer to the node
     * @param _who is who in ll mapping
     */
    function _del(uint256 _index, address _who) private {
        uint256 tail = llTail[_who];
        require(_index != head, Errors.BONDS_DELETE_HEAD);
        if (_index == tail) {
            llTail[_who] = staking[_who][tail].last;
        }
        uint256 a = staking[_who][_index].last;
        uint256 b = staking[_who][_index].next;
        staking[_who][a].next = staking[_who][_index].next;
        staking[_who][b].last = staking[_who][_index].last;

        staking[msg.sender][_index].value = IOU(0, 0, 0);
        staking[msg.sender][_index].next = 0;
        staking[msg.sender][_index].last = 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155.sol";
import "./IERC1155Receiver.sol";
import "./extensions/IERC1155MetadataURI.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    /**
     * @dev Hook that is called after any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

/// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IBonds is IERC1155{
    function IDToContract(uint256) external returns(address);

    function head() external returns(uint256);

    function llTail(address) external returns(uint256);
    
    function getStakingAt(address, uint256) external view returns(uint, uint, uint256, uint256, uint256);

    function newLoan(address, uint256, bytes32, bytes memory) external;
    
    function stake(uint256, uint256) external returns(uint);

    function unstake(uint256) external returns(bool);    

    function getAccruances(address, uint256) external view returns(uint256);

    function getInterest(address, uint256, uint256, uint256) external view returns(uint256);

}

/// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import {IAddressBook} from "../../IAddressBook.sol";
import "../../../libraries/Loan.sol";
import {IVersion} from "../../../Version/IVersion.sol";

/**
 * @title IERC20PaymentStandard
 * @author Carson Case
 * @dev
 * Payment Standard is meant to be the bare minimum of payment logic required to interact with Bonds 
 * and the rest of the ecosystem. 
 * Payment contract should only have logic for starting loans (configure and issue), 
 * making payments, collecting interest, and retrieving getting loan info.
 *
 * There should also only be **one** Payment contract. The key difference here for Payment Standard is that it is no 
 * longer unique to each investor. And instead will share it’s logic with all of them. 
 * Payment Standard also should be marked abstract enforcing that it is inherited by it’s child.
 * This means removing all the limits logic and moving it to a child contract like collateral or a specific RociPayment contract.
 */
 
interface IERC20PaymentStandard is IVersion {
    // NOTE 154 Bonds.sol 
    // (uint256 interest, ) = pc.getLoanInfo(id);
    // this function is removed. Use loanLookup in Bonds

    // ---------------
    // State Variables
    // ---------------
    function MAXIMUM_BORROW_LIMIT() external returns(uint);
    
    // note addresses are replaced with address book
    // enum is the index in the array returned by addressBook's function
    enum addresses_Payment{
        bondContract,
        NFCS
    }

    function investorsAddressLookupCategory() external returns(string memory);

    // Two mappings. One to get the loans for a user. And the other to get the the loans based off id
    
    // note these are removed as they're mappings and mess with the inheritance. If needed replace with getter functions
    function loanLookup(uint _id) external view returns(Loan.loan memory);
    // function loanIDs(address) external returns(uint[] memory);


    /**
     * @notice called when bonds are issued so as to make sure lender can only mint bonds once.
     * @param _id loan ID
     * @return the loan principal (so bonds knows how many NFTs to mint)
     * @return the borrowers address (so bonds can make sure borrower is calling this function)
     */
    function issueBonds(uint256 _id)
        external
        returns (uint256, address);

    /**
     * @notice gets the number of loans a person has
     * @param _who is who to look up
     * @return length
     */
    function getNumberOfLoans(address _who)
        external
        view
        returns (uint256);

    /**
     * @notice Called each time new NFTs are minted by staking
     * @param _am the amount of interest to add
     * @param _id is the id of the loan
     * @return true if added. Will not add interest if payment has been completed.
     *This prevents lenders from refusing to end a loan when it is rightfully over by forever
     *increasing the totalPaymentsValue through interest staking and never fully collecting payment.
     *This also means that if lenders do not realize interest gains soon enough they may not be able to collect them before
     *the borrower can complete the loan.
     */
    function addInterest(uint256 _am, uint256 _id)
        external
        returns (bool);


    /**
     * @param _id is the hash id of the loan. Same as bond ERC1155 ID as well
     * @return if delinquent or not. Meaning missed a payment
     */
    function missedPayment(uint256 _id) external view returns (bool);

    /**
     * @notice contract must be configured before bonds are issued. Pushes new loan to array for user
     * @param _erc20 is the ERC20 contract address that will be used for payments
     * @param _borrower is the borrower loan is being configured for. Keep in mind. ONLY this borrower can mint bonds to start the loan
     * @param _NFCSID is the user's NFCS NFT ID from Roci's Credit scoring system
     * @param _minPayment is the minimum payment that must be made before the payment period ends
     * @param _maturityDate payment must be made by this time or delinquent function will return true
     * @param _principal the origional loan value before interest
     * @param _interestRate the interest rate expressed as inverse. 2% = 1/5 = inverse of 5
     * @param _accrualPeriod the time it takes for interest to accrue in seconds
     * @return the id it just created
     */
    function configureNew(
        address _erc20,
        address _borrower,
        uint256 _minPayment,
        uint256 _NFCSID,
        uint256 _maturityDate,
        uint256 _principal,
        uint256 _interestRate,
        uint256 _accrualPeriod
    ) external returns (uint256);

    /**
     * @notice MUST approve this contract to spend your ERC1155s in bonds. Used to have this auto handled by the on received function.
     * However that was not a good idea as a hacker could create fake bonds.
     * @param _id is the id of the bond to send in
     * @param _amm is the amount to send
     * @param _receiver is the receiver of erc20 tokens
     */
    function withdrawl(
        uint256 _id,
        uint256 _amm,
        address _receiver
    ) external;

    /**
     * @notice function handles the payment of the loan. Does not have to be borrower
     *as payment comes in. The contract holds it until collection by bond owners. MUST APPROVE FIRST in ERC20 contract first
     * @param _id to pay off
     * @param _erc20Amount is amount in loan's ERC20 to pay
     */
    function payment(uint256 _id, uint256 _erc20Amount, string memory version)
        external;

    /**
     * @notice helper function
     * @param _id of loan to check
     * @return return if the contract is payed off or not as bool
     */
    function isComplete(uint256 _id) external view returns (bool);

    /**
     * @notice Returns the ID for a loan given the borrower and index in the array
     * @param _borrower is borrower
     * @param _index is the index in the borrowers loan array
     * @return the loan ID
     */
    //
    function getId(address _borrower, uint256 _index)
        external
        view
        returns (uint256);

    /**
    * @dev function to get a user's total outstanding balance (By NFCS ID)  
    * @param _nfcsId NFCS ID
    * @return total Oustanding balance
    */
    function getNFCSTotalOutstanding(uint _nfcsId) external view returns(uint);


    /**
    * @dev function to get a user's total outstanding balance (By NFCS ID)  
    * @param _nfcsId NFCS ID
    * @return total Oustanding balance
    */
    function getUserTotalOutstanding(uint _nfcsId) external view returns(uint);

 /**
    * @dev function to get a system total outstanding balance  
    * @return total Oustanding balance
    */
    function getTotalOutstanding() external view returns(uint);

}

// SPDX-License-Identifier: None
pragma solidity ^0.8.4;
uint constant ONE_HUNDRED_PERCENT = 100 ether;      // NOTE This CAN NOT exceed 2^256/2 -1 as type casting to int occurs

uint constant ONE_YEAR = 31556926;
uint constant ONE_DAY = 60*60*24;
uint constant APY_CONST = 3000000000 gwei;

uint8 constant CONTRACT_DECIMALS = 18;

address constant DEAD = 0x000000000000000000000000000000000000dEaD;

// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @author Konstantin Samarin
 * @notice Defines the error messages emitted by the different contracts of the RociFi protocol
 * @dev Error messages prefix glossary:
 *  - NFCS = NFCS
 *  - BONDS = Bonds
 *  - INVESTOR = Investor
 *  - POOL_INVESTOR = PoolInvestor
 *  - SCORE_DB = ScoreConfigs, ScoreDB
 *  - PAYMENT = ERC20CollateralPayment, ERC20PaymentStandard, RociPayment
 *  - PRICE_FEED = PriceFeed
 *  - REVENUE = PaymentSplitter, RevenueManager
 *  - LOAN = Loan 
 *  - VERSION = Version
 */
library Errors {
  string public constant NFCS_TOKEN_MINTED = '0'; //  Token already minted
  string public constant NFCS_TOKEN_NOT_MINTED = '1'; //  No token minted for address
  string public constant NFCS_ADDRESS_BUNDLED = '2';  // Address already bundled
  string public constant NFCS_WALLET_VERIFICATION_FAILED = '3'; //  Wallet verification failed
  string public constant NFCS_NONEXISTENT_TOKEN = '4';  // Nonexistent NFCS token
  string public constant NFCS_TOKEN_HAS_BUNDLE = '5'; //  Token already has an associated bundle
  string public constant NFCS_TOKEN_HAS_NOT_BUNDLE = '6'; //  Token does not have an associated bundle

  string public constant BONDS_HASH_AND_ENCODING = '100'; //  Hash of data signed must be the paymentContractAddress and id encoded in that order
  string public constant BONDS_BORROWER_SIGNATURE = '101';  // Data provided must be signed by the borrower
  string public constant BONDS_NOT_STACKING = '102'; //  Not staking any NFTs
  string public constant BONDS_NOT_STACKING_INDEX = '103'; //  Not staking any tokens at this index
  string public constant BONDS_DELETE_HEAD = '104';  // Cannot delete the head

  string public constant INVESTOR_ISSUE_BONDS = '200'; //  Issue minting bonds
  string public constant INVESTOR_INSUFFICIENT_AMOUNT = '201'; //  Cannot borrow an amount of 0
  string public constant INVESTOR_BORROW_WITH_ANOTHER_SCORE = '202'; //  Cannot borrow if there is active loans with different score

  string public constant POOL_INVESTOR_INTEREST_RATE = '300';  // Interest rate has to be greater than zero
  string public constant POOL_INVESTOR_ZERO_POOL_VALUE = '301';  // Pool value is zero
  string public constant POOL_INVESTOR_ZERO_TOTAL_SUPPLY = '302';  // Total supply is zero
  string public constant POOL_INVESTOR_BONDS_LOST = '303';  // Bonds were lost in unstaking
  string public constant POOL_INVESTOR_NOT_ENOUGH_FUNDS = '304';  // Not enough funds to fulfill the loan

  string public constant MANAGER_COLLATERAL_NOT_ACCEPTED = '400';  // Collateral is not accepted
  string public constant MANAGER_COLLATERAL_INCREASE = '401';  // When increasing collateral, the same ERC20 address should be used
  string public constant MANAGER_ZERO_WITHDRAW = '402';  // Cannot withdrawal zero
  string public constant MANAGER_EXCEEDING_WITHDRAW = '403';  // Requested withdrawal amount is too large

  string public constant SCORE_DB_EQUAL_LENGTH = '501';  // Arrays must be of equal length
  string public constant SCORE_DB_VERIFICATION = '502';  // Unverified score
  string public constant SCORE_DB_SCORE_NOT_GENERATED= '503';  // Score not yet generated.
  string public constant SCORE_DB_SCORE_GENERATING = '504';  // Error generating score.
  string public constant SCORE_DB_UNKNOW_FETCHING_SCORE = '505';  //  Unknown error fetching score.


  string public constant PAYMENT_NFCS_OUTDATED = '600';  // Outdated NFCS score outdated
  string public constant PAYMENT_ZERO_LTV = '601';  // LTV cannot be zero
  string public constant PAYMENT_NOT_ENOUGH_COLLATERAL = '602';  // Not enough collateral to issue a loan
  string public constant PAYMENT_NO_BONDS = '603';  // There is no bonds to liquidate a loan
  string public constant PAYMENT_FULFILLED = '604';  // Contract is paid off
  string public constant PAYMENT_NFCS_OWNERSHIP = '605';  // NFCS ID must belong to the borrower
  string public constant PAYMENT_NON_ISSUED_LOAN = '606';  // Loan has not been issued
  string public constant PAYMENT_WITHDRAWAL_COLLECTION = '607';  // There are not enough payments available for collection
  string public constant PAYMENT_LOAN_NOT_DELINQUENT = '608';  // Loan not delinquent
  string public constant PAYMENT_AMOUNT_TOO_LARGE = '609';  // Payment amount is too large
  string public constant PAYMENT_CLAIM_COLLATERAL = '610';  // Cannot claim collateral if this collateral is necessary for any non Closed/Liquidated loan's delinquency status

  string public constant PRICE_FEED_TOKEN_NOT_SUPPORTED = '700';  // Token is not supported
  
  string public constant REVENUE_ADDRESS_TO_SHARE = '800';  // Non-equal length of addresses and shares
  string public constant REVENUE_UNIQUE_INDEXES = '801';  // Indexes in an array must not be duplicate
  string public constant REVENUE_FAILED_ETHER_TX = '802';  // Failed to send Ether
  string public constant REVENUE_UNVERIFIED_INVESTOR = '803';  // Only verified investors may request funds or make a payment
  string public constant REVENUE_NOT_ENOUGH_FUNDS = '804';  // Not enough funds to complete this request

  string public constant LOAN_MIN_PAYMENT = '900';  // Minimal payment should be made
  string public constant LOAN_DAILY_LIMIT = '901';  // Exceeds daily borrow limit
  string public constant LOAN_DAILY_LIMIT_USER = '902';  // Exceeds user daily borrow limit
  string public constant LOAN_TOTAL_LIMIT_USER = '903';  // Exceeds user total borrow limit
  string public constant LOAN_TOTAL_LIMIT = '904';  // Exceeds total borrow limit
  string public constant LOAN_CONFIGURATION = '905';  // Loan that is already issued, or not configured cannot be issued
  string public constant LOAN_TOTAL_LIMIT_NFCS = '906';  // Exceeds total nfcs borrow limit
  string public constant LOAN_DAILY_LIMIT_NFCS = '907';  // Exceeds daily nfcs borrow limit

  string public constant VERSION = '1000';  // Incorrect version of contract

   
  string public constant ADDRESS_BOOK_SET_MIN_SCORE = '1100';  // New min score must be less then maxScore
  string public constant ADDRESS_BOOK_SET_MAX_SCORE = '1101';  // New max score must be more then minScore
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

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

/// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

interface IAddressBook{
    function addressList(string memory _category) external view returns(address[] memory);
    function dailyLimit() external  view returns (uint128);
    function globalLimit() external view returns (uint128);
    function setDailyLimit(uint128 newLimit) external;
    function setGlobalLimit(uint128 newLimit) external;
    function getMaturityDate() external view returns (uint256);
    function setLoanDuration(uint256 _newLoanDuration) external;

    function userDailyLimit() external  view returns (uint128);
    function userGlobalLimit() external view returns (uint128);
    function setUserDailyLimit(uint128 newLimit) external;
    function setUserGlobalLimit(uint128 newLimit) external;


    function globalNFCSLimit(uint _nfcsId) external view  returns (uint128);
    function setGlobalNFCSLimit(uint _nfcsId, uint128 newLimit) external;



    function latePenalty() external  view returns (uint);
    function scoreValidityPeriod() external view returns (uint);
    function setLatePenalty(uint newPenalty) external;
    function setScoreValidityPeriod(uint newValidityPeriod) external;

    function minScore() external  view returns (uint16);
    function maxScore() external view returns (uint16);
    function setMinScore(uint16 newScore) external;
    function setMaxScore(uint16 newScore) external;

    function notGenerated() external  view returns (uint16);
    function generationError() external view returns (uint16);
    function setNotGenerated(uint16 newValue) external;
    function setGenerationError(uint16 newValue) external;

    function penaltyAPYMultiplier() external  view returns (uint8);
    function gracePeriod() external view returns (uint128);
    function setPenaltyAPYMultiplier(uint8 newMultiplier) external;
    function setGracePeriod(uint128 newPeriod) external;
}

/// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import {ONE_DAY} from "../Globals.sol";
import {Errors} from "../libraries/Errors.sol";
/**
* @title Loan
* @author Carson Case
* @dev Library to abstract out edits to Loan object to help with global variable tracking
    NOTE
    In this library the function paramaters may seem confusing
    This is because there are special global/local instances of these loan objects

    _ln is an individual loan
    _user is a user's global amount in this payment contract
    _global is the payment contracts total sums
 */
library Loan{
   
    //Loan object. Stores lots of info about each loan
    enum Status{UNISSUED, NEW, APPROVED, PAIDPART, CLOSED, PAIDLATE, LIQUIDATED}
    struct loan {
        Status status;
        address ERC20Address;
        address borrower;
        uint256 nfcsID;
        uint256 maturityDate;
        uint128 issueDate;
        uint256 minPayment;
        uint256 interestRate;
        uint256 accrualPeriod;
        uint256 principal;
        uint256 totalPaymentsValue;
        uint256 awaitingCollection;
        uint256 paymentComplete;
        uint256 ltv;
        uint256 lt;
        uint16 score;
    }

    struct globalInfo{
        uint256 principal;
        uint256 totalPaymentsValue;
        uint256 awaitingCollection;
        uint256 paymentComplete;
        uint128 borrowedToday;
        uint128 lastBorrowTimestamp;
    }


    /**
    * @dev onPayment function to check and handle updates to struct for payments
    * @param _ln individual loan
    * @param _user global loan for user
    * @param _global global loan for the whole contract
     */
    function onPayment(loan storage _ln, globalInfo storage _user, globalInfo storage _global, globalInfo storage _nfcs, uint _erc20Amount) internal{
        require(
            _erc20Amount >= _ln.minPayment || //Payment must be more than min payment
                (
                getOutstanding(_ln) < _ln.minPayment  //Exception for the last payment (remainder)
                &&
                _erc20Amount >= getOutstanding(_ln)  // Exception is only valid if user is paying the loan off in full on this transaction
                ),
            Errors.LOAN_MIN_PAYMENT
        );

        _ln.awaitingCollection += _erc20Amount;
        _user.awaitingCollection += _erc20Amount;
        _global.awaitingCollection += _erc20Amount;
        _nfcs.awaitingCollection += _erc20Amount;


        _ln.paymentComplete += _erc20Amount; //Increase paymentComplete
        _user.paymentComplete += _erc20Amount;
        _global.paymentComplete += _erc20Amount;
        _nfcs.paymentComplete += _erc20Amount;

        // do a status update for anything payment dependant
        if(isComplete(_ln) && _ln.status != Status.LIQUIDATED){
            _ln.status = Status.CLOSED;
        }else if(_erc20Amount > 0 && !isLate(_ln)){
            _ln.status = Status.PAIDPART;
        } else if(isLate(_ln)){
            _ln.status = Status.PAIDLATE;
        }

        _updateLoanDay(_user);
        _updateLoanDay(_global);
    }

    function onWithdrawal(loan storage _ln, globalInfo storage _user, globalInfo storage _global, globalInfo storage _nfcs, uint _erc20Amount) internal{
        _ln.awaitingCollection -= _erc20Amount;
        _user.awaitingCollection -= _erc20Amount;
        _global.awaitingCollection -= _erc20Amount;
        _nfcs.awaitingCollection -= _erc20Amount;
    }

    function onLiquidate(loan storage _ln) internal{
        _ln.status = Status.LIQUIDATED;
    }


    function limitGlobalCheck(uint _totalOutstanding,  uint128  _limit,  string memory exeption) pure internal{
        if(_limit != 0) {
            require(_totalOutstanding <= _limit, exeption);
        }
    }        


    function limitDailyCheck(loan storage _ln, globalInfo storage _limitInfo, uint128  _limit, string memory exeption) internal{
        if(_limit != 0) {
            _updateLoanDay(_limitInfo);
            // Ensure that amount borrowed in last 24h + current borrow amount is less than the 24 limit for this user
            require(_limitInfo.borrowedToday + _ln.principal <= _limit, exeption);
            // Increase 24 limit by amount borrowed
            _limitInfo.borrowedToday += uint128(_ln.principal);
        }
    }


    /**
    * @dev function increases the total payment value on the loan for interest accrual
    * @param _ln individual loan
    * @param _user global loan for user
    * @param _global global loan for the whole contract
     */

    function increaseTotalPaymentsValue(loan storage _ln, globalInfo storage _user, globalInfo storage _global, globalInfo storage _nfcs, uint _am, uint penaltyAPYMultiplier) internal{
        // if loan is late we give an APR multiplier
        if(isLate(_ln)){
            _ln.interestRate = _ln.interestRate * penaltyAPYMultiplier;
        }

        _ln.totalPaymentsValue += _am;
        _user.totalPaymentsValue += _am;
        _global.totalPaymentsValue += _am;
        _nfcs.totalPaymentsValue += _am;

    }

    /// @dev function to issue a loan
    function issue(loan storage _ln, globalInfo storage _user, globalInfo storage _global, globalInfo storage _nfcs) internal{
        require(
            _ln.status == Status.NEW,
            Errors.LOAN_CONFIGURATION
        );

        _ln.status = Status.APPROVED;
        _ln.issueDate = uint128(block.timestamp);

        _user.principal += _ln.principal;
        _user.totalPaymentsValue += _ln.totalPaymentsValue;
        _user.awaitingCollection += _ln.awaitingCollection;
        _user.paymentComplete += _ln.paymentComplete;

        _global.principal += _ln.principal;
        _global.totalPaymentsValue += _ln.totalPaymentsValue;
        _global.awaitingCollection += _ln.awaitingCollection;
        _global.paymentComplete += _ln.paymentComplete;

        _nfcs.principal += _ln.principal;
        _nfcs.totalPaymentsValue += _ln.totalPaymentsValue;
        _nfcs.awaitingCollection += _ln.awaitingCollection;
        _nfcs.paymentComplete += _ln.paymentComplete;

    }

    /// @dev helper function returns if loan is complete
    function isComplete(loan storage _ln) internal view returns (bool) {
        return
            _ln.paymentComplete >=
            _ln.totalPaymentsValue;
    }

    /// @dev function returns if loan is late
    function isLate(loan storage _ln) internal view returns (bool) {
        return (block.timestamp >= _ln.maturityDate);
    }

    function getOutstanding(loan memory _ln) internal pure returns(uint){
        if(_ln.paymentComplete > _ln.totalPaymentsValue){
            return 0;
        }
        return(_ln.totalPaymentsValue - _ln.paymentComplete);
    }
    function getOutstanding(globalInfo memory _global) internal pure returns(uint){
        if(_global.paymentComplete > _global.totalPaymentsValue){
            return 0;
        }
        return(_global.totalPaymentsValue - _global.paymentComplete);
    }
    function _updateLoanDay(globalInfo storage _user) private{
        // If current time - last borrow time = is greater than 24 hours
        if((block.timestamp - _user.lastBorrowTimestamp) >= ONE_DAY){
            // then reset daily limit
            _user.borrowedToday = 0;
        }
        // Set lastBorrowedTimestamp for this user to now
        _user.lastBorrowTimestamp = uint128(block.timestamp);
    }


}

/// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

/// @title  Interface for implementing versioning of contracts
/// @author Konstantin Samarin
/// @notice Used to mark backwards-incompatible changes to the contract logic.
///         All interfaces of versioned contracts should inherit this interface

interface IVersion {
    /**
     * @notice returns the current version of the contract
     */
    function currentVersion() external pure returns(string memory);

    /**
     * @notice converts string to bytes32
     */
    function getVersionAsBytes(string memory v) external pure returns (bytes32 result);
}