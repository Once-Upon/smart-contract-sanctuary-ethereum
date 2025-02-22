/**
 *Submitted for verification at Etherscan.io on 2022-07-26
*/

pragma solidity ^0.4.21;

contract FiftyYearsChallenge {
    struct Contribution {
        uint256 amount;
        uint256 unlockTimestamp;
    }
    Contribution[] queue;   // 0 amount change length
    uint256 head;           // 1 will be modify by last timestamp

    address owner;          // 2
    function FiftyYearsChallenge(address player) public payable {
        require(msg.value == 1 ether);

        owner = player;
        queue.push(Contribution(msg.value, now + 50 years));
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function upsert(uint256 index, uint256 timestamp) public payable {
        require(msg.sender == owner);

        if (index >= head && index < queue.length) {
            // Update existing contribution amount without updating timestamp.
            Contribution storage contribution = queue[index];
            contribution.amount += msg.value;
        } else {
            // Append a new contribution. Require that each contribution unlock
            // at least 1 day after the previous one.
            require(timestamp >= queue[queue.length - 1].unlockTimestamp + 1 days);

            // 重新设置长度
            contribution.amount = msg.value;
            // 重新设置head
            contribution.unlockTimestamp = timestamp;
            // 先设置上个长度后放置，所以长度 + 1
            queue.push(contribution);
        }
    }

    function withdraw(uint256 index) public {
        require(msg.sender == owner);
        require(now >= queue[index].unlockTimestamp);

        // Withdraw this and any earlier contributions.
        uint256 total = 0;
        for (uint256 i = head; i <= index; i++) {
            total += queue[i].amount;

            // Reclaim storage.
            delete queue[i];
        }

        // Move the head of the queue forward so we don't have to loop over
        // already-withdrawn contributions.
        head = index + 1;

        msg.sender.transfer(total);
    }

    function getBlockamount(uint256 _nIndex) public view returns(uint256) {
        return queue[_nIndex].amount;
    }

    function getBlocktimestamp(uint256 _nIndex) public view returns(uint256) {
        return queue[_nIndex].unlockTimestamp;
    }

    function getOwnne() public view returns(address) {
        return owner;
    }

    function getHead() public view returns(uint256) {
        return head;
    }

    function getLength() public view returns(uint256) {
        return queue.length;
    }
}