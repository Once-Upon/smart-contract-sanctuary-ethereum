// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

contract SocialApp {
    // Struct to store user profiles
    struct Profile {
        address userAddress;
        string name;
        string bio;
        string imageHash;
    }

    // Struct to store posts
    struct Post {
        address userAddress;
        string text;
        string fileHash;
        uint timestamp;
    }
    // Struct to store message
    struct Message {
        address sender;
        address receiver;
        string text;
    }

    // Mapping to store user profiles
    mapping(address => Profile) profiles;
    // Mapping to store the number of posts a user has created
    mapping(address => uint) public postCounts;
    // Mapping to store all the posts of a user
    mapping(address => Post[]) posts;
    // Mapping to store all the messages of a user
    mapping(address => Message[]) messages;
    // Array to store all the posts of the app
    Post[] public allPosts;

    // Event to track when a new profile is created
    event NewProfile(
        address userAddress,
        string name,
        string bio,
        string imageHash
    );

    // Event to track when a new message is created
    event NewMessage(address sender, address receiver, string text);

    // Function to create a new user profile
    function createProfile(
        string memory _name,
        string memory _bio,
        string memory _imageHash
    ) public {
        // Check if the user already has a profile
        require(profiles[msg.sender].userAddress == address(0));

        // Create a new profile for the user
        profiles[msg.sender] = Profile(msg.sender, _name, _bio, _imageHash);

        emit NewProfile(msg.sender, _name, _bio, _imageHash);
    }

    function editProfile(
        string memory _name,
        string memory _bio,
        string memory _imageHash
    ) public {
        // Check if the user already has a profile
        require(profiles[msg.sender].userAddress != address(0));

        // Update the user's profile
        profiles[msg.sender].name = _name;
        profiles[msg.sender].bio = _bio;
        profiles[msg.sender].imageHash = _imageHash;
    }

    // Function to retrieve a user's profile
    function getProfile(
        address user
    ) public view returns (string memory, string memory, string memory) {
        Profile storage profile = profiles[user];
        return (profile.name, profile.imageHash, profile.bio);
    }

    function createPost(string memory _text, string memory fileHash) public {
        // Check if the user already has a profile
        require(
            profiles[msg.sender].userAddress != address(0),
            "Profile does not exist"
        );

        // Create a new post
        Post memory newPost = Post(
            msg.sender,
            _text,
            fileHash,
            block.timestamp
        );
        posts[msg.sender].push(newPost);
        allPosts.push(newPost);
        postCounts[msg.sender]++;
    }

    function editPost(uint _postId, string memory _text) public {
        // Check if the user already has a profile
        require(profiles[msg.sender].userAddress != address(0));
        // Check if the post id exist
        require(_postId < postCounts[msg.sender]);
        // Update the post
        posts[msg.sender][_postId].text = _text;
    }

    function deletePost(uint _postId) public {
        // Check if the user already has a profile
        require(profiles[msg.sender].userAddress != address(0));
        // Check if the post id exist
        require(_postId < postCounts[msg.sender]);
        // Shift all the elements after the one to delete to the left
        for (uint i = _postId; i < postCounts[msg.sender] - 1; i++) {
            posts[msg.sender][i] = posts[msg.sender][i + 1];
        }
        // Decrement the user's post count
        postCounts[msg.sender]--;
    }

    function getUserPosts(
        address _userAddress
    ) public view returns (Post[] memory) {
        // Check if the user already has a profile
        require(profiles[_userAddress].userAddress != address(0));
        return posts[_userAddress];
    }

    function message(
        address _receiver,
        string memory _text
    ) public returns (bool) {
        // Check if the user already has a profile
        require(profiles[msg.sender].userAddress != address(0));
        // Check if the receiver already has a profile
        require(profiles[_receiver].userAddress != address(0));
        // Check if the message is already sent
        require(
            messages[msg.sender].length == 0 ||
                messages[msg.sender][messages[msg.sender].length - 1]
                    .receiver !=
                _receiver
        );
        // Create a new message
        Message memory newMessage = Message(msg.sender, _receiver, _text);
        // Add the message to the mapping
        messages[msg.sender].push(newMessage);
        // Emit an event for the new message
        emit NewMessage(msg.sender, _receiver, _text);
        return true;
    }

    function getSentMessages() public view returns (Message[] memory) {
        // Check if the user already has a profile
        require(profiles[msg.sender].userAddress != address(0));
        return messages[msg.sender];
    }

    function getReceivedMessages() public view returns (Message[] memory) {
        // Check if the user already has a profile
        require(profiles[msg.sender].userAddress != address(0));
        return messages[msg.sender];
    }

    function getAllPosts() public view returns (Post[] memory) {
        return allPosts;
    }
}