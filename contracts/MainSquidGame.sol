//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface ISquidBusNFT {
    function getToken(uint _tokenId)
        external
        view
        returns (
            uint tokenId,
            address tokenOwner,
            uint level,
            uint createTimestamp,
            string memory uri
        );

    function mint(address to, uint busLevel) external;

    function allowedBusBalance(address user) external view returns (uint);

    function allowedUserToMintBus(address user) external view returns (bool);

    function firstBusTimestamp(address user) external;

    function seatsInBuses(address user) external view returns (uint);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface ISquidPlayerNFT {
    struct TokensViewFront {
        uint tokenId;
        uint rarity;
        address tokenOwner;
        uint squidEnergy;
        uint contractEndOnBlock;
        uint busyToBlock;
        uint createTimestamp;
        string uri;
    }

    function getToken(uint _tokenId) external view returns (TokensViewFront memory);

    function mint(
        address to,
        uint squidEnergy,
        uint contractEndOnBlock,
        uint rarity
    ) external;

    function lockTokens(
        uint[] calldata tokenId,
        uint busyToBlock,
        uint seDivide
    ) external returns (uint);

    function setGameContract(uint[] calldata tokenId, uint[] calldata contractEndOnBlock) external;

    function squidEnergyDecrease(uint[] calldata tokenId, uint[] calldata deduction) external;

    function squidEnergyIncrease(uint[] calldata tokenId, uint[] calldata addition) external;

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function availableSEAmount(address _user) external view returns (uint amount);

    function totalSEAmount(address _user) external view returns (uint amount);
}

interface IOracle {
    function consult(
        address tokenIn,
        uint amountIn,
        address tokenOut
    ) external view returns (uint amountOut);
}

interface IMasterChef {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    function userInfo(uint256 _pid, address _user) external view returns (UserInfo memory);
}

interface IautoBsw {
    struct UserInfo {
        uint256 shares; // number of shares for a user
        uint256 lastDepositedTime; // keeps track of deposited time for potential penalty
        uint256 BswAtLastUserAction; // keeps track of Bsw deposited at the last user action
        uint256 lastUserActionTime; // keeps track of the last user action time
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
        uint reward;
    }

    struct PlayerContract{
        uint duration; //in days
        uint priceInUSD;
        bool enable; //true: enabled; false: disabled
    }

    struct Game {
        uint minSeAmount;
        uint minStakeAmount; //min stake amount (in masterChef and autoBsw) to be available to play game
        uint chanceToWin; //base 10000
        RewardToken[] rewardTokens;
        string name;
        bool enable; //true - enable; false - disable
    }

    struct UserInfo {
        uint busBalance;
        uint allowedBusBalance;
        uint playerBalance;
        uint allowedSeatsInBuses;
        uint availableSEAmount;
        uint totalSEAmount;
        uint stakedAmount;
    }

    uint public decreaseWithdrawalFeeByDay; //150: -1,5% by day
    uint public withdrawalFee; //2700: 27%
    uint public recoveryTime; // 48h = 172800 for lock tokens after game play
    uint public seDivide; //base 10000
    uint public gracePeriod; //30d = 2592000; Period in seconds when SE didnt decrease after game
    bool public enableSeDivide; //enabled decrease SE after each game
    address public treasuryAddress;

    Game[] public games;
    PlayerContract[] playerContracts;
    address[] rewardTokens;
    mapping(address => uint) public withdrawTimeLock; //user address => block.timestamp; To calc withdraw fee
    mapping(address => uint) public firstGameCountdownSE; //user address => block.timestamp Grace period after this - SEDecrease enabled
    mapping(address => mapping(address => uint)) userBalances; //user balances: user address => token address => amount

    event GameAdded(uint gameIndex);
    event GameDisable(uint gameIndex);
    event GameEnable(uint gameIndex);
    event ChangeSEDivideState(bool state, uint seDivide);
    event GamePlay(address indexed user, uint indexed gameIndex, bool userWin);
    event Withdrew(address indexed user);

    //Initialize function --------------------------------------------------------------------------------------------

    function initialize(
        IERC20Upgradeable _usdtToken,
        IERC20Upgradeable _bswToken,
        ISquidBusNFT _busNFT,
        ISquidPlayerNFT _playerNFT,
        IOracle _oracle,
        IMasterChef _masterChef,
        IautoBsw _autoBsw,
        address _treasuryAddress
    ) public initializer {
        require(
            address(_usdtToken) != address(0) &&
                address(_bswToken) != address(0) &&
                address(_busNFT) != address(0) &&
                address(_playerNFT) != address(0) &&
                address(_oracle) != address(0) &&
                address(_masterChef) != address(0) &&
                address(_autoBsw) != address(0),
            "Address cant be zero"
        );
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();

        bswToken = _bswToken;
        usdtToken = _usdtToken;
        busNFT = _busNFT;
        playerNFT = _playerNFT;
        oracle = _oracle;
        masterChef = _masterChef;
        autoBsw = _autoBsw;
        treasuryAddress = _treasuryAddress;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //Modifiers -------------------------------------------------------------------------------------------------------

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    //External functions --------------------------------------------------------------------------------------------

    function addPlayerContract(PlayerContract calldata _playerContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        playerContracts.push(_playerContract);
    }

    function playerContractState(uint _pcIndex) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_pcIndex < playerContracts.length, "");
    }

    function setTreasuryAddress(address _treasuryAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasuryAddress != address(0), "Address cant be zero");
        treasuryAddress = _treasuryAddress;
    }

    function addNewGame(Game calldata _game) external onlyRole(DEFAULT_ADMIN_ROLE) {
        games.push(_game);
        for (uint i = 0; i < _game.rewardTokens.length; i++) {
            if (!_tokenInArray(_game.rewardTokens[i].token)) {
                rewardTokens.push(_game.rewardTokens[i].token);
            }
        }
        emit GameAdded(games.length);
    }

    function disableGame(uint _gameIndex) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_gameIndex < games.length, "Index out of bound");
        games[_gameIndex].enable = false;
        emit GameDisable(_gameIndex);
    }

    function enableGame(uint _gameIndex) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_gameIndex < games.length, "Index out of bound");
        games[_gameIndex].enable = true;
        emit GameEnable(_gameIndex);
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
        withdrawalFee = _withdrawalFee;
        decreaseWithdrawalFeeByDay = _decreaseWithdrawalFeeByDay;
    }

    function setRecoveryBlocks(uint _newRecoveryTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        recoveryTime = _newRecoveryTime;
    }

    function setEnableSeDivide(
        bool _state,
        uint _seDivide,
        uint _gracePeriod
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        enableSeDivide = _state;
        seDivide = _seDivide;
        gracePeriod = _gracePeriod;

        emit ChangeSEDivideState(_state, _seDivide);
    }

    //Public functions ----------------------------------------------------------------------------------------------

    function playGame(uint _gameIndex, uint[] calldata _playersId) public notContract whenNotPaused nonReentrant {
        require(_gameIndex < games.length, "Index out of bound");
        Game memory _game = games[_gameIndex];
        require(_game.enable, "Game is disabled");
        require(_checkBusAndPlayersAmount(msg.sender), "Check bus and players falls");
        require(_checkMinStakeAmount(msg.sender, _gameIndex), "Need more stake in pools");
        if (firstGameCountdownSE[msg.sender] == 0) {
            firstGameCountdownSE[msg.sender] = block.timestamp;
        }
        bool gracePeriodHasPassed = (block.timestamp - firstGameCountdownSE[msg.sender]) >= gracePeriod;
        uint _seDivide = enableSeDivide && gracePeriodHasPassed ? seDivide : 0;
        uint totalSE = playerNFT.lockTokens(_playersId, block.timestamp + recoveryTime, _seDivide);
        require(totalSE >= _game.minSeAmount, "Not enough SE amount");
        bool userWin = _getRandomForWin(_gameIndex);
        if (userWin) {
            if (withdrawTimeLock[msg.sender] == 0) withdrawTimeLock[msg.sender] = block.timestamp;
            for (uint i = 0; i < _game.rewardTokens.length; i++) {
                userBalances[msg.sender][_game.rewardTokens[i].token] += _game.rewardTokens[i].reward;
            }
        }
        emit GamePlay(msg.sender, _gameIndex, userWin);
    }

    function withdrawReward() public notContract whenNotPaused nonReentrant {
        uint calcFee;
        uint multipl = (block.timestamp - withdrawTimeLock[msg.sender]) / 86400;
        calcFee = (multipl * decreaseWithdrawalFeeByDay) >= withdrawalFee
            ? 0
            : withdrawalFee - (multipl * decreaseWithdrawalFeeByDay);

        for (uint i = 0; i < rewardTokens.length; i++) {
            address currentToken = rewardTokens[i];
            uint currentBalance = userBalances[currentToken];
            if (currentBalance > 0) {
                uint fee = (currentBalance * calcFee) / 10000;
                IERC20Upgradeable(currentToken).safeTransfer(treasuryAddress, fee);
                IERC20Upgradeable(currentToken).safeTransfer(msg.sender, currentBalance - fee);
            }
        }
        emit Withdrew(msg.sender);
    }

    function checkUserToPlayGames(address _user) public view returns (bool[] memory, bool) {

        //        conditions[0] = _checkMinStakeAmount(_user);
        conditions[1] = _checkBusAndPlayersAmount(_user);
        return conditions;
    }

    function userInfo(address _user) public view returns (UserInfo memory) {
        UserInfo memory _userInfo;
        _userInfo.busBalance = busNFT.balanceOf(_user);
        _userInfo.allowedBusBalance = busNFT.allowedBusBalance(_user);
        _userInfo.playerBalance = playerNFT.balanceOf(_user);
        _userInfo.allowedSeatsInBuses = busNFT.seatsInBuses(_user);
        _userInfo.availableSEAmount = playerNFT.availableSEAmount(_user);
        _userInfo.totalSEAmount = playerNFT.totalSEAmount(_user);
        _userInfo.stakedAmount = masterChef.userInfo(0, _user).amount + autoBsw.userInfo(_user).shares;
        return (_userInfo);
    }

    function getUserRewardBalances(address _user) public view returns (address[] memory, uint[] memory) {
        uint[] memory balances = new uint[](rewardTokens.length);
        for (uint i = 0; i < balances.length; i++) {
            balances[i] = userBalances[_user][rewardTokens[i]];
        }
        return (rewardTokens, balances);
    }

    //Internal functions --------------------------------------------------------------------------------------------

    function _checkMinStakeAmount(address _user, uint _gameIndex) internal view returns (bool) {
        require(_gameIndex < games.length, "Game index out of bound");
        uint stakeAmount = masterChef.userInfo(0, _user).amount;
        stakeAmount += autoBsw.userInfo(_user).shares;
        return stakeAmount >= games[_gameIndex].minStakeAmount;
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

    function _tokenInArray(address _token) internal view returns (bool) {
        for (uint i = 0; i < rewardTokens.length; i++) {
            if (_token == rewardTokens[i]) return true;
        }
        return false;
    }

    //Private functions --------------------------------------------------------------------------------------------

    function _getRandomForWin(uint _gameIndex) private view returns (bool) {
        uint random = (uint(keccak256(abi.encodePacked(blockhash(block.number - 1), gasleft()))) % 10000) + 1;
        if (random < games[_gameIndex].chanceToWin) {
            return true;
        }
        return false;
    }
}
