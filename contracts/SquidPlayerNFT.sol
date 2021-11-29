//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract SquidPlayerNFT is
    Initializable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant TOKEN_MINTER_ROLE = keccak256("TOKEN_MINTER");
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");
    bytes32 public constant SE_BOOST_ROLE = keccak256("SE_BOOST_ROLE");

    string private _internalBaseURI;
    uint private _lastTokenId;
    uint[5] private _rarityLimitsSE;

    struct Token {
        uint rarity; //Token rarity (Star)
        uint squidEnergy; // in 1e18
        uint createTimestamp;
        uint busyTo; //block number to which the token is busy
        uint contractEndTimestamp; //block number to which the token has game contract
    }

    struct TokensViewFront {
        uint tokenId;
        uint rarity;
        address tokenOwner;
        uint squidEnergy;
        uint contractEndTimestamp;
        uint busyTo; //Timestamp until which the player is busy
        uint createTimestamp;
        string uri;
    }

    mapping(uint256 => Token) private _tokens; // TokenId => Token

    event Initialize(string baseURI);
    event TokenMint(address indexed to, uint indexed tokenId, uint squidEnergy);

    //Initialize function --------------------------------------------------------------------------------------------

    function initialize(string memory baseURI) public initializer {
        __ERC721_init("SquidPlayerNFT", "SPLR");
        __ERC721Enumerable_init();
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _rarityLimitsSE[0] = 500 ether;
        _rarityLimitsSE[1] = 1200 ether;
        _rarityLimitsSE[2] = 1700 ether;
        _rarityLimitsSE[3] = 2300 ether;
        _rarityLimitsSE[4] = 3300 ether;

        _internalBaseURI = baseURI;
        emit Initialize(baseURI);
    }

    //External functions --------------------------------------------------------------------------------------------

    function setBaseURI(string calldata newBaseUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _internalBaseURI = newBaseUri;
    }

    function setRarityLimitsTable(uint[5] calldata newRarityLimits) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _rarityLimitsSE = newRarityLimits;
    }

    //Public functions ----------------------------------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function mint(
        address to,
        uint squidEnergy,
        uint contractEndTimestamp,
        uint rarity
    ) public onlyRole(TOKEN_MINTER_ROLE) nonReentrant {
        require(to != address(0), "Address can not be zero");
        require(rarity < _rarityLimitsSE.length, "Wrong rarity");
        require(squidEnergy <= _rarityLimitsSE[rarity], "Squid energy over rarity limit");
        _lastTokenId += 1;
        uint tokenId = _lastTokenId;
        _tokens[tokenId].squidEnergy = squidEnergy;
        _tokens[tokenId].createTimestamp = block.timestamp;
        _tokens[tokenId].contractEndTimestamp = contractEndTimestamp;
        _safeMint(to, tokenId);
    }

    function burn(uint _tokenId) public nonReentrant {
        require(_exists(_tokenId), "ERC721: token does not exist");
        require(ownerOf(_tokenId) == msg.sender, "Not token owner");
        _burn(_tokenId);
    }

    function getToken(uint _tokenId) public view returns (TokensViewFront memory) {
        require(_exists(_tokenId), "ERC721: token does not exist");
        Token memory token = _tokens[_tokenId];
        TokensViewFront memory tokenReturn;
        tokenReturn.tokenId = _tokenId;
        tokenReturn.rarity = token.rarity;
        tokenReturn.tokenOwner = ownerOf(_tokenId);
        tokenReturn.squidEnergy = token.squidEnergy;
        tokenReturn.contractEndTimestamp = token.contractEndTimestamp;
        tokenReturn.busyTo = token.busyTo;
        tokenReturn.createTimestamp = token.createTimestamp;
        tokenReturn.uri = tokenURI(_tokenId);
        return (tokenReturn);
    }

    //returns locked SE amount
    function lockTokens(uint[] calldata tokenId, uint busyTo, uint seDivide) public onlyRole(GAME_ROLE) returns(uint){
        uint seAmount;
        for (uint i = 0; i < tokenId.length; i++) {
            seAmount += _lockToken(tokenId[i], busyTo);
            if(seDivide > 0){
                _tokens[tokenId[i]].squidEnergy -= _tokens[tokenId[i]].squidEnergy * seDivide / 10000;
            }
        }
        return seAmount;
    }

    function setPlayerContract(uint[] calldata tokenId, uint[] calldata contractEndTimestamp) public onlyRole(GAME_ROLE) {
        require(tokenId.length == contractEndTimestamp.length, "Wrong calldata array size");
        for (uint i = 0; i < tokenId.length; i++) {
            _setPlayerContract(tokenId[i], contractEndTimestamp[i]);
        }
    }

    function squidEnergyDecrease(uint[] calldata tokenId, uint[] calldata deduction) public onlyRole(SE_BOOST_ROLE) {
        require(tokenId.length == deduction.length, "Wrong calldata array size");
        for (uint i = 0; i < tokenId.length; i++) {
            require(_exists(tokenId[i]), "ERC721: token does not exist");
            require(_tokens[tokenId[i]].squidEnergy >= deduction[i], "Wrong deduction value"); //TODO change deduction to divider
            _tokens[tokenId[i]].squidEnergy -= deduction[i];
        }
    }

    function squidEnergyIncrease(uint[] calldata tokenId, uint[] calldata addition) public onlyRole(SE_BOOST_ROLE) {
        require(tokenId.length == addition.length, "Wrong calldata array size");
        for (uint i = 0; i < tokenId.length; i++) {
            require(_exists(tokenId[i]), "ERC721: token does not exist");
            Token storage curToken = _tokens[tokenId[i]];
            require((curToken.squidEnergy + addition[i]) <= _rarityLimitsSE[curToken.rarity], "Wrong addition value");
            curToken.squidEnergy += addition[i];
        }
    }

    function arrayUserPlayers(address _user) public view returns(TokensViewFront[] memory){
        return arrayUserPlayers(_user, 0, balanceOf(_user)-1);
    }

    function arrayUserPlayers(
        address _user,
        uint _from,
        uint _to
    ) public view returns(TokensViewFront[] memory){
        require(_to < balanceOf(_user), "Wrong max array value");
        require((_to - _from) <= balanceOf(_user), "Wrong array range");
        TokensViewFront[] memory tokens = new TokensViewFront[](_to - _from);
        uint index = 0;
        for (uint i = _from; i <= _to; i++) {
            uint id = tokenOfOwnerByIndex(_user, i);
            tokens[index] = getToken(id);
            index++;
        }
        return(tokens);
    }

    function arrayUserPlayersWithValidContracts(address _user) public view returns(TokensViewFront[] memory){
        return arrayUserPlayersWithValidContracts(_user, 0, balanceOf(_user)-1);
    }

    function arrayUserPlayersWithValidContracts(
        address _user,
        uint _from,
        uint _to
    ) public view returns(TokensViewFront[] memory){
        require(_to < balanceOf(_user), "Wrong max array value");
        require((_to - _from) >= balanceOf(_user), "Wrong array range");
        TokensViewFront[] memory tokens = new TokensViewFront[](_to - _from);
        uint index = 0;
        for (uint i = _from; i <= _to; i++) {
            uint id = tokenOfOwnerByIndex(_user, i);
            TokensViewFront memory _currentToken = getToken(id);
            if(_currentToken.contractEndTimestamp > block.timestamp){
                tokens[index] = _currentToken;
                index++;
            }
        }
        return(tokens);
    }

    function availableSEAmount(address _user) public view returns(uint amount) {
        for(uint i = 0; i < balanceOf(_user); i++){
            Token memory curToken = _tokens[tokenOfOwnerByIndex(_user, i)];
            if(curToken.contractEndTimestamp > block.timestamp && curToken.busyTo < block.timestamp){
                amount += curToken.squidEnergy;
            }
        }
        return amount;
    }

    function totalSEAmount(address _user) public view returns(uint amount) {
        for(uint i = 0; i < balanceOf(_user); i++){
            Token memory curToken = _tokens[tokenOfOwnerByIndex(_user, i)];
                amount += curToken.squidEnergy;
        }
        return amount;
    }


    //Internal functions --------------------------------------------------------------------------------------------

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }

    function _burn(uint256 tokenId) internal override {
        super._burn(tokenId);
        delete _tokens[tokenId];
    }

    function _safeMint(address to, uint256 tokenId) internal override {
        super._safeMint(to, tokenId);
        emit TokenMint(to, tokenId, _tokens[tokenId].squidEnergy);
    }

    //Private functions --------------------------------------------------------------------------------------------

    function _lockToken(uint _tokenId, uint _busyTo) private returns(uint){
        require(_exists(_tokenId), "ERC721: token does not exist");
        require(_busyTo > block.timestamp, "Busy to block must be greater than current block number");
        Token storage _token = _tokens[_tokenId];
        require(_token.busyTo < block.timestamp, "Token already busy");
        require(_token.contractEndTimestamp > block.timestamp, "Token hasnt valid contract");
        _token.busyTo = _busyTo;
        return(_token.squidEnergy);
    }

    function _setPlayerContract(uint _tokenId, uint _contractEndTimestamp) private {
        require(_contractEndTimestamp > block.timestamp, "New contract must be greater than current block");
        require(_exists(_tokenId), "ERC721: token does not exist");
        require(_tokens[_tokenId].contractEndTimestamp <= block.timestamp, "Previous contract does not finished");
        _tokens[_tokenId].contractEndTimestamp = _contractEndTimestamp;
    }
}
