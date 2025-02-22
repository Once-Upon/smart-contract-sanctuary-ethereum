// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IDSLContext } from './interfaces/IDSLContext.sol';
import { IParser } from './interfaces/IParser.sol';
import { IStorageUniversal } from './interfaces/IStorageUniversal.sol';
import { ComparisonOpcodes } from './libs/opcodes/ComparisonOpcodes.sol';
import { BranchingOpcodes } from './libs/opcodes/BranchingOpcodes.sol';
import { LogicalOpcodes } from './libs/opcodes/LogicalOpcodes.sol';
import { OtherOpcodes } from './libs/opcodes/OtherOpcodes.sol';
import { ErrorsContext } from './libs/Errors.sol';

// import 'hardhat/console.sol';

/**
 * @dev Context of DSL code
 *
 * One of the core contracts of the project. It contains opcodes and aliases for commands.
 * During creating Context contract executes the `initOpcodes` function that provides
 * basic working opcodes
 */
contract DSLContext is IDSLContext {
    address public comparisonOpcodes; // an address for ComparisonOpcodes library, can be changed
    address public branchingOpcodes; // an address for BranchingOpcodes library, can be changed
    address public logicalOpcodes; // an address for LogicalOpcodes library (AND, OR, XOR), can be changed
    address public otherOpcodes; // an address for OtherOpcodes library, can be changed

    mapping(string => bytes1) public opCodeByName; // name => opcode (hex)
    mapping(bytes1 => bytes4) public selectorByOpcode; // opcode (hex) => selector (hex)
    mapping(string => uint8) public numOfArgsByOpcode; // opcode name => number of arguments
    mapping(string => bool) public isCommand; // opcode name => is opcode a command (command = !(math operator))
    // emun OpcodeLibNames {...} from IContext
    // Depending on the hex value, it will take the proper
    // library from the OpcodeLibNames enum check the library for each opcode
    // where the opcode adds to the Context contract
    mapping(bytes1 => OpcodeLibNames) public opcodeLibNameByOpcode;
    // if the command is complex and uses `asm functions` then it will store
    // the selector of the usage function from the Parser for that opcode.
    // Each opcode that was added to the context should contain the selector otherwise
    // it should be set by 0x0
    mapping(string => bytes4) public asmSelectors; // command => selector
    mapping(string => uint256) public opsPriors; // stores the priority for operators
    string[] public operators;
    // baseOpName -> branchCode -> selector
    mapping(string => mapping(bytes1 => bytes4)) public branchSelectors;
    // baseOpName -> branchName -> branchCode
    mapping(string => mapping(string => bytes1)) public branchCodes;
    // alias -> base command
    mapping(string => string) public aliases;

    modifier nonZeroAddress(address _addr) {
        require(_addr != address(0), ErrorsContext.CTX1);
        _;
    }

    constructor(
        address _comparisonOpcodes,
        address _branchingOpcodes,
        address _logicalOpcodes,
        address _otherOpcodes
    ) {
        require(
            _comparisonOpcodes != address(0) &&
                _branchingOpcodes != address(0) &&
                _logicalOpcodes != address(0) &&
                _otherOpcodes != address(0),
            ErrorsContext.CTX1
        );

        initOpcodes();

        comparisonOpcodes = _comparisonOpcodes;
        branchingOpcodes = _branchingOpcodes;
        logicalOpcodes = _logicalOpcodes;
        otherOpcodes = _otherOpcodes;
    }

    /**
     * @dev Creates a list of opcodes and its aliases with information about each of them:
     * - name
     * - selectors of opcode functions,
     * - used library for each of opcode for Executor contract
     * - asm selector of function that uses in Parser contract
     * Function contains simple opcodes as arithmetic, comparison and bitwise. In additional to that
     * it contains complex opcodes that can load data (variables with different types) from memory
     * and helpers like transfer tokens or native coins to the address or opcodes branching and internal
     * DSL functions.
     */
    function initOpcodes() internal {
        // Opcodes for operators

        // Ex. `a == b`
        _addOpcodeForOperator(
            '==',
            0x01,
            ComparisonOpcodes.opEq.selector,
            0x0,
            OpcodeLibNames.ComparisonOpcodes,
            1
        );

        // Ex. `a != b`
        _addOpcodeForOperator(
            '!=',
            0x14,
            ComparisonOpcodes.opNotEq.selector,
            0x0,
            OpcodeLibNames.ComparisonOpcodes,
            1
        );

        // Ex. `a < b`
        _addOpcodeForOperator(
            '<',
            0x03,
            ComparisonOpcodes.opLt.selector,
            0x0,
            OpcodeLibNames.ComparisonOpcodes,
            1
        );

        // Ex. `a > b`
        _addOpcodeForOperator(
            '>',
            0x04,
            ComparisonOpcodes.opGt.selector,
            0x0,
            OpcodeLibNames.ComparisonOpcodes,
            1
        );

        // Ex. `a <= b`
        _addOpcodeForOperator(
            '<=',
            0x06,
            ComparisonOpcodes.opLe.selector,
            0x0,
            OpcodeLibNames.ComparisonOpcodes,
            1
        );

        // Ex. `a >= b`
        _addOpcodeForOperator(
            '>=',
            0x07,
            ComparisonOpcodes.opGe.selector,
            0x0,
            OpcodeLibNames.ComparisonOpcodes,
            1
        );

        // Changes swaps two values. Ex. `a swap b`
        // TODO: add more tests
        _addOpcodeForOperator(
            'swap',
            0x05,
            ComparisonOpcodes.opSwap.selector,
            0x0,
            OpcodeLibNames.ComparisonOpcodes,
            3
        );

        // Used to reverse the logical state of its operand. Ex. `!a` or `!(a and b)`
        _addOpcodeForOperator(
            '!',
            0x02,
            ComparisonOpcodes.opNot.selector,
            0x0,
            OpcodeLibNames.ComparisonOpcodes,
            4
        );

        // If both the operands are true then condition becomes true. Ex. `a and b`
        _addOpcodeForOperator(
            'and',
            0x12,
            LogicalOpcodes.opAnd.selector,
            0x0,
            OpcodeLibNames.LogicalOpcodes,
            3
        );

        // It copies the bit if it is set in one operand but not both. Ex. `a xor b`
        _addOpcodeForOperator(
            'xor',
            0x11,
            LogicalOpcodes.opXor.selector,
            0x0,
            OpcodeLibNames.LogicalOpcodes,
            2
        );

        // It copies a bit if it exists in either operand. Ex. `a or b`
        _addOpcodeForOperator(
            'or',
            0x13,
            LogicalOpcodes.opOr.selector,
            0x0,
            OpcodeLibNames.LogicalOpcodes,
            2
        );

        // Ex. `a + b`
        _addOpcodeForOperator(
            '+',
            0x26,
            LogicalOpcodes.opAdd.selector,
            0x0,
            OpcodeLibNames.LogicalOpcodes,
            2
        );

        // Ex. `a - b`
        _addOpcodeForOperator(
            '-',
            0x27,
            LogicalOpcodes.opSub.selector,
            0x0,
            OpcodeLibNames.LogicalOpcodes,
            2
        );

        // Ex. `a * b`
        _addOpcodeForOperator(
            '*',
            0x28,
            LogicalOpcodes.opMul.selector,
            0x0,
            OpcodeLibNames.LogicalOpcodes,
            3
        );

        // Ex. `a / b`
        _addOpcodeForOperator(
            '/',
            0x29,
            LogicalOpcodes.opDiv.selector,
            0x0,
            OpcodeLibNames.LogicalOpcodes,
            3
        );

        // Branching

        /**
            bool true
            ifelse D E

            uint2567 7000
            end

            D {
                uint2567 0
            }
            E {
                uint2567 7000 + uint2567 1
            }
        */
        _addOpcode(
            'ifelse',
            0x23,
            BranchingOpcodes.opIfelse.selector,
            IParser.asmIfelse.selector,
            OpcodeLibNames.BranchingOpcodes,
            2,
            true
        );

        /**
            bool true
            if C
            end

            C {
                ${FIVE}
            }
        */
        _addOpcode(
            'if',
            0x25,
            BranchingOpcodes.opIf.selector,
            IParser.asmIf.selector,
            OpcodeLibNames.BranchingOpcodes,
            1,
            true
        );

        /**
            Ends the block of if/ifelse/func opcodes description
            Example: using with func opcode
            ```
            func SUM_OF_NUMBERS endf
            end

            SUM_OF_NUMBERS {
                (6 + 8) setUint256 SUM
            }
            ```
        */
        _addOpcode(
            'end',
            0x24,
            BranchingOpcodes.opEnd.selector,
            0x0,
            OpcodeLibNames.BranchingOpcodes,
            0,
            true
        );

        // Simple Opcodes
        _addOpcode(
            'blockNumber',
            0x15,
            OtherOpcodes.opBlockNumber.selector,
            0x0,
            OpcodeLibNames.OtherOpcodes,
            0,
            true
        );

        // Current block timestamp as seconds since unix epoch. Ex. `time <= FUTURE_TIME_VARIABLE`
        _addOpcode(
            'time',
            0x16,
            OtherOpcodes.opBlockTimestamp.selector,
            0x0,
            OpcodeLibNames.OtherOpcodes,
            0,
            true
        );

        // Current chain id. Ex. `blockChainId == 123`
        _addOpcode(
            'blockChainId',
            0x17,
            OtherOpcodes.opBlockChainId.selector,
            0x0,
            OpcodeLibNames.OtherOpcodes,
            0,
            true
        );

        // Ex. `bool true`
        _addOpcode(
            'bool',
            0x18,
            OtherOpcodes.opBool.selector,
            IParser.asmBool.selector,
            OpcodeLibNames.OtherOpcodes,
            1,
            true
        );

        // Ex. `uint256 567`
        _addOpcode(
            'uint256',
            0x1a,
            OtherOpcodes.opUint256.selector,
            IParser.asmUint256.selector,
            OpcodeLibNames.OtherOpcodes,
            1,
            true
        );

        // Ex. `msgSender != 0x0000000000000000000000000000000000000000`
        _addOpcode(
            'msgSender',
            0x1d,
            OtherOpcodes.opMsgSender.selector,
            0x0,
            OpcodeLibNames.OtherOpcodes,
            0,
            true
        );

        // Ex. `sendEth ETH_RECEIVER 1000000000000000000`
        _addOpcode(
            'sendEth',
            0x1e,
            OtherOpcodes.opSendEth.selector,
            IParser.asmSend.selector,
            OpcodeLibNames.OtherOpcodes,
            2,
            true
        );

        // Ex. `transfer TOKEN_ADDR TOKEN_RECEIVER 10`
        _addOpcode(
            'transfer',
            0x1f,
            OtherOpcodes.opTransfer.selector,
            IParser.asmTransfer.selector,
            OpcodeLibNames.OtherOpcodes,
            3,
            true
        );

        // Ex. `transferVar DAI RECEIVER AMOUNT`
        _addOpcode(
            'transferVar',
            0x2c,
            OtherOpcodes.opTransferVar.selector,
            IParser.asmTransferVar.selector,
            OpcodeLibNames.OtherOpcodes,
            3,
            true
        );

        // Ex. `transferFrom DAI OWNER RECEIVER 10`
        _addOpcode(
            'transferFrom',
            0x20,
            OtherOpcodes.opTransferFrom.selector,
            IParser.asmTransferFrom.selector,
            OpcodeLibNames.OtherOpcodes,
            4,
            true
        );

        // Ex. `transferFromVar DAI OWNER RECEIVER AMOUNT`
        _addOpcode(
            'transferFromVar',
            0x2a,
            OtherOpcodes.opTransferFromVar.selector,
            IParser.asmTransferFromVar.selector,
            OpcodeLibNames.OtherOpcodes,
            4,
            true
        );

        // Ex. `setLocalBool BOOLVAR true`
        _addOpcode(
            'setLocalBool',
            0x21,
            OtherOpcodes.opSetLocalBool.selector,
            IParser.asmSetLocalBool.selector,
            OpcodeLibNames.OtherOpcodes,
            2,
            true
        );

        // Ex. `(4 + 17) setUint256 VAR`
        _addOpcode(
            'setUint256',
            0x2e,
            OtherOpcodes.opSetUint256.selector,
            IParser.asmSetUint256.selector,
            OpcodeLibNames.OtherOpcodes,
            1,
            true
        );

        // Ex. (msgValue == 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) setBool IS_OWNER
        _addOpcode(
            'msgValue',
            0x22,
            OtherOpcodes.opMsgValue.selector,
            0x0,
            OpcodeLibNames.OtherOpcodes,
            0,
            true
        );

        // Ex. `balanceOf DAI USER`
        _addOpcode(
            'balanceOf',
            0x2b,
            OtherOpcodes.opBalanceOf.selector,
            IParser.asmBalanceOf.selector,
            OpcodeLibNames.OtherOpcodes,
            2,
            true
        );

        // Ex. `allowance DAI OWNER SPENDER`
        _addOpcode(
            'allowance',
            0x42,
            OtherOpcodes.opAllowance.selector,
            IParser.asmAllowanceMintBurn.selector,
            OpcodeLibNames.OtherOpcodes,
            3,
            true
        );

        // Ex. `mint DAI TO AMOUNT`
        _addOpcode(
            'mint',
            0x43,
            OtherOpcodes.opMint.selector,
            IParser.asmAllowanceMintBurn.selector,
            OpcodeLibNames.OtherOpcodes,
            3,
            true
        );

        // Ex. `burn DAI OWNER AMOUNT`
        _addOpcode(
            'burn',
            0x44,
            OtherOpcodes.opBurn.selector,
            IParser.asmAllowanceMintBurn.selector,
            OpcodeLibNames.OtherOpcodes,
            3,
            true
        );

        /** Example:
            func SUM_OF_NUMBERS endf
            end

            SUM_OF_NUMBERS {
                (6 + 8) setUint256 SUM
            }
        */
        _addOpcode(
            'func',
            0x30,
            BranchingOpcodes.opFunc.selector,
            IParser.asmFunc.selector,
            OpcodeLibNames.BranchingOpcodes,
            0, // actually can be any number of params
            true
        );

        // Push to array
        // Ex. `push 0xe7f8a90ede3d84c7c0166bd84a4635e4675accfc USERS`
        _addOpcode(
            'push',
            0x33,
            OtherOpcodes.opPush.selector,
            IParser.asmPush.selector,
            OpcodeLibNames.OtherOpcodes,
            2,
            true
        );

        // Get length of array
        // Ex. `lengthOf PARTNERS`
        _addOpcode(
            'lengthOf',
            0x34,
            OtherOpcodes.opLengthOf.selector,
            IParser.asmLengthOf.selector,
            OpcodeLibNames.OtherOpcodes,
            1,
            true
        );

        // Get element by index in the array
        // Ex. `get 3 USERS`
        _addOpcode(
            'get',
            0x35,
            OtherOpcodes.opGet.selector,
            IParser.asmGet.selector,
            OpcodeLibNames.OtherOpcodes,
            2,
            true
        );

        // Sums all elements in an array
        // Ex. `sumOf ARR_NAME`
        _addOpcode(
            'sumOf',
            0x40,
            OtherOpcodes.opSumOf.selector,
            IParser.asmSumOf.selector,
            OpcodeLibNames.OtherOpcodes,
            1,
            true
        );

        /* Sums struct variables values from the `struct type` array
            Ex. `sumThroughStructs ARR_NAME STRUCT_VARIABLE_NAME`

            For more info see command `declareArr struct`
            Usage:
                struct Bob { // declare the first struct
                  lastPayment: 1000
                }

                struct Mary { // declare the second struct
                  lastPayment: 2000
                }

                // declare the array that have type `struct`
                declareArr struct USERS

                // insert `Bob` name into `USERS` array,
                push Bob USERS

                // or use `insert` DSL command by inserting `Bob` name into `USERS` array
                insert Mary into USERS

                // usage of a `sumThroughStructs` command sums 1000 and 2000 and save to the stack
                sumThroughStructs USERS lastPayment

                // or command bellow will be preprocessed to the same `sumThroughStructs` format
                sumOf USERS.lastPayment
        */
        _addOpcode(
            'sumThroughStructs',
            0x38,
            OtherOpcodes.opSumThroughStructs.selector,
            IParser.asmSumThroughStructs.selector,
            OpcodeLibNames.OtherOpcodes,
            2,
            true
        );

        // Creates structs
        // Ex. `struct BOB { address: 0x123...456, lastDeposit: 3 }`
        // Ex. `BOB.lastDeposit >= 5`
        _addOpcode(
            'struct',
            0x36,
            OtherOpcodes.opStruct.selector,
            IParser.asmStruct.selector,
            OpcodeLibNames.OtherOpcodes,
            1,
            true
        );

        /************
         * For loop *
         ***********/
        // start of the for-loop
        // Ex.
        // ```
        // for USER in USERS {
        //   sendEth USER 1e18
        // }
        // ```
        _addOpcode(
            'for',
            0x37,
            BranchingOpcodes.opForLoop.selector,
            IParser.asmForLoop.selector,
            OpcodeLibNames.BranchingOpcodes,
            3,
            true
        );

        // internal opcode that is added automatically by Preprocessor
        // indicates the start of the for-loop block
        _addOpcode(
            'startLoop',
            0x32,
            BranchingOpcodes.opStartLoop.selector,
            0x0,
            OpcodeLibNames.BranchingOpcodes,
            0,
            true
        );

        // indicates the end of the for-loop block
        _addOpcode(
            'endLoop',
            0x39,
            BranchingOpcodes.opEndLoop.selector,
            0x0,
            OpcodeLibNames.BranchingOpcodes,
            0,
            true
        );

        // Complex Opcodes with sub Opcodes (branches)

        /*
            Types usage examples of var and loadRemote opcodes:
                var NUMBER_STORED_VALUE
                loadRemote bool ADDRESS_STORED_VALUE 9A676e781A523b5d0C0e43731313A708CB607508

            Where `*_STORED_VALUE` parameters can be set by using `setLocalBool`
            or `setUint256` opcodes
        */
        _addOpcode(
            'var',
            0x1b,
            OtherOpcodes.opLoadLocalUint256.selector,
            IParser.asmVar.selector,
            OpcodeLibNames.OtherOpcodes,
            1,
            true
        );

        // Activates record in Aggreement contract by Record ID
        // Ex. `enableRecord 5 at 0x9A676e781A523b5d0C0e43731313A708CB607508`,
        // where 5 is a `Record ID`;
        // `0x9A676e781A523b5d0C0e43731313A708CB607508` is an Agreement address
        _addOpcode(
            'enableRecord',
            0x41,
            OtherOpcodes.opEnableRecord.selector,
            IParser.asmEnableRecord.selector,
            OpcodeLibNames.OtherOpcodes,
            1,
            true
        );

        string memory name = 'loadRemote';
        _addOpcode(
            name,
            0x1c,
            OtherOpcodes.opLoadRemoteAny.selector,
            IParser.asmLoadRemote.selector,
            OpcodeLibNames.OtherOpcodes,
            3,
            true
        );
        // types that 'loadRemote' have for loading data
        _addOpcodeBranch(name, 'uint256', 0x01, OtherOpcodes.opLoadRemoteUint256.selector);
        _addOpcodeBranch(name, 'bool', 0x02, OtherOpcodes.opLoadRemoteBool.selector);
        _addOpcodeBranch(name, 'address', 0x03, OtherOpcodes.opLoadRemoteAddress.selector);
        _addOpcodeBranch(name, 'bytes32', 0x04, OtherOpcodes.opLoadRemoteBytes32.selector);

        // Ex. `declareArr uint256 BALANCES`
        name = 'declareArr';
        _addOpcode(
            name,
            0x31,
            OtherOpcodes.opDeclare.selector,
            IParser.asmDeclare.selector,
            OpcodeLibNames.OtherOpcodes,
            2,
            true
        );
        // types of arrays for declaration
        _addOpcodeBranch(name, 'uint256', 0x01, IStorageUniversal.setStorageUint256.selector);
        _addOpcodeBranch(name, 'struct', 0x02, bytes4(0x0));
        _addOpcodeBranch(name, 'address', 0x03, IStorageUniversal.setStorageAddress.selector);

        // Ex.
        // `compound deposit USDC` - deposits all USDC tokens to compound, receives cUSDC
        // `compound withdraw USDC` - withdtaw all USDC tokens from compound in exchange on cUSDC
        name = 'compound';
        _addOpcode(
            name,
            0x45,
            OtherOpcodes.opCompound.selector,
            IParser.asmCompound.selector,
            OpcodeLibNames.OtherOpcodes,
            2,
            true
        );
        // types that 'compound' have for loading data
        _addOpcodeBranch(name, 'deposit', 0x01, OtherOpcodes.opCompoundDeposit.selector);
        _addOpcodeBranch(name, 'withdraw', 0x02, OtherOpcodes.opCompoundWithdraw.selector);

        /***********
         * Aliases *
         **********/

        /*
            As the blockTimestamp is the current opcode the user can use time alias to
            simplify the DSL code string.
            Example of the base command:
                `blockTimestamp < var FUND_INVESTMENT_DATE`
            Example of the alias of the base command:
                `time < var FUND_INVESTMENT_DATE`
        */
        // _addAlias(<original>, <alias>);
        _addAlias('time', 'blockTimestamp');
        _addAlias('end', 'branch');
        _addAlias('declareArr uint256', 'uint256[]');
        _addAlias('declareArr string', 'string[]');
        _addAlias('declareArr bytes32', 'bytes32[]');
        _addAlias('declareArr address', 'address[]');
        _addAlias('declareArr bool', 'bool[]');
        _addAlias('declareArr struct', 'struct[]');
    }

    /**
     * @dev Returns the amount of stored operators
     */
    function operatorsLen() external view returns (uint256) {
        return operators.length;
    }

    /**
     * @dev Adds the opcode for the DSL command
     * @param _name is the name of the command
     * @param _opcode is the opcode of the command
     * @param _opSelector is the selector of the function for this opcode
       from onle of library in `contracts/libs/opcodes/*`
     * @param _asmSelector is the selector of the function from the Parser for that opcode
     * @param _libName is the name of library that is used fot the opcode
     * @param _numOfArgs The number of arguments for this opcode
     */
    function _addOpcode(
        string memory _name,
        bytes1 _opcode,
        bytes4 _opSelector,
        bytes4 _asmSelector,
        OpcodeLibNames _libName,
        uint8 _numOfArgs,
        bool _isCommand
    ) internal {
        require(_opSelector != bytes4(0), ErrorsContext.CTX2);
        require(
            opCodeByName[_name] == bytes1(0) && selectorByOpcode[_opcode] == bytes4(0),
            ErrorsContext.CTX3
        );
        opCodeByName[_name] = _opcode;
        selectorByOpcode[_opcode] = _opSelector;
        opcodeLibNameByOpcode[_opcode] = _libName;
        asmSelectors[_name] = _asmSelector;
        numOfArgsByOpcode[_name] = _numOfArgs;
        isCommand[_name] = _isCommand;
    }

    /**
     * @dev Adds the opcode for the operator
     * @param _name is the name of the operator
     * @param _opcode is the opcode of the operator
     * @param _opSelector is the selector of the function for this operator
       from onle of library in `contracts/libs/opcodes/*`
     * @param _asmSelector is the selector of the function from the Parser for this operator
     * @param _libName is the name of library that is used fot the operator
     * @param _priority is the priority for the opcode
     */
    function _addOpcodeForOperator(
        string memory _name,
        bytes1 _opcode,
        bytes4 _opSelector,
        bytes4 _asmSelector,
        OpcodeLibNames _libName,
        uint256 _priority
    ) internal {
        _addOpcode(_name, _opcode, _opSelector, _asmSelector, _libName, 0, false);
        _addOperator(_name, _priority);
    }

    /**
     * @dev As branched (complex) DSL commands have their own name, types and values the
     * _addOpcodeBranch provides adding opcodes using additional internal branch opcodes.
     * @param _baseOpName is the name of the command
     * @param _branchName is the type for the value
     * @param _branchCode is the code for the certain name and its type
     * @param _selector is the selector of the function from the Parser for this command
     */
    function _addOpcodeBranch(
        string memory _baseOpName,
        string memory _branchName,
        bytes1 _branchCode,
        bytes4 _selector
    ) internal {
        // TODO: will we use zero _selector in the future?
        // require(_selector != bytes4(0), ErrorsContext.CTX2);
        require(
            branchSelectors[_baseOpName][_branchCode] == bytes4(0) &&
                branchCodes[_baseOpName][_branchName] == bytes1(0),
            ErrorsContext.CTX5
        );
        branchSelectors[_baseOpName][_branchCode] = _selector;
        branchCodes[_baseOpName][_branchName] = _branchCode;
    }

    /**
     * @dev Adds the operator by its priority
     * Note: bigger number => bigger priority
     *
     * @param _op is the name of the operator
     * @param _priority is the priority of the operator
     */
    function _addOperator(string memory _op, uint256 _priority) internal {
        opsPriors[_op] = _priority;
        operators.push(_op);
    }

    /**
     * @dev Adds an alias to the already existing DSL command
     *
     * @param _baseCmd is the name of the command
     * @param _alias is the alias command name for the base command
     */
    function _addAlias(string memory _baseCmd, string memory _alias) internal {
        aliases[_alias] = _baseCmd;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../helpers/Stack.sol';

interface IDSLContext {
    enum OpcodeLibNames {
        ComparisonOpcodes,
        BranchingOpcodes,
        LogicalOpcodes,
        OtherOpcodes
    }

    function comparisonOpcodes() external view returns (address);

    function branchingOpcodes() external view returns (address);

    function logicalOpcodes() external view returns (address);

    function otherOpcodes() external view returns (address);

    function opCodeByName(string memory _name) external view returns (bytes1 _opcode);

    function selectorByOpcode(bytes1 _opcode) external view returns (bytes4 _selecotor);

    function numOfArgsByOpcode(string memory _name) external view returns (uint8 _numOfArgs);

    function isCommand(string memory _name) external view returns (bool _isCommand);

    function opcodeLibNameByOpcode(bytes1 _opcode) external view returns (OpcodeLibNames _name);

    function asmSelectors(string memory _name) external view returns (bytes4 _selecotor);

    function opsPriors(string memory _name) external view returns (uint256 _priority);

    function operators(uint256 _index) external view returns (string memory _operator);

    function branchSelectors(
        string memory _baseOpName,
        bytes1 _branchCode
    ) external view returns (bytes4 _selector);

    function branchCodes(
        string memory _baseOpName,
        string memory _branchName
    ) external view returns (bytes1 _branchCode);

    function aliases(string memory _alias) external view returns (string memory _baseCmd);

    // Functions
    function operatorsLen() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStorageUniversal {
    function setStorageBool(bytes32 position, bytes32 data) external;

    function setStorageAddress(bytes32 position, bytes32 data) external;

    function setStorageUint256(bytes32 position, bytes32 data) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// import 'hardhat/console.sol';

/**
 * @title List of Agreement errors
 */
library ErrorsAgreement {
    string constant AGR1 = 'AGR1'; // Agreement: bad record signatory
    string constant AGR2 = 'AGR2'; // Agreement: not all required records are executed
    string constant AGR3 = 'AGR3'; // Agreement: record fulfilment error
    string constant AGR4 = 'AGR4'; // Agreement: signatures are invalid
    string constant AGR5 = 'AGR5'; // Agreement: the transaction should have at least one condition
    string constant AGR6 = 'AGR6'; // Agreement: not all record conditions are satisfied
    string constant AGR7 = 'AGR7'; // Agreement: record already was executed by this signatory
    string constant AGR8 = 'AGR8'; // Agreement: the variable name is reserved
    string constant AGR9 = 'AGR9'; // Agreement: this record does not exist
    string constant AGR10 = 'AGR10'; // Agreement: this record has not yet been archived
    string constant AGR11 = 'AGR11'; // Agreement: not an owner
    string constant AGR12 = 'AGR12'; // Agreement: zero address
    string constant AGR13 = 'AGR13'; // Agreement: the record is not activated
    string constant AGR14 = 'AGR14'; // Agreement: the record is pre-define. can not be changed
    string constant AGR15 = 'AGR15'; // Agreement: time can not be in the past
    string constant AGR16 = 'AGR16'; // Agreement: out of range
}

library ErrorsGovernance {
    string constant GOV1 = 'GOV1'; // Governance: You can not vote YES anymore
    string constant GOV2 = 'GOV2'; // Governance: You can not vote NO anymore
}

/**
 * @title List of Context errors
 */
library ErrorsContext {
    string constant CTX1 = 'CTX1'; // Context: address is zero
    string constant CTX2 = 'CTX2'; // Context: empty opcode selector
    string constant CTX3 = 'CTX3'; // Context: duplicate opcode name or code
    string constant CTX4 = 'CTX4'; // Context: slicing out of range
    string constant CTX5 = 'CTX5'; // Context: duplicate opcode branch
    string constant CTX6 = 'CTX6'; // Context: wrong application address
    string constant CTX7 = 'CTX7'; // Context: the application address has already set
}

/**
 * @title List of Stack errors
 */
library ErrorsStack {
    string constant STK1 = 'STK1'; // Stack: uint256 type mismatch
    string constant STK2 = 'STK2'; // Stack: string type mismatch
    string constant STK3 = 'STK3'; // Stack: address type mismatch
    string constant STK4 = 'STK4'; // Stack: stack is empty
}

/**
 * @title List of OtherOpcodes errors
 */
library ErrorsGeneralOpcodes {
    string constant OP1 = 'OP1'; // Opcodes: opSetLocal call not success
    string constant OP2 = 'OP2'; // Opcodes: tries to get an item from non-existing array
    string constant OP3 = 'OP3'; // Opcodes: opLoadRemote call not success
    string constant OP4 = 'OP4'; // Opcodes: tries to put an item to non-existing array
    string constant OP5 = 'OP5'; // Opcodes: opLoadLocal call not success
    string constant OP6 = 'OP6'; // Opcodes: array is empty
    string constant OP8 = 'OP8'; // Opcodes: wrong type of array
}

/**
 * @title List of BranchingOpcodes errors
 */
library ErrorsBranchingOpcodes {
    string constant BR1 = 'BR1'; // BranchingOpcodes: LinkedList.getType() delegate call error
    string constant BR2 = 'BR2'; // BranchingOpcodes: array doesn't exist
    string constant BR3 = 'BR3'; // BranchingOpcodes: LinkedList.get() delegate call error
}

/**
 * @title List of Parser errors
 */
library ErrorsParser {
    string constant PRS1 = 'PRS1'; // Parser: delegatecall to asmSelector failure
    string constant PRS2 = 'PRS2'; // Parser: the name of variable can not be empty
}

/**
 * @title List of Preprocessor errors
 */
library ErrorsPreprocessor {
    string constant PRP1 = 'PRP1'; // Preprocessor: amount of parameters can not be 0
    string constant PRP2 = 'PRP2'; // Preprocessor: invalid parameters for the function
}

/**
 * @title List of OpcodesHelpers errors
 */
library ErrorsOpcodeHelpers {
    string constant OPH1 = 'OPH1'; // Opcodes: mustCall call not success
    string constant OPH2 = 'OPH2'; // Opcodes: mustDelegateCall call not success
}

/**
 * @title List of ByteUtils errors
 */
library ErrorsByteUtils {
    string constant BUT1 = 'BUT1'; // ByteUtils: 'end' index must be greater than 'start'
    string constant BUT2 = 'BUT2'; // ByteUtils: 'end' is greater than the length of the array
    string constant BUT3 = 'BUT3'; // ByteUtils: a hex value not from the range 0-9, a-f, A-F
    string constant BUT4 = 'BUT4'; // ByteUtils: hex lenght not even
}

/**
 * @title List of Executor errors
 */
library ErrorsExecutor {
    string constant EXC1 = 'EXC1'; // Executor: empty program
    string constant EXC2 = 'EXC2'; // Executor: did not find selector for opcode
    string constant EXC3 = 'EXC3'; // Executor: call not success
    string constant EXC4 = 'EXC4'; // Executor: call to program context not success
}

/**
 * @title List of StringUtils errors
 */
library ErrorsStringUtils {
    string constant SUT1 = 'SUT1'; // StringUtils: index out of range
    string constant SUT3 = 'SUT3'; // StringUtils: non-decimal character
    string constant SUT4 = 'SUT4'; // StringUtils: base was not provided
    string constant SUT5 = 'SUT5'; // StringUtils: invalid format
    string constant SUT6 = 'SUT6'; // StringUtils: decimals were not provided
    string constant SUT7 = 'SUT7'; // StringUtils: a string was not provided
    string constant SUT9 = 'SUT9'; // StringUtils: base was not provided
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IDSLContext } from './IDSLContext.sol';
import { Preprocessor } from '../Preprocessor.sol';

interface IParser {
    // Variables

    event ExecRes(bool result);
    event NewConditionalTx(address txObj);

    // Functions

    function parse(
        address _preprAddr,
        address _dslCtxAddr,
        address _programCtxAddr,
        string memory _codeRaw
    ) external;

    function parseCode(
        address _dslCtxAddr,
        address _programCtxAddr,
        string[] memory _code
    ) external;

    function asmSetLocalBool(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmSetUint256(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmVar(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmLoadRemote(
        bytes memory _program,
        address _ctxDSLAddr,
        address
    ) external returns (bytes memory newProgram);

    function asmDeclare(
        bytes memory _program,
        address _ctxDSLAddr,
        address
    ) external returns (bytes memory newProgram);

    function asmCompound(
        bytes memory _program,
        address _ctxDSLAddr,
        address
    ) external returns (bytes memory newProgram);

    function asmBool(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmUint256(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmSend(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmTransfer(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmTransferVar(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmTransferFrom(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmBalanceOf(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmAllowanceMintBurn(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmLengthOf(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmSumOf(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmSumThroughStructs(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmTransferFromVar(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmIfelse(
        bytes memory _program,
        address _ctxDSLAddr,
        address _programCtxAddr
    ) external returns (bytes memory newProgram);

    function asmIf(
        bytes memory _program,
        address _ctxDSLAddr,
        address _programCtxAddr
    ) external returns (bytes memory newProgram);

    function asmFunc(
        bytes memory _program,
        address _ctxDSLAddr,
        address _programCtxAddr
    ) external returns (bytes memory newProgram);

    function asmGet(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmPush(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmStruct(
        bytes memory _program,
        address _ctxDSLAddr,
        address _programCtxAddr
    ) external returns (bytes memory newProgram);

    function asmForLoop(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);

    function asmEnableRecord(
        bytes memory _program,
        address,
        address
    ) external returns (bytes memory newProgram);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IDSLContext } from '../../interfaces/IDSLContext.sol';
import { IProgramContext } from '../../interfaces/IProgramContext.sol';
import { IERC20 } from '../../interfaces/IERC20.sol';
import { ILinkedList } from '../../interfaces/ILinkedList.sol';
import { IStorageUniversal } from '../../interfaces/IStorageUniversal.sol';
import { StringUtils } from '../StringUtils.sol';
import { UnstructuredStorage } from '../UnstructuredStorage.sol';
import { OpcodeHelpers } from './OpcodeHelpers.sol';
import { ErrorsBranchingOpcodes } from '../Errors.sol';

// import 'hardhat/console.sol';

/**
 * @title Logical operator opcodes
 * @notice Opcodes for logical operators such as if/esle, switch/case
 */
library BranchingOpcodes {
    using UnstructuredStorage for bytes32;
    using StringUtils for string;

    function opIfelse(address _ctxProgram, address) public {
        if (IProgramContext(_ctxProgram).stack().length() == 0) {
            OpcodeHelpers.putToStack(_ctxProgram, 0); // for if-else condition to work all the time
        }

        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint16 _posTrueBranch = getUint16(_ctxProgram);
        uint16 _posFalseBranch = getUint16(_ctxProgram);

        IProgramContext(_ctxProgram).setNextPc(IProgramContext(_ctxProgram).pc());
        IProgramContext(_ctxProgram).setPc(last > 0 ? _posTrueBranch : _posFalseBranch);
    }

    function opIf(address _ctxProgram, address) public {
        if (IProgramContext(_ctxProgram).stack().length() == 0) {
            OpcodeHelpers.putToStack(_ctxProgram, 0); // for if condition to work all the time
        }

        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint16 _posTrueBranch = getUint16(_ctxProgram);

        if (last != 0) {
            IProgramContext(_ctxProgram).setNextPc(IProgramContext(_ctxProgram).pc());
            IProgramContext(_ctxProgram).setPc(_posTrueBranch);
        } else {
            IProgramContext(_ctxProgram).setNextPc(IProgramContext(_ctxProgram).program().length);
        }
    }

    function opFunc(address _ctxProgram, address) public {
        if (IProgramContext(_ctxProgram).stack().length() == 0) {
            OpcodeHelpers.putToStack(_ctxProgram, 0);
        }

        uint16 _reference = getUint16(_ctxProgram);

        IProgramContext(_ctxProgram).setNextPc(IProgramContext(_ctxProgram).pc());
        IProgramContext(_ctxProgram).setPc(_reference);
    }

    /**
     * @dev For loop setup. Responsible for checking iterating array existence, set the number of iterations
     * @param _ctxProgram Context contract address
     */
    function opForLoop(address _ctxProgram, address) external {
        IProgramContext(_ctxProgram).incPc(4); // skip loop's temporary variable name. It will be used later in opStartLoop
        bytes32 _arrNameB32 = OpcodeHelpers.getNextBytes(_ctxProgram, 4);

        // check if the array exists
        bytes memory data1 = OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature('getType(bytes32)', _arrNameB32)
        );
        require(bytes1(data1) != bytes1(0x0), ErrorsBranchingOpcodes.BR2);

        // Set loop
        uint256 _arrLen = ILinkedList(IProgramContext(_ctxProgram).appAddr()).getLength(
            _arrNameB32
        );
        IProgramContext(_ctxProgram).setForLoopIterationsRemaining(_arrLen);
    }

    /**
     * @dev Does the real iterating process over the body of the for-loop
     * @param _ctxDSL DSL Context contract address
     * @param _ctxProgram ProgramContext contract address
     */
    function opStartLoop(address _ctxProgram, address _ctxDSL) public {
        // Decrease by 1 the for-loop iterations couter as PC actually points onto the next block of code already
        uint256 _currCtr = IProgramContext(_ctxProgram).forLoopIterationsRemaining();
        uint256 _currPc = IProgramContext(_ctxProgram).pc() - 1;

        // Set the next program counter to the beginning of the loop block
        if (_currCtr > 1) {
            IProgramContext(_ctxProgram).setNextPc(_currPc);
        }

        // Get element from array by index
        bytes32 _arrName = OpcodeHelpers.readBytesSlice(_ctxProgram, _currPc - 4, _currPc);
        uint256 _arrLen = ILinkedList(IProgramContext(_ctxProgram).appAddr()).getLength(_arrName);
        uint256 _index = _arrLen - IProgramContext(_ctxProgram).forLoopIterationsRemaining();
        bytes1 _arrType = ILinkedList(IProgramContext(_ctxProgram).appAddr()).getType(_arrName);
        bytes32 _elem = ILinkedList(IProgramContext(_ctxProgram).appAddr()).get(_index, _arrName);

        // Set the temporary variable value: TMP_VAR = ARR_NAME[i]
        bytes32 _tempVarNameB32 = OpcodeHelpers.readBytesSlice(
            _ctxProgram,
            _currPc - 8,
            _currPc - 4
        );
        bytes4 setFuncSelector = IDSLContext(_ctxDSL).branchSelectors('declareArr', _arrType);
        OpcodeHelpers.mustDelegateCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSelector(setFuncSelector, _tempVarNameB32, _elem)
        );

        // Reduce the number of iterations remaining
        IProgramContext(_ctxProgram).setForLoopIterationsRemaining(_currCtr - 1);
    }

    /**
     * @dev This function is responsible for getting of the body of the for-loop
     * @param _ctxProgram Context contract address
     */
    function opEndLoop(address _ctxProgram, address) public {
        uint256 _currPc = IProgramContext(_ctxProgram).pc();
        IProgramContext(_ctxProgram).setPc(IProgramContext(_ctxProgram).nextpc());
        IProgramContext(_ctxProgram).setNextPc(_currPc); // sets next PC to the code after this `end` opcode
    }

    function opEnd(address _ctxProgram, address) public {
        IProgramContext(_ctxProgram).setPc(IProgramContext(_ctxProgram).nextpc());
        IProgramContext(_ctxProgram).setNextPc(IProgramContext(_ctxProgram).program().length);
    }

    function getUint16(address _ctxProgram) public returns (uint16) {
        bytes memory data = OpcodeHelpers.nextBytes(_ctxProgram, 2);

        // Convert bytes to bytes8
        bytes2 result;
        assembly {
            result := mload(add(data, 0x20))
        }

        return uint16(result);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IProgramContext } from '../../interfaces/IProgramContext.sol';
import { IERC20 } from '../../interfaces/IERC20.sol';
import { StringUtils } from '../StringUtils.sol';
import { UnstructuredStorage } from '../UnstructuredStorage.sol';
import { OpcodeHelpers } from './OpcodeHelpers.sol';
import { ErrorsGeneralOpcodes } from '../Errors.sol';

// import 'hardhat/console.sol';

/**
 * @title Set operator opcodes
 * @notice Opcodes for set operators such as AND, OR, XOR
 */
library LogicalOpcodes {
    using UnstructuredStorage for bytes32;
    using StringUtils for string;

    /**
     * @dev Compares two values in the stack. Put 1 if both of them are 1, put
     *      0 otherwise
     * @param _ctxProgram Context contract address
     */
    function opAnd(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        OpcodeHelpers.putToStack(_ctxProgram, (prev > 0) && (last > 0) ? 1 : 0);
    }

    /**
     * @dev Compares two values in the stack. Put 1 if either one of them is 1,
     *      put 0 otherwise
     * @param _ctxProgram Context contract address
     */
    function opOr(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        OpcodeHelpers.putToStack(_ctxProgram, (prev > 0) || (last > 0) ? 1 : 0);
    }

    /**
     * @dev Compares two values in the stack. Put 1 if the values ​
     * ​are different and 0 if they are the same
     * @param _ctxProgram Context contract address
     */
    function opXor(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        OpcodeHelpers.putToStack(
            _ctxProgram,
            ((prev > 0) && (last == 0)) || ((prev == 0) && (last > 0)) ? 1 : 0
        );
    }

    /**
     * @dev Add two values and put result in the stack.
     * @param _ctxProgram Context contract address
     */
    function opAdd(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        OpcodeHelpers.putToStack(_ctxProgram, prev + last);
    }

    /**
     * @dev Subtracts one value from enother and put result in the stack.
     * @param _ctxProgram Context contract address
     */
    function opSub(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        OpcodeHelpers.putToStack(_ctxProgram, prev - last);
    }

    /**
     * @dev Multiplies values and put result in the stack.
     * @param _ctxProgram Context contract address
     */
    function opMul(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        OpcodeHelpers.putToStack(_ctxProgram, prev * last);
    }

    /**
     * Divide two numbers from the top of the stack
     * @dev This is an integer division. Example: 5 / 2 = 2
     * @param _ctxProgram Context address
     */
    function opDiv(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        OpcodeHelpers.putToStack(_ctxProgram, prev / last);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IProgramContext } from '../../interfaces/IProgramContext.sol';
import { IERC20 } from '../../interfaces/IERC20.sol';
import { StringUtils } from '../StringUtils.sol';
import { UnstructuredStorage } from '../UnstructuredStorage.sol';
import { OpcodeHelpers } from './OpcodeHelpers.sol';
import { ErrorsGeneralOpcodes } from '../Errors.sol';

// import 'hardhat/console.sol';

/**
 * @title Comparator operator opcodes
 * @notice Opcodes for comparator operators such as >, <, =, !, etc.
 */
library ComparisonOpcodes {
    using UnstructuredStorage for bytes32;
    using StringUtils for string;

    /**
     * @dev Compares two values in the stack. Put 1 to the stack if they are equal.
     * @param _ctxProgram Context contract address
     */
    function opEq(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        IProgramContext(_ctxProgram).stack().push(last == prev ? 1 : 0);
    }

    /**
     * @dev Compares two values in the stack. Put 1 to the stack if they are not equal.
     * @param _ctxProgram Context contract address
     */
    function opNotEq(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        OpcodeHelpers.putToStack(_ctxProgram, last != prev ? 1 : 0);
    }

    /**
     * @dev Compares two values in the stack. Put 1 to the stack if value1 < value2
     * @param _ctxProgram Context contract address
     */
    function opLt(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        OpcodeHelpers.putToStack(_ctxProgram, prev < last ? 1 : 0);
    }

    /**
     * @dev Compares two values in the stack. Put 1 to the stack if value1 > value2
     * @param _ctxProgram Context contract address
     */
    function opGt(address _ctxProgram, address) public {
        opSwap(_ctxProgram, address(0));
        opLt(_ctxProgram, address(0));
    }

    /**
     * @dev Compares two values in the stack. Put 1 to the stack if value1 <= value2
     * @param _ctxProgram Context contract address
     */
    function opLe(address _ctxProgram, address) public {
        opGt(_ctxProgram, address(0));
        opNot(_ctxProgram, address(0));
    }

    /**
     * @dev Compares two values in the stack. Put 1 to the stack if value1 >= value2
     * @param _ctxProgram Context contract address
     */
    function opGe(address _ctxProgram, address) public {
        opLt(_ctxProgram, address(0));
        opNot(_ctxProgram, address(0));
    }

    /**
     * @dev Revert last value in the stack
     * @param _ctxProgram Context contract address
     */
    function opNot(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        OpcodeHelpers.putToStack(_ctxProgram, last == 0 ? 1 : 0);
    }

    /**
     * @dev Swaps two last element in the stack
     * @param _ctxProgram Context contract address
     */
    function opSwap(address _ctxProgram, address) public {
        uint256 last = IProgramContext(_ctxProgram).stack().pop();
        uint256 prev = IProgramContext(_ctxProgram).stack().pop();
        IProgramContext(_ctxProgram).stack().push(last);
        IProgramContext(_ctxProgram).stack().push(prev);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IDSLContext } from '../../interfaces/IDSLContext.sol';
import { IProgramContext } from '../../interfaces/IProgramContext.sol';
import { IERC20 } from '../../interfaces/IERC20.sol';
import { IcToken } from '../../interfaces/IcToken.sol';
import { IERC20Mintable } from '../../interfaces/IERC20Mintable.sol';
import { StringUtils } from '../StringUtils.sol';
import { UnstructuredStorage } from '../UnstructuredStorage.sol';
import { OpcodeHelpers } from './OpcodeHelpers.sol';
import { ErrorsGeneralOpcodes } from '../Errors.sol';

import 'hardhat/console.sol';

library OtherOpcodes {
    using UnstructuredStorage for bytes32;
    using StringUtils for string;

    function opLoadRemoteAny(address _ctxProgram, address _ctxDSL) public {
        _mustDelegateCall(_ctxProgram, _ctxDSL, 'loadRemote');
    }

    function opCompound(address _ctxProgram, address _ctxDSL) public {
        _mustDelegateCall(_ctxProgram, _ctxDSL, 'compound');
    }

    function _mustDelegateCall(
        address _ctxProgram,
        address _ctxDSL,
        string memory _opcode
    ) internal {
        address libAddr = IDSLContext(_ctxDSL).otherOpcodes();
        bytes4 _selector = OpcodeHelpers.nextBranchSelector(_ctxDSL, _ctxProgram, _opcode);
        OpcodeHelpers.mustDelegateCall(
            libAddr,
            abi.encodeWithSelector(_selector, _ctxProgram, _ctxDSL)
        );
    }

    function opBlockNumber(address _ctxProgram, address) public {
        OpcodeHelpers.putToStack(_ctxProgram, block.number);
    }

    function opBlockTimestamp(address _ctxProgram, address) public {
        OpcodeHelpers.putToStack(_ctxProgram, block.timestamp);
    }

    function opBlockChainId(address _ctxProgram, address) public {
        OpcodeHelpers.putToStack(_ctxProgram, block.chainid);
    }

    function opMsgSender(address _ctxProgram, address) public {
        OpcodeHelpers.putToStack(
            _ctxProgram,
            uint256(uint160(IProgramContext(_ctxProgram).msgSender()))
        );
    }

    function opMsgValue(address _ctxProgram, address) public {
        OpcodeHelpers.putToStack(
            _ctxProgram,
            uint256(uint160(IProgramContext(_ctxProgram).msgValue()))
        );
    }

    function _getParam(address _ctxProgram, uint256 _slice) internal returns (bytes32) {
        return OpcodeHelpers.getNextBytes(_ctxProgram, _slice);
    }

    /**
     * @dev Sets boolean variable in the application contract.
     * The value of bool variable is taken from DSL code itself
     * @param _ctxProgram ProgramContext contract address
     */
    function opSetLocalBool(address _ctxProgram, address) public {
        bytes32 _varNameB32 = _getParam(_ctxProgram, 4);
        bytes memory data = OpcodeHelpers.nextBytes(_ctxProgram, 1);
        bool _boolVal = uint8(data[0]) == 1;
        // Set local variable by it's hex
        OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature('setStorageBool(bytes32,bool)', _varNameB32, _boolVal)
        );
        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    /**
     * @dev Sets uint256 variable in the application contract. The value of the variable is taken from stack
     * @param _ctxProgram ProgramContext contract address
     */
    function opSetUint256(address _ctxProgram, address) public {
        bytes32 _varNameB32 = _getParam(_ctxProgram, 4);
        uint256 _val = IProgramContext(_ctxProgram).stack().pop();

        // Set local variable by it's hex
        OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature('setStorageUint256(bytes32,uint256)', _varNameB32, _val)
        );
        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    /**
     * @dev Gets an element by its index in the array
     * @param _ctxProgram ProgramContext contract address
     */
    function opGet(address _ctxProgram, address) public {
        uint256 _index = opUint256Get(_ctxProgram, address(0));
        bytes32 _arrNameB32 = _getParam(_ctxProgram, 4);

        // check if the array exists
        bytes memory data = OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature('getType(bytes32)', _arrNameB32)
        );
        require(bytes1(data) != bytes1(0x0), ErrorsGeneralOpcodes.OP2);
        (data) = OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature(
                'get(uint256,bytes32)',
                _index, // index of the searched item
                _arrNameB32 // array name, ex. INDEX_LIST, PARTNERS
            )
        );
        OpcodeHelpers.putToStack(_ctxProgram, uint256(bytes32(data)));
    }

    /**
     * @dev Sums uin256 elements from the array (array name should be provided)
     * @param _ctxDSL DSLContext contract instance address
     * @param _ctxProgram ProgramContext contract address
     */
    function opSumOf(address _ctxProgram, address _ctxDSL) public {
        bytes32 _arrNameB32 = _getParam(_ctxProgram, 4);

        _checkArrType(_ctxDSL, _ctxProgram, _arrNameB32, 'uint256');
        bytes32 _length = _getArrLength(_ctxProgram, _arrNameB32);
        // sum items and store into the stack
        uint256 total = _sumOfVars(_ctxProgram, _arrNameB32, _length);
        OpcodeHelpers.putToStack(_ctxProgram, total);
    }

    /**
     * @dev Sums struct variables values from the `struct type` array
     * @param _ctxDSL DSLContext contract instance address
     * @param _ctxProgram ProgramContext contract address
     */
    function opSumThroughStructs(address _ctxProgram, address _ctxDSL) public {
        bytes32 _arrNameB32 = _getParam(_ctxProgram, 4);
        bytes32 _varNameB32 = _getParam(_ctxProgram, 4);

        _checkArrType(_ctxDSL, _ctxProgram, _arrNameB32, 'struct');
        bytes32 _length = _getArrLength(_ctxProgram, _arrNameB32);
        // sum items and store into the stack
        uint256 total = _sumOfStructVars(_ctxProgram, _arrNameB32, bytes4(_varNameB32), _length);
        OpcodeHelpers.putToStack(_ctxProgram, total);
    }

    /**
     * @dev Inserts items to DSL structures using mixed variable name (ex. `BOB.account`).
     * Struct variable names already contain a name of a DSL structure, `.` dot symbol, the name of
     * variable. `endStruct` word (0xcb398fe1) is used as an indicator for the ending loop for
     * the structs parameters
     * @param _ctxProgram ProgramContext contract address
     */
    function opStruct(address _ctxProgram, address) public {
        // get the first variable name
        bytes32 _varNameB32 = _getParam(_ctxProgram, 4);

        // till found the `endStruct` opcode
        while (bytes4(_varNameB32) != 0xcb398fe1) {
            // get a variable value for current _varNameB32
            bytes32 _value = _getParam(_ctxProgram, 32);
            OpcodeHelpers.mustCall(
                IProgramContext(_ctxProgram).appAddr(),
                abi.encodeWithSignature(
                    'setStorageUint256(bytes32,uint256)',
                    _varNameB32,
                    uint256(_value)
                )
            );
            // get the next variable name in struct
            _varNameB32 = _getParam(_ctxProgram, 4);
        }
    }

    /**
     * @dev Inserts an item to array
     * @param _ctxProgram ProgramContext contract address
     */
    function opPush(address _ctxProgram, address) public {
        bytes32 _varValue = _getParam(_ctxProgram, 32);
        bytes32 _arrNameB32 = _getParam(_ctxProgram, 4);
        // check if the array exists
        bytes memory data = OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature('getType(bytes32)', _arrNameB32)
        );
        require(bytes1(data) != bytes1(0x0), ErrorsGeneralOpcodes.OP4);
        OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature(
                'addItem(bytes32,bytes32)',
                _varValue, // value that pushes to the array
                _arrNameB32 // array name, ex. INDEX_LIST, PARTNERS
            )
        );
    }

    /**
     * @dev Declares an empty array
     * @param _ctxProgram ProgramContext contract address
     */
    function opDeclare(address _ctxProgram, address) public {
        bytes32 _arrType = _getParam(_ctxProgram, 1);
        bytes32 _arrName = _getParam(_ctxProgram, 4);

        OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature(
                'declare(bytes1,bytes32)',
                bytes1(_arrType), // type of the array
                _arrName
            )
        );
    }

    function opLoadLocalUint256(address _ctxProgram, address) public {
        opLoadLocal(_ctxProgram, 'getStorageUint256(bytes32)');
    }

    function opLoadLocalAddress(address _ctxProgram, address) public {
        opLoadLocal(_ctxProgram, 'getStorageAddress(bytes32)');
    }

    function opLoadRemoteUint256(address _ctxProgram, address) public {
        opLoadRemote(_ctxProgram, 'getStorageUint256(bytes32)');
    }

    function opLoadRemoteBytes32(address _ctxProgram, address) public {
        opLoadRemote(_ctxProgram, 'getStorageBytes32(bytes32)');
    }

    function opLoadRemoteBool(address _ctxProgram, address) public {
        opLoadRemote(_ctxProgram, 'getStorageBool(bytes32)');
    }

    function opLoadRemoteAddress(address _ctxProgram, address) public {
        opLoadRemote(_ctxProgram, 'getStorageAddress(bytes32)');
    }

    function opBool(address _ctxProgram, address) public {
        bytes memory data = OpcodeHelpers.nextBytes(_ctxProgram, 1);
        OpcodeHelpers.putToStack(_ctxProgram, uint256(uint8(data[0])));
    }

    function opUint256(address _ctxProgram, address) public {
        OpcodeHelpers.putToStack(_ctxProgram, opUint256Get(_ctxProgram, address(0)));
    }

    function opSendEth(address _ctxProgram, address) public {
        address payable recipient = payable(_getAddress(_ctxProgram));
        uint256 amount = opUint256Get(_ctxProgram, address(0));
        recipient.transfer(amount);
        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    function _getAddress(address _ctxProgram) internal returns (address result) {
        result = address(
            uint160(uint256(opLoadLocalGet(_ctxProgram, 'getStorageAddress(bytes32)')))
        );
    }

    /****************
     * ERC20 Tokens *
     ***************/

    function opTransfer(address _ctxProgram, address) public {
        address payable token = payable(_getAddress(_ctxProgram));
        address payable recipient = payable(_getAddress(_ctxProgram));
        uint256 amount = opUint256Get(_ctxProgram, address(0));
        IERC20(token).transfer(recipient, amount);
        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    function opTransferVar(address _ctxProgram, address) public {
        address payable token = payable(_getAddress(_ctxProgram));
        address payable recipient = payable(_getAddress(_ctxProgram));
        uint256 amount = uint256(opLoadLocalGet(_ctxProgram, 'getStorageUint256(bytes32)'));
        IERC20(token).transfer(recipient, amount);
        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    function opTransferFrom(address _ctxProgram, address) public {
        address payable token = payable(_getAddress(_ctxProgram));
        address payable from = payable(_getAddress(_ctxProgram));
        address payable to = payable(_getAddress(_ctxProgram));
        uint256 amount = opUint256Get(_ctxProgram, address(0));
        IERC20(token).transferFrom(from, to, amount);
        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    function opTransferFromVar(address _ctxProgram, address) public {
        address payable token = payable(_getAddress(_ctxProgram));
        address payable from = payable(_getAddress(_ctxProgram));
        address payable to = payable(_getAddress(_ctxProgram));
        uint256 amount = uint256(opLoadLocalGet(_ctxProgram, 'getStorageUint256(bytes32)'));

        IERC20(token).transferFrom(from, to, amount);
        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    function opBalanceOf(address _ctxProgram, address) public {
        address payable token = payable(_getAddress(_ctxProgram));
        address payable user = payable(_getAddress(_ctxProgram));
        OpcodeHelpers.putToStack(_ctxProgram, IERC20(token).balanceOf(user));
    }

    function opAllowance(address _ctxProgram, address) public {
        address payable token = payable(_getAddress(_ctxProgram));
        address payable owner = payable(_getAddress(_ctxProgram));
        address payable spender = payable(_getAddress(_ctxProgram));
        uint256 allowance = IERC20(token).allowance(owner, spender);
        OpcodeHelpers.putToStack(_ctxProgram, allowance);
    }

    function opMint(address _ctxProgram, address) public {
        address payable token = payable(_getAddress(_ctxProgram));
        address payable to = payable(_getAddress(_ctxProgram));
        uint256 amount = uint256(opLoadLocalGet(_ctxProgram, 'getStorageUint256(bytes32)'));
        IERC20Mintable(token).mint(to, amount);
        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    function opBurn(address _ctxProgram, address) public {
        address payable token = payable(_getAddress(_ctxProgram));
        address payable to = payable(_getAddress(_ctxProgram));
        uint256 amount = uint256(opLoadLocalGet(_ctxProgram, 'getStorageUint256(bytes32)'));
        IERC20Mintable(token).burn(to, amount);
        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    /********************
     * end ERC20 Tokens *
     *******************/

    function opLengthOf(address _ctxProgram, address) public {
        uint256 _length = uint256(opLoadLocalGet(_ctxProgram, 'getLength(bytes32)'));
        OpcodeHelpers.putToStack(_ctxProgram, _length);
    }

    function opUint256Get(address _ctxProgram, address) public returns (uint256) {
        return uint256(_getParam(_ctxProgram, 32));
    }

    function opLoadLocalGet(
        address _ctxProgram,
        string memory funcSignature
    ) public returns (bytes32 result) {
        bytes32 MSG_SENDER = 0x9ddd6a8100000000000000000000000000000000000000000000000000000000;
        bytes memory data;
        bytes32 varNameB32 = _getParam(_ctxProgram, 4);
        if (varNameB32 == MSG_SENDER) {
            data = abi.encode(IProgramContext(_ctxProgram).msgSender());
        } else {
            // Load local variable by it's hex
            data = OpcodeHelpers.mustCall(
                IProgramContext(_ctxProgram).appAddr(),
                abi.encodeWithSignature(funcSignature, varNameB32)
            );
        }

        result = bytes32(data);
    }

    function opAddressGet(address _ctxProgram, address) public returns (address) {
        bytes32 contractAddrB32 = _getParam(_ctxProgram, 20);
        /**
         * Shift bytes to the left so that
         * 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512000000000000000000000000
         * transforms into
         * 0x000000000000000000000000e7f1725e7734ce288f8367e1bb143e90bb3f0512
         * This is needed to later conversion from bytes32 to address
         */
        contractAddrB32 >>= 96;

        return address(uint160(uint256(contractAddrB32)));
    }

    function opLoadLocal(address _ctxProgram, string memory funcSignature) public {
        bytes32 result = opLoadLocalGet(_ctxProgram, funcSignature);

        OpcodeHelpers.putToStack(_ctxProgram, uint256(result));
    }

    function opLoadRemote(address _ctxProgram, string memory funcSignature) public {
        bytes32 varNameB32 = _getParam(_ctxProgram, 4);
        bytes32 contractAddrB32 = _getParam(_ctxProgram, 20);

        /**
         * Shift bytes to the left so that
         * 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512000000000000000000000000
         * transforms into
         * 0x000000000000000000000000e7f1725e7734ce288f8367e1bb143e90bb3f0512
         * This is needed to later conversion from bytes32 to address
         */
        contractAddrB32 >>= 96;

        address contractAddr = address(uint160(uint256(contractAddrB32)));

        // Load local value by it's hex
        bytes memory data = OpcodeHelpers.mustCall(
            contractAddr,
            abi.encodeWithSignature(funcSignature, varNameB32)
        );

        OpcodeHelpers.putToStack(_ctxProgram, uint256(bytes32(data)));
    }

    function opCompoundDeposit(address _ctxProgram) public {
        address payable token = payable(_getAddress(_ctxProgram));
        bytes memory data = OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature('compounds(address)', token)
        );
        address cToken = address(uint160(uint256(bytes32(data))));
        uint256 balance = IcToken(token).balanceOf(address(this));
        // approve simple token to use it into the market
        IERC20(token).approve(cToken, balance);
        // supply assets into the market and receives cTokens in exchange
        IcToken(cToken).mint(balance);

        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    function opCompoundWithdraw(address _ctxProgram) public {
        address payable token = payable(_getAddress(_ctxProgram));
        // `token` can be used in the future for more different underluing tokens
        bytes memory data = OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature('compounds(address)', token)
        );
        address cToken = address(uint160(uint256(bytes32(data))));

        // redeems cTokens in exchange for the underlying asset (USDC)
        // amount - amount of cTokens
        IcToken(cToken).redeem(IcToken(cToken).balanceOf(address(this)));

        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    function opEnableRecord(address _ctxProgram, address) public {
        uint256 recordId = uint256(opLoadLocalGet(_ctxProgram, 'getStorageUint256(bytes32)'));
        address payable contractAddr = payable(_getAddress(_ctxProgram));

        OpcodeHelpers.mustCall(
            contractAddr,
            abi.encodeWithSignature('activateRecord(uint256)', recordId)
        );
        OpcodeHelpers.putToStack(_ctxProgram, 1);
    }

    /**
     * @dev Sums struct variables values from the `struct type` array
     * @param _ctxProgram ProgramContext contract address
     * @param _arrNameB32 Array's name in bytecode
     * @param _varName Struct's name in bytecode
     * @param _length Array's length in bytecode
     * @return total Total sum of each element in the `struct` type of array
     */
    function _sumOfStructVars(
        address _ctxProgram,
        bytes32 _arrNameB32,
        bytes4 _varName,
        bytes32 _length
    ) internal returns (uint256 total) {
        for (uint256 i = 0; i < uint256(_length); i++) {
            // get the name of a struct
            bytes memory item = _getItem(_ctxProgram, i, _arrNameB32);

            // get struct variable value
            bytes4 _fullName = IProgramContext(_ctxProgram).structParams(bytes4(item), _varName);
            (item) = OpcodeHelpers.mustCall(
                IProgramContext(_ctxProgram).appAddr(),
                abi.encodeWithSignature('getStorageUint256(bytes32)', bytes32(_fullName))
            );
            total += uint256(bytes32(item));
        }
    }

    /**
     * @dev Returns the element from the array
     * @param _ctxProgram ProgramContext contract address
     * @param _index Array's index
     * @param _arrNameB32 Array's name in bytecode
     * @return item Item from the array by its index
     */
    function _getItem(
        address _ctxProgram,
        uint256 _index,
        bytes32 _arrNameB32
    ) internal returns (bytes memory item) {
        item = OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature('get(uint256,bytes32)', _index, _arrNameB32)
        );
    }

    /**
     * @dev Sums uin256 elements from the array (array name should be provided)
     * @param _ctxProgram ProgramContext contract address
     * @param _arrNameB32 Array's name in bytecode
     * @param _length Array's length in bytecode
     * @return total Total sum of each element in the `uint256` type of array
     */
    function _sumOfVars(
        address _ctxProgram,
        bytes32 _arrNameB32,
        bytes32 _length
    ) internal returns (uint256 total) {
        for (uint256 i = 0; i < uint256(_length); i++) {
            bytes memory item = _getItem(_ctxProgram, i, _arrNameB32);
            total += uint256(bytes32(item));
        }
    }

    /**
     * @dev Checks the type for array
     * @param _ctxDSL DSLContext contract address
     * @param _ctxProgram ProgramContext contract address
     * @param _arrNameB32 Array's name in bytecode
     * @param _typeName Type of the array, ex. `uint256`, `address`, `struct`
     */
    function _checkArrType(
        address _ctxDSL,
        address _ctxProgram,
        bytes32 _arrNameB32,
        string memory _typeName
    ) internal {
        bytes memory _type;
        // check if the array exists
        (_type) = OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature('getType(bytes32)', _arrNameB32)
        );
        require(
            bytes1(_type) == IDSLContext(_ctxDSL).branchCodes('declareArr', _typeName),
            ErrorsGeneralOpcodes.OP8
        );
    }

    /**
     * @dev Returns array's length
     * @param _ctxProgram ProgramContext contract address
     * @param _arrNameB32 Array's name in bytecode
     * @return Array's length in bytecode
     */
    function _getArrLength(address _ctxProgram, bytes32 _arrNameB32) internal returns (bytes32) {
        bytes memory data = OpcodeHelpers.mustCall(
            IProgramContext(_ctxProgram).appAddr(),
            abi.encodeWithSignature('getLength(bytes32)', _arrNameB32)
        );
        return bytes32(data);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ErrorsStack } from '../libs/Errors.sol';

contract Stack {
    uint256[] public stack;

    function length() external view returns (uint256) {
        return _length();
    }

    function seeLast() external view returns (uint256) {
        return _seeLast();
    }

    function push(uint256 data) external {
        stack.push(data);
    }

    function pop() external returns (uint256) {
        uint256 data = _seeLast();
        stack.pop();

        return data;
    }

    function clear() external {
        delete stack;
    }

    function _length() internal view returns (uint256) {
        return stack.length;
    }

    function _seeLast() internal view returns (uint256) {
        require(_length() > 0, ErrorsStack.STK4);
        return stack[_length() - 1];
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IDSLContext } from './interfaces/IDSLContext.sol';
import { IPreprocessor } from './interfaces/IPreprocessor.sol';
import { StringStack } from './libs/StringStack.sol';
import { StringUtils } from './libs/StringUtils.sol';
import { ErrorsPreprocessor } from './libs/Errors.sol';

/**
 * @dev Preprocessor of DSL code
 * @dev This contract is a singleton and should not be deployed more than once
 *
 * It can remove comments that were created by user in the DSL code string. It
 * transforms the users DSL code string to the list of commands that can be used
 * in a Parser contract.
 *
 * DSL code in postfix notation as
 * user's string code -> Preprocessor -> each command is separated in the commands list
 */
library Preprocessor {
    using StringUtils for string;
    using StringStack for string[];

    /************************
     * == MAIN FUNCTIONS == *
     ***********************/

    /**
     * @dev The main function that transforms the user's DSL code string to the list of commands.
     *
     * Example:
     * The user's DSL code string is
     * ```
     * uint256 6 setUint256 A
     * ```
     * The end result after executing a `transform()` function is
     * ```
     * ['uint256', '6', 'setUint256', 'A']
     * ```
     *
     * @param _ctxAddr is a context contract address
     * @param _program is a user's DSL code string
     * @return code The list of commands that storing `result`
     */
    function transform(
        address _ctxAddr,
        string memory _program
    ) external view returns (string[] memory code) {
        // _program = removeComments(_program);
        code = split(_program, '\n ,:(){}', '(){}');
        code = removeSyntacticSugar(code);
        code = simplifyCode(code, _ctxAddr);
        code = infixToPostfix(_ctxAddr, code);
        return code;
    }

    /**
     * @dev Searches the comments in the program and removes comment lines
     * Example:
     * The user's DSL code string is
     * ```
     *  bool true
     *  // uint256 2 * uint256 5
     * ```
     * The end result after executing a `removeComments()` function is
     * ```
     * bool true
     * ```
     * @param _program is a current program string
     * @return _cleanedProgram new string program that contains only clean code without comments
     */
    function removeComments(
        string memory _program
    ) public pure returns (string memory _cleanedProgram) {
        bool isCommented;

        // searchedSymbolLen is a flag that uses for searching a correct end symbol
        uint256 searchedSymbolLen; // 1 - search \n symbol, 2 - search */ symbol
        uint256 tempIndex; // uses for checking if the index was changed
        uint256 i;
        string memory char;

        while (i < _program.length()) {
            char = _program.char(i);
            tempIndex = i;
            if (isCommented) {
                (tempIndex, isCommented) = _getEndCommentSymbol(
                    searchedSymbolLen,
                    i,
                    _program,
                    char
                );
            } else {
                (searchedSymbolLen, tempIndex, isCommented) = _getCommentSymbol(i, _program, char);
            }

            if (tempIndex > i) {
                i = tempIndex;
                continue;
            }

            if (isCommented) {
                i += 1;
                continue;
            }

            _cleanedProgram = _cleanedProgram.concat(char);
            i += 1;
        }
    }

    /**
     * @dev Splits the user's DSL code string to the list of commands
     * avoiding several symbols:
     * - removes additional and useless symbols as ' ', `\\n`
     * - defines and adding help 'end' symbol for the ifelse condition
     * - defines and cleans the code from `{` and `}` symbols
     *
     * Example:
     * The user's DSL code string is
     * ```
     * (var TIMESTAMP > var INIT)
     * ```
     * The end result after executing a `split()` function is
     * ```
     * ['var', 'TIMESTAMP', '>', 'var', 'INIT']
     * ```
     *
     * @param _program is a user's DSL code string
     * @param _separators Separators that will be used to split the string
     * @param _separatorsToKeep we're using symbols from this string as separators but not removing
     *                          them from the resulting array
     * @return The list of commands that storing in `result`
     */
    function split(
        string memory _program,
        string memory _separators,
        string memory _separatorsToKeep
    ) public pure returns (string[] memory) {
        string[] memory _result = new string[](50);
        uint256 resultCtr;
        string memory buffer; // here we collect DSL commands, var names, etc. symbol by symbol
        string memory char;

        for (uint256 i = 0; i < _program.length(); i++) {
            char = _program.char(i);

            if (char.isIn(_separators)) {
                if (buffer.length() > 0) {
                    _result[resultCtr++] = buffer;
                    buffer = '';
                }
            } else {
                buffer = buffer.concat(char);
            }

            if (char.isIn(_separatorsToKeep)) {
                _result[resultCtr++] = char;
            }
        }

        if (buffer.length() > 0) {
            _result[resultCtr++] = buffer;
            buffer = '';
        }

        return _result;
    }

    /**
     * @dev Removes scientific notation from numbers and removes currency symbols
     * Example
     * 1e3 = 1,000
     * 1 GWEI = 1,000,000,000
     * 1 ETH = 1,000,000,000,000,000,000
     * @param _code Array of DSL commands
     * @return Code without syntactic sugar
     */
    function removeSyntacticSugar(string[] memory _code) public pure returns (string[] memory) {
        string[] memory _result = new string[](50);
        uint256 _resultCtr;
        string memory _chunk;
        string memory _prevChunk;
        uint256 i;

        while (i < _nonEmptyArrLen(_code)) {
            _prevChunk = i == 0 ? '' : _code[i - 1];
            _chunk = _code[i++];

            _chunk = _checkScientificNotation(_chunk);
            if (_isCurrencySymbol(_chunk)) {
                (_resultCtr, _chunk) = _processCurrencySymbol(_resultCtr, _chunk, _prevChunk);
            }

            _result[_resultCtr++] = _chunk;
        }
        return _result;
    }

    /**
     * @dev Depending on the type of the command it gets simplified
     * @param _code Array of DSL commands
     * @param _ctxAddr Context contract address
     * @return Simplified code
     */
    function simplifyCode(
        string[] memory _code,
        address _ctxAddr
    ) public view returns (string[] memory) {
        string[] memory _result = new string[](50);
        uint256 _resultCtr;
        string memory _chunk;
        string memory _prevChunk;
        uint256 i;

        while (i < _nonEmptyArrLen(_code)) {
            _prevChunk = i == 0 ? '' : _code[i - 1];
            _chunk = _code[i++];

            if (IDSLContext(_ctxAddr).isCommand(_chunk)) {
                (_result, _resultCtr, i) = _processCommand(_result, _resultCtr, _code, i, _ctxAddr);
            } else if (_isCurlyBracket(_chunk)) {
                (_result, _resultCtr) = _processCurlyBracket(_result, _resultCtr, _chunk);
            } else if (_isAlias(_chunk, _ctxAddr)) {
                (_result, _resultCtr) = _processAlias(_result, _resultCtr, _ctxAddr, _chunk);
            } else if (_chunk.equal('insert')) {
                (_result, _resultCtr, i) = _processArrayInsert(_result, _resultCtr, _code, i);
            } else {
                (_result, _resultCtr) = _checkIsNumberOrAddress(_result, _resultCtr, _chunk);
                _result[_resultCtr++] = _chunk;
            }
        }
        return _result;
    }

    /**
     * @dev Transforms code in infix format to the postfix format
     * @param _code Array of DSL commands
     * @param _ctxAddr Context contract address
     * @return Code in the postfix format
     */
    function infixToPostfix(
        address _ctxAddr,
        string[] memory _code
    ) public view returns (string[] memory) {
        string[] memory _result = new string[](50);
        string[] memory _stack = new string[](50);
        uint256 _resultCtr;
        string memory _chunk;
        uint256 i;

        while (i < _nonEmptyArrLen(_code)) {
            _chunk = _code[i++];

            if (_isOperator(_chunk, _ctxAddr)) {
                (_result, _resultCtr, _stack) = _processOperator(
                    _stack,
                    _result,
                    _resultCtr,
                    _ctxAddr,
                    _chunk
                );
            } else if (_isParenthesis(_chunk)) {
                (_result, _resultCtr, _stack) = _processParenthesis(
                    _stack,
                    _result,
                    _resultCtr,
                    _chunk
                );
            } else {
                _result[_resultCtr++] = _chunk;
            }
        }

        // Note: now we have a stack with DSL commands and we will pop from it and save to the resulting array to move
        //       from postfix to infix notation
        while (_stack.stackLength() > 0) {
            (_stack, _result[_resultCtr++]) = _stack.popFromStack();
        }
        return _result;
    }

    /***************************
     * == PROCESS FUNCTIONS == *
     **************************/

    /**
     * @dev Process insert into array command
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _code Current DSL code that we're processing
     * @param i Current pointer to the element in _code array that we're processing
     * @return Modified _result array, mofified _resultCtr, and modified `i`
     */
    function _processArrayInsert(
        string[] memory _result,
        uint256 _resultCtr,
        string[] memory _code,
        uint256 i
    ) internal pure returns (string[] memory, uint256, uint256) {
        // Get the necessary params of `insert` command
        // Notice: `insert 1234 into NUMBERS` -> `push 1234 NUMBERS`
        string memory _insertVal = _code[i];
        string memory _arrName = _code[i + 2];

        _result[_resultCtr++] = 'push';
        _result[_resultCtr++] = _insertVal;
        _result[_resultCtr++] = _arrName;

        return (_result, _resultCtr, i + 3);
    }

    /**
     * @dev Process summing over array comand
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _code Current DSL code that we're processing
     * @param i Current pointer to the element in _code array that we're processing
     * @return Modified _result array, mofified _resultCtr, and modified `i`
     */
    function _processSumOfCmd(
        string[] memory _result,
        uint256 _resultCtr,
        string[] memory _code,
        uint256 i
    ) internal pure returns (string[] memory, uint256, uint256) {
        // Ex. (sumOf) `USERS.balance` -> ['USERS', 'balance']
        // Ex. (sumOf) `USERS` ->['USERS']
        string[] memory _sumOfArgs = split(_code[i], '.', '');

        // Ex. `sumOf USERS.balance` -> sum over array of structs
        // Ex. `sumOf USERS` -> sum over a regular array
        if (_nonEmptyArrLen(_sumOfArgs) == 2) {
            // process `sumOf` over array of structs
            _result[_resultCtr++] = 'sumThroughStructs';
            _result[_resultCtr++] = _sumOfArgs[0];
            _result[_resultCtr++] = _sumOfArgs[1];
        } else {
            // process `sumOf` over a regular array
            _result[_resultCtr++] = 'sumOf';
            _result[_resultCtr++] = _sumOfArgs[0];
        }

        return (_result, _resultCtr, i + 1);
    }

    /**
     * @dev Process for-loop
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _code Current DSL code that we're processing
     * @param i Current pointer to the element in _code array that we're processing
     * @return Modified _result array, mofified _resultCtr, and modified `i`
     */
    function _processForCmd(
        string[] memory _result,
        uint256 _resultCtr,
        string[] memory _code,
        uint256 i
    ) internal pure returns (string[] memory, uint256, uint256) {
        // TODO
    }

    /**
     * @dev Process `struct` comand
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _code Current DSL code that we're processing
     * @param i Current pointer to the element in _code array that we're processing
     * @return Modified _result array, mofified _resultCtr, and modified `i`
     */
    function _processStruct(
        string[] memory _result,
        uint256 _resultCtr,
        string[] memory _code,
        uint256 i
    ) internal pure returns (string[] memory, uint256, uint256) {
        // 'struct', 'BOB', '{', 'balance', '456', '}'
        _result[_resultCtr++] = 'struct';
        _result[_resultCtr++] = _code[i]; // struct name
        // skip `{` (index is i + 1)

        uint256 j = i + 1;
        while (!_code[j + 1].equal('}')) {
            _result[_resultCtr++] = _code[j + 1]; // struct key
            _result[_resultCtr++] = _code[j + 2]; // struct value

            j = j + 2;
        }
        _result[_resultCtr++] = 'endStruct';

        return (_result, _resultCtr, j + 2);
    }

    /**
     * @dev Process `ETH`, `WEI` symbols in the code
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _chunk The current piece of code that we're processing (should be the currency symbol)
     * @param _prevChunk The previous piece of code
     * @return Mofified _resultCtr, and modified `_prevChunk`
     */
    function _processCurrencySymbol(
        uint256 _resultCtr,
        string memory _chunk,
        string memory _prevChunk
    ) internal pure returns (uint256, string memory) {
        uint256 _currencyMultiplier = _getCurrencyMultiplier(_chunk);

        try _prevChunk.toUint256() {
            _prevChunk = StringUtils.toString(_prevChunk.toUint256() * _currencyMultiplier);
        } catch {
            _prevChunk = StringUtils.toString(
                _prevChunk.parseScientificNotation().toUint256() * _currencyMultiplier
            );
        }

        // this is to rewrite old number (ex. 100) with an extended number (ex. 100 GWEI = 100000000000)
        if (_resultCtr > 0) {
            --_resultCtr;
        }

        return (_resultCtr, _prevChunk);
    }

    /**
     * @dev Process DSL alias
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _ctxAddr Context contract address
     * @param _chunk The current piece of code that we're processing
     * @return Modified _result array, mofified _resultCtr, and modified `i`
     */
    function _processAlias(
        string[] memory _result,
        uint256 _resultCtr,
        address _ctxAddr,
        string memory _chunk
    ) internal view returns (string[] memory, uint256) {
        uint256 i;

        // Replace alises with base commands
        _chunk = IDSLContext(_ctxAddr).aliases(_chunk);

        // Process multi-command aliases
        // Ex. `uint256[]` -> `declareArr uint256`
        string[] memory _chunks = split(_chunk, ' ', '');

        // while we've not finished processing all the program - keep going
        while (i < _nonEmptyArrLen(_chunks)) {
            _result[_resultCtr++] = _chunks[i++];
        }

        return (_result, _resultCtr);
    }

    /**
     * @dev Process any DSL command
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _code Current DSL code that we're processing
     * @param i Current pointer to the element in _code array that we're processing
     * @param _ctxAddr Context contract address
     * @return Modified _result array, mofified _resultCtr, and modified `i`
     */
    function _processCommand(
        string[] memory _result,
        uint256 _resultCtr,
        string[] memory _code,
        uint256 i,
        address _ctxAddr
    ) internal view returns (string[] memory, uint256, uint256) {
        string memory _chunk = _code[i - 1];
        if (_chunk.equal('struct')) {
            (_result, _resultCtr, i) = _processStruct(_result, _resultCtr, _code, i);
        } else if (_chunk.equal('sumOf')) {
            (_result, _resultCtr, i) = _processSumOfCmd(_result, _resultCtr, _code, i);
        } else if (_chunk.equal('for')) {
            (_result, _resultCtr, i) = _processForCmd(_result, _resultCtr, _code, i);
        } else {
            uint256 _skipCtr = IDSLContext(_ctxAddr).numOfArgsByOpcode(_chunk) + 1;

            i--; // this is to include the command name in the loop below
            // add command arguments
            while (_skipCtr > 0) {
                _result[_resultCtr++] = _code[i++];
                _skipCtr--;
            }
        }

        return (_result, _resultCtr, i);
    }

    /**
     * @dev Process open and closed parenthesis
     * @param _stack Stack that is used to process parenthesis
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _chunk The current piece of code that we're processing
     * @return Modified _result array, mofified _resultCtr, and modified _stack
     */
    function _processParenthesis(
        string[] memory _stack,
        string[] memory _result,
        uint256 _resultCtr,
        string memory _chunk
    ) internal pure returns (string[] memory, uint256, string[] memory) {
        if (_chunk.equal('(')) {
            // opening bracket
            _stack = _stack.pushToStack(_chunk);
        } else if (_chunk.equal(')')) {
            // closing bracket
            (_result, _resultCtr, _stack) = _processClosingParenthesis(_stack, _result, _resultCtr);
        }

        return (_result, _resultCtr, _stack);
    }

    /**
     * @dev Process closing parenthesis
     * @param _stack Stack that is used to process parenthesis
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @return Modified _result array, mofified _resultCtr, and modified _stack
     */
    function _processClosingParenthesis(
        string[] memory _stack,
        string[] memory _result,
        uint256 _resultCtr
    ) public pure returns (string[] memory, uint256, string[] memory) {
        while (!_stack.seeLastInStack().equal('(')) {
            (_stack, _result[_resultCtr++]) = _stack.popFromStack();
        }
        (_stack, ) = _stack.popFromStack(); // remove '(' that is left
        return (_result, _resultCtr, _stack);
    }

    /**
     * @dev Process curly brackets
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _chunk The current piece of code that we're processing
     * @return Modified _result array, mofified _resultCtr
     */
    function _processCurlyBracket(
        string[] memory _result,
        uint256 _resultCtr,
        string memory _chunk
    ) internal pure returns (string[] memory, uint256) {
        // if `_chunk` equal `{` - do nothing
        if (_chunk.equal('}')) {
            _result[_resultCtr++] = 'end';
        }

        return (_result, _resultCtr);
    }

    /**
     * @dev Process any operator in DSL
     * @param _stack Stack that is used to process parenthesis
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _ctxAddr Context contract address
     * @param _chunk The current piece of code that we're processing
     * @return Modified _result array, mofified _resultCtr, and modified _stack
     */
    function _processOperator(
        string[] memory _stack,
        string[] memory _result,
        uint256 _resultCtr,
        address _ctxAddr,
        string memory _chunk
    ) internal view returns (string[] memory, uint256, string[] memory) {
        while (
            _stack.stackLength() > 0 &&
            IDSLContext(_ctxAddr).opsPriors(_chunk) <=
            IDSLContext(_ctxAddr).opsPriors(_stack.seeLastInStack())
        ) {
            (_stack, _result[_resultCtr++]) = _stack.popFromStack();
        }
        _stack = _stack.pushToStack(_chunk);

        return (_result, _resultCtr, _stack);
    }

    /**************************
     * == HELPER FUNCTIONS == *
     *************************/

    /**
     * @dev Checks if chunk is a currency symbol
     * @param _chunk is a current chunk from the DSL string code
     * @return True or false based on whether chunk is a currency symbol or not
     */
    function _isCurrencySymbol(string memory _chunk) internal pure returns (bool) {
        return _chunk.equal('ETH') || _chunk.equal('GWEI');
    }

    /**
     * @dev Checks if chunk is an operator
     * @param _ctxAddr Context contract address
     * @return True or false based on whether chunk is an operator or not
     */
    function _isOperator(string memory _chunk, address _ctxAddr) internal view returns (bool) {
        for (uint256 i = 0; i < IDSLContext(_ctxAddr).operatorsLen(); i++) {
            if (_chunk.equal(IDSLContext(_ctxAddr).operators(i))) return true;
        }
        return false;
    }

    /**
     * @dev Checks if a string is an alias to a command from DSL
     * @param _ctxAddr Context contract address
     * @return True or false based on whether chunk is an alias or not
     */
    function _isAlias(string memory _chunk, address _ctxAddr) internal view returns (bool) {
        return !IDSLContext(_ctxAddr).aliases(_chunk).equal('');
    }

    /**
     * @dev Checks if chunk is a parenthesis
     * @param _chunk Current piece of code that we're processing
     * @return True or false based on whether chunk is a parenthesis or not
     */
    function _isParenthesis(string memory _chunk) internal pure returns (bool) {
        return _chunk.equal('(') || _chunk.equal(')');
    }

    /**
     * @dev Checks if chunk is a curly bracket
     * @param _chunk Current piece of code that we're processing
     * @return True or false based on whether chunk is a curly bracket or not
     */
    function _isCurlyBracket(string memory _chunk) internal pure returns (bool) {
        return _chunk.equal('{') || _chunk.equal('}');
    }

    /**
     * @dev Parses scientific notation in the chunk if there is any
     * @param _chunk Current piece of code that we're processing
     * @return Chunk without a scientific notation
     */
    function _checkScientificNotation(string memory _chunk) internal pure returns (string memory) {
        if (_chunk.mayBeNumber() && !_chunk.mayBeAddress()) {
            return _parseScientificNotation(_chunk);
        }
        return _chunk;
    }

    /**
     * @dev As the string of values can be simple and complex for DSL this function returns a number in
     * Wei regardless of what type of number parameter was provided by the user.
     * For example:
     * `uint256 1000000` - simple
     * `uint256 1e6 - complex`
     * @param _chunk provided number
     * @return updatedChunk amount in Wei of provided _chunk value
     */
    function _parseScientificNotation(
        string memory _chunk
    ) internal pure returns (string memory updatedChunk) {
        try _chunk.toUint256() {
            updatedChunk = _chunk;
        } catch {
            updatedChunk = _chunk.parseScientificNotation();
        }
    }

    /**
     * @dev Checks if chunk is a number or address and processes it if so
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @param _chunk Current piece of code that we're processing
     * @return Modified _result array, mofified _resultCtr
     */
    function _checkIsNumberOrAddress(
        string[] memory _result,
        uint256 _resultCtr,
        string memory _chunk
    ) internal pure returns (string[] memory, uint256) {
        if (_chunk.mayBeAddress()) return (_result, _resultCtr);
        if (_chunk.mayBeNumber()) {
            (_result, _resultCtr) = _addUint256(_result, _resultCtr);
        }

        return (_result, _resultCtr);
    }

    /**
     * @dev Adds `uint256` to a number
     * @param _result Output array that the function is modifying
     * @param _resultCtr Current pointer to the empty element in the _result param
     * @return Modified _result array, mofified _resultCtr
     */
    function _addUint256(
        string[] memory _result,
        uint256 _resultCtr
    ) internal pure returns (string[] memory, uint256) {
        if (_resultCtr == 0 || (!(_result[_resultCtr - 1].equal('uint256')))) {
            _result[_resultCtr++] = 'uint256';
        }
        return (_result, _resultCtr);
    }

    /**
     * @dev checks the value, and returns the corresponding multiplier.
     * If it is Ether, then it returns 1000000000000000000,
     * If it is GWEI, then it returns 1000000000
     * @param _chunk is a command from DSL command list
     * @return returns the corresponding multiplier.
     */
    function _getCurrencyMultiplier(string memory _chunk) internal pure returns (uint256) {
        if (_chunk.equal('ETH')) {
            return 1000000000000000000;
        } else if (_chunk.equal('GWEI')) {
            return 1000000000;
        } else return 0;
    }

    /**
     * @dev Checks if a symbol is a comment, then increases `i` to the next
     * no-comment symbol avoiding an additional iteration
     * @param i is a current index of a char that might be changed
     * @param _program is a current program string
     * @param _char Current character
     * @return Searched symbol length
     * @return New index
     * @return Is code commented or not
     */
    function _getCommentSymbol(
        uint256 i,
        string memory _program,
        string memory _char
    ) internal pure returns (uint256, uint256, bool) {
        if (_canGetSymbol(i + 1, _program)) {
            string memory nextChar = _program.char(i + 1);
            if (_char.equal('/') && nextChar.equal('/')) {
                return (1, i + 2, true);
            } else if (_char.equal('/') && nextChar.equal('*')) {
                return (2, i + 2, true);
            }
        }
        return (0, i, false);
    }

    /**
     * @dev Checks if a symbol is an end symbol of a comment, then increases _index to the next
     * no-comment symbol avoiding an additional iteration
     * @param _ssl is a searched symbol len that might be 0, 1, 2
     * @param i is a current index of a char that might be changed
     * @param _p is a current program string
     * @param _char Current character
     * @return A new index of a char
     * @return Is code commented or not
     */
    function _getEndCommentSymbol(
        uint256 _ssl,
        uint256 i,
        string memory _p,
        string memory _char
    ) internal pure returns (uint256, bool) {
        if (_ssl == 1 && _char.equal('\n')) {
            return (i + 1, false);
        } else if (_ssl == 2 && _char.equal('*') && _canGetSymbol(i + 1, _p)) {
            string memory nextChar = _p.char(i + 1);
            if (nextChar.equal('/')) {
                return (i + 2, false);
            }
        }
        return (i, true);
    }

    /**
     * @dev Checks if it is possible to get next char from a _program
     * @param _index is a current index of a char
     * @param _program is a current program string
     * @return True if program has the next symbol, otherwise is false
     */
    function _canGetSymbol(uint256 _index, string memory _program) internal pure returns (bool) {
        try _program.char(_index) {
            return true;
        } catch Error(string memory) {
            return false;
        }
    }

    /**
     * @dev Returns the length of a string array excluding empty elements
     * Ex. nonEmptyArrLen['h', 'e', 'l', 'l', 'o', '', '', '']) == 5 (not 8)
     * @param _arr Input string array
     * @return i The legth of the array excluding empty elements
     */
    function _nonEmptyArrLen(string[] memory _arr) internal pure returns (uint256 i) {
        while (i < _arr.length && !_arr[i].equal('')) {
            i++;
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ErrorsStringUtils } from './Errors.sol';
import { ByteUtils } from './ByteUtils.sol';

/**
 * @dev Library that simplifies working with strings in Solidity
 */
library StringUtils {
    /**
     * @dev Get character in string by index
     * @param _s Input string
     * @param _index Target index in the string
     * @return Character by index
     */
    function char(string memory _s, uint256 _index) public pure returns (string memory) {
        require(_index < length(_s), ErrorsStringUtils.SUT1);
        bytes memory _sBytes = new bytes(1);
        _sBytes[0] = bytes(_s)[_index];
        return string(_sBytes);
    }

    /**
     * @dev Compares two strings
     * @param _s1 One string
     * @param _s2 Another string
     * @return Are string equal
     */
    function equal(string memory _s1, string memory _s2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(_s1)) == keccak256(abi.encodePacked(_s2));
    }

    /**
     * @dev Gets length of the string
     * @param _s Input string
     * @return The lenght of the string
     */
    function length(string memory _s) internal pure returns (uint256) {
        return bytes(_s).length;
    }

    /**
     * @dev Concats two strings
     * @param _s1 One string
     * @param _s2 Another string
     * @return The concatenation of the strings
     */
    function concat(string memory _s1, string memory _s2) internal pure returns (string memory) {
        return string(abi.encodePacked(_s1, _s2));
    }

    /**
     * @dev Creates a substring from a string
     * Ex. substr('0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE', 2, 42) => '9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE'
     * @param _str Input string
     * @param _start Start index (inclusive)
     * @param _end End index (not inclusive)
     * @return Substring
     */
    function substr(
        string memory _str,
        uint256 _start,
        uint256 _end
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        bytes memory result = new bytes(_end - _start);
        for (uint256 i = _start; i < _end; i++) {
            result[i - _start] = strBytes[i];
        }
        return string(result);
    }

    /**
     * @dev Checks is _char is present in the _string
     * Ex. `_`.in('123_456') => true
     * Ex. `8`.in('123456') => false
     * @param _char Searched character
     * @param _string String to search in
     * @return Is the character presented in the string
     */
    function isIn(string memory _char, string memory _string) public pure returns (bool) {
        for (uint256 i = 0; i < length(_string); i++) {
            if (equal(char(_string, i), _char)) return true;
        }
        return false;
    }

    // Convert an hexadecimal string (without "0x" prefix) to raw bytes
    function fromHex(string memory s) public pure returns (bytes memory) {
        return ByteUtils.fromHexBytes(bytes(s));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation
     * @notice Inspired by OraclizeAPI's implementation - MIT licence
     * https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol
     * @param _num Input number
     * @return Number represented as a string
     */
    function toString(uint256 _num) internal pure returns (string memory) {
        if (_num == 0) {
            return '0';
        }
        uint256 _temp = _num;
        uint256 _digits;
        while (_temp != 0) {
            _digits++;
            _temp /= 10;
        }
        bytes memory _buffer = new bytes(_digits);
        while (_num != 0) {
            _digits -= 1;
            _buffer[_digits] = bytes1(uint8(48 + uint256(_num % 10)));
            _num /= 10;
        }
        return string(_buffer);
    }

    /**
     * @dev Converts a decimal number (provided as a string) to uint256
     * @param _s Input decimal number (provided as a string)
     * @return value Unsigned integer from input string
     */
    function toUint256(string memory _s) public pure returns (uint256 value) {
        bytes memory b = bytes(_s);
        uint256 tmp;
        for (uint256 i = 0; i < b.length; i++) {
            tmp = uint8(b[i]);
            require(tmp >= 0x30 && tmp <= 0x39, ErrorsStringUtils.SUT3);
            value = value * 10 + (tmp - 0x30); // 0x30 ascii is '0'
        }
    }

    /**
     * @dev Converts a decimal number (provided as a string) with e symbol (1e18) to number (returned as a string)
     * @param _s Input decimal number (provided as a string)
     * @return result Unsigned integer in a string format
     */
    function parseScientificNotation(string memory _s) public pure returns (string memory result) {
        bool isFound; // was `e` symbol found
        uint256 tmp;
        bytes memory b = bytes(_s);
        string memory base;
        string memory decimals;

        for (uint256 i = 0; i < b.length; i++) {
            tmp = uint8(b[i]);

            if (tmp >= 0x30 && tmp <= 0x39) {
                if (!isFound) {
                    base = concat(base, string(abi.encodePacked(b[i])));
                } else {
                    decimals = concat(decimals, string(abi.encodePacked(b[i])));
                }
            } else if (tmp == 0x65 && !isFound) {
                isFound = true;
            } else {
                // use only one `e` sympol between values without spaces; example: 1e18 or 456e10
                revert(ErrorsStringUtils.SUT5);
            }
        }

        require(!equal(base, ''), ErrorsStringUtils.SUT9);
        require(!equal(decimals, ''), ErrorsStringUtils.SUT6);
        result = toString(toUint256(base) * (10 ** toUint256(decimals)));
    }

    /**
     * @dev If the string starts with a number, so we assume that it's a number.
     * @param _string is a current string for checking
     * @return isNumber that is true if the string starts with a number, otherwise is false
     */
    function mayBeNumber(string memory _string) public pure returns (bool) {
        require(!equal(_string, ''), ErrorsStringUtils.SUT7);
        bytes1 _byte = bytes(_string)[0];
        return uint8(_byte) >= 48 && uint8(_byte) <= 57;
    }

    /**
     * @dev If the string starts with `0x` symbols, so we assume that it's an address.
     * @param _string is a current string for checking
     * @return isAddress that is true if the string starts with `0x` symbols, otherwise is false
     */
    function mayBeAddress(string memory _string) public pure returns (bool) {
        require(!equal(_string, ''), ErrorsStringUtils.SUT7);
        if (bytes(_string).length != 42) return false;

        bytes1 _byte = bytes(_string)[0];
        bytes1 _byte2 = bytes(_string)[1];
        return uint8(_byte) == 48 && uint8(_byte2) == 120;
    }

    /**
     * @dev Checks is string is a valid DSL variable name (matches regexp /^([A-Z_$][A-Z\d_$]*)$/g)
     * @param _s is a current string to check
     * @return isCapital whether the string is a valid DSL variable name or not
     */
    function isValidVarName(string memory _s) public pure returns (bool) {
        require(!equal(_s, ''), ErrorsStringUtils.SUT7);

        uint8 A = 0x41;
        uint8 Z = 0x5a;
        uint8 underscore = 0x5f;
        uint8 dollar = 0x24;
        uint8 zero = 0x30;
        uint8 nine = 0x39;

        uint8 symbol;
        // This is the same as applying regexp /^([A-Z_$][A-Z\d_$]*)$/g
        for (uint256 i = 0; i < length(_s); i++) {
            symbol = uint8(bytes(_s)[i]);
            if (
                (i == 0 &&
                    !((symbol >= A && symbol <= Z) || symbol == underscore || symbol == dollar)) ||
                (i > 0 &&
                    !((symbol >= A && symbol <= Z) ||
                        (symbol >= zero && symbol <= nine) ||
                        symbol == underscore ||
                        symbol == dollar))
            ) {
                return false;
            }
        }
        return true;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ErrorsStack } from '../libs/Errors.sol';
import { StringUtils } from './StringUtils.sol';

// TODO: add tests for this file
/**
 * @dev This library has all the functions to use solidity string array as a struct
 */
library StringStack {
    using StringUtils for string;

    /**
     * @dev Push element to array in the first position
     * As the array has fixed size, we drop the last element
     * when addind a new one to the beginning of the array
     * @param _stack String stack
     * @param _element String to be added to the stack
     * @return Modified stack
     */
    function pushToStack(
        string[] memory _stack,
        string memory _element
    ) external pure returns (string[] memory) {
        _stack[stackLength(_stack)] = _element;
        return _stack;
    }

    function popFromStack(
        string[] memory _stack
    ) external pure returns (string[] memory, string memory) {
        string memory _topElement = seeLastInStack(_stack);
        _stack[stackLength(_stack) - 1] = '';
        return (_stack, _topElement);
    }

    function stackLength(string[] memory _stack) public pure returns (uint256) {
        uint256 i;
        while (!_stack[i].equal('')) {
            i++;
        }
        return i;
    }

    function seeLastInStack(string[] memory _stack) public pure returns (string memory) {
        uint256 _len = stackLength(_stack);
        require(_len > 0, ErrorsStack.STK4);
        return _stack[_len - 1];
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IPreprocessor {
    function transform(
        address _ctxAddr,
        string memory _program
    ) external view returns (string[] memory);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ErrorsByteUtils } from './Errors.sol';

// import "hardhat/console.sol";

/**
 * Library to simplify working with bytes
 */
library ByteUtils {
    function slice(
        bytes calldata _data,
        uint256 _start,
        uint256 _end
    ) public pure returns (bytes memory) {
        require(_start < _end, ErrorsByteUtils.BUT1);
        require(_end <= _data.length, ErrorsByteUtils.BUT2);
        return _data[_start:_end];
    }

    /**
     * Convert an hexadecimal string in bytes (without "0x" prefix) to raw bytes
     */
    function fromHexBytes(bytes memory ss) public pure returns (bytes memory) {
        require(ss.length % 2 == 0, ErrorsByteUtils.BUT4); // length must be even
        bytes memory r = new bytes(ss.length / 2);
        for (uint256 i = 0; i < ss.length / 2; ++i) {
            r[i] = bytes1(fromHexChar(ss[2 * i]) * 16 + fromHexChar(ss[2 * i + 1]));
        }
        return r;
    }

    /**
     * @dev Convert an hexadecimal character to their value
     */
    function fromHexChar(bytes1 c) public pure returns (uint8) {
        if (c >= bytes1('0') && c <= bytes1('9')) {
            return uint8(c) - uint8(bytes1('0'));
        }
        if (c >= bytes1('a') && c <= bytes1('f')) {
            return 10 + uint8(c) - uint8(bytes1('a'));
        }
        if (c >= bytes1('A') && c <= bytes1('F')) {
            return 10 + uint8(c) - uint8(bytes1('A'));
        }
        revert(ErrorsByteUtils.BUT3);
    }
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../helpers/Stack.sol';

interface IProgramContext {
    // Variables
    function ANYONE() external view returns (address);

    function stack() external view returns (Stack);

    function program() external view returns (bytes memory);

    function currentProgram() external view returns (bytes memory);

    function programAt(uint256 _start, uint256 _size) external view returns (bytes memory);

    function pc() external view returns (uint256);

    function nextpc() external view returns (uint256);

    function appAddr() external view returns (address);

    function msgSender() external view returns (address);

    function msgValue() external view returns (uint256);

    function isStructVar(string memory _varName) external view returns (bool);

    function labelPos(string memory _name) external view returns (uint256);

    function setLabelPos(string memory _name, uint256 _value) external;

    function forLoopIterationsRemaining() external view returns (uint256);

    function setProgram(bytes memory _data) external;

    function setPc(uint256 _pc) external;

    function setNextPc(uint256 _nextpc) external;

    function incPc(uint256 _val) external;

    function setMsgSender(address _msgSender) external;

    function setMsgValue(uint256 _msgValue) external;

    function setStructVars(
        string memory _structName,
        string memory _varName,
        string memory _fullName
    ) external;

    function structParams(
        bytes4 _structName,
        bytes4 _varName
    ) external view returns (bytes4 _fullName);

    function setForLoopIterationsRemaining(uint256 _forLoopIterationsRemaining) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILinkedList {
    function getType(bytes32 _arrName) external view returns (bytes1);

    function getLength(bytes32 _arrName) external view returns (uint256);

    function get(uint256 _index, bytes32 _arrName) external view returns (bytes32 data);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library UnstructuredStorage {
    function getStorageBool(bytes32 position) internal view returns (bool data) {
        assembly {
            data := sload(position)
        }
    }

    function getStorageAddress(bytes32 position) internal view returns (address data) {
        assembly {
            data := sload(position)
        }
    }

    function getStorageBytes32(bytes32 position) internal view returns (bytes32 data) {
        assembly {
            data := sload(position)
        }
    }

    function getStorageUint256(bytes32 position) internal view returns (uint256 data) {
        assembly {
            data := sload(position)
        }
    }

    function setStorageBool(bytes32 position, bytes32 data) internal {
        bool val = data != bytes32(0);
        assembly {
            sstore(position, val)
        }
    }

    function setStorageBool(bytes32 position, bool data) internal {
        assembly {
            sstore(position, data)
        }
    }

    function setStorageAddress(bytes32 position, bytes32 data) internal {
        address val = address(bytes20(data));
        assembly {
            sstore(position, val)
        }
    }

    function setStorageAddress(bytes32 position, address data) internal {
        assembly {
            sstore(position, data)
        }
    }

    function setStorageBytes32(bytes32 position, bytes32 data) internal {
        assembly {
            sstore(position, data)
        }
    }

    function setStorageUint256(bytes32 position, bytes32 data) internal {
        uint256 val = uint256(bytes32(data));
        assembly {
            sstore(position, val)
        }
    }

    function setStorageUint256(bytes32 position, uint256 data) internal {
        assembly {
            sstore(position, data)
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IDSLContext } from '../../interfaces/IDSLContext.sol';
import { IProgramContext } from '../../interfaces/IProgramContext.sol';
import { StringUtils } from '../StringUtils.sol';
import { UnstructuredStorage } from '../UnstructuredStorage.sol';
import { ErrorsOpcodeHelpers } from '../Errors.sol';

// import 'hardhat/console.sol';

/**
 * @title Opcode helper functions
 * @notice Opcode helper functions that are used in other opcode libraries
 * @dev Opcode libraries are: ComparisonOpcodes, BranchingOpcodes, LogicalOpcodes, and OtherOpcodes
 */
library OpcodeHelpers {
    using UnstructuredStorage for bytes32;
    using StringUtils for string;

    // TODO: get rid of putToStack function
    function putToStack(address _ctxProgram, uint256 _value) public {
        IProgramContext(_ctxProgram).stack().push(_value);
    }

    function nextBytes(address _ctxProgram, uint256 size) public returns (bytes memory out) {
        out = IProgramContext(_ctxProgram).programAt(IProgramContext(_ctxProgram).pc(), size);
        IProgramContext(_ctxProgram).incPc(size);
    }

    function nextBytes1(address _ctxProgram) public returns (bytes1) {
        return nextBytes(_ctxProgram, 1)[0];
    }

    /**
     * @dev Reads the slice of bytes from the raw program
     * @dev Warning! The maximum slice size can only be 32 bytes!
     * @param _ctxProgram Context contract address
     * @param _start Start position to read
     * @param _end End position to read
     * @return res Bytes32 slice of the raw program
     */
    function readBytesSlice(
        address _ctxProgram,
        uint256 _start,
        uint256 _end
    ) public view returns (bytes32 res) {
        bytes memory slice = IProgramContext(_ctxProgram).programAt(_start, _end - _start);
        // Convert bytes to bytes32
        assembly {
            res := mload(add(slice, 0x20))
        }
    }

    function nextBranchSelector(
        address _ctxDSL,
        address _ctxProgram,
        string memory baseOpName
    ) public returns (bytes4) {
        bytes1 branchCode = nextBytes1(_ctxProgram);
        return IDSLContext(_ctxDSL).branchSelectors(baseOpName, branchCode);
    }

    /**
     * @dev Check .call() function and returns data
     * @param addr Context contract address
     * @param data Abi fubction with params
     * @return callData returns data from call
     */
    function mustCall(address addr, bytes memory data) public returns (bytes memory) {
        (bool success, bytes memory callData) = addr.call(data);
        require(success, ErrorsOpcodeHelpers.OPH1);
        return callData;
    }

    /**
     * @dev Check .delegatecall() function and returns data
     * @param addr Context contract address
     * @param data Abi fubction with params
     * @return delegateCallData returns data from call
     */
    function mustDelegateCall(address addr, bytes memory data) public returns (bytes memory) {
        (bool success, bytes memory delegateCallData) = addr.delegatecall(data);
        require(success, ErrorsOpcodeHelpers.OPH2);
        return delegateCallData;
    }

    function getNextBytes(
        address _ctxProgram,
        uint256 _bytesNum
    ) public returns (bytes32 varNameB32) {
        bytes memory varName = nextBytes(_ctxProgram, _bytesNum);

        // Convert bytes to bytes32
        assembly {
            varNameB32 := mload(add(varName, 0x20))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Interface of the cToken that defined as asset in https://v2-app.compound.finance/
 */
interface IcToken {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function mint(uint256 mintAmount) external returns (uint);

    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeem(uint256 redeemTokens) external returns (uint);

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (uint256.max means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

import { IERC20 } from './IERC20.sol';

/**
 * @dev Interface of ERC20 token with `mint` and `burn` functions
 */
interface IERC20Mintable is IERC20 {
    function mint(address _to, uint256 _amount) external;

    function burn(address _to, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >= 0.4.22 <0.9.0;

library console {
	address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

	function _sendLogPayload(bytes memory payload) private view {
		uint256 payloadLength = payload.length;
		address consoleAddress = CONSOLE_ADDRESS;
		assembly {
			let payloadStart := add(payload, 32)
			let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
		}
	}

	function log() internal view {
		_sendLogPayload(abi.encodeWithSignature("log()"));
	}

	function logInt(int256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int256)", p0));
	}

	function logUint(uint256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
	}

	function logString(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function logBool(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function logAddress(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function logBytes(bytes memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
	}

	function logBytes1(bytes1 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
	}

	function logBytes2(bytes2 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
	}

	function logBytes3(bytes3 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
	}

	function logBytes4(bytes4 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
	}

	function logBytes5(bytes5 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
	}

	function logBytes6(bytes6 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
	}

	function logBytes7(bytes7 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
	}

	function logBytes8(bytes8 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
	}

	function logBytes9(bytes9 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
	}

	function logBytes10(bytes10 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
	}

	function logBytes11(bytes11 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
	}

	function logBytes12(bytes12 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
	}

	function logBytes13(bytes13 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
	}

	function logBytes14(bytes14 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
	}

	function logBytes15(bytes15 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
	}

	function logBytes16(bytes16 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
	}

	function logBytes17(bytes17 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
	}

	function logBytes18(bytes18 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
	}

	function logBytes19(bytes19 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
	}

	function logBytes20(bytes20 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
	}

	function logBytes21(bytes21 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
	}

	function logBytes22(bytes22 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
	}

	function logBytes23(bytes23 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
	}

	function logBytes24(bytes24 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
	}

	function logBytes25(bytes25 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
	}

	function logBytes26(bytes26 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
	}

	function logBytes27(bytes27 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
	}

	function logBytes28(bytes28 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
	}

	function logBytes29(bytes29 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
	}

	function logBytes30(bytes30 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
	}

	function logBytes31(bytes31 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
	}

	function logBytes32(bytes32 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
	}

	function log(uint256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
	}

	function log(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function log(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function log(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function log(uint256 p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256)", p0, p1));
	}

	function log(uint256 p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string)", p0, p1));
	}

	function log(uint256 p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool)", p0, p1));
	}

	function log(uint256 p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address)", p0, p1));
	}

	function log(string memory p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256)", p0, p1));
	}

	function log(string memory p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
	}

	function log(string memory p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
	}

	function log(string memory p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
	}

	function log(bool p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256)", p0, p1));
	}

	function log(bool p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
	}

	function log(bool p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
	}

	function log(bool p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
	}

	function log(address p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256)", p0, p1));
	}

	function log(address p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
	}

	function log(address p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
	}

	function log(address p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
	}

	function log(uint256 p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
	}

	function log(string memory p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256)", p0, p1, p2));
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
	}

	function log(string memory p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
	}

	function log(string memory p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
	}

	function log(bool p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256)", p0, p1, p2));
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
	}

	function log(bool p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
	}

	function log(bool p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
	}

	function log(bool p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256)", p0, p1, p2));
	}

	function log(bool p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
	}

	function log(bool p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
	}

	function log(bool p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256)", p0, p1, p2));
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
	}

	function log(address p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
	}

	function log(address p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
	}

	function log(address p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256)", p0, p1, p2));
	}

	function log(address p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
	}

	function log(address p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
	}

	function log(address p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
	}

	function log(address p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256)", p0, p1, p2));
	}

	function log(address p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
	}

	function log(address p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
	}

	function log(address p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
	}

}