/**
 *Submitted for verification at Etherscan.io on 2023-02-07
*/

// SPDX-License-Identifier: MIT
interface IERC20 {
    function transferFrom(address from,address to,uint256 amount) external returns (bool);
}

interface USDT {
    function transferFrom(address sender, address recipient, uint256 amount) external;
}

contract Transfer {

    constructor(){
    }

    function transfer(address token, address[] memory dests, uint256[] memory values) external{

        require(dests.length == values.length,"length not match");

        for(uint256 i=0;i<dests.length;i++){
            IERC20(token).transferFrom(msg.sender, dests[i], values[i]);
        }

    }


    function transferUSDT(address token, address[] memory dests, uint256[] memory values) external{

        require(dests.length == values.length,"length not match");

        for(uint256 i=0;i<dests.length;i++){
            USDT(token).transferFrom(msg.sender, dests[i], values[i]);
        }

    }

}