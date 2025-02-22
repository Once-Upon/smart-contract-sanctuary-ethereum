// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC721A.sol";
import "./Ownable.sol";
import "./Counters.sol";
import "./MerkelProof.sol";

contract ERC721A_Cont is ERC721A, Ownable {

  // MintPrice = "Free Mint"

  string _baseTokenURI;
  bytes32 public merkleRoot;

  bool public isActive = false;
  bool public isWhitelistSaleActive = false;

  uint256 public MAX_SUPPLY = 1000;
  uint256 public maximumAllowedTokensPerPurchase = 2;
  uint256 public maximumAllowedTokensPerWallet = 3;
  uint256 public whitelistWalletLimitation = 2;

  mapping(address => uint256) private _whitelistWalletMints;
  mapping(address => uint256) private _publicWalletMints;


  constructor(string memory baseURI) ERC721A("ERC721A", "E7") {
    setBaseURI(baseURI);
  }

  modifier saleIsOpen {
    require(totalSupply() <= MAX_SUPPLY, "Sale has ended.");
    _;
  }

  // Minting for devs to use in future giveaways and raffles and treasury

  function devMint(uint256 _count, address _address) external onlyOwner {
    uint256 supply = totalSupply();

    require(supply + _count <= MAX_SUPPLY, "Total supply exceeded.");
    require(supply <= MAX_SUPPLY, "Total supply spent.");

    _safeMint(_address, _count);
  }

  // Free mint for whitelisted people

  function whitelistMint(bytes32[] calldata _merkleProof, uint256 _count) public payable isValidMerkleProof(_merkleProof) saleIsOpen {
    uint256 mintIndex = totalSupply();

    require(isWhitelistSaleActive, "Presale is not active");
    require(mintIndex < MAX_SUPPLY, "All tokens have been minted");
    require(balanceOf(msg.sender) + _count <= whitelistWalletLimitation, "Cannot purchase this many tokens");
    require(_whitelistWalletMints[msg.sender] + _count <= 2, "You have already minted max");

    _whitelistWalletMints[msg.sender] += _count;

    _safeMint(msg.sender, _count);

  }

  // Free mint for public

  function mint(uint256 _count) public payable saleIsOpen {
    uint256 mintIndex = totalSupply();

    require(isActive, "Sale is not active currently.");
    require(balanceOf(msg.sender) + _count <= maximumAllowedTokensPerWallet, "Max holding cap reached.");
    require(mintIndex + _count <= MAX_SUPPLY, "Total supply exceeded.");
    require( _count <= maximumAllowedTokensPerPurchase, "Exceeds maximum allowed tokens");
    require(_publicWalletMints[msg.sender] + _count <= 1, "You have already minted or minting more than allowed.");


    _publicWalletMints[msg.sender] += _count;

    _safeMint(msg.sender, _count);
    
  }

  modifier isValidMerkleProof(bytes32[] calldata merkleProof) {
      require(
          MerkleProof.verify(
              merkleProof,
              merkleRoot,
              keccak256(abi.encodePacked(msg.sender))
          ),
          "Address does not exist in list"
      );
    _;
  }

  function setMerkleRootHash(bytes32 _rootHash) public onlyOwner {
    merkleRoot = _rootHash;
  }
  
  function setWhitelistSaleWalletLimitation(uint256 maxMint) external  onlyOwner {
    whitelistWalletLimitation = maxMint;
  }

  function setMaximumAllowedTokens(uint256 _count) public onlyOwner {
    maximumAllowedTokensPerPurchase = _count;
  }

  function setMaximumAllowedTokensPerWallet(uint256 _count) public onlyOwner {
    maximumAllowedTokensPerWallet = _count;
  }

  function setMaxMintSupply(uint256 maxMintSupply) external  onlyOwner {
    MAX_SUPPLY = maxMintSupply;
  }

  function toggleSaleStatus() public onlyOwner {
    isActive = !isActive;
  }

  function toggleWhiteslistSaleStatus() external onlyOwner {
    isWhitelistSaleActive = !isWhitelistSaleActive;
  }

  function setBaseURI(string memory baseURI) public onlyOwner {
    _baseTokenURI = baseURI;
  }


  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function withdraw() external onlyOwner {
    uint balance = address(this).balance;
    payable(owner()).transfer(balance);
  }
}