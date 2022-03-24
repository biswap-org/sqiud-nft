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


interface IMasterChef {

    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    function userInfo(uint _pid, address _user) external view returns (UserInfo memory);
}

interface IautoBsw {
    function balanceOf() external view returns(uint);
    function totalShares() external view returns(uint);

    struct UserInfo {
        uint shares; // number of shares for a user
        uint lastDepositedTime; // keeps track of deposited time for potential penalty
        uint BswAtLastUserAction; // keeps track of Bsw deposited at the last user action
        uint lastUserActionTime; // keeps track of the last user action time
    }

    function userInfo(address user) external view returns (UserInfo memory);
}


contract MainSquidGame is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public bswToken;
    IERC20Upgradeable public usdtToken;
    ISquidBusNFT public busNFT;
    ISquidPlayerNFT public playerNFT;
    IOracle public oracle;
    IMasterChef public masterChef;
    IautoBsw public autoBsw;

    struct RewardToken {
        address token;
        uint128 rewardInUSD;
        uint128 rewardInToken;
    }

    struct PlayerContract{
        uint32 duration; //in seconds
        uint128 priceInUSD;
        bool enable; //true: enabled; false: disabled
    }

    struct Game {
        uint128 minSeAmount;
        uint128 minStakeAmount; //min stake amount (in masterChef and autoBsw) to be available to play game
        uint chanceToWin; //base 10000
        RewardToken[] rewardTokens;
        string name;
        bool enable; //true - enable; false - disable
    }

    struct UserInfo {
        uint busBalance;
        uint allowedBusBalance;
        uint secToNextBus; //how many seconds are left until the next bus
        uint playerBalance;
        uint allowedSeatsInBuses;
        uint availableSEAmount;
        uint availableSEAmountV2;
        uint totalSEAmount;
        uint stakedAmount;
        uint bswBalance;
        RewardToken[] rewardBalance;
        uint currentFee;
    }

    struct GameInfo {
        uint index;
        Game game;
        bool playerAndBusAmount;
        bool bswStake;
        bool seAmount;
    }

    uint constant MAX_WITHDRAWAL_FEE = 5000;

    uint public decreaseWithdrawalFeeByDay; //150: -1,5% by day
    uint public withdrawalFee; //2700: 27%
    uint public recoveryTime; // 48h = 172800 for lock tokens after game play

    address public treasuryAddress;

    Game[] public games;
    PlayerContract[] public playerContracts;
    address[] rewardTokens;
    mapping(address => uint) public withdrawTimeLock; //user address => block.timestamp; To calc withdraw fee
    mapping(address => uint) public firstGameCountdownSE; //user address => block.timestamp Grace period after this - SEDecrease enabled
    mapping(address => mapping(address => uint128)) userBalances; //user balances: user address => token address => amount

    IBiswapPair private pairForRand;

    Game[] public gamesV2;
    PlayerContract[] public playerContractsV2;

    event GameAdded(uint gameIndex, uint contractVersion);
    event GameDisable(uint gameIndex);
    event GameEnable(uint gameIndex);
    event GamePlay(address indexed user, uint indexed gameIndex, bool userWin, address[] rewardTokens, uint128[] rewardAmount);
    event Withdrew(address indexed user, RewardToken[] _rewardBalance);
    event RewardTokenChanged(uint gameIndex);
    event SetNewGameParam(uint gameIndex, uint contractVersion);

    //Initialize function --------------------------------------------------------------------------------------------

    function initialize(
        IERC20Upgradeable _usdtToken,
        IERC20Upgradeable _bswToken,
        ISquidBusNFT _busNFT,
        ISquidPlayerNFT _playerNFT,
        IOracle _oracle,
        IMasterChef _masterChef,
        IautoBsw _autoBsw,
        address _treasuryAddress,
        uint _recoveryTime
    ) public initializer {
        require(
            address(_usdtToken) != address(0) &&
            address(_bswToken) != address(0) &&
            address(_busNFT) != address(0) &&
            address(_playerNFT) != address(0) &&
            address(_oracle) != address(0) &&
            address(_autoBsw) != address(0),
            "Address cant be zero"
        );
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        bswToken = _bswToken;
        usdtToken = _usdtToken;
        busNFT = _busNFT;
        playerNFT = _playerNFT;
        oracle = _oracle;
        autoBsw = _autoBsw;
        treasuryAddress = _treasuryAddress;
        recoveryTime = _recoveryTime;

    }

    //Modifiers -------------------------------------------------------------------------------------------------------

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    //External functions --------------------------------------------------------------------------------------------

    function changePlayerContract(uint _pcIndex, uint contractVersion, PlayerContract calldata _playerContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if(contractVersion == 1){
            require(_pcIndex < playerContracts.length, "Index out of bound");
            playerContracts[_pcIndex] = _playerContract;
        } else if(contractVersion == 2){
            require(_pcIndex < playerContractsV2.length, "Index out of bound");
            playerContractsV2[_pcIndex] = _playerContract;
        } else{
            revert("Wrong contract version");
        }
    }

    function addPlayerContract(PlayerContract calldata _playerContract, uint contractVersion) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if(contractVersion == 1){
            playerContracts.push(_playerContract);
        } else if(contractVersion == 2){
            playerContractsV2.push(_playerContract);
        } else{
            revert("Wrong contract version");
        }
    }

    function setAutoBsw(IautoBsw _autoBsw) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(_autoBsw) != address(0), "Address cant be zero");
        autoBsw = _autoBsw;
    }

    function setTreasuryAddress(address _treasuryAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasuryAddress != address(0), "Address cant be zero");
        treasuryAddress = _treasuryAddress;
    }

    function addNewGame(Game calldata _game, uint contractVersion) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if(contractVersion == 1){
            games.push(_game);
        } else if(contractVersion == 2){
            gamesV2.push(_game);
        } else{
            revert("Wrong contract version");
        }
        for (uint i = 0; i < _game.rewardTokens.length; i++) {
            if (!_tokenInArray(_game.rewardTokens[i].token)) {
                rewardTokens.push(_game.rewardTokens[i].token);
            }
        }
        emit GameAdded(games.length, contractVersion);
    }

    function setGameParameters(uint _gameIndex, Game calldata _newGame, uint contractVersion) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if(contractVersion == 1){
            require(_gameIndex < games.length, "Index out of bound");
            delete games[_gameIndex];
            games[_gameIndex] = _newGame;
        } else if(contractVersion == 2){
            require(_gameIndex < gamesV2.length, "Index out of bound");
            delete gamesV2[_gameIndex];
            gamesV2[_gameIndex] = _newGame;
        } else{
            revert("Wrong contract version");
        }

        for (uint i = 0; i < _newGame.rewardTokens.length; i++) {
            if (!_tokenInArray(_newGame.rewardTokens[i].token)) {
                rewardTokens.push(_newGame.rewardTokens[i].token);
            }
        }
        emit SetNewGameParam(_gameIndex, contractVersion);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setWithdrawalFee(uint _decreaseWithdrawalFeeByDay, uint _withdrawalFee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        //MSG-02
        require(_withdrawalFee <= MAX_WITHDRAWAL_FEE, "Incorrect value withdrawal Fee");
        withdrawalFee = _withdrawalFee;
        decreaseWithdrawalFeeByDay = _decreaseWithdrawalFeeByDay;
    }

    function setRecoveryTime(uint _newRecoveryTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        recoveryTime = _newRecoveryTime;
    }

    //Public functions ----------------------------------------------------------------------------------------------

    function playGame(uint _gameIndex, uint[] calldata _playersId, uint contractVersion) public notContract whenNotPaused nonReentrant {
        Game memory _game;
        if(contractVersion == 1){
            require(_gameIndex < games.length, "Index out of bound");
            _game = games[_gameIndex];
        } else if(contractVersion == 2){
            require(_gameIndex < gamesV2.length, "Index out of bound");
            _game = gamesV2[_gameIndex];
        } else{
            revert("Wrong contract version");
        }
        require(_game.enable, "Game is disabled");
        require(_checkBusAndPlayersAmount(msg.sender), "Check bus and players falls");
        require(_checkMinStakeAmount(msg.sender, _gameIndex, contractVersion), "Need more stake in pools");
        if (firstGameCountdownSE[msg.sender] == 0) {
            firstGameCountdownSE[msg.sender] = block.timestamp;
        }
        bool willDecreaseSE = contractVersion == 1 ? true : false;
        uint128 totalSE = playerNFT.lockTokens(_playersId, uint32(block.timestamp + recoveryTime), willDecreaseSE, msg.sender, contractVersion);
        require(totalSE >= _game.minSeAmount, "Not enough SE amount");
        bool userWin = _getRandomForWin(_gameIndex, contractVersion);
        address[] memory _rewardTokens = new address[](_game.rewardTokens.length);
        uint128[] memory _rewardAmount = new uint128[](_game.rewardTokens.length);
        if (userWin) {
            for (uint i = 0; i < _game.rewardTokens.length; i++) {
                _rewardAmount[i] = _game.rewardTokens[i].rewardInToken == 0 ?
                _getPriceInToken(_game.rewardTokens[i].token, _game.rewardTokens[i].rewardInUSD) :
                _game.rewardTokens[i].rewardInToken;
                _rewardTokens[i] = _game.rewardTokens[i].token;
            }
            _balanceIncrease(msg.sender, _rewardTokens, _rewardAmount);
        }
        emit GamePlay(msg.sender, _gameIndex, userWin, _rewardTokens, _rewardAmount);
    }

    function withdrawReward() public notContract whenNotPaused nonReentrant {
        require(withdrawTimeLock[msg.sender] > 0, "Withdraw not allowed");
        uint calcFee;
        uint multipl = (block.timestamp - withdrawTimeLock[msg.sender]) / 86400;
        calcFee = (multipl * decreaseWithdrawalFeeByDay) >= withdrawalFee
            ? 0
            : withdrawalFee - (multipl * decreaseWithdrawalFeeByDay);

        RewardToken[] memory _rewardBalance = new RewardToken[](rewardTokens.length);
        for (uint i = 0; i < rewardTokens.length; i++) {
            address currentToken = rewardTokens[i];
            uint128 currentBalance = userBalances[msg.sender][currentToken];
            _rewardBalance[i].token = currentToken;
            _rewardBalance[i].rewardInToken = userBalances[msg.sender][currentToken];
            delete userBalances[msg.sender][currentToken];
            if (currentBalance > 0) {
                uint fee = (currentBalance * calcFee) / 10000;
                IERC20Upgradeable(currentToken).safeTransfer(treasuryAddress, fee);
                IERC20Upgradeable(currentToken).safeTransfer(msg.sender, currentBalance - fee);
            }
        }
        //MSG-03
        delete withdrawTimeLock[msg.sender];
        emit Withdrew(msg.sender, _rewardBalance);
    }

    function buyContracts(uint[] memory _tokensId, uint _contractIndex) public notContract whenNotPaused nonReentrant {
        require(_tokensId.length > 0, "Cant by contracts without tokensId");
        require(_contractIndex < playerContracts.length, "Wrong index out of bound");
        require(playerContracts[_contractIndex].enable, "Selected contract disabled");
        uint priceInBSW = playerContracts[_contractIndex].priceInUSD;
        uint totalCost = priceInBSW * _tokensId.length;
        IERC20Upgradeable(bswToken).safeTransferFrom(msg.sender, treasuryAddress, totalCost);
        playerNFT.setPlayerContract(_tokensId, playerContracts[_contractIndex].duration, msg.sender, 1);
    }

    function buyContractsV2(uint[] memory _tokensId, uint _contractIndex) public notContract whenNotPaused nonReentrant {
        require(_tokensId.length > 0, "Cant by contracts without tokensId");
        require(_contractIndex < playerContractsV2.length, "Wrong index out of bound");
        (uint totalCost,) = getContractV2Cost(_tokensId, _contractIndex);
        IERC20Upgradeable(bswToken).safeTransferFrom(msg.sender, treasuryAddress, totalCost);
        playerNFT.setPlayerContract(_tokensId, playerContractsV2[_contractIndex].duration, msg.sender, 2);
    }

    function getContractV2Cost(uint[] memory _playersId, uint _contractIndex) public view returns(uint totalCost, uint[] memory playersCost) {
        uint priceInBSW = playerContractsV2[_contractIndex].priceInUSD;
        playersCost = new uint[](_playersId.length);
        (uint totalSeAmount, uint[] memory seAmount) = playerNFT.getSEAmountFromTokensId(_playersId);
        for(uint i = 0; i < playersCost.length; i++){
            playersCost[i] = priceInBSW * seAmount[i] / 1e18;
        }
        totalCost = priceInBSW * totalSeAmount / 1e18;
    }

    function getUserContractsV2Cost(address _user) public view returns(uint[] memory playersId, uint[][] memory contractCost){
        ISquidPlayerNFT.TokensViewFront[] memory userPlayers = playerNFT.arrayUserPlayers(_user);
        uint countWOContract;
        for(uint i = 0; i < userPlayers.length; i++){
            if(userPlayers[i].contractV2EndTimestamp < uint32(block.timestamp)) countWOContract++;
        }
        playersId = new uint[](countWOContract);

        contractCost = new uint[][](playerContractsV2.length);
        for(uint i = 0; i < userPlayers.length; i++){
            if(userPlayers[i].contractV2EndTimestamp < uint32(block.timestamp)){
                playersId[--countWOContract] = userPlayers[i].tokenId;
            }
        }
        for(uint i = 0; i < playerContractsV2.length; i++){
            (, contractCost[i]) = getContractV2Cost(playersId, i);
        }
        return(playersId, contractCost);
    }

    function userInfo(address _user) public view returns (UserInfo memory) {
        UserInfo memory _userInfo;

        uint autoBswBalance = autoBsw.balanceOf() * autoBsw.userInfo(_user).shares / autoBsw.totalShares();
        _userInfo.busBalance = busNFT.balanceOf(_user);
        _userInfo.allowedBusBalance = busNFT.allowedBusBalance(_user);
        _userInfo.playerBalance = playerNFT.balanceOf(_user);
        _userInfo.allowedSeatsInBuses = busNFT.seatsInBuses(_user);
        _userInfo.availableSEAmount = playerNFT.availableSEAmount(_user);
        _userInfo.availableSEAmountV2 = playerNFT.availableSEAmountV2(_user);
        _userInfo.totalSEAmount = playerNFT.totalSEAmount(_user);
        _userInfo.stakedAmount = autoBswBalance; //+ masterChef.userInfo(0, _user).amount //Check only autoBsw holder pool
        _userInfo.bswBalance = IERC20Upgradeable(bswToken).balanceOf(_user);
        _userInfo.secToNextBus = busNFT.secToNextBus(_user);
        RewardToken[] memory _rewardBalance = new RewardToken[](rewardTokens.length);
        for(uint i = 0; i < rewardTokens.length; i++){
            _rewardBalance[i].token = rewardTokens[i];
            _rewardBalance[i].rewardInToken = userBalances[_user][rewardTokens[i]];
        }
        _userInfo.rewardBalance = _rewardBalance;
        uint calcFee;
        uint multipl = (block.timestamp - withdrawTimeLock[_user]) / 1 days;
        calcFee = (multipl * decreaseWithdrawalFeeByDay) >= withdrawalFee
            ? 0
            : withdrawalFee - (multipl * decreaseWithdrawalFeeByDay);
        _userInfo.currentFee = calcFee;
        return (_userInfo);
    }

    function getUserRewardBalances(address _user) public view returns (address[] memory, uint128[] memory) {
        uint128[] memory balances = new uint128[](rewardTokens.length);
        for (uint i = 0; i < balances.length; i++) {
            balances[i] = userBalances[_user][rewardTokens[i]];
        }
        return (rewardTokens, balances);
    }

    function getGameCount(uint contractVersion) public view returns(uint count){
        count = contractVersion == 1 ? games.length : gamesV2.length;
    }

    function getGameInfo(address _user, uint contractVersion) public view returns(GameInfo[] memory){
        GameInfo[] memory gamesInfo =  new GameInfo[](contractVersion == 1 ? games.length : gamesV2.length);
        bool playerAndBusAmount = _user != address(0) ?  _checkBusAndPlayersAmount(_user) : false;
        for(uint i = 0; i < gamesInfo.length; i++){
            bool bswStake = _user != address(0) ?  _checkMinStakeAmount(_user, i, contractVersion) : false;
            bool seAmount = _user != address(0) ?
                contractVersion == 1 ?
                    playerNFT.availableSEAmount(_user) >= games[i].minSeAmount :
                    playerNFT.availableSEAmountV2(_user) >= gamesV2[i].minSeAmount :
                false;
            gamesInfo[i].index = i;
            gamesInfo[i].game = contractVersion == 1 ? games[i] : gamesV2[i];
            gamesInfo[i].playerAndBusAmount = playerAndBusAmount;
            gamesInfo[i].bswStake = bswStake;
            gamesInfo[i].seAmount = seAmount;

            for(uint j = 0; j < gamesInfo[i].game.rewardTokens.length; j++){
                gamesInfo[i].game.rewardTokens[j].rewardInToken = gamesInfo[i].game.rewardTokens[j].rewardInToken == 0 ?
                    _getPriceInToken(gamesInfo[i].game.rewardTokens[j].token, gamesInfo[i].game.rewardTokens[j].rewardInUSD) :
                    gamesInfo[i].game.rewardTokens[j].rewardInToken;
            }
        }
        return(gamesInfo);
    }


    //Internal functions --------------------------------------------------------------------------------------------

    function _checkMinStakeAmount(address _user, uint _gameIndex, uint contractVersion) internal view returns (bool) {
        uint autoBswBalance = autoBsw.balanceOf() * autoBsw.userInfo(_user).shares / autoBsw.totalShares();
        uint stakeAmount = autoBswBalance;// + masterChef.userInfo(0, _user).amount; //Check only autoBsw holder pool
        if(contractVersion == 1){
            return stakeAmount >= games[_gameIndex].minStakeAmount;
        } else if(contractVersion == 2) {
            return stakeAmount >= gamesV2[_gameIndex].minStakeAmount;
        } else revert("Wrong contract version");
    }

    function _checkBusAndPlayersAmount(address _user) internal view returns (bool) {
        return busNFT.seatsInBuses(_user) != 0 && busNFT.seatsInBuses(_user) >= playerNFT.balanceOf(_user);
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

    function _getPriceInToken(address _token, uint _amount) internal view returns (uint128) {
        return uint128(oracle.consult(address(usdtToken), _amount, _token));
    }

    function _tokenInArray(address _token) internal view returns (bool) {
        for (uint i = 0; i < rewardTokens.length; i++) {
            if (_token == rewardTokens[i]) return true;
        }
        return false;
    }

    //Private functions --------------------------------------------------------------------------------------------

    function _getRandomForWin(uint _gameIndex, uint contractVersion) private view returns (bool) {
        uint chanceToWin = contractVersion == 1 ? games[_gameIndex].chanceToWin : gamesV2[_gameIndex].chanceToWin;
        uint random = (uint(keccak256(abi.encodePacked(blockhash(block.number - 1), gasleft()))) % 10000) + 1;
        return random < chanceToWin;
    }

    function _balanceIncrease(address _user, address[] memory _token, uint128[] memory _amount) private {
        require(_token.length == _amount.length, "Wrong arrays length");
        if(withdrawTimeLock[_user] == 0) withdrawTimeLock[_user] = block.timestamp;
        for(uint i = 0; i < _token.length; i++){
            userBalances[_user][_token[i]] +=  _amount[i];
        }
    }

    function _balanceDecrease(address _user, address[] memory _token, uint128[] memory _amount) private {
        require(_token.length == _amount.length);
        for(uint i = 0; i < _token.length; i++){
            require(userBalances[_user][_token[i]] >=  _amount[i], "Insufficient balance");
            userBalances[_user][_token[i]] -=  _amount[i];
        }
    }
}

