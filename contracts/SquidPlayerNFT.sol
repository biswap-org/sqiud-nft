// SPDX-License-Identifier: MIT
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
    bytes32 public constant TOKEN_FREEZER = keccak256("TOKEN_FREEZER");

    string private _internalBaseURI;
    uint private _lastTokenId;
    uint128[5] private _rarityLimitsSE; //SE limit to each rarity

    struct Token {
        uint8 rarity; //Token rarity (Star)
        uint32 createTimestamp;
        uint32 busyTo; //Timestamp to which the token is busy
        uint32 contractEndTimestamp; //Timestamp to which the token has game contract
        uint128 squidEnergy; // in 1e18 340282366920938463463e18 max
        bool stakeFreeze; //Freeze token when staking
    }

    struct TokensViewFront {
        uint tokenId;
        uint8 rarity;
        address tokenOwner;
        uint128 squidEnergy;
        uint128 maxSquidEnergy;
        uint32 contractEndTimestamp;
        uint32 busyTo; //Timestamp until which the player is busy
        uint32 createTimestamp;
        bool stakeFreeze;
        string uri;
    }

    mapping(uint => Token) private _tokens; // TokenId => Token

    //for decrease SE when token lock
    uint128 public seDivide; //base 10000
    uint public gracePeriod; //45d = 3 888 000; Period in seconds when SE didnt decrease after game
    bool public enableSeDivide; //enabled decrease SE

    event Initialize(string baseURI);
    event TokenMint(address indexed to, uint indexed tokenId, uint8 rarity, uint128 squidEnergy);
    event TokensLock(uint[] _tokenId, uint32 busyTo, uint128[] decreaseSE);
    event SEIncrease(uint[] _tokenId, uint128[] addition);
    event NewContract(uint[] _tokenId, uint32 contractEndTimestamp);
    event ChangeSEDivideState(bool state, uint seDivide, uint gracePeriod);

    //Initialize function --------------------------------------------------------------------------------------------

    function initialize(string memory baseURI, uint128 _seDivide, uint _gracePeriod, bool _enableSeDivide) public initializer {
        __ERC721_init("Biswap Squid Players", "BSP"); //BSP - Biswap Squid Players
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
        seDivide = _seDivide;
        gracePeriod = _gracePeriod;
        enableSeDivide = _enableSeDivide;
        emit Initialize(baseURI);
    }

    //External functions --------------------------------------------------------------------------------------------

    function setBaseURI(string calldata newBaseUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _internalBaseURI = newBaseUri;
    }

    function setRarityLimitsTable(uint128[5] calldata newRarityLimits) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _rarityLimitsSE = newRarityLimits;
    }

    function setSeDivide(
        bool _enableSeDivide,
        uint128 _seDivide,
        uint _gracePeriod
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        //MSG-01
        require(seDivide <= 10000, "Wrong seDivide parameter. Must be less or equal than 10000");
        enableSeDivide = _enableSeDivide;
        seDivide = _seDivide;
        gracePeriod = _gracePeriod;

        emit ChangeSEDivideState(_enableSeDivide, _seDivide, _gracePeriod);
    }

    function tokenFreeze(uint _tokenId) external onlyRole(TOKEN_FREEZER) {
        require(!_tokens[_tokenId].stakeFreeze, "ERC721: Token already frozen");
        // Clear all approvals when freeze token
        _approve(address(0), _tokenId);

        _tokens[_tokenId].stakeFreeze = true;
    }

    function tokenUnfreeze(uint _tokenId) external onlyRole(TOKEN_FREEZER) {
        require(_tokens[_tokenId].stakeFreeze, "ERC721: Token already unfrozen");
        _tokens[_tokenId].stakeFreeze = false;
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
        uint128 squidEnergy,
        uint32 contractEndTimestamp,
        uint8 rarity
    ) public onlyRole(TOKEN_MINTER_ROLE) nonReentrant {
        require(to != address(0), "Address can not be zero");
        require(rarity < _rarityLimitsSE.length, "Wrong rarity");
        require(squidEnergy <= _rarityLimitsSE[rarity], "Squid energy over rarity limit");
        _lastTokenId += 1;
        uint tokenId = _lastTokenId;
        _tokens[tokenId].rarity = rarity;
        _tokens[tokenId].squidEnergy = squidEnergy;
        _tokens[tokenId].createTimestamp = uint32(block.timestamp);
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
        tokenReturn.maxSquidEnergy = _rarityLimitsSE[token.rarity];
        tokenReturn.contractEndTimestamp = token.contractEndTimestamp;
        tokenReturn.busyTo = token.busyTo;
        tokenReturn.stakeFreeze = token.stakeFreeze;
        tokenReturn.createTimestamp = token.createTimestamp;
        tokenReturn.uri = tokenURI(_tokenId);
        return (tokenReturn);
    }

    //returns locked SE amount
    function lockTokens(
        uint[] calldata tokenId,
        uint32 busyTo,
        bool willDecrease, //will decrease SE or not
        address user
    ) public onlyRole(GAME_ROLE) returns (uint128) {
        uint128 seAmount;
        uint128[] memory decreaseSE = new uint128[](tokenId.length);
        for (uint i = 0; i < tokenId.length; i++) {
            require(ownerOf(tokenId[i]) == user, "Not owner of token");
            uint128 curSEAmount;
            (curSEAmount, decreaseSE[i]) = _lockToken(tokenId[i], busyTo, willDecrease);
            seAmount += curSEAmount;
        }
        emit TokensLock(tokenId, busyTo, decreaseSE);
        return seAmount;
    }

    function setPlayerContract(uint[] calldata tokenId, uint32 contractEndTimestamp, address user) public onlyRole(GAME_ROLE) {
        for (uint i = 0; i < tokenId.length; i++) {
            require(ownerOf(tokenId[i]) == user, "Not owner of token");
            _setPlayerContract(tokenId[i], contractEndTimestamp);
        }
        emit NewContract(tokenId, contractEndTimestamp);
    }

    function squidEnergyDecrease(uint[] calldata tokenId, uint128[] calldata deduction, address user) public onlyRole(SE_BOOST_ROLE) {
        require(tokenId.length == deduction.length, "Wrong calldata array size");
        for (uint i = 0; i < tokenId.length; i++) {
            require(_exists(tokenId[i]), "ERC721: token does not exist");
            require(ownerOf(tokenId[i]) == user, "Not owner of token");
            require(!_tokens[tokenId[i]].stakeFreeze, "ERC721: Token frozen");
            require(_tokens[tokenId[i]].squidEnergy >= deduction[i], "Wrong deduction value");
            _tokens[tokenId[i]].squidEnergy -= deduction[i];
        }
    }

    function squidEnergyIncrease(uint[] calldata tokenId, uint128[] calldata addition, address user) public onlyRole(SE_BOOST_ROLE) {
        require(tokenId.length == addition.length, "Wrong calldata array size");
        for (uint i = 0; i < tokenId.length; i++) {
            require(_exists(tokenId[i]), "ERC721: token does not exist");
            require(ownerOf(tokenId[i]) == user, "Not owner of token");
            require(!_tokens[tokenId[i]].stakeFreeze, "ERC721: Token frozen");
            Token storage curToken = _tokens[tokenId[i]];
            require((curToken.squidEnergy + addition[i]) <= _rarityLimitsSE[curToken.rarity], "Wrong addition value");
            curToken.squidEnergy += addition[i];
        }
        emit SEIncrease(tokenId, addition);
    }

    function arrayUserPlayers(address _user) public view returns (TokensViewFront[] memory) {
        if (balanceOf(_user) == 0) return new TokensViewFront[](0);
        return arrayUserPlayers(_user, 0, balanceOf(_user) - 1);
    }

    function arrayUserPlayers(
        address _user,
        uint _from,
        uint _to
    ) public view returns (TokensViewFront[] memory) {
        //SPN-01
        require(_to < balanceOf(_user), "Wrong max array value");
        require((_to - _from) <= balanceOf(_user), "Wrong array range");
        TokensViewFront[] memory tokens = new TokensViewFront[](_to - _from + 1);
        uint index = 0;
        for (uint i = _from; i <= _to; i++) {
            uint id = tokenOfOwnerByIndex(_user, i);
            tokens[index] = getToken(id);
            index++;
        }
        return (tokens);
    }

    function arrayUserPlayersWithValidContracts(address _user) public view returns (TokensViewFront[] memory) {
        if (balanceOf(_user) == 0) return new TokensViewFront[](0);
        return arrayUserPlayersWithValidContracts(_user, 0, balanceOf(_user) - 1);
    }

    function arrayUserPlayersWithValidContracts(
        address _user,
        uint _from,
        uint _to
    ) public view returns (TokensViewFront[] memory) {
        //SPN-01
        require(_to < balanceOf(_user), "Wrong max array value");
        require((_to - _from) <= balanceOf(_user), "Wrong array range");
        uint[] memory index = new uint[](_to - _from + 1);
        uint count = 0;
        for (uint i = _from; i <= _to; i++) {
            uint id = tokenOfOwnerByIndex(_user, i);
            if (getToken(id).contractEndTimestamp > block.timestamp) {
                index[count] = id;
                count++;
            }
        }
        TokensViewFront[] memory tokensView = new TokensViewFront[](count);
        for (uint i = 0; i < count; i++) {
            tokensView[i] = getToken(index[i]);
        }
        return (tokensView);
    }

    function availableSEAmount(address _user) public view returns (uint128 amount) {
        for (uint i = 0; i < balanceOf(_user); i++) {
            Token memory curToken = _tokens[tokenOfOwnerByIndex(_user, i)];
            if (
                curToken.contractEndTimestamp > block.timestamp &&
                curToken.busyTo < block.timestamp &&
                !curToken.stakeFreeze
            ) {
                amount += curToken.squidEnergy;
            }
        }
        return amount;
    }

    function totalSEAmount(address _user) public view returns (uint128 amount) {
        for (uint i = 0; i < balanceOf(_user); i++) {
            Token memory curToken = _tokens[tokenOfOwnerByIndex(_user, i)];
            amount += curToken.squidEnergy;
        }
        return amount;
    }

    function approve(address to, uint tokenId) public override {
        require(!_tokens[tokenId].stakeFreeze, "ERC721: Token frozen");
        super.approve(to, tokenId);
    }

    //Internal functions --------------------------------------------------------------------------------------------

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }

    function _burn(uint tokenId) internal override {
        super._burn(tokenId);
        delete _tokens[tokenId];
    }

    function _safeMint(address to, uint tokenId) internal override {
        super._safeMint(to, tokenId);
        emit TokenMint(to, tokenId, _tokens[tokenId].rarity, _tokens[tokenId].squidEnergy);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint tokenId
    ) internal virtual override(ERC721EnumerableUpgradeable) {
        require(!_tokens[tokenId].stakeFreeze, "ERC721: Token frozen");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    //Private functions --------------------------------------------------------------------------------------------

    function _lockToken(uint _tokenId, uint32 _busyTo, bool willDecrease) private returns (uint128 SEAmount, uint128 decreaseSE) {
        require(_exists(_tokenId), "ERC721: token does not exist");
        require(_busyTo > block.timestamp, "Busy to block must be greater than current block number");
        Token storage _token = _tokens[_tokenId];
        require(!_token.stakeFreeze, "Token frozen");
        require(_token.busyTo < block.timestamp, "Token already busy");
        require(_token.contractEndTimestamp > block.timestamp, "Token hasnt valid contract");
        _token.busyTo = _busyTo;
        bool gracePeriodHasPassed = (block.timestamp - _token.createTimestamp) >= gracePeriod;
        uint128 _seDivide = enableSeDivide && gracePeriodHasPassed && willDecrease ? seDivide : 0;
        SEAmount = _token.squidEnergy;
        decreaseSE = (SEAmount * _seDivide) / 10000;
        _token.squidEnergy -= decreaseSE;
        return (SEAmount, decreaseSE);
    }

    function _setPlayerContract(uint _tokenId, uint32 _contractEndTimestamp) private {
        Token storage _token = _tokens[_tokenId];
        require(_contractEndTimestamp > block.timestamp, "New contract must be greater than current block");
        require(!_token.stakeFreeze, "Token frozen");
        require(_exists(_tokenId), "ERC721: token does not exist");
        require(_token.contractEndTimestamp <= block.timestamp, "Previous contract does not finished");
        _token.contractEndTimestamp = _contractEndTimestamp;
    }
}
