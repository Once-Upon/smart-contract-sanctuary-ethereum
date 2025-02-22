// SPDX-License-Identifier: MIT
// @author: Exotic Technology LTD




pragma solidity ^0.8.0;

import "./ERC721.sol";
import "./ownable.sol";
import "./ERC721enumerable.sol";
//import "./merkle.sol";





contract exxCollector is Ownable, ERC721, ERC721Enumerable {
    
    
    
    bool public saleIsActive = false;

    uint256 public  MAX_TOKEN = 101; 
    
    uint256  public royalty = 100;

    uint256 public SALE_START = 0;

    address LVScontract;

    string private _baseURIextended;

    string public PROVENANCE;
 

    mapping(address => uint) public minters;
    
    mapping(address => bool) private senders;
    
    mapping(uint => bool) private claimedLvs;
    mapping(uint => bool) private claimedXoxo;

    
    constructor() ERC721("EXX", "EX") {
       

        _baseURIextended = "ipfs://QmUAFYNCnMQ17TX9evuFJpE89ca5HZjyN3SEegLz3HB1XZ/"; //cover

        senders[msg.sender] = true; // add owner

    }

 

   function addSender(address _address) public onlyOwner  {
        
        require(_address != address(0));
        senders[_address] = true;
       
    }
    
    function removeSender(address _address) public onlyOwner {
        require(_address != address(0));
        senders[_address] = false;
        
    }


     function updateLvsAddress(address _contract)public {
        require(senders[_msgSender()]);
        LVScontract = _contract;
    }


   function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view override  returns (
        address receiver,
        uint256 royaltyAmount
    ){
        require(_exists(_tokenId));
        return (owner(), uint256(royalty * _salePrice / 1000));

    }


    function flipSaleState() public  {
        require(senders[_msgSender()]);
        saleIsActive = !saleIsActive;
    }



    function updateRoyalty(uint newRoyalty) public onlyOwner {
        royalty = newRoyalty ;
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
            super._beforeTokenTransfer(from, to, tokenId);
        }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
            return super.supportsInterface(interfaceId);
        }

    function setBaseURI(string memory baseURI_)  external {
             require(senders[_msgSender()]);
            _baseURIextended = baseURI_;
        }

    function _baseURI() internal view virtual override returns (string memory) {
            return _baseURIextended;
        }

    function setProvenance(string memory provenance) public onlyOwner {
            PROVENANCE = provenance;
        }



    function getSaleState() public view returns (bool) {
            return saleIsActive;
    }


   function updateMax(uint _max) public  {
            require(senders[_msgSender()]);
            
            uint256 ts = totalSupply();
            
            require(_max >= ts,"too low");

            MAX_TOKEN = _max;

        }
 



    function claimed(uint _tokenId)public view returns(bool){
        require(_exists(_tokenId), "nonexistent token");
        return claimedLvs[_tokenId]; 

    }

    
    function MintClaim () public {
        
        require(saleIsActive, "closed!");

        uint claimerBalance =  IERC721(LVScontract).balanceOf(_msgSender()); // check LVS balance for owner
        
        require(claimerBalance > 0,"NO LVS");

        uint256 ts = totalSupply();

        require(ts + claimerBalance <= MAX_TOKEN, "maxTotal");

        for (uint i = 0; i < claimerBalance; i++){ // add token to claimed list
               
            uint claimedLvsToken = IERC721Enumerable(LVScontract).tokenOfOwnerByIndex(_msgSender(),i);

            require(!claimedLvs[claimedLvsToken],"Claimed");
            claimedLvs[claimedLvsToken] = true;

             _safeMint(_msgSender(), claimedLvsToken);
            
        }

        
     

    }

    function burn(uint256 tokenId) external  {
        require(senders[_msgSender()]);
        require(ERC721.ownerOf(tokenId) == _msgSender(), "ERC721: transfer from incorrect owner");
        
        _burn(tokenId);
    }

    

    function withdraw(address _beneficiary) public onlyOwner {
        uint balance = address(this).balance;
        payable(_beneficiary).transfer(balance);
    }


    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "address");
       
        _transferOwnership(newOwner);

    }
    
}   

/*                                                                   
                               %%%%%*       /%%%%*                              
                         %%%                         %%                         
                     .%%                                 %%                     
                   %%                                       %                   
                 %%                                           %                 
               %%                                               %               
             .%     @@@@@@@@@@@@@@@@@@@@@               @@@@                    
            %%      @@@                @@@             @@@         ,            
            %       @@@                  @@@         @@@                        
           %%       &&&                   &@@@     @@@              %           
           %        &&&                     @@@@ @@@                            
          ,%        &&&&&&&&&&&&&&&&&&&%%(.   @@@@@                             
           %        %%%                      @@@@@@@                            
           %        %%%                    @@@@   @@@@                          
           %%       %%%                  @@@@       @@@             %           
            %%      %%%                 @@@           @@@          %            
             %%     %%%               @@@               @@@       %             
              %%    %%%%%%%%%%%%%%%%@@@                  @@@@    %              
                %%                                             %                
                  %%                                         %                  
                    %%                                     %                    
                       %%%                             %%                       
                            %%%                   %%#                           
                                    #%%%%%%%                 

*/