// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './IERC165.sol';
import './IERC721.sol';
import './IERC721Metadata.sol';
import './IERC721Receiver.sol';
import './ICatBlocks.sol';
import './IHyperCats.sol';
import './Art.sol';

/**
 * @dev Minimal Purely On-chain ERC721
 */
contract ArtTest is IERC165 
, IERC721
, IERC721Metadata
{
    Art private _art;
    ICatBlocks private _catBlocks;
    IHyperCats private _hyperCats;

    constructor (address art) {
        _artist = msg.sender;
        _art = Art(art);
    }

    // Other Contracts
    function setCatBlocksContract(address catBlocks) public onlyArtist {
        _catBlocks = ICatBlocks(catBlocks);
    }
    function setHyperCatsContract(address hyperCats) public onlyArtist {
        _hyperCats = IHyperCats(hyperCats);
    }

    function catBlocks_tokenIdToHash(uint256 tokenId) external view returns (bytes32){
        return _catBlocks.tokenIdToHash(tokenId);
    }
    function catBlocks_tokensOfAccount(address account) external view returns (uint256[] memory){
        return _catBlocks.tokensOfOwner(account);
    }
    function hyperCats_balanceOfAccount(address account) external view returns (uint256){
        return _hyperCats.balanceOf(account);
    }

    // Permissions ---
    address private _artist;
    modifier onlyArtist(){
        require(_artist == msg.sender, 'a');
        _;
    }

    // Used by martketplaces to allow controlling marketplace information (like banners)
    function owner() public view virtual returns (address) {
        return _artist;
    }

    // Interfaces ---
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId
            ;
    }

    // Metadata ---
    string private constant _name = 'TestContract';
    string private constant _symbol = 'TEST';

    function name() public pure override(IERC721Metadata) returns (string memory) {
        return _name;
    }

    function symbol() public pure override(IERC721Metadata) returns (string memory) {
        return _symbol;
    }

    // On-chain json must be wrapped in base64 dataUri also: 
    // Reference: https://andyhartnett.medium.com/solidity-tutorial-how-to-store-nft-metadata-and-svgs-on-the-blockchain-6df44314406b

    // Open sea contractURI to get open sea metadata
    // https://docs.opensea.io/docs/contract-level-metadata
    function contractURI() public view returns (string memory) {
        return _art.generateArt(0x000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F, 7);
    }

    function tokenURI(uint256 tokenId) public view override(IERC721Metadata) returns (string memory) {
        return _art.generateArt(_hashes[tokenId], 3);
    }

    function generateArt(uint256 tokenId, uint kind) public view returns (string memory) {
        return _art.generateArt(_hashes[tokenId], kind);
    }

    // Token Ownership ---
    uint256 private _totalSupply;
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /** tokenId => hash */ 
    mapping (uint256 => uint256) private _hashes;

    /** tokenId => owner */ 
    mapping (uint256 => address) private _owners;
    function ownerOf(uint256 tokenId) public view override(IERC721) returns (address) {
        return _owners[tokenId];
    }

    /** Owner balances */
    mapping(address => uint256) private _balances;
    function balanceOf(address user) public view override(IERC721) returns (uint256) {
        return _balances[user];
    }

    /** Create a new nft
     *
     * tokenId = totalSupply (i.e. new tokenId = length, like a standard array index, first tokenId=0)
     */
    function createToken(uint256 tokenId, uint256 tokenHash) public onlyArtist returns (uint256) {

        // nextTokenId = _totalSupply
        require(_totalSupply == tokenId, 'n' );
        _totalSupply++;

        _balances[msg.sender] += 1;
        _owners[tokenId] = msg.sender;
        // _hashes[tokenId] = uint256(keccak256(abi.encodePacked(msg.sender, tokenId)));
        _hashes[tokenId] = tokenHash;
    
        emit Transfer(address(0), msg.sender, tokenId);

        return tokenId;
    }

    // Transfers ---

    function _transfer(address from, address to, uint256 tokenId) internal  {
        // Is from actually the token owner
        require(ownerOf(tokenId) == from, 'o');
        // Does msg.sender have authority over this token
        require(_isApprovedOrOwner(tokenId), 'A');
        // Prevent sending to 0
        require(to != address(0), 't');

        // Clear approvals from the previous owner
        if(_tokenApprovals[tokenId] != address(0)){
            _approve(address(0), tokenId);
        }

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override(IERC721) {
        _transfer(from, to, tokenId);
        _checkReceiver(from, to, tokenId, '');
    }
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data_) public override(IERC721) {
        _transfer(from, to, tokenId);
        _checkReceiver(from, to, tokenId, data_);
    }
    function transferFrom(address from, address to, uint256 tokenId) public virtual override(IERC721) {
        _transfer(from, to, tokenId);
    }

    function _checkReceiver(address from, address to, uint256 tokenId, bytes memory data_) internal  {
        
        // If contract, confirm is receiver
        uint256 size; 
        assembly { size := extcodesize(to) }
        if (size > 0)
        {
            bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data_);
            require(retval == IERC721Receiver(to).onERC721Received.selector, 'z');
        }
    }

    // Approvals ---

    /** Temporary approval during token transfer */ 
    mapping (uint256 => address) private _tokenApprovals;

    function approve(address to, uint256 tokenId) public override(IERC721) {
        address owner = ownerOf(tokenId);
        require(owner == msg.sender || isApprovedForAll(owner, msg.sender), 'o');

        _approve(to, tokenId);
    }
    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override(IERC721) returns (address) {
        return _tokenApprovals[tokenId];
    }

    /** Approval for all (operators approved to transfer tokens on behalf of an owner) */
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    function setApprovalForAll(address operator, bool approved) public virtual override(IERC721) {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    function isApprovedForAll(address owner, address operator) public view override(IERC721) returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    function _isApprovedOrOwner(uint256 tokenId) internal view  returns (bool) {
        address owner = ownerOf(tokenId);
        return (owner == msg.sender 
            || getApproved(tokenId) == msg.sender 
            || isApprovedForAll(owner, msg.sender));
    }

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICatBlocks {
    function tokensOfOwner(address owner) external view returns (uint256[] memory);
    function tokenIdToHash(uint256 tokenId) external view returns (bytes32);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHyperCats {
    function balanceOf(address account) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract Art {

    constructor () {
        _artist = msg.sender;
    }

    /** Security ---
     *  
     *  - Prevent impersonation
     *    - Only the artist's allowed contracts can `call` this
     *    - prevent `delegate_call` (which would bypass storage-based security checks)
     *  
     */ 

    address private _artist;
    modifier onlyArtist(){
        require(_artist == msg.sender, 'a');
        _;
    }

    function isDelegated () internal view returns (bool) {
        // This must be the contract's published address which is deterministic
        return address (this) != 0x65b657064fCF1c9067bfe23dC1736DDA790de55C; // THIS_CONTRACT_ADDRESS
    }

    /** address => hash */ 
    mapping (address => bool) private _allowedCaller;
    modifier onlyAllowedCallers(){
        require(!isDelegated(), 'd');
        require(_allowedCaller[msg.sender], 'c');
        _;
    }

    function addAllowedCaller(address caller) public onlyArtist {
        _allowedCaller[caller] = true;
    }

    function generateArt(uint rvs, uint kind) public view onlyAllowedCallers returns (string memory) {
        return string(generateArtData(rvs, kind));
    }

    /** 
     * kind: bit 0x01 = base64
     * kind: bit 0x02 = tokenURI/contractURI json
     * kind: bit 0x04 = contractURI (instead of tokenURI)
     * kind: bit 0x08 = kitten (instead of cat)
     * kind: bit 0x10 = TODO: old timey effect 
     * kind: bit 0x40 = Memory dump
     */
    function generateArtData(uint rvs, uint kind) private pure returns (bytes memory) {
        bytes memory output;
        

        // DataPack 
        bytes memory pDataPackCompressed = hex"08207374796c653d27086c696e656172477208ff02616469656e74073a75726c28237808207472616e73666f08ff0166696c6cff04087472616e736c617404272f3e3c062069643d277808ff05726d3d27ff07073b7374726f6b65083e3c73746f70ff0108ff0c73746f702d6308ff0d6f6c6f723a0008ff0eff082fff033e0820786c696e6b3a6808ff107265663d27230827ff0f3cff03ff09082f673e3c2f673e3c08ff08757365ff1178083d272d333030272008636c69705061746805303b20302e07273e3c7061746808206f7061636974790666696c746572067363616c652808ff0b2d776964746808ff05726d3d27ff1b071a0e01101a0e02063d273630302706ff0a6528302c0820636c69702d706108ff2174683d277572071a0e08101a0e09086c6c69707365ff06052720643d2707ff082f673e3c67070e0a0e0c1b1001051c0a1c0c1b061a0e0a10190a083e3c72656374207808ff2aff1579ff157708ff2b69647468ff1f08ff2c20686569676808272063793d27002705130a130c1b0729272063783d27071a1301161a1302030b190a081a1d070b1a1d080b06ff226c28237806ff1e3c1a0e0305ff193d270007ff1d2d312c312907ff2e2072783d2707ff0b2d6c696e650302010e06272072793d27040e16b62908ff0166696c6c3a6e081a2403091a24040b082101a63029b6b7b807ff2d74ff1fff06063a726f756e64061a0e07100c1003273e3c0300236604ff0a652804261b260504311b310607ff3d6f6e65ff0b07293bff1aff0432071a1001131a1002072101a6300f01a707b2b3b4b5aaa50e082720ff16556e697408ff4d733d2775736508ff4e72537061636508ff26ff36ff18ff0608ff396a6f696eff41081a240209ff3e1a24081d01a9df29aeafb0086e0e210a29ff4c2108ff540aff3fb901a70474696f6e07ff4f4f6e55736507ff14333627ff20071a1303451a1304071a0e043d1a0e0507100a100c1b1302071a1306161a1307073a093a09193a0b07240a240c1a2401076fabacada8660e06ff0870617468061231282a190a04090bff3a030e126a08657363726970ff560827ff01636f6c6f7208ff652d696e74657208ff66706f6c61ff5608ff672dff1a733a7308ff68524742ff436608ff6965476175737308ff6a69616e426c7508ff6b72207374644408ff6c65766961ff56082720726573756c7408ff6e3d27626c757208ff6fff082fff1a3e08ff57ff1820643d2708ff14323927ff2020082920ff1b2d312c3108726f746174652800081a1c04301a1c050d081a14050b1a14060b08ff4b0e210a29ff5f08ff77210aff53b101051a271827230504051b010804ff08ff13031a1305031a1c01031a1c02031a1c03031a1c06031a1c07031a1c0804673e3c67043b20302e04281b2804041d0a1d0c042718272403361b3607302c352c2d3630071a13060b1a130707ff331a1d09ff320719390b0b19390907ff52050b1a2406071a1402091a140307ff761a1407ff3207011e01031bff3a05ff4365ff2405ff230b0c100502021a1d06051403090703033d1b3d04ff2f16020365002303300023030dff3203451a13031a1c04031a1c05031a1c09031a1c0a031a1c0b031a1c0c031a1c0d031a1c0e083d27687474703a2f08ffa32f7777772e7708ffa4332e6f72672f08ff703cff1aff09320827ff0635ff493529083429ff0bff04342908ffa8ff51ff39636108ffa970ff41ff1c3a082c36302c352c363008ff04323329ff1c3a08ff48ffac302e382708ff05726d3d27ff74081306181a1307ff32080e210cff78ff550e06ff43ff16ff0906757365ff11780609360919360b0609390919390b06093a02193a0b060a140c1a140106442144180503061d01bc2bff3a052927ff3433051a2407ff320502070e126c0465223a220403041d03031a1303031a1304031a0e06036600230330303003182823072720786d6c6e7307ff14333127ff45071f0a1f0c1b3e01071a1f023e1a1f03071a1301281a13020708ff9a09ff9a0a071a130c181a130d071a0e042f1a0e0507191d0b0b191d090719270b0b1927090719360b0b1936090702e8ff6302e90e04696e670004464646460429ff08670429ff4367040203ff63040e16b60c030a090a05ff082fff1605ff5c09190a05ff7d24ff7e05ffa231190a052136180503052ad57a76d7030023330300233503ff1231031a1d01031a1d02031a1d03031a1d04031a1d050327030103202120061a1f013e0c3e060a100c1a1001061a10034b190a061a1d0933190a061a14040bff8f06122a2728190a04ff1c3a3104ff254d0004ff45002904271b27070300236503002336036564000300236403ff250003302c3003090b0203ff950303ff950403201e20087b226e616dffbc5408fffb4553542d41520854222c2264ff6422085465737420417274000000376cfffc542d434f4e54524143fffd3a22fffe2044ff64202d20436f6e74726163742200fffcfffd3a22436f6f6c20fffe2044ff6422002c2261747472696275746573223a5b7b2274726169745f747970ffbc00222c2276616c75ffbc00227d2c7b2274726169745f747970ffbc00617765736f6d656e657373222c2276616c75ffbc31303025227d5d002c22696d6167ffbc00227d00726f756e64006f76616c006469616d6f6e6400737175617269736800666c75666679007363727566667900706c61696e0063686f6e6b657200736c69636b0072656374616e67756c6172007465656e7900636865656b79006c656d6f6e0073696c6b790063687562627900736b696e6e79007769646500626c6f636b79007570726967687400616c65727400706f696e74790063757276fff3736c616e74fff3666f6c64fff3666c6f707079007369646577617973007065726b7900737068796e780066696572636500737175696e74ffd073756c6c656e006d65656b00737465726e006d65616e0064726f6f70790063726f737300616c6d6f6e6400646f6500676c6172ffd0736c6565707900706c656164ffd07468696e006269670068756765006e6f726d616c00736d616c6c007468696e6e657374006e65757472616c0070757273fff3706c656173fff3706f7574ffd064726f6f70ffd0646973706c656173fff3696d7061727469616c0064756c6c00736d696cffd0646f776e7761726400646f776e7761726453686f7274007570776172640075707761726453686f727400626c61636b00236238646566ffc13161316231ff97636664326465ff44616661666100233066306631ff983837346636ff98ffc2ffc2ff44303964396400233264316631360023613036613661fff1646564fff377686974ff9738623932653900233132313231320023303530353035ff443666366636ff443362346439ffdd3833383338ff4466633264340023383232363733ffdd63323532650067696e676572ffde6437626231ff4466616537ff98656364646435ff446366636663fff13938363439ff443761343634ff4466656465ff983861343030ffc16365356635ffc13332323731ffc1346232393162fff2663366326100677261790023376538343961fff43264326462ffde3535343633fff26136653763ff4435633764ffc1336433643364ff44356232643400233730336535370062726f776eff4430663066ff98383135643431fff46564316339ff4432646663ff97343033303163fff26534653335fff464393739370023343932633138ff4430386538ff973735326634ff98326632333233006272697469736820626c75ff973565363337330023636464306435fff461646365370023346435313661ffde3035353638fff4636137633100233236323432640023313331323163ffde373537353700233139316131ffc13137313631370063616c69636ffff137653264ff97653238343363ff443339363936fff26231653632fff264343034ff9832363236323600637265616d79fff13164306336fff133643663ff973265323532ff98626661383962ffde66343533340023343333353264002337393539343400233239323932390070696e6bffde6534633961ff446662386565ff443164666566ff4466663066ff97643337336265ff446262316561fff435366462ff973563326535320023613834643934ffdd6531383239fff23032393537ffdd3431623336006379616e00236238663466ffc16365646364ffc16562663866ffc13664613463ff98613065626638ffde3939626231ffdd3835353631fff2383931623100233234323233ffc1313832613335002331353165323300677265656effde36366138ffc13763613236390023636564656436ffde3037313431ffdd37353834350023376139613661ffdd353537343400233166323332ff98333433613331002332343265316600666c65736879ff443364386438ff443265396539ff446665626562fff16362366236ff4433636563ff976433383839370023623437393739ff443061386138ffde65343034ff98613937353735ff4435663566350073616e64fff13463376234fff166653064370023633139643861fff437623861330023626138383832fff230336533ff97376235363536ffdd6132373237fff2663538353800746f79676572ff443039343735fff465636164630023343932343164ffdd38323531ffc1643439316262ffdd3731353135002338303830383000626c75ff976436663966660079656c6c6f77ff4439653961ff97636166616133006f72616e6765ff446639633636fff166303930320074616262790073686f727468616972007369616d6573650073616e6463617400616c69656e007a6f6d6269ff973530353035ff9844423730393300234533384641420023ffd1464630ff98ffd1464600233031ffc23038ff9833333333333300627265fff370616c6574746500686561644100686561644200656172006579657300657965436f6c6f72526967687400657965436f6c6f724c65667400707570696c73006d6f75746800776869736b657273003c3f786d6c2076657273696f6e3d27312e302720656e636f64696e673d275554462d3827207374616e64616c6f6e653d276e6f273f3e3c7376672077696474683d273130302527206865696768743d2731303025272076696577426f783d273020302033303020333030272076657273696f6e3d27312e31ffc43a786c696e6bffa5313939392f786c696e6bffc4ffa532ffc22f737667ffc43a737667ffa532ffc22f737667ff43646566733e3cff03ff0931ff1232ff1233ff1234ff1235ff1236ff1237ff1238ff1239ffdf30ffdf31ffdf32ffdf33ffdf34ffdf35ffdf36ffdf37ffdf38ffdf3927ff0f3cff03ff0f3cff03ff093230ff123231ff123232ff12323327ff0f3cff1aff093234ff6d3d27302030ffa635ff6d3d27302e3520302e35ffa636ff6d3d27312031ffa637ff6d3d27332033ff703c2f64656673ff4031ffd2ff453135302e302c3135302e302920ff1b302e303129ff1b00ffd3ff01ff1aff04323429ffb13238ff714d002c004c005affd73e3c67ff3432382927ff4032ffd2ff36ff18ff09323927ff48ff043529ffed34fff5ff72323729ff72353429ff72383129ff7231303829ff503729ffee5aff60ff063829ffee5aff26ff36ff4367ff093330ff18ff093331ffa7ffee6336302c31352c36302c32302c36302c323063302c352d36302c2d31302d36302c2d31307affc5202d342c20313829ffc5202d382c333629ffc52d31322c353429ff082f673e3cffb2333027ff37ff503429ffee4800ff9134ff3030272063793d27313635272072783d2700ff3b3530ff7bff83ff34323829ff18ff063131ff49362927ff193d27302e3327ff203529fff5007aff7b2fff833e3c67ff1d002c3129ff43ff833e3cff16ff093332ff71005335fff62cfff65affd7ff403133ffb932ffd2ff093333ffb13334ff71005affd7ff403134ffb93429ff7bff83ff3727ff403132ffb93229ff143333ff7b2fff83ff01ff1aff04323429ffb13335ff71007affd73e3c67ff3433352927ff4033ffd2ff36ff9134ff3030ff383630ff3b3630ff50ffaa36ff254d302c004c2d3132342c004c3132342c00ff9134ff303130ff383131ff3b3131ff0865ff2434ff302d3130ff383131ff3b3131ff503429fff54c3135302c2d3135305aff26ff36ff9136ff302d3638ff383735ff3b313030ff50ffaa3132ff254d2d31362c004c31362c00ff18ff06ffaa3132ff254d302c354c2d31362c00ff9139ff3030ff383136ff3b3335ff0865ff243130ff302d3736ff383730ff3b313030ff0865ff2439ff303736ff383730ff3b313030ff263e3c70617468ff3627ff093336ffa7ffee6336fff6ffab2c3563ff892c352c2d36302c357aff58313429ff582d313429ff5830ff7329ff583134ff7329ff582d3134ff7329ff60ff3627ff093337ffa7ff254d2d32302c006330ffab2c352c363063352cff892c352c2d36307aff14333727ff4531352c3429ff14333727ff4533fff629ff7bff13ff83ffef20ff0765282d002c2d0029ffb13338ff57ff18ff09333927ffef20ff1b312c312920ff7429fff57aff43616e696d617465206174747269627574654e616d653d27642720747970653d27786d6c2720726570656174436f756e743d27696e646566696e69746527206475723d27387327206b657954696d65733d27303b302e3437353b302e353b302e3532353b31272076616c7565733d2720002000207a3b2000207a20ff082f706174683e3c2fff16ff403136ffb938ffd2ff343338ffd3ff4500ffd3ff093430ff913138ff3000ff3800ff3b00ff43616e696d6174654d6fff56206475723d273630732720726570656174436f756e743d27696e646566696e697465272063616c634d6f64653d276c696e65617227206b657954696d65733d2720ff173033ff8431ff173135ff8432ff173231ff8433ff173337ff8434ff173433ff8435ff173532ff8436ff173634ff8437ff173733ff8438ff173837ff8439ff1739353b203127206b6579506f696e74733d27ff1731ff1731ff1732ff1732ff1733ff1733ff1734ff1734ff1735ff1735ff1736ff1736ff1737ff1737ff1738ff1738ff1739ff1739303b20312e30303b20312720706174683d274dfff64c332c324c2d312c314c2d322c324c2d352c304c2d312d324c342d314c352c324c312d314cfff64cfff65aff082f656c6c697073653e3cff83ffefff43636972636c6520723d27323527ff1d302e31352927ff063139ff493729ff26ffefff43636972636c6520723d27313527ff1d302e31352927ff063139ff493729ff7bff132f673e3c757365ff09343127ff1178333927ff017374726f6b652d77696474683a32ff0bff043137293b66696c6c3a7472616e73706172656e74ff26ff452d002920ff076528002927ff2d74ff1fff3727ff063135ffb938ffd2ff3433382927ff37ff4367ff4500ff7329ff43ffb23430ff7bffb2343127ff37ff7b67ff2000ffd3ff2030ffd3ff203029ff18ff48ff04323029ffed2e35fff56c302effc2312c302effc2315aff60ff09343227ff48ff04323029ffed2e35fff5ff14343227ff37ff0867ff3627ff2030ffd3ff09343327ffefff18ffadffaeff60ffadffaeff60ffadff3627ffaeff082f673e3cffb2343327ff37ff7bff1367ff203029ff18ff06323129ff0bff04323129ff51ffedfff55aff60ff09343427ff06323229ff0bff04323129ff51ffedfff5ff14343427ff37ff7b2fff833e3c7465787420783d2735252720793d27353025272066696c6c3d27234646ffc2302720746578746c656e6774683d27393025273e464f522054455354494e47204f4e4c59202d20636f6e74616374207269636b6c6f76652e6574683c2f746578743e3c2f673e3c2f7376673e000b01000b024c0b03890b04a80b05b40b06c70b07e50b08f00b0901130a02fff702130a01020b0112090a010b0b000b0c0f0a0d0c0b0ef31a0d010e0b0f370c100f1a0d02100b10491a0d03100b111d0c12111a0d04120b12561a0d05120b13171a0d06130b145b1a0d07141a0d08091a0d090b0b15640c16151a0d0a160b162c1a0d0b161a0d0c0f1a0dff990b0d0a0d0c0b17f91a0d01170b17320c18171a0d02180b184e1a0d03180c18111a0d04180b18501a0d05180b191c1a0d06190b1a581a0d071a0b1b031a0d081b1a0d090b0c1c151a0d0a1c0b1c231a0d0b1c0b1d331a0d0c1d1a0dff99090d0a0d0c0b1efe1a0d011e0b1e360c1f1e1a0d021f0b1f4f1a0d031f0b20180c21201a0d04210b21601a0d05210b21191a0d06211a0d07120b220b1a0d08220b233f1a0d09230b244a0c25241a0d0a250b25061a0d0b250b262f1a0d0c261a0dff99020d0a0d0c1b2701061a0d01270b27340c28271a0d02280b284d1a0d03280c29211a0d04290b295f1a0d05291a0d06261a0d07120c2a091a0d082a1a0d090b0c2a151a0d0a2a0b2a201a0d0b2a1a0d0c271a0dff991b0d0b0d040a2b0c1b2c010f1a2b012c0c2c171a2b022c0b2c461a2b032c0b2d1a0c2e2d1a2b042e1a2b05151a2b06210b2e5a1a2b072e0b2e3c0c2f2e1a2b082f1a2b09290c2f151a2b0a2f0b2f141a2b0b2f1a2b0c171a2bff990d2b0b2b050a300c1b3101161a3001310c31171a3002311a3003280c31211a3004311a3005140b31261a3006311a30071f0b32271a3008320b33591a3009330b340e1a300a340b35301a300b351a300c1e1a30ff992b300a300c1b36011e1a3001360c370f1a3002371a30031f0b371b0c38371a3004381a3005330b38251a3006381a30071a0c39251a3008391a30090b0b39240c3a391a300a3a0b3a2b1a300b3a1a300c271a30ff9925300b30070a3b0c1b3c01241a3b013c0c3c261a3b023c1a3b032c0c3c201a3b043c0b3c631a3b053c0b3d151a3b063d0b3e5c1a3b073e0c3f2d1a3b083f1a3b09230c3f151a3b0a3f0b3f311a3b0b3f0b40381a3b0c401a3bff99303b0b3b080a410c1b42012c1a4101420c421d1a4102421a4103100c422b1a4104420b42661a4105421a41062f0b43541a4107430c442e1a4108441a41092d0c44151a410a441a410b380b443b1a410c440b440d1a410d44190a3b410b41090a450c1b4601321a4501460c46271a4502461a4503120c12441a4504121a4505141a45060f1a4507180b120c1a4508120b144c1a4509140b46551a450a460b47211a450b471a450c171a45ff9941450b450a0a480c1b49013e1a4801490c4a351a48024a0b4a4b1a48034a0b4b1e0c4c4b1a48044c1a4805331a4806471a48071f1a48080d1a48090b0c1f391a480a1f1a480b351a480c401a48ff9945480a1f0c1b3301441a1f01330c33171a1f02331a1f032c0c33191a1f04331a1f053e0b33291a1f06331a1f07430c35111a1f08351a1f094b0c351e1a1f0a351a1f0b380b35351a1f0c351a1fff9922ffc64bffe73fffc7180c3e091a1f043e0b3e611a1f053e1a1f06201a1f07430c3e1b1a1f083e1a1f090b0c3e151a1f0a3e1a1f0b381a1f0c401a1f0d0c190a12ffc651ffe717ffc72c0c3e451a1f043e1a1f053c1a1f06331a1f07460c3c2e1a1f083c1a1f09151a1f0a341a1f0b391a1f0c0f1a1f0d44190a441f0a1f0c1b3c01571a1f013c0c3c351a1f023c1a1f03240c3c251a1f043c1a1f051a1a1f06320b1a531a1f071a1a1f082e1a1f090b0c3c151a1f0a3c0b3c281a1f0b3c1a1f0c0f1a1f0d0c190a34ffc65effe716ffc7280b3e130c403e1a1f04400b40441a1f05400b401f1a1f06401a1f071a1a1f082e1a1f093a1a1f0a141a1f0b171a1f0c171a1fff990c1f0b1a100a1f0c1b4601651a1f01460c481e1a1f02480b1e621a1f031e0c483e1a1f04480b48571a1f05481a1f063c0b4c511a1f074c0c4d091a1f084d1a1f090b1a1f0a0b1a1f0b4b0b4d2d1a1f0c4d1a1fff991a1f0b1f110a4d0c1b4e016a1a4d014e0c4e271a4d024e1a4d03180c4e2d1a4d044e1a4d051e1a4d06351a4d07481a4d080d1a4d090b0c1e151a4d0a1e1a4d0b2a1a4d0c171a4dff991f4d041effd6340a480c1a4801361a4802370c36091a4803361a4804271a4805301a48060b1a48073e1a48083f1a4809441a480a351a480b211a480c181a480d451a480eff320b480a360c1b4801711a3601481a3602110c483d1a3603481a36042c1a36052f1a36060b0c480d1a3607481a36081a0b48161a3609481a360a1a1a360b4b1a360c181a360d451a360eff3209360a360c1b4d01791a36014d1a3602130c4d331a36034d0b33451a3604331a36051f1a36060b0c331b1a3607331a36081f1a36092f1a360a131a360b4b1a360c281a360d441a360eff3202360a130c1b28017fffc8110c2841ffbe28ffbf35ff7c0bff8aff9affc9ff9a0b4b1a130c141a130dff9a0e29190a1b130a130c1a1301491a13024b0c283effbe28ffbf17ff7cff9a06021a1307411a1308221a13092d1a130a3d1a130b4b1a130c101a130d450b10771a130e10190a0dff2f280186ffc8190c280dffbe28ffbf17ff7c1fff8a211a1308111a13090d1a130a381a130b4bffcaff9a0eff322bff2f28018dffc821ff5932ff7c0bff8aff9affc9ff9a0b271a130c4c1a130d251a130eff3225ff2f2701951a1301271a130221ff592c0b283eff7c281a1306241a1307011a13081b1a13094b0b24220c28241a130a281a130b2f1a130c231a130d250c24271a130e24190a30ff2f24019c1a1301241a130221ffbe1affbf1dff7c171a1306121a13073e1a1308200c24201a1309241a130a201a130b161a130c231a130d120c23461a130e23190a3bff2f2301a31a1301231a1302210c2309ffbe23ffbf1dff7c0b0c23171a1306231a1307411a13ffc9450b23401a130b231a130c141a130d250c14201a130e14190a41ff2f1401ac1a1301141a1302370c1409ffbe140b143affbf14ff7c2bff8a091a13082d1a1309441a130a351a130b1cffcaff9a0eff3245ff2f1401b21a1301141a130221ffbe09ffbf43ff7c341a1306291a1307341a1308391a13094b1a130a471a130b01ffca440c1c101a130e1c190a2213ffe8461a1002210c131a1a1003131a1004181a1005451a1006021a10070d1a1008261a10093b1a100a3f1a100b4b1a100c181a100d451a100eff321210ffe80e1a1002210c130d1a1003131a10040f1a1005380c0f2b1a10060f1a1007450b0f2e1a10080f1a10094b1a100a3a1a100b2d1a100c431a100d250b0f8f1a100e0f190a4410040fffd634ffe80e1a10023c1a10030d1a10042f1a1005011a1006010c0e0d1a10070e0c0e0d1a10080e1a10090b0c0e1b1a100a0e190a0b100a0e0c1b1001b9ff352bff5a12ffc0010c1016ff420dff9209ff2909ff27c0ff352bffcb0cffc0300c1020ff421bff9230ff2902ff27caff1e311a0e0309ff5a02ffc01f1a0e07390c101bff232b0c102bff291bff27d1ff352bff5a44ffc0011a0e072d0c100dff920dff290dff27d6ff1e381a0e033bffcb30ffc0010c1023ff4202ff230b1a0e0a0d190a2bff27dcff1e381a0e030d1a0e042f0c10091a0e0510ffc01f0c1034ff4202ff23020c1002ff2925ff27e1ff35021a0e042f0c101b1a0e0510ffc0481a0e072d0c100dff232b0c1009ff2930ff27e8ff351b1a0e043e1a0e0534ffc01a0c1020ff423bff920dff293bff27eeff352b1a0e043e1a0e0544ffc0340c100dff420dff920dff2941ff27f5ff350dff5a12ffc0010c1034ff420dff9209ff2945ff27f9ff3502ff5a3effc0020c1034ff420dff23090c1044ff29220e0a0e0c1b100201ff353bffcb12ffc01b1a0e07250c100d1a0e08100c101b1a0e09100c1030ff29120e0a0e0c1b100208ff35221a0e04481a0e0534ffc00c1a0e07390c10301a0e08100c103b1a0e09100c1009ff29440e040effd6250a100c1b130211ff4a12ffe90bff5b16ff4a3d1a100319190a09ff5b1aff4a11ffe902ff5b1fff4a0c1a100348190a1bff5b26ff4a441a100344190a0dff5b2cff4a30ffe92b100410ffd6410a130c1b160235ff3122ff5925ff7c171a1306171a130709190a0bff963dff313bffbe2bffbf3bff7c171affaf09ff9644ff3112ffbe0cffbf0dff7c171b160154ffd802ff964cff3122ffbe2bffbf12ff7c2b1affaf1bff9654ff3112ff59120c161fff7c161b1601aeff5cff320dff965dff3144ffbe22ffbf250c1634ff7c160b1678ffd82bff9668ff3145ff5944ff7c3d1affaf25ff9672ff3144ffbe3bffbf09ff7c020c1617ffd830ff9677ff3144ffbe340c1602ffbf160b1647ff7c160b1696ffd83b130413ffd60d0a1c0c1b24027fffd90dff7f01ff75ff8015ff814bff820c190a0bff28240288ffd91bff7f01ff75ff8015ff814bff820c190a09ff28240296ffd90dff7f2fff75ff8042ff810b0c2401ff8224190a02ff2824029dffd91bff7f2fff75ff8042ff810b0c2401ff8224190a1b1c0401ffd6340a1c0c1b2402a9ff7d241b2602afff7e261b2702b7ff7f271b2802bfff9b28ff9c271b2802c7ff8028ff81281b2902cfff82291b2902d7ff9d291b2902dfff9e291b3102e7ff9f311b3102efffa0311b3102f7ffa1311b3102ff00ffda0bff28320307ff7d321b33030dff7e33ff7f28ff9b31ff9c281b280315ff80281b33031dff81331b350325ff82351b35032dff9d351b350335ff9e351b36033dff9fff880345ffa0ff88034dffa136ffa233190a09ff28330355ff7d331b33035cff7e331b360364ff7f361b39036cff9b39ff9cff880374ff80361b39037cff81391b390384ff82391b39038cff9d391b3a0394ff9e3a1b3d039cff9ffff8a4ffa0fff8acffa1fff8b4ffa23d190a02ff283d03bcff7d3dff7e261b3d03c1ff7f3d1b3e03c9ff9b3eff9c3dff80361b3d03d1ff81fff8d9ff82fff8e1ff9dfff8e9ff9efff8f1ff9ffff8f9ffa03dffa135ffa235190a1bff28350401ff7d351b350407ff7e351b3d040fff7f3d1b3e0417ff9b3eff9cfff91fff80fff927ff81fff92fff82fff937ff9dfff93fff9efff947ff9ffff94fffa0fff957ffa13dffa228190a0dff2828045fff7d28ff7e351b28046cff7f281b3d0474ff9b3dff9cff857cff80ff8584ff81ff858cff82ff8594ff9dff859cff9eff85a4ff9fff85acffa0ff85b4ffa1ff85bcffa228190a2bff282804c4ff7d28ff7e26ff7f361b2604cbff9b26ff9c36ff80271b2604d3ff8126ff8227ff9d39ff9e3a1b2604dbff9f261b2604e3ffa0261b2604ebffa1261b2604f3ffa226190a25ff282604fbff7d26ff7e351b260502ff7f261b27050aff9b27ff9cff4612ff80261b27051aff8127ff82ff4622ff9d261b27052aff9e27ff9f26ffa0291b260532ffa1ff463affa226190a30ff28260542ff7dff4647ff7e261b27054fff7f271b360557ff9b36ff9c271b27055fff80271b360567ff81ff88056fff82ff880577ff9dff88057fff9eff880587ff9fff88058fffa0ff880597ffa1ff88059fffa236190a3bff283605a7ff7d36ff7eff46acff7f261b3605b4ff9b36ff9cff46bcff80ff46c4ff81ff46ccff82ff46d4ff9dff46dcff9eff46e4ff9fff46ecffa0ff46f4ffa1ff46fcffa226190a41ff28260604ff7d261b36060aff7eff880612ff7f361b3a061aff9b3aff9cff880622ff80ff88062aff81ff880632ff82ff88063aff9dff880642ff9eff88064aff9f36ffa0291b360652ffa136ffda45ff2831065aff7d31ff7e331b310661ff7f311b360669ff9b36ff9cff4771ff80ff4779ff81ff4781ff82ff4789ff9dff4791ff9eff4799ff9fff47a1ffa0ff47a9ffa1ff47b1ffda22ff283106b9ff7d31ff7e351b3106beff7f311b3506c6ff9b35ff9c31ff80391b3106ceff81ff47d6ff82ff47deff9dff47e6ff9eff47eeff9f31ffa0291b3106f6ffa1ff47feffda12ff28310706ff7d31ff7e331b33070dff7f331b350715ff9b35ff9c33ff80fff01dff81fff025ff82fff02dff9d27ff9e291b270735ff9ffff03dffa027ffa129ffa229190a441c041cffd6250a270c1b3307451a2701331b33074a1a270233190a0b270a270c1b3307521a2701331b3307591a270233190a09270a270c1a2701261b2607611a270226190a02270a260c1b2707691a2601fff0701a260227190a1b260a260c1a2601241a260229190a0d260a260c1a2601321b2707781a260227190a2b260426ffd6220a270c1a2701241a27021d091d0dffcc0d191d022b191d1b251a27031d091d45ffcc09191d0202191d1b1b191d0d0d191d2b2b191d2525191d3030191d3b3b191d41411a27041d091d09191d0b0b1a27051d091d0dffcc09191d0202191d1b1b1a27061d1a27070b1a27080b1a2709ff320b270a1d0cffe032ffe12d092702ffcd25ffe22709270dffcd451927022219271b12ffe32709270919270b09ffe42709271bffcd091927ff9327ff8b09ff861b270780ffe027ffe11509333019330b09193309021933021b19331b0d19330d2b19332b2519332530ffe23309334119330b09193309021933021b19331b0d19330d2b19332b25193325301933303b19333b41ffe33309331b19330b021933091b1933020dffe43309331b19330b0b193309091933ff9333ff330b33ff00ffea02ff861b350786ffe035ffe12f09360dffce0d1936022b19361b25ffe236093625ffce091936020d19361b2519360d3019362b3bffe336ffb32bffe436ffb31b1a1d0636ff8b1bff86ffe028ffe11fffb325ffe23609360219360b0919360912ffe336ffb325ffe43609361bffce091936ff9336ff8b0dff861b360790ffe036ffe145093902ff8c25ffe239093902ff8c3bffe339ffb430ffe43909391bff8c091939ff9339ff8b2bff86ffe014ffe12bffb40bffe239ffb40bffe339ffb422ffe43909391bff8c091939ff93391a1d070c1a1d08221a1d09ff3225ff861b390798ffe039ffe12bffb51b193a093bffe2ff5d25ffe3ff5d12ffe43affb50b193a09091a1d063a1a1d071a1a1d0812ffea30ff86ffe031ffe12bffb51b193a093bffe2ff5d25ffe3ff5d44ffe43a093a1b193a0b0b193a0909193aff933a1a1d071f1a1d0844ffea3bff861b3307a0ffe033ffe112093a30193a0b09193a0902193a021b193a1b0d193a0d2b193a2b25193a253bffe23a093a41193a0b09193a0902193a021b193a1b0d193a0d2b193a2b25193a2530193a303b193a3b41ffe33affb53b193a0941ffe4ff5d0d1a1d063aff330b3a7f1a1d093a190a41ff861b3d07a6ffe03dffe12b093e3b193e0b09193e0902193e021b193e1b0d193e0d2b193e2b25193e2530193e303bffe23e093e25193e0b02193e091b193e020d193e1b2b193e0d25193e2b41ffe33e093e09193e0b45ffe43e093e09193e0b2b1a1d063eff331a1d093a190a451d041dffd6220a3a0c1a3a01241a3a02091a3a03091a3a040b1a3a050b1a3a060b1a3a07ff320b3a0a240c1a240132ff8d09ffba09ff5e27ff8d0bffba02ff5e35ff8d0bffba1bff5e28ff5205091a2406091a240709190a0dff5e36ff8d09ffba2bff5e141a24020bff3e1a24050b1a24060bffba2524ffb639ff8e09ffeb3014ffb631ff8e09ffeb3b14ffb633ff8e0bffeb4114ffb63dff8e0b1a140409ff8f451404140a0a0a0c1a0a01091a0a02021a0a030d1a0a043b1a0a051a04240a0a0a0c1a0a01091a0a02021a0a030d1a0a043b1a0a051a1a0a062a1a0a07230b1a801a0a081a0423ffd641190a0b0b18272401190a09ff870118282402ffec022a1827240118282403ffec1b2a18272402190a0dff8703190a2bff8704190a25ff8705190a30ff870118282404ffec3b2a0427ffd644190a0b0bffc301190a0928ffc302190a0228ffc303182a2302ff611b31ffc303182a2304ff610d31ffc305190a2b28ffc305182a2306ff612531ffc306190a3028ffc306182a2303ff613b31ffc306182a2304ff614131ffc307190a4528ffc308190a2228ffc307182a2308ff61123104280a060a1e062a0f06310e06321006331306350107360b073909073a02073d1b073e0d073f2f07422b07432507463007473b073b41074845074922074c12071244074d3407340c234e1d360217361d4e171d144e08140b184e3603184f3604185036051851360618523607185336081854360918551d0218561d0418571d0518581d0618591d07151d481a1548491a1c49485715484c4415444d1a051a4e1f4c391a171a4e4c05394f1f4c3a3917394f4c053a501f4c3d3a173a504c053d511f4c123d173d514c054c51144d4c02254c4d02091f4d124c1d124d09174c511214124c0b1c4d124825124d0b3d144d4c0b1c4e4d4825484e4c3d213d0a1b1f4c3e3d253d52524c213e0a1b1f0a3f3e253e52520a210a2a1b1f2a420a250a53532a1f2a43311f3146321f3247331f333b351735271a171a28391427540b162834541c34272818272401112835ff8702113935ff8703113b35ff8704113f35ff870511243527182723011135ff79021142ff79031143ff79041146ff79051147ff7906114cff7907114dff790811231a27041a34042734043455174e133217131c3a171c26121712264818261c0218321202253a44322625484426321826130218321306184f1307185013081851130318521305185313091854130a1855130b1857130c185a130d185b130e045c262526494f32255d49324f1b3207ad1b4907b51b4f07bd0d5e581c5f3f5e255e5f26511c5f3f5825585f26511c513f59255f515d580d51591c60355125516026521c60355925616026521c6035592562605d52255259265d25604d2650255059266025602352502563595d601b5907c51b6007cf256456602925295659601b5607d71b5907e117601e3d173d1e3e171e0f0a170a0e2a170e1031170f0133180136011810130118136001182a3d0118311e0118330a0118361201183e1c01256544363e18361c01181c1201251244361c181c0e0118364e01183e0f011344030b1b0307e92744030104051b0107efffe51004051b0107f7ffe51304051b0107fdffe52aff7a03ffe531ff7a07ffe533ff7a0cffe565ff7a1affe512ff7a27ffe51cff7a2effe536ff7a34ffe53e04051301060b0c01450703400b04882105030421030105250114030b07034b2105ffbd45052505ff94112106ffbd2b062506ff94192110ffbd2f102510ff94372111ffbd45112511ff942d2112ffbd2f122512ff94212113ffbd1b132513ff94202119ffbd1b19250414030925031418151d1413411d19132218136002181c6003182060041821600518226006182a600718316008183360091836600a1837600b183e600c1840600d18443d0218603d0318653d0418663d0518673d0618683d0718693d08186a3d09186b3d0a186c3d0b186d3d0c186e3d0d103d13441d13013d1d3d121310131c60101c20651d20011c1d011220101c2166102022671d21122010202a681d22122010203169102a336a1031366b1033376c10363e6d1d3711361011406e18361e02213e360518361e0318401e041d44400518051e0518401e0618601e0718651e0818661e0918671e0a18681e0b18691e0c186a1e0d186b1e0e181e0a021e6c0602216d1e6c181e0a031d6c121e181e0a041d6e1e06181e0a051d6f1e06181e0a061d701e0618060a07181e0a0818710a0918720a0a1d0a127218120e021d72121018120e031d0e121018100f0218120f0318730f0418740f0518750f0618760f0718770f08180f4e0518784e0218794e031d7a047918794e041d4e04790b040004793d047b1304130104011c047c210b7d00047e221022047b107f791310807b011081137c1082017d10837c7e21847f792085158421847b041e8685840484ffe6837c208531ffe67d011e3185ffe61379208586fffa85151d8522ffe67b04202286fffa221521227fffe67c13207f84fffa7f151d7f80ffe6017b208684fffa8615218681ffe67c13208784fffa8715218780ffe6017b208084fffa80151d8081ffe67e7c208131fffa81151d8182ffe67d01208231fffa82152131832020207b0d1e82204504207910837b851084132224227f872a10857b22242286802a102a13222422877f15107f0122242280861510807c221022018110817c31203101331e33311504317e28860122337d3728877c81317e3728880482837b3e2889792084133e283e7b83820411288a13842079111d113e3621368affb78b05208c448b0c4415228b40440b0c448b1e8b44151e448b15208b8c441d44058b248b1188ffb78c05208d448c0c4415228c40440b0c448c1e8c44151e448c15208c8d441d44058c248c3689ffb78d05208e448d2244400b151e8d44151e448d15208d8e441d44058d248d113effb78e05208f448e2244400b151e8e44151e448e15208e8f441d44058e248e368a442444883e68248f898a682168156a2490883e682168156a246a898a681068449010918f6a24926811691e116b151d6b92112411913669ffdb6905209236690c3615226940360b0c36691e6936151e366915206992361d36056924696b4436ffdb9205209336920c3615229240360b0c36921e9236151e369215209293361d3605922492118f36ffdb9305209436932236400b151e9336151e369315209394361d36059324936b9036ffdb6b052094366b2236400b151e4036151e364015204094361d3605402405116a361011888b1036898c10408b8d106b8c8e10948d3e10958e8a21968c89209760961e9697151d97119621118b88209660111e1196152196361121118e8c203665111e1136151d36401121118d8b204065111e11401521406b1121118a8e206566111e1165151d65941121113e8d206b66111e116b15216b9511101188971094899610958b9710978c9610968b3610988c4010998d3610368e4010408d65109a8e6b109b3e6510658a6b106b4469109c8f92109d6993109e9205109f939010a0056a21a1928f20a260a11ea1a2151da26ba1216b694420a1606b1e60a115216b9c6021600592209c67601e609c151d9c9d6021609369209d67601e609d1521679e6021606a05209d66601e609d151d9d9f6021609093209e66601e609e152166a060106044a2109e8f6b109f69a210a0926b106b699c10a1926710a2939c109c05671067939d10a3056610a4909d109d6a660b66000ba5000ca66e0ba7000ba8000ca96f20aa66152466a970aa04a96e0b6e000baa000cab6f206fa51524a570ab6f046fa61eab66021eaca60204ad661eaea90204af6604b0a91eb1660204b2a91eb3a5021eb4a90204b5a51eb6a60204b7a504b8a61eb9a5020bba140bbb001dbc380a0c0a142138bc1904bd1421bebc1910bfbb0a10c0bc3810c10abd10c238be10c3bdbb10c4bebc21c538bc20c6bac51ec5c6151dc6bfc521bf0abb20c5babf1ebfc51521c5c0bf21bfbe3820c0babf1ebfc0151dc0c1bf21bfbd0a20c1babf1ebfc11521c1c2bf21bfbcbe20c2babf1ebfc2151dc2c3bf21bfbbbd20c3babf1ebac31521bfc4ba10babbc610c3bcc510c40ac610c638c510c50ac010c738c110c8bdc010c0bec110c1bdc210c9bebf10cabbc210c2bcbf28bfbbbac40a2f28cbbcc3c6382f28ccbbbac40a1828cdbcc3c638181dcebf0920cf140d1ed0cf4521cfcbd020d0140d1e14d0451dd0bf14201419251e1914452114cb190b19001dd1bc782278d1bc7e04d17a1d7a784e224e7abc7e107a19d110d2784e21d34e7820d40fd31ed3d41521d47ad3217ad11920d30f7a1e0fd3151d7ad20f100f19d410d2787a10d3d1d410d44e7a207a0c731ed57a450b7a0004d6750475761076d5d610d77a7521d8757a20d977d81ed8d9151dd976d82176d6d520d877761e76d8152177d7761076d5d910d77a7710d8d6d910d9757724773c453724da15173724db2c0b371d2c864b24dc3c453724dd862cdc1d2c871624dc3c4537243c872cdc242c170b371ddc864b1dde87301e30371521df09300b302a20e0df3020df4be01ee0df151edf3715213709df20df3730203016df1e3730150b30000bdf0404e1030403dd04e23c04e38604e48704e5bc04e67704e73d04e86d04e96c04ea6d04eb6c04ec1e04ed7104ee6d046d6c04efbc04f0741374070b0e083d015c0e0963015e0e09a801510e09ed01260e0a32015d0e0a7701520e0abc015f0e0b0101580e0b4601610e0b8b01620e0bd101560e0c1701630e0c5d01500e0ca301530e0ce901480e0d2f013a0e0d7501540e0dbb01640e0e0101290e0e4701590e0e84015a0e0e4701490e0e47014f0e0eca01550e0f1001570e0f56015b0e0e4701320e0f9c02e10e120e0c07861d2607450226ff6321078717ffbb212686450226ff6321078717ffbb1d07864b0207ff631d078716ffbb0c26862129264b0229ff631d07871602070e126e250724fff7070e12eb2007dc0d1e24074520072c021d26de070c07dc2029070d1e072945200d2c021d29de0d0c0ddc2adcde242607290dde0e133225073ffff7070e141b0c07dd0207ff6302e20e126c0c07dd0b0d6e1d24070d0224ff631d073c16ffbb0c24dd2126244b0226ff631d243c1602240e143effd402e20e126c2103dd0dffd41d073c16ffbb1d03dd4bffd41d243c1602240e1463250328fff7030e14781d0386e00c07032103072dffd41d0387372107032f02070e14c125033bfff7030e15d10c03861d0703db0207ff6302e40e15f4210386db02030e126c02e3ff632003db2b1d07870302070e15f40c038602030e1463250339fff7030e15f61e03da0202030e162c0f0479ff3c822083847b13ff3c852a7f80017cff3c228133317d7effd503330c07220c0d0129033107810d7cffd5037f0c07850c0d7b290380072a0d13ffd503830c07820c0d0429038407200d790e16b70c030925071d030902070e16df0f8889ff3c119495978b8cff3c969899368d8eff3c409a9b653e8a0e17260f448fff3c609e9fa06992ff3c6ba1a29c9305ff3c67a3a49d906a0e17e50f0479ff3c822083847b13ff3c852a7f80017cff3c228133317d7effd503330c05220c07012903310581077cffd5017f0c03850c057b290180032a0513ffd501830c03820c0504290184032005790e1954250142ff6219d11d01bc2eff3a19fe250147ff621a2202e50e1a911d01bc15ff3a1a981d01bc15ff3a146325014cff621a9e1d01bc25ff3a1acc1d01bc25ff3a1b0c25014dff621b300f88890e16b62101682f1d03910c1d04680c1d05910c29010304053e8a0e1b52250123ff621b700b014821036c0102030e1b9f250146ff621bc4ffb81c36ffb8126c02e6ff631d01bc18ff3a126c0c0377ffd41d01bc18ff3a1463250143ff621c3bffb81c36ffb81463250135ff621cb102e70e1cde21016c17ff3a1d1f21016c17ff3a1d5f250127ff621d8a1d011c4b0c0301ffd42101212bff3a1dc125011aff621f1d21013d4bff3a1f58ffcf200f02e80e201d02e90e2020ffcf207a0b01b420030115200106031e0301151b01013a1e04030102040e208fff4bff3cff5f16b6ff53b1016eff3cff4c16b6ff3fb901a70e2096ff78ff55ffb0210cff4b0e210a1e0170021e0370091e047009296f01ac03a8040e210a1e0170091e0370021d04a9df29ae01b00304ff55ffb0210cff78ff550e211102eaff6302eb0e21ba02ec0e21ee02ed0e21f51e017202ff3a21fc1e010e02ff3a22031d01a91e1d03a8ff90126a1d016e711d0366ff9023af1d01aa1e1d03a6ff90126a1d01a5711d03a7ff90241fffcf24fe02e80e201d02e90e250b02eeff63026d0e25cf02ef0e26512101bcbc210378bc26bb0119030e26ce210178bc2103d2bc2104d4bc21054ebc2a19010f03d304d1050e2727250134ff6227670c01732003012b1e010345ff3a126a02f00e27a60c011fff3a208fffdcd8d9d6750e27f60c011f0b033920040203200512041e0405151d05010402050e208f2001d8411e0401452001d6411e050145ffdc04d905750e284614011002250201fff7020e288d0c011f20020903200412021e0204151d04010202040e208fffdcd8d9d6750e28461401101b250201fff7020e288d0c011f20021b03200312021e0203151d03010202030e208f2001d84a1e0201152001d64a1e030115ffdc02d903750e28a20fbbbcff3cbac3c4c60a38ff3cc5c7c8c0bdbeff3cc1c9cac2bbbc0e295e2abfcbcecfd014cccd0e29c21301080b";
        

        assembly {
// START ---    

            
// ---- DEBUG ----

// Log calls
// 
// function log_byte(byteValue) {
//     let pOutput := m_get(/*/*VAR_ID_DEBUG*/0x150*/276)
// 
//     let len := mload(pOutput)
//     // store the increased length
//     mstore(pOutput, add(len, 1))
// 
//     // store the byte
//     mstore8(add(pOutput, add(len, 32)), byteValue)
// }
// function log_digit(v, tensValue) {
//     if not(slt(v, tensValue)) { log_byte(add(48/*0*/, smod(sdiv(v, tensValue), 10))) }
// }
// function log_varString(varId) {
//     log_string(m_get(varId))
// }
// function log_string(pEntry) {
//     let sEntry := mload(pEntry)
//     pEntry := add(pEntry,32)
// 
//     log_bytes(pEntry, sEntry)
// }
// function log_bytes(pEntry, sEntry) {
//     for { let k := 0 } slt(k, sEntry) { k := add(k, 1)}{
//         log_byte(mload8(add(pEntry, k)))
//     }
// }
// function log_literal(text) {
//     let pEntry := 0x00
//     mstore(pEntry, text)
//     for { let k := 0 } slt(k, 32) { k := add(k, 1)}{
//         let v := mload8(add(pEntry, k))
//         if iszero(v) { leave }
//         log_byte(v)
//     }
// }
// function log_int(v) {
//     log_digit(v, 100000000)
//     log_digit(v, 10000000)
//     log_digit(v, 1000000)
//     log_digit(v, 100000)
//     log_digit(v, 10000)
//     log_digit(v, 1000)
//     log_digit(v, 100)
//     log_digit(v, 10)
//     log_digit(v, 1)
// }
// function log_gas() {
//     log_literal('\n GAS=\x00')
//     log_int(gas())
// }
// function log_wasteRemainingGas() {
//     log_literal('\n# wasteRemainingGas\x00')
// 
//     for { let k := 0 } sgt(gas(), 100000) { k := add(k, 1)}{
//         if iszero(smod(k,25000)){
//             log_gas()
//             log_literal(' :: iterations: \x00')
//             log_int(k)
//         }
//     }
//     log_gas()
// }

// ---- DEBUG END ----

// ---- YUL CODE ----
function mload8(addr) -> result {
    // yul: result := shr(0xF8, mload(addr)) leave 
    result := shr(0xF8, mload(addr)) leave 

}
function m_varAddress(varId) -> result {
    // if !Number.isInteger(varId) { throw new Error(`m_varAddress: varId is not an integer: ${varId}`) }
    result := add(mload(/*PP_VARS*/0x80), mul(varId, 32)) leave 

}
function m_get(varId) -> result {
    result := mload(m_varAddress(varId)) leave 

}
function m_set(varId, value) {
    mstore(m_varAddress(varId), value)
}


// ---- Utility Methods ----
function op_isKittenOutput(setVarId, _ignore) {
    m_set(setVarId, hasKindFlag(/*KIND_FLAG_KITTEN*/0x08))
}
function op_getRvsValue(setVarId, varId) {
    // rvs[0] = most signficant byte, which is the left most (smallest index in memory)
    m_set(setVarId, mload8(add(m_get(/*VAR_ID_RVS*/0x120), m_get(varId))))
}

function op_getBreedIndex(setVarId, breedsVarId, rvsBreedVarId, oddsFieldIndex) {
    let pBreedsArray := m_get(breedsVarId)
    let len := mload(pBreedsArray)

    let rv := m_get(rvsBreedVarId)

    for { let i := 0 }  slt(i, len) {  i := add(i, 1) } {
        let pBreedArray := mload(add(pBreedsArray, mul(32, add(i, 1))))
        let pOdds := add(pBreedArray, mul(32, add(oddsFieldIndex, 1)))
        let odds := mload(pOdds)
        rv := sub(rv, odds)
        if slt(rv, 0) {
            m_set(setVarId, i)
            leave
        }
    }
    m_set(setVarId, 0)
}

// Commands
function hasKindFlag(kindFlag) -> result {
    result := iszero(iszero(and(m_get(/*VAR_ID_KIND*/0x160), kindFlag))) leave 

}

function op_command_writeAttributeValue(setVarId, keyVarId, valueVarId, betweenKeyValueTemplateVarId, afterAttributeTemplateVarId) {
    if iszero(hasKindFlag(/*KIND_FLAG_JSON*/0x02)) {
        // Skip json
        leave
    }
    write_dataPackString(m_get(keyVarId))
    write_dataPackString(m_get(betweenKeyValueTemplateVarId))
    write_dataPackString(m_get(valueVarId))
    write_dataPackString(m_get(afterAttributeTemplateVarId))
}

// templateKind: 1=token,2=contract
function op_command_writeTemplate(templateVarId, templateKindVarId) {
    if iszero(hasKindFlag(/*KIND_FLAG_JSON*/0x02)) {
        // Skip json
        leave
    }

    let isWritingContract := hasKindFlag(/*KIND_FLAG_CONTRACT*/0x04)
    let templateKind := m_get(templateKindVarId)

    if and(isWritingContract, eq(templateKind, 1)) {
        // Skip token template if generating contract
        leave
    }
    if and(not(isWritingContract), eq(templateKind, 2)) {
        // Skip token template if generating contract
        leave
    }
    write_dataPackString(m_get(templateVarId))
}

// Arrays
function op_mem_create(setVarId, countVarId) {
    let count := m_get(countVarId)
    let pMem := allocate(mul(add(count, 1), 32))
    // mem: [memLength], [0:count,...]
    let pArray := add(pMem, 32)
    mstore(pArray, count)

    m_set(setVarId, pArray)
}
function op_mem_setItem(arrayVarId, itemIndex, valueVarId) {
    let pArray := m_get(arrayVarId)
    let pItem := add(pArray, mul(32, add(itemIndex, 1)))
    let v := m_get(valueVarId)
    mstore(pItem, v)
}
function op_mem_getItem(setVarId, arrayVarId, itemIndex) {
    let pArray := m_get(arrayVarId)
    let pItem := add(pArray, mul(32, add(itemIndex, 1)))
    m_set(setVarId, mload(pItem))
}
function op_mem_getLength(setVarId, arrayVarId) {
    let pArray := m_get(arrayVarId)
    // array[0]: length
    m_set(setVarId, mload(pArray))
}

// Output
function write_byte_inner(byteValue) {
    let pOutput := m_get(/*VAR_ID_OUTPUT*/0x140)

    let len := mload(pOutput)

    // store the byte
    mstore8(add(add(pOutput, 32), len), byteValue)

    // store the increased length
    mstore(pOutput, add(len, 1))
}


function enableBase64() {
    let pOutputQueue := allocate(1)
    mstore(/*PP_OUTPUT_QUEUE*/0x00, pOutputQueue)
    // Reset length to 0
    mstore(pOutputQueue, 0)
    // Clean new memory
    mstore(add(pOutputQueue, 32), 0)
}
function disableBase64() {
    write_flush()

    // NULL if not enabled
    mstore(/*PP_OUTPUT_QUEUE*/0x00, 0)
}

function write_flush() {
    let pOutputQueue := mload(/*PP_OUTPUT_QUEUE*/0x00)
    if pOutputQueue {

        let pOutput := m_get(/*VAR_ID_OUTPUT*/0x140)
        let len := mload(pOutputQueue)
        write_base64Queue(pOutputQueue)

        switch len 
            case 0 {
                // Backup 4 bytes (entire base64 write)
                mstore(pOutput, sub(mload(pOutput), 4))
            }
            case 1 {
                // Backup and write padding bytes
                mstore(pOutput, sub(mload(pOutput), 2))
                write_byte_inner(0x3D/*=*/)
                write_byte_inner(0x3D/*=*/)
                leave
            }
            case 2 {
                // Backup and write padding bytes
                mstore(pOutput, sub(mload(pOutput), 1))
                write_byte_inner(0x3D/*=*/)
                leave
            }
    }
}

function getBase64Symbol(value) -> result {
    value := and(value, 0x3F)
    if slt(value, 26) {
        result := add(value, 65/*A=65-0*/) leave 

    }
    if slt(value, 52) {
        result := add(value, 71/*a=97-26*/) leave 

    }
    if slt(value, 62) {
        result := sub(value, 4/*0=48-52*/) leave 

    }
    if eq(value, 62) {
        result := 43/*+*/ leave 

    }
    if eq(value, 63) {
        result := 47/* / */ leave 

    }
}

function write_base64Queue(pOutputQueue) {

    let bits := mload(add(pOutputQueue, 32))

    // Reset queue
    mstore(pOutputQueue, 0)
    mstore(add(pOutputQueue, 32), 0)

    // console.log('write_byte - base64 queue full', { bits })

    // write value at output
    let pOutput := m_get(/*VAR_ID_OUTPUT*/0x140)
    let outputLength := mload(pOutput)

    // // ....  00000000 11111111  11111111 11111111
    // // ....  00000000 xxxxxxxx  xxxxxxxx xx111111 => [35]
    // mstore8(add(pOutput, add(outputLength, 35/*32+[0,1,2,3]*/)), and(bits, 0x3F))
    // // ....  00000000 00000011  11111111 11111111
    // bits := shr(6, bits)
    // // ....  00000000 000000xx  xxxxxxxx xx111111 => [34]
    // mstore8(add(pOutput, add(outputLength, 34/*32+[0,1,2,3]*/)), and(bits, 0x3F))
    // // ....  00000000 00000000  00001111 11111111
    // bits := shr(6, bits)
    // // ....  00000000 00000000  0000xxxx xx111111 => [33]
    // mstore8(add(pOutput, add(outputLength, 33/*32+[0,1,2,3]*/)), and(bits, 0x3F))
    // // ....  00000000 00000000  00000000 00111111
    // bits := shr(6, bits)
    // // ....  00000000 00000000  00000000 xx111111 => [32]
    // mstore8(add(pOutput, add(outputLength, 32/*32+[0,1,2,3]*/)), and(bits, 0x3F))

    let pRightmost := add(add(pOutput, 35/*32+[3,2,1,0]*/), outputLength)
    for { let i := 0 }  slt(i, 4) {  i := add(i, 1) } {
        // ....  00000000 xxxxxxxx  xxxxxxxx xx111111 => 32+[3,2,1,0]
        mstore8(sub(pRightmost, i), getBase64Symbol(bits))
        // ....  00000000 00000011  11111111 11111111
        bits := shr(6, bits)
    }

    mstore(pOutput, add(outputLength, 4))
}

function write_byte(byteValue) {
    let pOutputQueue := mload(/*PP_OUTPUT_QUEUE*/0x00)
    if pOutputQueue {
        let queueLength := mload(pOutputQueue)

        // Store in the rightmost location of the 32 slot
        //          [61]     [62]      [63]     |
        // ........ AAAAAAAA BBBBBBBB  CCCCCCCC |
        // ........ aaaaaa aabbbb bbbbcc cccccc |
        mstore8(add(add(pOutputQueue, 61/*32+32-3*/), queueLength), byteValue)
        queueLength := add(queueLength, 1)
        mstore(pOutputQueue, queueLength)

        // 3*bytes is full -> write 4*base64
        if eq(queueLength, 3) {
            queueLength := 0
            write_base64Queue(pOutputQueue)
        }

        leave
    }

    write_byte_inner(byteValue)
}

function write_nullString(pNullTerminatedString) {
    for {  }  true {  pNullTerminatedString := add(pNullTerminatedString, 1) } {
        let x := mload8(pNullTerminatedString)
        if iszero(x) { leave }

        write_byte(x)
    }
}

function write_dataPackString(v) {
    let pEntry := add(m_get(/*VAR_ID_DATA_PACK_STRINGS*/0x131), v)
    write_nullString(pEntry)
}

function write_digit(v, tensValue) {
    if iszero(slt(v, tensValue)) { write_byte(add(48/*0*/, smod(sdiv(v, tensValue), 10))) }
}
function write_int(valueVarId) {
    let v := m_get(valueVarId)

    // if !Number.isFinite(v) {
    //     console.error(`intToString: not a number`, { v })
    //     throw new Error(`intToString: not a number ${v}`)
    // }
    // if !Number.isInteger(v) {
    //     console.error(`intToString: not an integer`, { v })
    //     throw new Error(`intToString: not an integer ${v}`)
    // }

    if eq(v, 0) {
        write_byte(48/*0*/)
        leave
    }

    if slt(v, 0) {
        write_byte(45/*-*/)
        v := sub(0, v)
    }

    write_digit(v, 100000)
    write_digit(v, 10000)
    write_digit(v, 1000)
    write_digit(v, 100)
    write_digit(v, 10)
    write_digit(v, 1)
}

function write_drawInstruction(aByte, bVarId, cByte, dVarId) {
    write_byte(aByte)
    write_int(bVarId)
    write_byte(cByte)
    write_int(dVarId)
}


// ---- Decompress Data Pack ----

function appendUsingTable(pTarget, isControlByte, b) {
    let sTarget := mload(pTarget)
    pTarget := add(pTarget, 32)

    if isControlByte {
        let pSource := m_get(b)
        let sSource := mload(pSource)
        pSource := add(pSource, 32)


        for { let iSource := 0 }  slt(iSource, sSource) {  } {
            let piTarget := add(pTarget, sTarget)
            let piSource := add(pSource, iSource)
            mstore(piTarget,mload(piSource))

            let sCopied := sub(sSource, iSource)
            if sgt(sCopied, 32) {
                sCopied := 32
            }

            sTarget := add(sTarget, sCopied)
            iSource := add(iSource, sCopied)
        }
    }
    if iszero(isControlByte) {
        mstore8(add(pTarget, sTarget), b)
        sTarget := add(sTarget, 1)
    }

    mstore(sub(pTarget, 32), sTarget)
}

function run_decompressDataPack(_pDataPackCompressed) {
    // Skip length
    _pDataPackCompressed := add(_pDataPackCompressed, 32)

    let pDataPack := allocate(/*LENGTH_DATA_PACK_ALL*/23599)
    // Reset length to 0
    mstore(pDataPack, 0)

    // Assign pDataPack vars
    m_set(/*VAR_ID_DATA_PACK_ALL*/0x130, pDataPack)
    m_set(/*VAR_ID_DATA_PACK_STRINGS*/0x131, add(add(32, pDataPack), /*INDEX_DATA_PACK_STRINGS*/0))
    m_set(/*VAR_ID_DATA_PACK_OPS*/0x132, add(add(32, pDataPack), /*INDEX_DATA_PACK_OPS*/10866))


    // Decompress
    /**
     * mode := 0: Loading data
     * mode := 1: Loading table
     * mode >= 2: Loading table entry
     */
    let mode := 1
    let isControlByte := 0

    // Record ff00 entry
    let iCurrentTableEntry := 1
    let pEntry := allocate(1)
    mstore8(add(pEntry, 32), 0xff)
    m_set(0, pEntry)

    for { let i := 0 }  slt(i, /*LENGTH_DATA_PACK_COMPRESSED*/15949) {  i := add(i, 1) } {
        let b := mload8(add(_pDataPackCompressed, i))
        if and(eq(b, 0xFF), iszero(isControlByte)) {
            isControlByte := 1
            mode := sub(mode, 1)
            continue
        }

        if sgt(mode, 1) {
            // Continue loading table entry

            appendUsingTable(pEntry, isControlByte, b)
            isControlByte := 0

            // Use up mode item
            mode := sub(mode, 1)
            if eq(mode, 1) {
                // Done
                moveFreePointerToEnd(pEntry)

                // Store pEntry in var
                m_set(iCurrentTableEntry, pEntry)

                // Next table entry
                iCurrentTableEntry := add(iCurrentTableEntry, 1)
            }
            continue
        }
        if sgt(mode, 0) {

            if iszero(b) {
                // Begin content
                mode := 0
                // Skip content length (4 bytes)
                i := add(i, 4)
                continue
            }

            // Start loading table entry by recording the length to load
            mode := add(mode, b)
            // Prepare next memory
            pEntry := allocate(0)

            continue
        }

        appendUsingTable(pDataPack, isControlByte, b)
        isControlByte := 0
    }

    // Move free memory pointer past data pack + size
    moveFreePointerToEnd(pDataPack)
}

// ---- Run Data Pack Ops ----

function run_DataPackOps(pDataPackOps) {
    for { let iByte := 0 }  slt(iByte, /*LENGTH_DATA_PACK_OPS*/12733) {  } {
        let countBytesUsed := op_byteCall(pDataPackOps, iByte)
        iByte := add(iByte, countBytesUsed)
    }
}


    

function op_byteCall(pDataPackOps, iByteStart) -> result {

    let opId := mload8(add(pDataPackOps, iByteStart))
    
    
    
    let argByte_1 := mload8(add(pDataPackOps, add(iByteStart, 1)))
    
    switch opId 
        case 1 { /*op_write_string*/write_dataPackString(m_get(argByte_1)) result := 2  leave }

        case 2 { /*op_write_var*/write_int(argByte_1) result := 2  leave }

    let argByte_2 := mload8(add(pDataPackOps, add(iByteStart, 2)))
    
    switch opId 
        case 3 { /*op_ceil_100*/m_set(argByte_1, sdiv(add(m_get(argByte_2), 99), 100)) result := 3  leave }

        case 4 { /*op_copy*/m_set(argByte_1, m_get(argByte_2)) result := 3  leave }

        case 5 { /*op_getArrayLength*/op_mem_getLength(argByte_1, argByte_2) result := 3  leave }

        case 6 { /*op_getLength*/op_mem_getLength(argByte_1, argByte_2) result := 3  leave }

        case 7 { op_getRvsValue(argByte_1,argByte_2) result := 3  leave }

        case 8 { op_isKittenOutput(argByte_1,argByte_2) result := 3  leave }

        case 9 { /*op_loadArray_create*/op_mem_create(argByte_1, argByte_2) result := 3  leave }

        case 10 { /*op_loadObject_create*/op_mem_create(argByte_1, argByte_2) result := 3  leave }

        case 11 { /*op_loadUint8*/m_set(argByte_1, argByte_2) result := 3  leave }

        case 12 { /*op_unaryNegative*/m_set(argByte_1, sub(0, m_get(argByte_2))) result := 3  leave }

        case 13 { /*op_unaryNot*/m_set(argByte_1, iszero(m_get(argByte_2))) result := 3  leave }

        case 14 { /*op_write_text*/write_dataPackString(add(mul(argByte_1, 256), argByte_2)) result := 3  leave }

        case 15 { /*op_write_vertex*/
            write_drawInstruction(
            77/*M*/,
            argByte_1,
            44/*,*/,
            argByte_2)
             result := 3  leave }

    let argByte_3 := mload8(add(pDataPackOps, add(iByteStart, 3)))
    
    switch opId 
        case 16 { /*op_average*/m_set(argByte_1, sdiv(add(m_get(argByte_2), m_get(argByte_3)), 2)) result := 4  leave }

        case 17 { /*op_bitwiseAnd*/m_set(argByte_1, and(m_get(argByte_2), m_get(argByte_3))) result := 4  leave }

        case 18 { /*op_bitwiseOr*/m_set(argByte_1, or(m_get(argByte_2), m_get(argByte_3))) result := 4  leave }

        case 19 { /*op_command_writeTemplate*/op_command_writeTemplate(argByte_2,argByte_3) result := 4  leave }

        case 20 { /*op_comparisonGreater*/m_set(argByte_1, sgt(m_get(argByte_2), m_get(argByte_3))) result := 4  leave }

        case 21 { /*op_comparisonLess*/m_set(argByte_1, slt(m_get(argByte_2), m_get(argByte_3))) result := 4  leave }

        case 22 { /*op_comparisonLessEqual*/m_set(argByte_1, not(sgt(m_get(argByte_2), m_get(argByte_3)))) result := 4  leave }

        case 23 { /*op_getArrayItem*/op_mem_getItem(argByte_1, argByte_2, m_get(argByte_3)) result := 4  leave }

        case 24 { /*op_getObjectField*/op_mem_getItem(argByte_1, argByte_2, argByte_3) result := 4  leave }

        case 25 { /*op_loadArray_setItem*/op_mem_setItem(argByte_1, m_get(argByte_2), argByte_3) result := 4  leave }

        case 26 { /*op_loadObject_setItem*/op_mem_setItem(argByte_1, argByte_2, argByte_3) result := 4  leave }

        case 27 { /*op_loadUint16*/m_set(argByte_1, add(mul(argByte_2, 256), argByte_3)) result := 4  leave }

        case 28 { /*op_logicalAnd*/m_set(argByte_1, and(m_get(argByte_2), m_get(argByte_3))) result := 4  leave }

        case 29 { /*op_mathAdd*/m_set(argByte_1, add(m_get(argByte_2), m_get(argByte_3))) result := 4  leave }

        case 30 { /*op_mathDiv*/m_set(argByte_1, sdiv(m_get(argByte_2), m_get(argByte_3))) result := 4  leave }

        case 31 { /*op_mathMod*/m_set(argByte_1, smod(m_get(argByte_2), m_get(argByte_3))) result := 4  leave }

        case 32 { /*op_mathMul*/m_set(argByte_1, mul(m_get(argByte_2), m_get(argByte_3))) result := 4  leave }

        case 33 { /*op_mathSub*/m_set(argByte_1, sub(m_get(argByte_2), m_get(argByte_3))) result := 4  leave }

    let argByte_4 := mload8(add(pDataPackOps, add(iByteStart, 4)))
    
    switch opId 
        case 34 { /*op_constrain*/
            let x_ltMin := slt(m_get(argByte_2), m_get(argByte_3))
            let x_gtMax := sgt(m_get(argByte_2), m_get(argByte_4))
            if  x_ltMin  { m_set(argByte_1, m_get(argByte_3)) }
            if  x_gtMax  { m_set(argByte_1, m_get(argByte_4)) }
            if  not(or(x_ltMin, x_gtMax))  { m_set(argByte_1, m_get(argByte_2)) }
             result := 5  leave }

        case 35 { op_getBreedIndex(argByte_1,argByte_2,argByte_3,argByte_4) result := 5  leave }

        case 36 { /*op_lerp_100*/
            let x_a := mul(m_get(argByte_2), sub(100, m_get(argByte_4)))
            let x_b := mul(m_get(argByte_3), m_get(argByte_4))
            let x_result := sdiv(add(x_a, x_b), 100)
            m_set(argByte_1, x_result)
             result := 5  leave }

        case 37 { /*op_ternary*/
            let x_default := iszero(m_get(argByte_2))
            if  not(x_default)  { m_set(argByte_1, m_get(argByte_3)) }
            if  x_default  { m_set(argByte_1, m_get(argByte_4)) }
             result := 5  leave }

        case 38 { /*op_write_line*/
            write_drawInstruction(
            77/*M*/,
            argByte_1,
            44/*,*/,
            argByte_2)
            write_drawInstruction(
            76/*L*/,
            argByte_3,
            44/*,*/,
            argByte_4)
             result := 5  leave }

    let argByte_5 := mload8(add(pDataPackOps, add(iByteStart, 5)))
    
    switch opId 
        case 39 { /*op_command_writeAttributeValue*/op_command_writeAttributeValue(argByte_1, argByte_2, argByte_3, argByte_4, argByte_5) result := 6  leave }

    let argByte_6 := mload8(add(pDataPackOps, add(iByteStart, 6)))
    
    switch opId 
        case 40 { /*op_bezierPoint_100*/
            let x_t100 := m_get(argByte_6)
            let x_tInv := sub(100, x_t100)
            // let x_a :=          mul(mul(mul(m_get(argByte_2),        x_tInv), x_tInv), x_tInv)
            // let x_b :=      mul(mul(mul(mul(m_get(argByte_3), 3),    x_tInv), x_tInv), x_t100)
            // let x_c :=      mul(mul(mul(mul(m_get(argByte_4), 3),    x_tInv), x_t100), x_t100)
            // let x_d :=          mul(mul(mul(m_get(argByte_5),        x_t100), x_t100), x_t100)
            // let x_result := sdiv(add(add(add(x_a), x_b), x_c), x_d), 1000000)
            let x1 :=                          m_get(argByte_2)
            let x2 := add(
            mul(x1, x_tInv),
            mul(mul(m_get(argByte_3), 3),                      x_t100)
            )
            let x3 := add(
            mul(x2, x_tInv),
            mul(mul(mul(m_get(argByte_4), 3),             x_t100), x_t100)
            )
            let x4 := add(
            mul(x3, x_tInv),
            mul(mul(mul(m_get(argByte_5),        x_t100), x_t100), x_t100)
            )
            let x_result := sdiv(x4, 1000000)
            m_set(argByte_1, x_result)
             result := 7  leave }

        case 41 { /*op_write_bezierVertex*/
            write_drawInstruction(
            67/*C*/,
            argByte_1,
            44/*,*/,
            argByte_2)
            write_drawInstruction(
            32/* */,
            argByte_3,
            44/*,*/,
            argByte_4)
            write_drawInstruction(
            32/* */,
            argByte_5,
            44/*,*/,
            argByte_6)
             result := 7  leave }

    let argByte_7 := mload8(add(pDataPackOps, add(iByteStart, 7)))
    
    let argByte_8 := mload8(add(pDataPackOps, add(iByteStart, 8)))
    
    switch opId 
        case 42 { /*op_write_bezier*/
            write_drawInstruction(
            77/*M*/,
            argByte_1,
            44/*,*/,
            argByte_2)
            write_drawInstruction(
            67/*C*/,
            argByte_3,
            44/*,*/,
            argByte_4)
            write_drawInstruction(
            32/* */,
            argByte_5,
            44/*,*/,
            argByte_6)
            write_drawInstruction(
            32/* */,
            argByte_7,
            44/*,*/,
            argByte_8)
             result := 9  leave }

}
    
            


// ---- Memory Management ----

function allocate(length) -> result {
    let pStart := mload(/*PP_FREE_MEMORY*/0x40)

    // align with uint256
    pStart := mul(sdiv(add(pStart, 31), 32), 32)

    mstore(/*PP_FREE_MEMORY*/0x40, add(add(pStart, 32), length))
    mstore(pStart, length)
    result := pStart leave 

}
function moveFreePointerToEnd(pItem) {
    let length := mload(pItem)
    mstore(/*PP_FREE_MEMORY*/0x40, add(pItem, add(length, 32)))
}

// Align memory start
if slt(mload(/*PP_FREE_MEMORY*/0x40), /*FREE_MEMORY_MIN_START_POS*/0xFFFD0) {
    mstore(/*PP_FREE_MEMORY*/0x40, /*FREE_MEMORY_MIN_START_POS*/0xFFFD0)
}

// Store length at memory start
let pMemoryStart := allocate(0)

// Disable base64 by default
mstore(/*PP_OUTPUT_QUEUE*/0x00, 0)

mstore(/*PP_VARS*/0x80, add(allocate(0x4000), 32))

m_set(/*VAR_ID_RVS*/0x120, add(allocate(32), 32))
mstore(m_get(/*VAR_ID_RVS*/0x120), rvs)


// Store memory start
m_set(/*VAR_ID_MEM_START*/0x110, pMemoryStart)

// Store dataPack vars
m_set(/*VAR_ID_DATA_PACK_COMPRESSED*/0x121, pDataPackCompressed)

// Allocate max size for pOutput
m_set(/*VAR_ID_OUTPUT*/0x140, add(allocate(40000), 32))
// Reset length to 0
mstore(m_get(/*VAR_ID_OUTPUT*/0x140), 0)

// Allocate max size for debug log
m_set(/*VAR_ID_DEBUG*/0x150, add(allocate(40000), 32))
// Reset length to 0
mstore(m_get(/*VAR_ID_DEBUG*/0x150), 0)

// ---- RUN ----


m_set(/*VAR_ID_KIND*/0x160, kind)
if and(hasKindFlag(/*KIND_FLAG_JSON*/0x02), hasKindFlag(/*KIND_FLAG_BASE64*/0x01)) {
    // Write base64 prefix for tokenURI
    let pText := allocate(0)
    mstore(pText, 'data:application/json;base64,\x00')
    write_nullString(pText)
}
if hasKindFlag(/*KIND_FLAG_BASE64*/0x01) {
    enableBase64()
}

run_decompressDataPack(m_get(/*VAR_ID_DATA_PACK_COMPRESSED*/0x121))
run_DataPackOps(m_get(/*VAR_ID_DATA_PACK_OPS*/0x132))
write_flush()
    

// Select output
switch kind
case 64 {
    output := m_get(/*VAR_ID_MEM_START*/0x110)
}
default {
    output := m_get(/*VAR_ID_OUTPUT*/0x140)
}

// Set free memory pointer to after output
mstore(0x40, add(output, add(32, mload(output))))

// --- END ---    
        }
        

        return output;
    }
}