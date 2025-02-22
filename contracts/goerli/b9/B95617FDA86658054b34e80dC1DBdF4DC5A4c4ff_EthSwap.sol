pragma solidity ^0.5.0;

import "./Token.sol";

contract EthSwap {
    string public name = "EthSwap Instant Exchange";
    Token public token;
    uint256 public rate = 100;

    event TokensPurchased(
        address account,
        address token,
        uint256 amount,
        uint256 rate
    );

    event TokensSold(
        address account,
        address token,
        uint256 amount,
        uint256 rate
    );

    constructor(Token _token) public {
        token = _token;
    }

    function buyTokens() public payable {
        // Redemption rate = # of token they receive for 1 ether
        // Amount of Ethereum * Redemption rate
        uint256 tokenAmount = msg.value * rate;

        // require that the ethSwap has enough token balance
        require(token.balanceOf(address(this)) >= tokenAmount);

        // transfer tokens to user
        token.transfer(msg.sender, tokenAmount);

        // Emit an event
        emit TokensPurchased(msg.sender, address(token), tokenAmount, rate);
    }

    function sellTokens(uint256 _amount) public {
        // user cant sell more tokens than they have
        require(token.balanceOf(msg.sender) >= _amount);

        // Calculate the amount of ether to redeem
        uint256 etherAmount = _amount / rate;

        // Require ethSwap has enough Ether
        require(address(this).balance >= etherAmount);

        // Perform sale
        token.transferFrom(msg.sender, address(this), _amount);
        msg.sender.transfer(etherAmount);

        // emit an event
        emit TokensSold(msg.sender, address(token), _amount, rate);
    }
}

pragma solidity ^0.5.0;

contract Token {
    string public name = "DApp Token";
    string public symbol = "DAPP";
    uint256 public totalSupply = 1000000000000000000000000; // 1 million tokens
    uint8 public decimals = 18;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() public {
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address _to, uint256 _value)
        public
        returns (bool success)
    {
        require(balanceOf[msg.sender] >= _value);
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value)
        public
        returns (bool success)
    {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        require(_value <= balanceOf[_from]);
        require(_value <= allowance[_from][msg.sender]);
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
}