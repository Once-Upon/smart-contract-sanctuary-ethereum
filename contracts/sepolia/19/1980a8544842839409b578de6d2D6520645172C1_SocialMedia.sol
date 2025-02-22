/**
 *Submitted for verification at Etherscan.io on 2023-06-05
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract SocialMedia{
    mapping (string => user) public users;
    post[] public posts;
    uint public postNum = 0;
    uint public userid = 0;
    
    event PostCreated(
        address addr,
        string post
    );

    event Success(
        bool success,
        string text
    );

    struct user {
        uint id;
        string name;
        string privateKey;
        uint[] posts;
        bool account;
    }

    struct post {
        uint id;
        string title;
        string body;
        uint date;
        uint likes;
    }

    function createPost(string memory title, string memory p,string memory privateKey) public{
        user storage currentUser = users[privateKey];
        currentUser.posts.push(postNum);
        users[privateKey] = currentUser;
        post memory newPost = post({id: users[privateKey].id, title: title, body: p, date: block.timestamp, likes: 0});
        posts.push(newPost);
        postNum++;
        emit PostCreated(msg.sender,"New post was created");
    }

    function signin(string memory username,string memory privateKey) public {
        if(users[privateKey].account == false){
            users[privateKey] = user({id: userid, name: username,privateKey: privateKey, posts: new uint[](0), account: true});
            userid++;
            emit Success(true,"account was created successfully");

        }else{
            emit Success(true,"account already exists");
        }
    }

    function getPost(string memory addr) public view  returns (uint[] memory){
        return users[addr].posts;
    }
}