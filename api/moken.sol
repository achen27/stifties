pragma solidity 0.4.24;
pragma experimental "v0.5.0";



interface ERC721TokenReceiver {


    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the recipient
    ///  after a `safetransfer`. This function MAY throw to revert and reject the
    ///  transfer. This function MUST use 50,000 gas or less. Return of other
    ///  than the magic value MUST result in the transaction being reverted.
    ///  Note: the contract address is always the message sender.
    /// @param _from The sending address 
    /// @param _tokenId The NFT identifier which is being transfered
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`
    function onERC721Received(address _from, uint256 _tokenId, bytes _data) external returns (bytes4);
}

/**
 * @title ERC721 Non-Fungible Token Standard basic interface
 * @dev see https://github.com/ethereum/eips/issues/721
 */
interface ERC721 {
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _tokenOwner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _tokenOwner, address indexed _operator, bool _approved);

    function balanceOf(address _tokenOwner) external view returns (uint256 _balance);
    function ownerOf(uint256 _tokenId) external view returns (address _tokenOwner);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes _data) external;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external;
    function transferFrom(address _from, address _to, uint256 _tokenId) external;
    function approve(address _to, uint256 _tokenId) external;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address _operator);
    function isApprovedForAll(address _tokenOwner, address _operator) external view returns (bool);
}

/// @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
interface ERC721Enumerable {
    function totalSupply() external view returns (uint256);
    function tokenOfOwnerByIndex(address _tokenOwner, uint256 _index) external view returns (uint256 _tokenId);
    function tokenByIndex(uint256 _index) external view returns (uint256);
}

/// @title ERC-721 Non-Fungible Token Standard, optional metadata extension
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
interface ERC721Metadata {
    function name() external pure returns (string _name);
    function symbol() external pure returns (string _symbol);
    function tokenURI(uint256 _tokenId) external view returns (string);
}

interface ERC165 {
    /// @notice Query if a contract implements an interface
    /// @param _interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `_interfaceID` and
    ///  `_interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 _interfaceID) external view returns (bool);
}


interface ERC998NFT {
    event ReceivedChild(address indexed _from, uint256 indexed _tokenId, address indexed _childContract, uint256 _childTokenId);
    event TransferChild(address indexed _to, bytes _data, uint256 indexed _childTokenId);    
    
    function childOwnerOf(address _childContract, uint256 _childTokenId) external view returns (uint256 tokenId);
    function onERC721Received(address _from, uint256 _childTokenId, bytes _data) external returns(bytes4);
    function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId) external;
    function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId, bytes data) external;
    
}

interface ERC998NFTEnumerable {
    function totalChildContracts(uint256 _tokenId) external view returns(uint256);
    function childContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address childContract);
    function totalChildTokens(uint256 _tokenId, address _childContract) external view returns(uint256);
    function childTokenByIndex(uint256 _tokenId, address _childContract, uint256 _index) external view returns (uint256 childTokenId);
}

contract Mokens is ERC721, ERC721Enumerable, ERC721Metadata, ERC165, ERC998NFT, ERC998NFTEnumerable {
    uint256 public blockNum;
    
    
    /// @dev Magic value to be returned upon successful reception of an NFT
    ///  Equals to bytes4(keccak256("onERC721Received(address,uint256,bytes)"))
    bytes4 constant ERC721_RECEIVED = 0xf0b9e5ba;
    
    constructor() public {

        blockNum = block.number;
        owner = msg.sender;
        startNextEra_("Genesis");

    }
    /******************************************************************************/
    /******************************************************************************/
    /******************************************************************************/
    /* ERC165Impl ***********************************************************/
    function supportsInterface(bytes4 _interfaceID) external view returns (bool) {
        return _interfaceID == 0x01ffc9a7  //ERC165
            || _interfaceID == 0x80ac58cd  //ERC721
            || _interfaceID == 0x5b5e139f  //ERC721Metadata
            || _interfaceID == 0x780e9d63; //ERC721Enumerable
    }
    /******************************************************************************/
    /******************************************************************************/
    /******************************************************************************/
    /* Token Data ***********************************************************/
    struct Moken {
        string name;
        uint256 data;
    }
    //tokenId to moken
    mapping (uint256 => Moken) private mokens;
    uint256 private mokensLength = 0;

    // Mapping from owner to list of owned token IDs
    mapping (address => uint32[]) private ownedTokens;

    uint256 constant UINT16_MASK =          0x000000000000000000000000000000000000000000000000000000000000ffff;
    uint256 constant MOKEN_LINK_HASH_MASK = 0xffffffffffffffff000000000000000000000000000000000000000000000000;
    uint256 constant MOKEN_DATA_MASK =      0x0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 constant MAX_MOKENS = 4294967296;
    uint256 constant MAX_OWNER_MOKENS = 65536;

    /******************************************************************************/
    /******************************************************************************/
    /******************************************************************************/
    /* Contract Management ***********************************************************/
    address public owner;
    
    // Mapping from token ID to approved address
    mapping (uint256 => address) private tokenApprovals;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private operatorApprovals;

    function getBalance() external view returns(uint256) {
        return address(this).balance;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Must be the owner.");
        _;
    }

    modifier onlyApproved(uint256 _tokenId) {
        address tokenOwner = address(mokens[_tokenId].data);
        require(tokenOwner != address(0), "The tokenId does not exist.");
        require(msg.sender == tokenOwner || tokenApprovals[_tokenId] == msg.sender || operatorApprovals[tokenOwner][msg.sender],
            "Must be the token owner or approved to take this action.");
        _;
    }

    function withdraw(address _sendTo, uint256 _amount) external onlyOwner {
        address mokensContract = this;
        if (_amount > mokensContract.balance) {
            _sendTo.transfer(mokensContract.balance);
        } else {
            _sendTo.transfer(_amount);
        }

    }
    
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }
    
    

    /******************************************************************************/
    /******************************************************************************/
    /******************************************************************************/
    /* ERC721Impl ***********************************************************/

    function balanceOf(address _tokenOwner) external view returns (uint256 totalMokensOwned) {
        require(_tokenOwner != address(0), "Owner cannot be the 0 address.");
        return ownedTokens[_tokenOwner].length;
    }
    
    function getTopTenTokenArray(address _tokenOwner) external view returns (uint256[10]) {
        require(_tokenOwner != address(0), "Owner cannot be the 0 address.");
        uint256[10] memory mokensOwned; 
        uint256 iterations = 10;
        if (ownedTokens[_tokenOwner].length < 10) iterations = 10 - ownedTokens[_tokenOwner].length;
        for (uint i=0; i<iterations; i++) {
            mokensOwned[i] = ownedTokens[_tokenOwner][i];
        }
        return mokensOwned;
    }

    function ownerOf(uint256 _tokenId) external view returns (address tokenOwner) {
        tokenOwner = address(mokens[_tokenId].data);
        require(tokenOwner != address(0), "The tokenId does not exist.");
        return tokenOwner;
    }

    function approve(address _to, uint256 _tokenId) external {
        address tokenOwner = address(mokens[_tokenId].data);
        require(tokenOwner != address(0), "The tokenId does not exist.");
        require(msg.sender == tokenOwner || operatorApprovals[tokenOwner][msg.sender], "Must be the token owner or approved operator.");

        if (tokenApprovals[_tokenId] != address(0) || _to != address(0)) {
            tokenApprovals[_tokenId] = _to;
            emit Approval(tokenOwner, _to, _tokenId);
        }
    }

    function getApproved(uint256 _tokenId) external view returns (address approvedAddress) {
        address tokenOwner = address(mokens[_tokenId].data);
        require(tokenOwner != address(0), "The tokenId does not exist.");
        return tokenApprovals[_tokenId];
    }


    function setApprovalForAll(address _to, bool _approved) external {
        require(_to != address(0), "Cannot set a 0 address.");
        operatorApprovals[msg.sender][_to] = _approved;
        emit ApprovalForAll(msg.sender, _to, _approved);
    }

    function isApprovedForAll(address _tokenOwner, address _operator) external view returns (bool approved) {
        return operatorApprovals[_tokenOwner][_operator];
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external onlyApproved(_tokenId) {
        clearApprovalAndTransfer(_from, _to, _tokenId, "", false);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external onlyApproved(_tokenId) {
        clearApprovalAndTransfer(_from, _to, _tokenId, "", true);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes _data) external onlyApproved(_tokenId) {
        clearApprovalAndTransfer(_from, _to, _tokenId, _data, true);
    }

    function isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function clearApprovalAndTransfer(address _from, address _to, uint256 _tokenId, bytes _data, bool _safe) private {
        require(_from != address(0), "_from cannot be the 0 address.");
        require(_to != address(0), "_to cannot be the 0 address.");
        uint256 data = mokens[_tokenId].data;
        address tokenOwner = address(data);
        require(tokenOwner == _from, "The tokenId is not owned by _from.");

        //Clear approval
        if (tokenApprovals[_tokenId] != address(0)) {
            tokenApprovals[_tokenId] = address(0);
            emit Approval(_from, address(0), _tokenId);
        }

        //removing the tokenId
        // 1. We replace _tokenId in ownedTokens[_from] with the last token id
        //    in ownedTokens[_from]
        uint256 lastTokenIndex = ownedTokens[_from].length - 1;
        uint256 lastTokenId = ownedTokens[_from][lastTokenIndex];
        if(lastTokenId != _tokenId) {
            uint256 tokenIndex = data >> 160 & UINT16_MASK;
            ownedTokens[_from][tokenIndex] = uint32(lastTokenId);
            // 2. We set lastTokeId to point to its new position in ownedTokens[_from]
            uint256 lastTokenIdData = mokens[lastTokenId].data;
            mokens[lastTokenId].data = lastTokenIdData & 0xffffffffffffffffffff0000ffffffffffffffffffffffffffffffffffffffff | tokenIndex << 160;
        }
        // 3. We remove lastTokenId from the end of ownedTokens[_from]
        ownedTokens[_from].length--;
        
        //adding the tokenId
        uint256 ownedTokensIndex = ownedTokens[_to].length;
        // prevents 16 bit overflow
        require(ownedTokensIndex < MAX_OWNER_MOKENS, "An single token owner address cannot possess more than 65,536 mokens.");
        mokens[_tokenId].data = data & 0xffffffffffffffffffff00000000000000000000000000000000000000000000 | ownedTokensIndex << 160 | uint256(_to);
        ownedTokens[_to].push(uint32(_tokenId));

        emit Transfer(_from, _to, _tokenId);

        if (_safe) {
            if(isContract(_to)) {
                bytes4 val = ERC721TokenReceiver(_to).onERC721Received(_from, _tokenId, _data);
                require(val == ERC721_RECEIVED, "The receiving contract must be able to receive this token.");
            }
        }
    }


    /******************************************************************************/
    /******************************************************************************/
    /******************************************************************************/
    /* ERC721EnumerableImpl **************************************************/

    function exists(uint256 _tokenId) external view returns (bool) {
        return _tokenId < mokensLength;
    }

    function tokenOfOwnerByIndex(address _tokenOwner, uint256 _index) external view returns (uint256 tokenId) {
        require(_index < ownedTokens[_tokenOwner].length, "Owner does not own a moken at this index.");
        return ownedTokens[_tokenOwner][_index];
    }

    function totalSupply() external view returns (uint256 totalMokens) {
        return mokensLength;
    }

    function tokenByIndex(uint256 _index) external view returns (uint256 tokenId) {
        require(_index < mokensLength, "TokenId at this index does not exist.");
        return _index;
    }
    /******************************************************************************/
    /******************************************************************************/
    /******************************************************************************/
    /* ERC721MetadataImpl **************************************************/
    string constant name_ = "Mokens";
    string constant symbol_ = "MKN";

    function name() external pure returns (string) {
        return name_;
    }

    function symbol() external pure returns (string) {
        return symbol_;
    }

    mapping (uint256 => string) private tokenURI_;

    string private defaultURIStart = "https://api.mokens.io/moken/";
    string private defaultURIEnd = ".json";

    function setDefaultURIStart(string _defaultURIStart) external onlyOwner {
        defaultURIStart = _defaultURIStart;
    }

    function setDefaultURIEnd(string _defaultURIEnd) external onlyOwner {
        defaultURIEnd = _defaultURIEnd;
    }

    function setTokenURI(uint256 _tokenId, string _uri) external onlyApproved(_tokenId) {
        tokenURI_[_tokenId] = _uri;
    }

    function deleteCustomTokenURI(uint256 _tokenId) external onlyApproved(_tokenId) {
        delete tokenURI_[_tokenId];
    }

    function hasCustomURI(uint256 _tokenId) external view returns (bool) {
        require(_tokenId < mokensLength, "The tokenId does not exist.");
        return bytes(tokenURI_[_tokenId]).length > 0;
    }

    function tokenURI(uint256 _tokenId) external view returns (string tokenURIString) {
        require(_tokenId < mokensLength, "The tokenId does not exist.");
        if(bytes(tokenURI_[_tokenId]).length == 0) {
            return makeIntString(defaultURIStart,_tokenId,defaultURIEnd);
        }
        else {
            return tokenURI_[_tokenId];
        }
    }

    // creates a string made from an integer between two strings
    function makeIntString(string startString, uint256 v, string endString) private pure returns (string) {
        uint256 maxlength = 10;
        bytes memory reversed = new bytes(maxlength);
        uint256 numDigits = 0;
        if(v == 0) {
            numDigits = 1;
            reversed[0] = byte(48);
        }
        else {
            while (v != 0) {
                uint256 remainder = v % 10;
                v = v / 10;
                reversed[numDigits++] = byte(48 + remainder);
            }
        }
        bytes memory startStringBytes = bytes(startString);
        bytes memory endStringBytes = bytes(endString);
        uint256 startStringLength = startStringBytes.length;
        uint256 endStringLength = endStringBytes.length;
        bytes memory newStringBytes = new bytes(startStringLength + numDigits + endStringLength);
        uint256 i;
        for (i = 0; i < startStringLength; i++) {
            newStringBytes[i] = startStringBytes[i];
        }
        for (i = 0; i < numDigits; i++) {
            newStringBytes[i + startStringLength] = reversed[numDigits - 1 - i];
        }
        for (i = 0; i < endStringLength; i++) {
            newStringBytes[i + startStringLength + numDigits] = endStringBytes[i];
        }
        return string(newStringBytes);
    }

    /******************************************************************************/
    /******************************************************************************/
    /******************************************************************************/
    /* Eras  **************************************************/

    event NewEra(
        uint256 index,
        bytes32 name,
        uint256 startTokenId
    );

    // index to era
    mapping (uint256 => bytes32) private eras;
    uint256 private eraLength = 0;

    // era to index+1
    mapping (bytes32 => uint256) private eraIndex;

    function startNextEra_(bytes32 _eraName) private returns (uint256 index, uint256 startTokenId) {
        require(_eraName != 0, "eraName is empty string.");
        require(eraIndex[_eraName] == 0, "Era name already exists.");
        startTokenId = mokensLength;
        index = eraLength++;
        eras[index] = _eraName;
        eraIndex[_eraName] = index+1;
        emit NewEra(index, _eraName, startTokenId);
        return (index, startTokenId);
    }

    // It is predicted that often a new era comes with a mint price change
    function startNextEra(bytes32 _eraName,  uint256 _mintStepPrice, uint256 _mintPriceOffset, uint256 _mintPriceBuffer) external onlyOwner
    returns (uint256 index, uint256 startTokenId, uint256 mintPrice) {
        require(_mintStepPrice < 10000 ether, "mintStepPrice must be less than 10,000 ether.");
        mintPriceOffset = _mintPriceOffset;
        mintStepPrice = _mintStepPrice;
        mintPriceBuffer = _mintPriceBuffer;
        uint256 totalStepPrice = mokensLength * _mintStepPrice;
        require(totalStepPrice >= _mintPriceOffset, "(mokensLength * mintStepPrice) must be greater than or equal to mintPriceOffset.");
        mintPrice = totalStepPrice - _mintPriceOffset;
        emit MintPriceConfigurationChange(mintPrice, _mintStepPrice, _mintPriceOffset, _mintPriceBuffer);
        emit MintPriceChange(mintPrice);
        (index, startTokenId) = startNextEra_(_eraName);
        return (index, startTokenId, mintPrice);
    }

    function startNextEra(bytes32 _eraName) external onlyOwner returns (uint256 index, uint256 startTokenId) {
        return startNextEra_(_eraName);
    }

    
    function eraByIndex(uint256 _index) external view returns(bytes32 era) {
        require(_index < eraLength, "No era at this index.");
        return eras[_index];
    }

    
    function eraByName(bytes32 _eraName) external view returns(uint256 indexOfEra) {
        uint256 index = eraIndex[_eraName];
        require(index != 0, "No era exists with this name.");
        return index-1;
    }

    function currentEra() external view returns(bytes32 era) {
        return eras[eraLength-1];
    }

    function currentEraIndex() external view returns(uint256 indexOfEra) {
        return eraLength-1;
    }

    function eraExists(bytes32 _eraName) external view returns(bool) {
        return eraIndex[_eraName] != 0;
    }

    function totalEras() external view returns (uint256 totalEras_) {
        return eraLength;
    }

    /******************************************************************************/
    /******************************************************************************/
    /******************************************************************************/
    /* Minting  **************************************************/
    event Mint(
        address indexed mintContract,
        address indexed owner,
        bytes32 indexed era,
        string mokenName,
        bytes32 data,
        uint256 tokenId,
        bytes32 currencyName,
        uint256 price
    );

    
    event MintPriceChange(
        uint256 mintPrice
    );

    event MintPriceConfigurationChange(
        uint256 mintPrice,
        uint256 mintStepPrice,
        uint256 mintPriceOffset,
        uint256 mintPriceBuffer
    );

    uint256 public mintPriceOffset = 0 szabo;
    uint256 public mintStepPrice = 500 szabo;
    uint256 public mintPriceBuffer = 5000 szabo;
    
    function mintData() external view returns(uint256 mokensLength_, uint256 mintStepPrice_, uint256 mintPriceOffset_) {
        return (mokensLength, mintStepPrice, mintPriceOffset);
    }

    function setMintPrice(uint256 _mintStepPrice, uint256 _mintPriceOffset, uint256 _mintPriceBuffer) external onlyOwner returns(uint256 mintPrice) {
        require(_mintStepPrice < 10000 ether, "mintStepPrice must be less than 10,000 ether.");
        mintPriceOffset = _mintPriceOffset;
        mintStepPrice = _mintStepPrice;
        mintPriceBuffer = _mintPriceBuffer;
        uint256 totalStepPrice = mokensLength * _mintStepPrice;
        require(totalStepPrice >= _mintPriceOffset, "(mokensLength * mintStepPrice) must be greater than or equal to mintPriceOffset.");
        mintPrice = totalStepPrice - _mintPriceOffset;
        emit MintPriceConfigurationChange(mintPrice, _mintStepPrice, _mintPriceOffset, _mintPriceBuffer);
        emit MintPriceChange(mintPrice);
        return mintPrice;
    }
    
    function mintPrice() external view returns(uint256) {
        return (mokensLength * mintStepPrice) - mintPriceOffset;
    }

    //moken name to tokenId+1
    mapping (string => uint256) private tokenByName_;

    function mint(address _tokenOwner, string _mokenName, bytes32 _linkHash) external payable returns (uint256 tokenId) {

        require(_tokenOwner != address(0), "Owner cannot be the 0 address.");

        tokenId = mokensLength++;
        // prevents 32 bit overflow
        require(tokenId < MAX_MOKENS, "Only 4,294,967,296 mokens can be created.");
        uint256 mintStepPrice_ = mintStepPrice;
        uint256 mintPriceBuffer_ = mintPriceBuffer;

        //Was enough ether passed in?
        uint256 currentMintPrice = (tokenId * mintStepPrice_) - mintPriceOffset;
        uint256 pricePaid = currentMintPrice;
        if(msg.value < currentMintPrice) {
            require(mintPriceBuffer_ > currentMintPrice || msg.value >= currentMintPrice - mintPriceBuffer_, "Paid ether is lower than mint price.");
            pricePaid = msg.value;
        }

        string memory lowerMokenName = validateAndLower(_mokenName);
        require(tokenByName_[lowerMokenName] == 0, "Moken name already exists.");

        uint256 eraIndex_ = eraLength-1;
        uint256 ownedTokensIndex = ownedTokens[_tokenOwner].length;
        // prevents 16 bit overflow
        require(ownedTokensIndex < MAX_OWNER_MOKENS, "An single owner address cannot possess more than 65,536 mokens.");

        // adding the current era index, ownedTokenIndex and owner address to data
        // this saves gas for each mint.
        uint256 data = uint256(_linkHash) & MOKEN_LINK_HASH_MASK | eraIndex_ << 176 | ownedTokensIndex << 160 | uint160(_tokenOwner);
        
        // create moken
        mokens[tokenId].name = _mokenName;
        mokens[tokenId].data = data;
        tokenByName_[lowerMokenName] = tokenId+1;

        //add moken to the specific owner
        ownedTokens[_tokenOwner].push(uint32(tokenId));

        //emit events
        emit Transfer(address(0), _tokenOwner, tokenId);
        emit Mint(this, _tokenOwner, eras[eraIndex_], _mokenName, bytes32(data), tokenId, "Ether", pricePaid);
        emit MintPriceChange(currentMintPrice + mintStepPrice_);

        //send minter the change if any
        if(msg.value > currentMintPrice) {
            msg.sender.transfer(msg.value - currentMintPrice);
        }
        
        return tokenId;
    }
    /*
    address[] private mintContracts;
    mapping (address => uint256) private mintContractIndex;
   
    // add contract to list of contracts that can mint mokens 
    function addMintContract(address _contract) external onlyManager {
        require(isContract(_contract), "Address is not a contract.");
        require(mintContractIndex[_contract] == 0, "Contract already added.");
        mintContracts.push(_contract);
        mintContractIndex[_contract] = mintContracts.length;
    }
   
    function removeMintContract(address _contract) external onlyManager {
        uint256 index = mintContractIndex[_contract];
        require(index != 0, "Mint contract was not added.");
        uint256 lastIndex = mintContracts.length-1;
        address lastMintContract = mintContracts[lastIndex];
        mintContracts[index-1] = lastMintContract;
        mintContractIndex[lastMintContract] = index;
        delete mintContractIndex[_contract];
        mintContracts.length--;
    }
    
    function isMintContract(address _contract) public view returns (bool) {
        return mintContractIndex[_contract] != 0;
    }
    
    function totalMintContracts() external view returns (uint256 totalMintContracts_) {
        return mintContracts.length;
    }
    
    function mintContractByIndex(uint256 index) external view returns (address contract_) {
        require(index < mintContracts.length, "Contract index does not exist.");
        return mintContracts[index];
    }

    // enables third-party contracts to mint mokens.
    // enables the ability to accept other currency/tokens for payment.
    function contractMint(address _tokenOwner, string _mokenName, bytes32 _linkHash, bytes32 _currencyName, uint256 _pricePaid) external returns (uint256 tokenId) {

        require(_tokenOwner != address(0), "Token owner cannot be the 0 address.");
        require(isMintContract(msg.sender),"Not an approved mint contract.");

        tokenId = mokensLength++;
        uint256 mokensLength_ = tokenId+1;
        // prevents 32 bit overflow
        require(tokenId < MAX_MOKENS, "Only 4,294,967,296 mokens can be created.");
        
        string memory lowerMokenName = validateAndLower(_mokenName);
        require(tokenByName_[lowerMokenName] == 0, "Moken name already exists.");

        uint256 eraIndex_ = eraLength-1;
        uint256 ownedTokensIndex = ownedTokens[_tokenOwner].length;
        // prevents 16 bit overflow
        require(ownedTokensIndex < MAX_OWNER_MOKENS, "An single token owner address cannot possess more than 65,536 mokens.");

        // adding the current era index, ownedTokenIndex and owner address to data
        // this saves gas for each mint.
        uint256 data = uint256(_linkHash) & MOKEN_LINK_HASH_MASK | eraIndex_ << 176 | ownedTokensIndex << 160 | uint160(_tokenOwner);

        // create moken
        mokens[tokenId].name = _mokenName;
        mokens[tokenId].data = data;
        tokenByName_[lowerMokenName] = mokensLength_;

        //add moken to the specific owner
        ownedTokens[_tokenOwner].push(uint32(tokenId));

        emit Transfer(address(0), _tokenOwner, tokenId);
        emit Mint(msg.sender, _tokenOwner, eras[eraIndex_], _mokenName, bytes32(data), tokenId, _currencyName, _pricePaid);
        emit MintPriceChange((mokensLength_ * mintStepPrice) - mintPriceOffset);
        
        return tokenId;
    }
*/

    function validateAndLower(string _s) private pure returns(string mokenName) {
        bytes memory _sBytes = bytes(_s);
        uint256 length = _sBytes.length;
        require(length != 0, "Moken name cannot be an empty string.");
        require(length < 101, "Moken name cannot be greater than 100 characters.");
        //make sure the string does not start or end with whitepace.
        require(uint256(_sBytes[0]) > 0x20 && uint256(_sBytes[length-1]) > 0x20, "Moken names should not contain leading or trailing spaces or nonprintable characters.");
        //lowercase the string
        for (uint256 i = 0; i < length; i++) {
            uint256 b = uint256(_sBytes[i]);
            if(b < 0x5b && b > 0x40) {
                _sBytes[i] = byte(b+32);
            }
        }
        return string(_sBytes);
    }

    /******************************************************************************/
    /******************************************************************************/
    /******************************************************************************/
    /* Mokens  **************************************************/

    function mokenNameExists(string _mokenName) external view returns(bool) {
        return tokenByName_[validateAndLower(_mokenName)] != 0;
    }

    function mokenId(string _mokenName) external view returns (uint256 tokenId) {
        tokenId = tokenByName_[validateAndLower(_mokenName)];
        require(tokenId != 0, "No moken exists with this name.");
        return tokenId-1;
    }

    function mokenData(uint256 _tokenId) external view returns (bytes32 data) {
        data = bytes32(mokens[_tokenId].data);
        require(data != 0, "The tokenId does not exist.");
        return data;
    }

    function eraFromMokenData(bytes32 _data) public view returns(bytes32 era) {
        return eras[uint256(_data) >> 176 & UINT16_MASK];
    }

    function eraFromMokenData(uint256 _data) public view returns(bytes32 era) {
        return eras[_data >> 176 & UINT16_MASK];
    }

    function mokenEra(uint256 _tokenId) external view returns(bytes32 era) {
        uint256 data = mokens[_tokenId].data;
        require(data != 0, "The tokenId does not exist.");
        return eraFromMokenData(data);
    }

    function moken(uint256 _tokenId) external view 
    returns (string memory mokenName, bytes32 era, bytes32 data, address tokenOwner) {
        data = bytes32(mokens[_tokenId].data);
        require(data != 0, "The tokenId does not exist.");
        return (
            mokens[_tokenId].name, 
            eraFromMokenData(data),
            data, 
            address(data)
        );
    }
    
    function mokenBytes32(uint256 _tokenId) external view 
    returns (bytes32 mokenNameBytes32, bytes32 era, bytes32 data, address tokenOwner) {
        data = bytes32(mokens[_tokenId].data);
        require(data != 0, "The tokenId does not exist.");
        bytes memory mokenNameBytes = bytes(mokens[_tokenId].name);
        require(mokenNameBytes.length != 0, "The tokenId does not exist.");
        assembly {
            mokenNameBytes32 := mload(add(mokenNameBytes, 32))
        }
        return (
            mokenNameBytes32, 
            eraFromMokenData(data),
            data, 
            address(data)
        );
    }
    
    
    function mokenNoName(uint256 _tokenId) external view 
    returns (bytes32 era, bytes32 data, address tokenOwner) {
        data = bytes32(mokens[_tokenId].data);
        require(data != 0, "The tokenId does not exist.");
        return (
            eraFromMokenData(data),
            data, 
            address(data)
        );
    }

    function mokenName(uint256 _tokenId) external view returns (string memory mokenName_) {
        mokenName_ = mokens[_tokenId].name;
        require(bytes(mokenName_).length != 0, "The tokenId does not exist.");
        return mokenName_;
    }
    
    function mokenNameBytes32(uint256 _tokenId) external view returns (bytes32 mokenNameBytes32_) {
        bytes memory mokenNameBytes = bytes(mokens[_tokenId].name);
        require(mokenNameBytes.length != 0, "The tokenId does not exist.");
        assembly {
            mokenNameBytes32_ := mload(add(mokenNameBytes, 32))
        }
        return mokenNameBytes32_;
    }
    
    /******************************************************************************/
    /******************************************************************************/
    /******************************************************************************/
    /* ERC998 Implementation  **************************************************/
    
    // tokenId => child contract
    mapping(uint256 => address[]) private childContracts;
    
    // tokenId => (child address => contract index+1)
    mapping(uint256 => mapping(address => uint256)) private childContractIndex;
  
    // tokenId => (child address => array of child tokens)
    mapping(uint256 => mapping(address => uint256[])) private childTokens;
  
    // tokenId => (child address => (child token => child index+1)
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) private childTokenIndex;
    
    // child address => childId => tokenId
    mapping(address => mapping(uint256 => uint256)) private childTokenOwner;
    
    function test(uint256 _tokenId, address _childContract, uint256 _childTokenId) view external returns (uint256) {
        return childTokenIndex[_tokenId][_childContract][_childTokenId];
    }
    
    function removeChild(uint256 _tokenId, address _childContract, uint256 _childTokenId) private {
        uint256 tokenIndex = childTokenIndex[_tokenId][_childContract][_childTokenId];
        require(tokenIndex != 0, "Child token not owned by token.");
        
        // remove child token
        uint256 lastTokenIndex = childTokens[_tokenId][_childContract].length-1;
        uint256 lastToken = childTokens[_tokenId][_childContract][lastTokenIndex];
        childTokens[_tokenId][_childContract][tokenIndex-1] = lastToken;
        childTokenIndex[_tokenId][_childContract][lastToken] = tokenIndex;
        childTokens[_tokenId][_childContract].length--;
        delete childTokenIndex[_tokenId][_childContract][_childTokenId];
        delete childTokenOwner[_childContract][_childTokenId];
        
        // remove contract
        if(lastTokenIndex == 0) {
            uint256 contractIndex = childContractIndex[_tokenId][_childContract];
            uint256 lastContractIndex = childContracts[_tokenId].length - 1;
            address lastContract = childContracts[_tokenId][lastContractIndex];
            childContracts[_tokenId][contractIndex] = lastContract;
            childContractIndex[_tokenId][lastContract] = contractIndex;
            childContracts[_tokenId].length--;
            delete childContractIndex[_tokenId][_childContract];
        }

    }
    
    function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId, bytes _data) onlyApproved(_tokenId) external {
        removeChild(_tokenId, _childContract, _childTokenId);
        ERC721(_childContract).safeTransferFrom(this, _to, _childTokenId, _data);
        /*
        //require that the child was transfered safely to it's destination
        require(
          _childContract.call(
            bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)")), this, _to, _childTokenId, _data
          ), "safeTransferFrom call failed."
        );
        */
        emit TransferChild(_to, _data, _childTokenId);
    }
    
    function onERC721Received(address _from, uint256 _childTokenId, bytes _data) external returns(bytes4) {
        require(_data.length > 0, "_data must contain the uint256 tokenId to transfer the child token to.");
        // convert up to 32 bytes of_data to uint256, owner nft tokenId passed as uint in bytes
        uint256 _tokenId;
        assembly { 
            _tokenId := calldataload(132)
        }
        if(_data.length < 32) {
            _tokenId = _tokenId >> 256 - _data.length * 8;
        }
        
        receiveChild(_from, _tokenId, msg.sender, _childTokenId);
        
        return ERC721_RECEIVED;
    }
    
    function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId) external onlyApproved(_tokenId) {
        removeChild(_tokenId, _childContract, _childTokenId);
        //require that the child was transfered safely to it's destination
        require(
          _childContract.call(
            bytes4(keccak256("safeTransferFrom(address,address,uint256)")), this, _to, _childTokenId
          )
        );
        emit TransferChild(_to, new bytes(0), _childTokenId);
    }
  
    
    function receiveChild(address _from, uint256 _tokenId, address _childContract, uint256 _childTokenId) private {
        uint256 childTokensLength = childTokens[_tokenId][_childContract].length;
        if(childTokensLength == 0) {
            childContractIndex[_tokenId][_childContract] = childContracts[_tokenId].length;
            childContracts[_tokenId].push(_childContract);
        }
        childTokens[_tokenId][_childContract].push(_childTokenId);
        childTokenIndex[_tokenId][_childContract][_childTokenId] = childTokensLength+1;
        childTokenOwner[_childContract][_childTokenId] = _tokenId;
        
        emit ReceivedChild(_from, _tokenId, _childContract, _childTokenId);
    }

    /*
    
   
    

    
    function safeTransferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId, bytes _data) onlyApproved(_tokenId) external {
        removeChild(_tokenId, _childContract, _childTokenId);
        //require that the child was transfered safely to it's destination
        require(
          _childContract.call(
            bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)")), this, _to, _childTokenId, _data
          )
        );
        emit TransferChild(_to, _data, _childTokenId);
    }
    
    function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId) external onlyApproved(_tokenId) {
        removeChild(_tokenId, _childContract, _childTokenId);
        //require that the child was transfered safely to it's destination
        require(
          _childContract.call(
            bytes4(keccak256("transferFrom(address,address,uint256)")), this, _to, _childTokenId
          )
        );
        emit TransferChild(_to, new bytes(0), _childTokenId);
    }
    
    function transferChildToComposable(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId, uint256 composableId) external onlyApproved(_tokenId) {
        removeChild(_tokenId, _childContract, _childTokenId);
        //require that the child was transfered safely to it's destination
        require(
          _childContract.call(
            bytes4(keccak256("transferFrom(address,address,uint256)")), this, _to, _childTokenId
          )
        );
        emit TransferChild(_to, new bytes(0), _childTokenId);
    }
    */
    
    /*
    // This contract must be approved in _childContract so the child can be obtained
    // Either the approve or setApprovalForAll functions can be used to approve this contract to get the child.
    function getChild(address _from, uint256 _tokenId, address _childContract, uint256 _childTokenId) external {
        uint256 childTokensLength = childTokens[_tokenId][_childContract].length;
        if(childTokensLength == 0) {
            childContractIndex[_tokenId][_childContract] = childContracts[_tokenId].length;
            childContracts[_tokenId].push(_childContract);
        }
        childTokens[_tokenId][_childContract].push(_childTokenId);
        childTokenIndex[_tokenId][_childContract][_childTokenId] = childTokensLength+1;
        childTokenOwner[_childContract][_childTokenId] = _tokenId;
        
        require(
          _childContract.call(
            bytes4(keccak256("transferFrom(address,address,uint256)")), _from, this, _childTokenId
          )
        );
        emit ReceivedChild(_tokenId, _childContract, _childTokenId, _from);
    }
    
    
    function transferChild(address _to, uint256 _tokenId, address _childContract, uint256 _childTokenId) onlyApproved(_tokenId) external {
        removeChild(_tokenId, _childContract, _childTokenId);
        //require that the child was transfered safely to it's destination
        require(
          _childContract.call(
            bytes4(keccak256("transferFrom(address,address,uint256,bytes)")), this, _to, _childTokenId
          )
        );
        bytes data;
        
        
        emit TransferChild(_to, data, _childTokenId);
    }
    */
    
    function childOwnerOf(address _childContract, uint256 _childTokenId) external view returns (uint256 tokenId) {
        tokenId = childTokenOwner[_childContract][_childTokenId];
        if(tokenId == 0) {
            require(childTokenIndex[tokenId][_childContract][_childTokenId] != 0, "Child token is not owned by any tokens.");
        }
        return tokenId;
    }
    
    function childExists(address _childContract, uint256 _childTokenId) external view returns (bool) {
        uint256 tokenId = childTokenOwner[_childContract][_childTokenId];
        return childTokenIndex[tokenId][_childContract][_childTokenId] != 0;
    }
    
    function totalChildContracts(uint256 _tokenId) external view returns(uint256) {
        return childContracts[_tokenId].length;
    }
    
    function childContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address childContract) {
        require(_index < childContracts[_tokenId].length, "Contract address does not exist for this token and index.");
        return childContracts[_tokenId][_index];
    }
    
    function totalChildTokens(uint256 _tokenId, address _childContract) external view returns(uint256) {
        return childTokens[_tokenId][_childContract].length;
    }
    
    function childTokenByIndex(uint256 _tokenId, address _childContract, uint256 _index) external view returns (uint256 childTokenId) {
        require(_index < childTokens[_tokenId][_childContract].length, "Token does not own a child token at contract address and index.");
        return childTokens[_tokenId][_childContract][_index];
    }
    
}
