// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract CrowdFunding {
    
    struct Campaign {
        address owner;
        string title;
        string description;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        string image;
        address[] donators;
        uint256[] donations;
    }

    mapping(uint256 => Campaign) public Campaigns;
    uint256 numberOfCampaigns = 0;

    function createCampaign(address _owner, string memory _title, string memory _description, uint256 _target,
    uint256 _deadline, string memory _image) public returns(uint256){

        Campaign storage campaign = Campaigns[numberOfCampaigns];

        require(campaign.deadline < block.timestamp , "The deadline should be a date of future.");
        campaign.owner = _owner;
        campaign.title = _title;
        campaign.description = _description;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;

        numberOfCampaigns++;

        return numberOfCampaigns-1;


    } 
    function  donateToCampaign(uint256 _id) public payable {
        uint256 amount = msg.value;
        Campaign storage campaign = Campaigns[_id];
        campaign.donators.push(msg.sender);
        campaign.donations.push(amount);
    }

    function getDonators(uint _id) public view returns(address[] memory , uint256[] memory) {
        return(Campaigns[_id].donators, Campaigns[_id].donations); 
    }

    function getCompaigns() public view returns(Campaign[] memory){

        Campaign[] memory allcampaign = new Campaign[](numberOfCampaigns);

         for(uint i=0 ;i<numberOfCampaigns; i++) {
            Campaign storage item = Campaigns[i];
            allcampaign[i] = item;
        }
        return (allcampaign);
    }
}