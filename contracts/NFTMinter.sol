// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interface/ISquidBusNFT.sol";
import "./interface/ISquidPlayerNFT.sol";
import "./interface/IOracle.sol";
import "./interface/IBiswapPair.sol";


contract NFTMinter is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint public busChancesBase;
    uint public busPriceInUSD;
    uint public playerPriceInUSD;

    uint public playerChancesBase;

    address public treasuryAddressBus;
    address public treasuryAddressPlayer;

    IERC20Upgradeable public bswToken;
    IERC20Upgradeable public usdtToken;
    ISquidBusNFT public busNFT;
    ISquidPlayerNFT public playerNFT;
    IOracle public oracle;

    struct ChanceTableBus {
        uint8 level; //Desired value
        uint64 chance; // Probability
    }

    struct ChanceTablePlayer {
        uint8 rarity;
        uint128 maxValue;
        uint128 minValue;
        uint32 chance;
    }

    struct BusToken {
        uint tokenId;
        uint8 level;
        uint32 createTimestamp;
        string uri;
    }

    ChanceTableBus[] public busChance; //value: Bus level
    ChanceTablePlayer[] public playerChance; //Player chance table

    bool public checkPeriodPlayerLimits;
    uint public periodLimitPlayers; //limit players by period
    mapping(uint => uint) public playersMintCount; //Count mint players by 6 hours (6 hours count => players count)

    IBiswapPair private pairForRand;

    mapping(address => bool) public inQueue; //User in queue
    struct Queue{
        address caller;
        uint blockNumber;
    }
    Queue[] public playerQueue;
    Queue[] public busQueue;
    uint nonce;

    // event TokenMint(address indexed to, uint indexed tokenId, uint8 rarity, uint128 squidEnergy); //PlayerNFT contract event
    // event TokenMint(address indexed to, uint indexed tokenId, uint8 level); //Bus NFT event

    //Initialize function --------------------------------------------------------------------------------------------

    function initialize(
        IERC20Upgradeable _usdtToken,
        IERC20Upgradeable _bswToken,
        ISquidBusNFT _busNFT,
        ISquidPlayerNFT _playerNFT,
        IOracle _oracle,
        address _treasuryAddressBus,
        address _treasuryAddressPlayer,
        uint _busPriceInUSD,
        uint _playerPriceInUSD
    ) public initializer {
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        bswToken = _bswToken;
        usdtToken = _usdtToken;
        busNFT = _busNFT;
        playerNFT = _playerNFT;
        oracle = _oracle;
        treasuryAddressBus = _treasuryAddressBus;
        treasuryAddressPlayer = _treasuryAddressPlayer;
        busPriceInUSD = _busPriceInUSD;
        playerPriceInUSD = _playerPriceInUSD;

        playerChancesBase = 1000;
        busChancesBase = 100;

        busChance.push(ChanceTableBus({level: 1, chance: 45}));
        busChance.push(ChanceTableBus({level: 2, chance: 37}));
        busChance.push(ChanceTableBus({level: 3, chance: 13}));
        busChance.push(ChanceTableBus({level: 4, chance: 4}));
        busChance.push(ChanceTableBus({level: 5, chance: 1}));

        playerChance.push(ChanceTablePlayer({rarity: 1, maxValue: 500, minValue: 300, chance: 500}));
        playerChance.push(ChanceTablePlayer({rarity: 2, maxValue: 1200, minValue: 500, chance: 350}));
        playerChance.push(ChanceTablePlayer({rarity: 3, maxValue: 1700, minValue: 1200, chance: 110}));
        playerChance.push(ChanceTablePlayer({rarity: 4, maxValue: 2300, minValue: 1700, chance: 35}));
        playerChance.push(ChanceTablePlayer({rarity: 5, maxValue: 3300, minValue: 2300, chance: 5}));
    }

    //Modifiers -------------------------------------------------------------------------------------------------------

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    //External functions --------------------------------------------------------------------------------------------

    function setPeriodLimitPlayers(uint newLimit, bool enabled)  external onlyRole(DEFAULT_ADMIN_ROLE) {
        periodLimitPlayers = newLimit;
        checkPeriodPlayerLimits = enabled;
    }

    function setPrices(uint _busPriceInUSD, uint _playerPriceInUSD) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_busPriceInUSD != 0 && _playerPriceInUSD != 0, "Wrong price");
        busPriceInUSD = _busPriceInUSD;
        playerPriceInUSD = _playerPriceInUSD;
    }

    function setTreasuryAddress(address _treasuryAddressBus, address _treasuryAddressPlayer)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_treasuryAddressBus != address(0) && _treasuryAddressPlayer != address(0), "Address cant be zero");
        treasuryAddressBus = _treasuryAddressBus;
        treasuryAddressPlayer = _treasuryAddressPlayer;
    }

    function setPairForRand(IBiswapPair _pair) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pairForRand = _pair;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setBusChanceTable(ChanceTableBus[] calldata _newBusChanceTable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint _busChancesBase = 0;
        delete busChance;
        for (uint i = 0; i < _newBusChanceTable.length; i++) {
            _busChancesBase += _newBusChanceTable[i].chance;
            busChance.push(_newBusChanceTable[i]);
        }
        busChancesBase = _busChancesBase;
    }

    function setPlayerChanceTable(ChanceTablePlayer[] calldata _newPlayerChanceTable)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint _playerChancesBase = 0;
        delete playerChance;
        for (uint i = 0; i < _newPlayerChanceTable.length; i++) {
            _playerChancesBase += _newPlayerChanceTable[i].chance;
            playerChance.push(_newPlayerChanceTable[i]);
        }
        playerChancesBase = _playerChancesBase;
    }

    //Public functions ----------------------------------------------------------------------------------------------

    function buyBus() public notContract whenNotPaused {
        require(!inQueue[msg.sender], "Wait queue");
        require(busNFT.allowedUserToMintBus(msg.sender), "Mint bus not allowed. Balance over limit");
        inQueue[msg.sender] = true;
        uint priceInBSW = _getPriceInBSW(busPriceInUSD);
        bswToken.safeTransferFrom(msg.sender, treasuryAddressBus, priceInBSW);

        closeBusQueue(false, 0);
        busQueue.push(Queue({caller: msg.sender, blockNumber: block.number}));
    }

    function buyPlayer() public notContract whenNotPaused {
        require(!inQueue[msg.sender], "Wait queue");
        require(busNFT.seatsInBuses(msg.sender) > playerNFT.balanceOf(msg.sender), "No free places in buses");
        inQueue[msg.sender] = true;
        if(checkPeriodPlayerLimits){
            require(playersMintCount[block.timestamp / (6*3600)] < periodLimitPlayers, "Mint over period limit");
            playersMintCount[block.timestamp / (6*3600)]  += 1;
        }
        uint priceInBSW = _getPriceInBSW(playerPriceInUSD);
        bswToken.safeTransferFrom(msg.sender, treasuryAddressPlayer, priceInBSW);

        closePlayerQueue(false, 0);
        playerQueue.push(Queue({caller: msg.sender, blockNumber: block.number}));
    }

    function getBusTokens(address _user) public view returns(BusToken[] memory){
        require(_user != address(0), "Address cant be zero");
        uint amount = busNFT.balanceOf(_user);
        BusToken[] memory busTokens = new BusToken[](amount);
        if(amount > 0 ){
            for(uint i = 0; i < amount; i++){
                (uint tokenId,
                ,
                uint8 level,
                uint32 createTimestamp,
                string memory uri) = busNFT.getToken(busNFT.tokenOfOwnerByIndex(_user, i));
                busTokens[i].tokenId = tokenId;
                busTokens[i].level = level;
                busTokens[i].createTimestamp = createTimestamp;
                busTokens[i].uri = uri;
            }
        }
        return(busTokens);
    }

    function getPlayerTokens(address _user) public view returns(ISquidPlayerNFT.TokensViewFront[] memory){
        require(_user != address(0), "Address cant be zero");
        return(playerNFT.arrayUserPlayers(_user));
    }

    function getPricesInBSW() public view returns(uint busPrice, uint playerPrice){
        busPrice = _getPriceInBSW(busPriceInUSD);
        playerPrice = _getPriceInBSW(playerPriceInUSD);
    }

    function getLimitPlayerParameters() public view returns(uint totalLimit, uint mintedOnPeriod, uint timeLeft){
        totalLimit = periodLimitPlayers;
        mintedOnPeriod = playersMintCount[block.timestamp / (6*3600)];
        timeLeft = 6*3600 - block.timestamp % (6*3600);
    }

    function getQueuesSize() public view returns(uint, uint){
        return(busQueue.length, playerQueue.length);
    }

    //limit: Cycle limit per transaction
    function manuallyCloseBusQueue(uint limit) public whenNotPaused {
        closeBusQueue(true, limit);
    }

    function manuallyClosePlayerQueue(uint limit) public whenNotPaused {
        closePlayerQueue(true, limit);
    }

    function selfClaimBus() public notContract whenNotPaused {
        for(uint i = 0; i < busQueue.length; i++){
            if(busQueue[i].caller == msg.sender){
                closeBusQueueByIndex(i);
                return;
            }
        }
    }

    function selfClaimPlayer() public notContract whenNotPaused {
        for(uint i = 0; i < playerQueue.length; i++){
            if(playerQueue[i].caller == msg.sender){
                closePlayerQueueByIndex(i);
                return;
            }
        }
    }


    //Internal functions --------------------------------------------------------------------------------------------

    function closeBusQueue(bool allQueue, uint limit) internal {
        uint queueLength = busQueue.length;
        uint count = 1;
        if(queueLength == 0) return;
        limit = limit == 0 || limit > queueLength ? queueLength : limit;
        uint i = 0;
        while(i < limit){
            if (closeBusQueueByIndex(i)) {
                if(!allQueue && count == 0) break;
                count = count == 0 ? 0 : count - 1;
                limit--;
            } else {
                i++;
                continue;
            }
        }
    }

    function closeBusQueueByIndex(uint index) internal returns(bool){
        Queue memory _busQueue = busQueue[index];
        if ( _busQueue.blockNumber >= block.number ) {
            return false;
        }
        if( (block.number - _busQueue.blockNumber) > 255){
            busQueue[index].blockNumber = block.number;
            return false;
        }
        address user = _busQueue.caller;
        bytes32 hash = keccak256(abi.encodePacked(user, blockhash(_busQueue.blockNumber)));
        uint8 busLevel = _randomBusLevel(hash);
        busQueue[index] = busQueue[busQueue.length - 1];
        busQueue.pop();
        busNFT.mint(user, busLevel);
        inQueue[user] = false;
        return true;
    }

    function closePlayerQueue(bool allQueue, uint limit) internal {
        uint queueLength = playerQueue.length;
        uint count = 1;
        if(queueLength == 0) return;
        limit = limit == 0 || limit > queueLength ? queueLength : limit;

        uint i = 0;
        while(i < limit){
            if (closePlayerQueueByIndex(i)) {
                if(!allQueue && count == 0) break;
                count = count == 0 ? 0 : count - 1;
                limit--;
            } else {
                i++;
                continue;
            }
        }
    }

    function closePlayerQueueByIndex(uint index) internal returns(bool){
        Queue memory _playerQueue = playerQueue[index];
        if ( _playerQueue.blockNumber >= block.number ) {
            return false;
        }

        if( (block.number - _playerQueue.blockNumber) > 255){
            playerQueue[index].blockNumber = block.number;
            return false;
        }

        address user = _playerQueue.caller;
        bytes32 hash = keccak256(abi.encodePacked(user, blockhash(_playerQueue.blockNumber)));
        (uint8 rarity, uint128 squidEnergy) = _getRandomPlayer(hash);
        playerQueue[index] = playerQueue[playerQueue.length - 1];
        playerQueue.pop();
        playerNFT.mint(user, squidEnergy * 1e18, 0, rarity - 1);
        inQueue[user] = false;
        return true;
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    function _getPriceInBSW(uint _amount) internal view returns (uint) {
        return oracle.consult(address(usdtToken), _amount, address(bswToken));
    }

    //Private functions --------------------------------------------------------------------------------------------

    function _getRandomPlayer(bytes32 hash) private view returns (uint8, uint128) {
        ChanceTablePlayer[] memory _playerChance = playerChance;
        uint _randomForRarity = _getRandomMinMax(1, playerChancesBase, hash);
        uint count = 0;
        for (uint i = 0; i < _playerChance.length; i++) {
            count += _playerChance[i].chance;
            if (_randomForRarity <= count) {
                uint8 rarity = _playerChance[i].rarity;
                uint128 squidEnergy = uint128(_getRandomMinMax(_playerChance[i].minValue, _playerChance[i].maxValue, hash));
                return (rarity, squidEnergy);
            }
        }
        revert("Cant find random level");
    }

    function _getRandomMinMax(uint _min, uint _max, bytes32 hash) private pure returns (uint random) {
        uint diff = (_max - _min) + 1;
        random = (uint(hash) % diff) + _min;
    }

    function _randomBusLevel(bytes32 hash) private view returns (uint8) {
        ChanceTableBus[] memory _busChance = busChance;

        uint _randomForLevel = _getRandomMinMax(1, busChancesBase, hash);
        uint64 count = 0;
        for (uint i = 0; i < _busChance.length; i++) {
            count += _busChance[i].chance;
            if (_randomForLevel <= count) {
                return (_busChance[i].level);
            }
        }
        revert("Cant find random level");
    }
}
