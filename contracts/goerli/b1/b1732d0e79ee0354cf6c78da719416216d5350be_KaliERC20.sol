/**
 *Submitted for verification at Etherscan.io on 2022-12-10
*/

/**
 *Submitted for verification at Etherscan.io on 2022-02-11
*/

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

/// @notice Single owner access control contract.
/// @author Modified from SushiSwap (https://github.com/sushiswap/trident/blob/master/contracts/TridentOwnable.sol)
abstract contract KaliOwnable {
    event OwnershipTransferred(address indexed from, address indexed to);

    event ClaimTransferred(address indexed from, address indexed to);

    error NotOwner();

    error NotPendingOwner();

    address public owner;

    address public pendingOwner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();

        _;
    }

    function _init(address owner_) internal {
        owner = owner_;

        emit OwnershipTransferred(address(0), owner_);
    }

    function claimOwner() public virtual {
        if (msg.sender != pendingOwner) revert NotPendingOwner();

        emit OwnershipTransferred(owner, msg.sender);

        owner = msg.sender;

        pendingOwner = address(0);
    }

    function transferOwner(address to, bool direct) public onlyOwner virtual {
        if (direct) {
            owner = to;

            emit OwnershipTransferred(msg.sender, to);
        } else {
            pendingOwner = to;

            emit ClaimTransferred(msg.sender, to);
        }
    }
}

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// License-Identifier: AGPL-3.0-only
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
contract KaliERC20 is KaliOwnable {
    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event PauseFlipped(bool paused);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();

    error Initialized();

    error NoArrayParity();

    error SignatureExpired();

    error InvalidSignature();

    /*///////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    string public details;

    uint8 public constant decimals = 18;

    /*///////////////////////////////////////////////////////////////
                            ERC-20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*///////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal INITIAL_CHAIN_ID;

    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*///////////////////////////////////////////////////////////////
                            DAO STORAGE
    //////////////////////////////////////////////////////////////*/

    bool public paused;

    modifier notPaused() {
        if (paused) revert Paused();

        _;
    }

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function init(
        string calldata name_,
        string calldata symbol_,
        string calldata details_,
        address[] calldata accounts_,
        uint256[] calldata amounts_,
        bool paused_,
        address owner_
    ) public virtual {
        if (INITIAL_CHAIN_ID != 0) revert Initialized();

        if (accounts_.length != amounts_.length) revert NoArrayParity();

        name = name_;

        symbol = symbol_;

        details = details_;

        paused = paused_;

        INITIAL_CHAIN_ID = block.chainid;

        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();

        // cannot realistically overflow on human timescales
        unchecked {
            for (uint256 i; i < accounts_.length; i++) {
                _mint(accounts_[i], amounts_[i]);
            }
        }

        KaliOwnable._init(owner_);
    }

    /*///////////////////////////////////////////////////////////////
                            ERC-20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public notPaused virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public notPaused virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // saves gas for limited approvals

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*///////////////////////////////////////////////////////////////
                            EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > deadline) revert SignatureExpired();

        // cannot realistically overflow on human timescales
        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
                            ),
                            owner,
                            spender,
                            value,
                            nonces[owner]++,
                            deadline
                        )
                    )
                )
            );

            address recoveredAddress = ecrecover(digest, v, r, s);

            if (recoveredAddress == address(0) || recoveredAddress != owner) revert InvalidSignature();

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                    keccak256(bytes(name)),
                    keccak256('1'),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*///////////////////////////////////////////////////////////////
                            MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // cannot underflow because a user's balance
        // will never be larger than the total supply
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) public virtual {
        uint256 allowed = allowance[from][msg.sender]; // saves gas for limited approvals

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        _burn(from, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            GOV LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) public onlyOwner virtual {
        _mint(to, amount);
    }

    function ownerBurn(address from, uint256 amount) public onlyOwner virtual {
        _burn(from, amount);
    }

    function flipPause() public onlyOwner virtual {
        paused = !paused;

        emit PauseFlipped(paused);
    }
}

/// @notice Helper utility that enables calling multiple local methods in a single call.
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol)
abstract contract Multicall {
    function multicall(bytes[] calldata data) public virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);
        
        // cannot realistically overflow on human timescales
        unchecked {
            for (uint256 i = 0; i < data.length; i++) {
                (bool success, bytes memory result) = address(this).delegatecall(data[i]);

                if (!success) {
                    if (result.length < 68) revert();
                    
                    assembly {
                        result := add(result, 0x04)
                    }
                    
                    revert(abi.decode(result, (string)));
                }
                results[i] = result;
            }
        }
    }
}

/// @notice Factory to deploy Kali ERC20.
contract KaliERC20factory is Multicall {
    event ERC20deployed(
        KaliERC20 indexed kaliERC20, 
        string name, 
        string symbol, 
        string details, 
        address[] accounts,
        uint256[] amounts,
        bool paused,
        address indexed owner
    );

    error NullDeploy();

    address private immutable erc20Master;

    constructor(address erc20Master_) {
        erc20Master = erc20Master_;
    }
    
    function deployKaliERC20(
        string calldata name_,
        string memory symbol_,
        string calldata details_,
        address[] calldata accounts_,
        uint256[] calldata amounts_,
        bool paused_,
        address owner_
    ) public virtual returns (KaliERC20 kaliERC20) {
        kaliERC20 = KaliERC20(_cloneAsMinimalProxy(erc20Master, name_));
        
        kaliERC20.init(
            name_,
            symbol_,
            details_,
            accounts_,
            amounts_,
            paused_,
            owner_
        );

        emit ERC20deployed(kaliERC20, name_, symbol_, details_, accounts_, amounts_, paused_, owner_);
    }

    /// @dev modified from Aelin (https://github.com/AelinXYZ/aelin/blob/main/contracts/MinimalProxyFactory.sol)
    function _cloneAsMinimalProxy(address base, string memory name_) internal virtual returns (address clone) {
        bytes memory createData = abi.encodePacked(
            // constructor
            bytes10(0x3d602d80600a3d3981f3),
            // proxy code
            bytes10(0x363d3d373d3d3d363d73),
            base,
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );

        bytes32 salt = keccak256(bytes(name_));

        assembly {
            clone := create2(
                0, // no value
                add(createData, 0x20), // data
                mload(createData),
                salt
            )
        }
        // if CREATE2 fails for some reason, address(0) is returned
        if (clone == address(0)) revert NullDeploy();
    }
}