/**
 *Submitted for verification at Etherscan.io on 2022-02-23
*/

/// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

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
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
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

/**
* @dev to mint POE tokens
 */
interface PoExtended{
    function mint(address) external returns (bool);
}

/**
* @title NFT
* @dev ERC721 contract that holds the bonus NFTs
 */
interface INFT{
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

/**
 * @dev These functions deal with verification of Merkle Trees proofs.
 *
 * The proofs can be generated using the JavaScript library
 * https://github.com/miguelmota/merkletreejs[merkletreejs].
 * Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
 *
 * See `test/utils/cryptography/MerkleProof.test.js` for some examples.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

/**
* @title PoExtended
* @author Carson Case [[email protected]]
* @notice PoExtended is a POE token with owner delegated minters and a merkle claim system
*/

/**
* @title PaymentSlitter
* @author Carson Case > [email protected]
* @dev is ownable. For now, by deployer, but can be changed to DAO
 */

contract PaymentSplitter is Ownable, Pausable{
    using MerkleProof for bytes32[];
    /// @dev the merkle root which CAN be updated
    bytes32 public merkleRoot;

    
    mapping(address => bool) approved_minters;

    //Treasury address
    address payable public treasury;

    //Base commission rate for refferals. Decimal expressed as an interger with decimal at 10^3 place (1 = 0.1%, 10 = 1%).
    uint256 public baseCommission;

    //xGDAO address
    address xGDAO;

    //POE address
    address POEContract;

    //Cost to sign up
    uint256 public basePrice;

    //how much to increase price per each new sign up
    uint256 public priceIncrease;

    //NFT bonus address
    address bonusNFTAddress;

    //Lookup if address has already purchased
    mapping(address => bool) public hasPurchased;

    //Keep track of who has referred how many people
    mapping(address => uint) public referralCount;

    //Referrer whitelist
    mapping(address => bool) public referrerWhitelist;
	
	//Is user registered for obfuscated refs
	mapping(address => bool) public isUserRegistered;
	
	//Keep a private list of addresses assigned to hashes
	mapping(bytes32 => address payable) private hashToAddress;

    //Count the total buyers
    uint256 public buyerCount = 0;

    //Max referrals
    uint256 public maxReferrals = 0;

    //Free if a users holds this much xGDAO or more
    uint256 minXGDAOFree;

    //Nft bonus info
    struct nftBonus{
        uint128 id;
        //Decimal expressed as an interger with decimal at 10^18 place.
        uint128 multiplier;
    }

    //Array of NFT bonus info
    nftBonus[] bonusNFTs; 

    /**
    * @notice arrays must have the same length 
    * @param _treasury address to receive payments
    * @param _basePrice for starting price
    * @param _priceIncrease for increase in price per new buyer
    * @param _bonusNFTAddress to look up bonus NFTs
    * @param _commission base referral commission before bonus
    * @param _bonusNFTIDs ids of bonus NFTs (length must match multipliers)
    * @param _bonusNFTMultipliers multipliers of bonus NFTs (length must match IDs) 100% is 10^18
     */
    constructor(
        address payable _treasury,
        address _xGDAOAddress,
        uint256 _basePrice,
        uint256 _priceIncrease,
        address _bonusNFTAddress,
        uint256 _commission,
        uint128[] memory _bonusNFTIDs,
        uint128[] memory _bonusNFTMultipliers
        ) 
        Ownable()
        {
        bonusNFTAddress = _bonusNFTAddress;
        _addBonusNFTs(_bonusNFTIDs, _bonusNFTMultipliers);

        treasury = _treasury;
        xGDAO = _xGDAOAddress;
        basePrice = _basePrice;
        priceIncrease = _priceIncrease;
        baseCommission = _commission;

    }

    /// @dev some functions only callable by approved minters
    modifier onlyMinter(){
        require(approved_minters[msg.sender], "must be approved by owner to call this function");
        _;
    }

     /// @dev only owner can add minters
    function addMinter(address _minter) external onlyOwner{
        require(approved_minters[_minter] != true, "Minter is already approved");
        approved_minters[_minter] = true;
    }

    /// @dev owner can remove them too
    function removeMinter(address _minter) external onlyOwner{
        require(approved_minters[_minter] != false, "Minter is already not-approved");
        approved_minters[_minter] = false;
    }

    /// @dev A minter can forefit their minting status (useful for contracts)
    function forefitMinterRole()external{
        require(approved_minters[msg.sender] == true, "msg.sender must be an approved minter");
        approved_minters[msg.sender] = false;
    }

    /// @dev function for dev to manually increment referrer counts
    function incrementReferrerCounts(address[] memory _referrers, uint[] memory _increment) external onlyOwner{
        require(_referrers.length == _increment.length, "arrays must be the same length");
        for(uint i = 0; i < _referrers.length; i++){
            referralCount[_referrers[i]] += _increment[i];
        }
    }
    
    /// @dev function for dev to set has purchased
    function setHasPurchased(address _who, bool _to) external onlyMinter{
        hasPurchased[_who] = _to;
    }

    /// @dev set xGDAO address
    function setXGDAOAddress(address _new) external onlyMinter{
        xGDAO = _new;
    }

    /// @dev set POE Contract address
    function setPOEContractAddress(address _new) external onlyMinter{
        POEContract = _new;
    }

    /// @dev set maxReferrals. If zero, no max
    function setMaxReferrals(uint _new) external onlyMinter{
        maxReferrals = _new;
    }

    /// @dev set minXGDAO. If zero, no free amount
    function setMinXGDAOFree(uint _new) external onlyMinter{
        minXGDAOFree = _new;
    }

    /// @dev add referrers to a whitelist
    function addToReferrerWhitelist(address[] memory _list) external onlyMinter{
        for(uint i = 0; i < _list.length; i++){
            referrerWhitelist[_list[i]] = true;
        }
    }

    /// @dev remove referrers from whitelist
    function removeFromeReferrerWhitelist(address[] memory _list) external onlyMinter{
        for(uint i = 0; i < _list.length; i++){
            referrerWhitelist[_list[i]] = false;
        }
    }

    function updateMerkleRoot(bytes32 _new) external onlyMinter{
        merkleRoot = _new;
    }
    /**
    * @notice purchase function. Can only be called once by an address
    * @param _referrer must have an auth token. Pass 0 address if no referrer
     */
    function purchasePOE(bytes32[] memory proof, address payable _referrer, bytes32 _hashedRef) external payable{
		bytes32 root = bytes20(merkleRoot);
        bytes32 leaf = bytes20(msg.sender);
        require(proof.verify(root,leaf), "Address not eligible for claim");

        address payable referrer;

        if(_hashedRef == 0) {
          // if hash not given, use _referrer
          referrer = _referrer;
        } else {
          // use hashed ref instead
          referrer = hashToAddress[_hashedRef];
          require(referrer != address(0), "Incorrect function params");
        }

        uint256 price = getPrice();
        if(minXGDAOFree != 0 && IERC20(xGDAO).balanceOf(msg.sender) >= minXGDAOFree){
            price = 0;
        }

        require(msg.sender != _referrer, "You cannot use yourself as a referrer");
        require(msg.value == price, "You must pay the exact price to purchase. Call the getPrice() function to see the price in wei");
        require(!hasPurchased[msg.sender],"You may only purchase once per address");

        referralCount[referrer]++;
        //If there is a referrer send them commission. If free then don't bother with commissions
        if(price > 0){
            //Give commisson if there's a referrer and he hasn't surpassed max, if he's not whitelisted, or of course, there is no max
            if(
            referrer != address(0) && 
            (
            referrerWhitelist[referrer] ||
            maxReferrals == 0 ||
            referralCount[referrer] < maxReferrals
            )
            ){
                uint256 rebate = (price * 5) / 100;         //5% rebate if using a referrer
                price = price - rebate;
                payable(msg.sender).transfer(rebate);
                //Calculate commission and subtract from price to avoid rounding errors
                uint256 commission = getCommission(price, referrer);
                referrer.transfer(commission);
                treasury.transfer(price-commission);
                //If not, treasury gets all the price
            }else{
                treasury.transfer(price);
            }
        }

        //Mark buyer as having purchased
        hasPurchased[msg.sender] = true;
        
        //Mint a POE
        PoExtended(POEContract).mint(msg.sender);

        // Only increase buyer count if not paused
        if(!paused()){
            buyerCount++;
        }
    }

    /**
    * @notice for owner to change base commission
    * @param _new is new commission
     */
    function changeBaseCommission(uint256 _new) external onlyOwner {
        baseCommission = _new;
    }

    /**
    * @notice for owner to change the price curve contract address
    * @param _new is the new address
     */
    function setBasePrice(uint256 _new) external onlyMinter{
        basePrice = _new;
    }

    function changeIncrease(uint256 _new) external onlyMinter{
        priceIncrease = _new;
    }

    /**
    * @notice for owner to add some new bonus NFTs
    * @dev see _addBonusNFTs
    * @param _bonusNFTIDs array of IDs
    * @param  _bonusNFTMultipliers array of multipliers
     */
    function addBonusNFTs(uint128[] memory _bonusNFTIDs, uint128[] memory _bonusNFTMultipliers) public onlyOwner{
        _addBonusNFTs(_bonusNFTIDs, _bonusNFTMultipliers);
    }
	
	function registerForReferralProgram() public {
		require(isUserRegistered[msg.sender] == false, "User is already registered");

		bytes32 hashedAddy = keccak256(abi.encodePacked(msg.sender));
		hashToAddress[hashedAddy] = payable(msg.sender);
		isUserRegistered[msg.sender] = true;
	}

    /**
    * @notice function to return the current price based on buyer count
    * @dev if priceCurveAddress is 0 address use the default z curve. If not use that contracts price curve function
    * @return the price
     */
    function getPrice() public view returns(uint256) {
        uint256 prevSignups = buyerCount * priceIncrease;
        return basePrice + prevSignups;
    }

    /**
    * @notice function returns the commission based on base commission rate, NFT bonus, and price
    * @param _price is passed in, but should be calculated with getPrice()
    * @param _referrer is to look up NFT bonuses
    * @return the commission ammount
     */
    function getCommission(uint256 _price, address _referrer) internal view returns(uint256){
        uint128 bonus = getNFTBonus(_referrer);
        uint256 commission;
        if(bonus > 0){
            commission = baseCommission + ((baseCommission * bonus) / 1000);
        }else{
            commission = baseCommission;
        }      
        return((_price * commission) / 1000);
    }

    /**
    * @notice function to get the NFT bonus of a person
    * @param _referrer is the referrer address
    * @return the sum of bonuses they own
     */
    function getNFTBonus(address _referrer) public view returns(uint128){
        uint128 bonus = 0;
        INFT nft = INFT(bonusNFTAddress);
        //Loop through nfts and add up bonuses that the referrer owns
        for(uint8 i = 0; i < bonusNFTs.length; i++){
            if(nft.balanceOf(_referrer, bonusNFTs[i].id) > 0){
                bonus += bonusNFTs[i].multiplier;
            }
        }
        return bonus;
    }

    /**
    * @notice private function to add new NFTs as bonuses 
    * @param _bonusNFTIDs array of ids matching multipliers
    * @param _bonusNFTMultipliers array of multipliers matching ids
     */
    function _addBonusNFTs(uint128[] memory _bonusNFTIDs, uint128[] memory _bonusNFTMultipliers) private{
        require(_bonusNFTIDs.length == _bonusNFTMultipliers.length, "The array parameters must have the same length");
        //Add all the NFTs
        for(uint8 i = 0; i < _bonusNFTIDs.length; i++){
            bonusNFTs.push(
                nftBonus(_bonusNFTIDs[i],_bonusNFTMultipliers[i])
            );
        }
    }

}