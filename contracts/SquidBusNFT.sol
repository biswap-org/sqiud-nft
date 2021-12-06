// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract SquidBusNFT is
    Initializable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant TOKEN_MINTER_ROLE = keccak256("TOKEN_MINTER");

    uint public minBusBalance; // min bus balance by user on start
    uint public maxBusBalance; // max bus balance after bus addition period
    uint public busAdditionPeriod; // bus addition period in seconds (add 1 bus available to mint after each period)

    string private internalBaseURI;
    uint private lastTokenId;
    uint private maxBusLevel; // maximum bus capacity

    struct Token {
        uint level; //how many players can fit on the bus
        uint createTimestamp;
    }

    mapping(uint256 => Token) private tokens; // TokenId => Token
    mapping(address => uint) public firstBusTimestamp; //timestamp when user mint first bus

    event Initialize(string baseURI);
    event TokenMint(address indexed to, uint indexed tokenId, uint level);

    //Initialize function --------------------------------------------------------------------------------------------

    function initialize(
        string memory baseURI,
        uint _maxBusLevel,
        uint _minBusBalance,
        uint _maxBusBalance,
        uint _busAdditionPeriod
    ) public initializer {
        __ERC721_init("SquidBusNFT", "SBUS");
        __ERC721Enumerable_init();
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        internalBaseURI = baseURI;
        maxBusLevel = _maxBusLevel; // 5
        minBusBalance = _minBusBalance; // 2
        maxBusBalance = _maxBusBalance; // 5
        busAdditionPeriod = _busAdditionPeriod; // 604800 for 7 days

        emit Initialize(baseURI);
    }

    //External functions --------------------------------------------------------------------------------------------

    function setBusParameters(
        uint _maxBusLevel,
        uint _minBusBalance,
        uint _maxBusBalance,
        uint _busAdditionPeriod
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_maxBusLevel > 0, "maxBusLevel must be > 0");
        require(_maxBusBalance > _minBusBalance, "maxBusBalance must be > minBusBalance");
        require(_busAdditionPeriod > 0, "busAdditionPeriod must be > 0");
        maxBusLevel = _maxBusLevel;
        minBusBalance = _minBusBalance;
        maxBusBalance = _maxBusBalance;
        busAdditionPeriod = _busAdditionPeriod;
    }

    function setBaseURI(string calldata newBaseUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        internalBaseURI = newBaseUri;
    }

    //Public functions --------------------------------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function mint(address _to, uint _busLevel) public onlyRole(TOKEN_MINTER_ROLE) nonReentrant {
        require(_to != address(0), "Address can not be zero");
        require(_busLevel <= maxBusLevel, "Volume out of range");
        if (firstBusTimestamp[_to] == 0) {
            firstBusTimestamp[_to] = block.timestamp;
        }
        lastTokenId += 1;
        uint tokenId = lastTokenId;
        tokens[tokenId].level = _busLevel;
        tokens[tokenId].createTimestamp = block.timestamp;
        _safeMint(_to, tokenId);
    }

    function burn(uint _tokenId) public {
        require(_exists(_tokenId), "ERC721: token does not exist");
        require(ownerOf(_tokenId) == msg.sender, "Not token owner");
        _burn(_tokenId);
    }

    function getToken(uint _tokenId)
        public
        view
        returns (
            uint tokenId,
            address tokenOwner,
            uint level,
            uint createTimestamp,
            string memory uri
        )
    {
        require(_exists(_tokenId), "ERC721: token does not exist");
        Token memory _token = tokens[_tokenId];
        tokenId = _tokenId;
        tokenOwner = ownerOf(_tokenId);
        level = _token.level;
        createTimestamp = _token.createTimestamp;
        uri = tokenURI(_tokenId);
    }

    function allowedBusBalance(address _user) public view returns (uint) {
        if (firstBusTimestamp[_user] == 0) return minBusBalance;

        uint passedTime = (block.timestamp - firstBusTimestamp[_user]);
        uint additionalQuantity = passedTime / busAdditionPeriod;
        return (
            (minBusBalance + additionalQuantity) > maxBusBalance ? maxBusBalance : (minBusBalance + additionalQuantity)
        );
    }

    function secToNextBus(address _user) public view returns(uint) {
        if (firstBusTimestamp[_user] == 0 || allowedBusBalance(_user) >= maxBusBalance) return 0;
        uint passedTime = (block.timestamp - firstBusTimestamp[_user]);
        uint timeLeft = (passedTime / busAdditionPeriod + 1) * busAdditionPeriod - passedTime;

        return timeLeft;
    }

    function allowedUserToMintBus(address _user) public view returns(bool) {
        if(balanceOf(_user) < allowedBusBalance(_user)) return true;

        return false;
    }

    function allowedUserToPlayGame(address _user) public view returns(bool) {
        if(balanceOf(_user) <= allowedBusBalance(_user)) return true;

        return false;
    }

    function seatsInBuses(address _user) public view returns(uint) {
        if(allowedUserToPlayGame(_user)){
            uint countBuses = balanceOf(_user);
            uint seats;
            for(uint i = 0; i < countBuses; i++){
                seats += tokens[tokenOfOwnerByIndex(_user, i)].level;
            }
            return(seats);
        } else {
            return 0;
        }
    }

    //Internal functions --------------------------------------------------------------------------------------------

    function _baseURI() internal view override returns (string memory) {
        return internalBaseURI;
    }

    function _burn(uint256 _tokenId) internal override {
        super._burn(_tokenId);
        delete tokens[_tokenId];
    }

    function _safeMint(address _to, uint256 _tokenId) internal override {
        super._safeMint(_to, _tokenId);
        emit TokenMint(_to, _tokenId, tokens[_tokenId].level);
    }

    //Private functions --------------------------------------------------------------------------------------------
}
