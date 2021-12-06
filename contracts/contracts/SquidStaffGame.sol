//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @notice Price oracle interface
 */
interface IOracle {
    function consult(
        address tokenIn,
        uint amountIn,
        address tokenOut
    ) external view returns (uint amountOut);
}

/**
 * @title Biswap GameFi Staff squid game contract
 */
contract SquidStaffGame is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    //price oracle
    IOracle oracle;

    IERC20Upgradeable bswToken;
    IERC20Upgradeable usdtToken;

    struct Game {
        uint earlyWithdrawalFee; //fee take when user withdraw early time is end in base 10000
        uint priceInUSDT; //in USDT
        address[] listRewardTokens; //List reward tokens
        uint[] rewardTokensDistribution; //Distribution of tokens in relation to the first token Base 10000
        bool enabled; //game is enable if true
    }

    struct UserGame {
        uint priceInBSW;
        uint startBlock;
        uint endBlock;
        uint lastRewardBlock;
        mapping(address => uint) rewardPerBlock; // token => reward per block
        mapping(address => uint) rewardDebt; //rewardToken => rewardDebt
    }

    struct UserGameFront {
        uint gameIndex;
        uint priceInBSW;
        uint remainBlocks;
        address[] rewardsTokens;
        uint[] rewards;
    }

    struct ChanceTable {
        uint32 value; //Desired value
        uint64 chance; // Probability
    }

    Game[] public games;

    ChanceTable[] daysChances;
    ChanceTable[] roiChances;

    uint crossingDaysIndex; //Index after which the transition to another crossing Roi Index
    uint crossingRoiIndex; //The index that divides the ROI array into 2 blocks
    uint daysChancesBase; //Divide base of chance days
    uint roiChanceBase; //Divide base of chance roi
    address public treasuryAddress;

    mapping(address => mapping(uint => UserGame)) public userGames; //user => gameIndex => UserGame
    mapping(uint => uint) public activeGames; //Count players in active games: gameIndex => count players

    event AddNewGame(Game game);
    event GameDisable(uint indexed gameIndex);
    event GameStart(address indexed player, uint indexed gameIndex, uint day, uint roi);
    event EarlyWithdraw(address indexed user, uint indexed gameIndex);
    event GameClaimed(address indexed user, uint indexed gameIndex);

    //Initialize function ---------------------------------------------------------------------------------------------

    function initialize(
        address _treasuryAddress,
        IERC20Upgradeable _bswToken,
        IERC20Upgradeable _usdtToken
    ) public initializer {
        require(_treasuryAddress != address(0), "Address cant be zero");
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();
        __Pausable_init();

        //Add days chance table
        daysChances.push(ChanceTable({value: 10, chance: 200}));
        daysChances.push(ChanceTable({value: 12, chance: 200}));
        daysChances.push(ChanceTable({value: 13, chance: 300}));
        daysChances.push(ChanceTable({value: 15, chance: 400}));
        daysChances.push(ChanceTable({value: 18, chance: 500}));
        daysChances.push(ChanceTable({value: 20, chance: 600}));
        daysChances.push(ChanceTable({value: 21, chance: 700}));
        daysChances.push(ChanceTable({value: 22, chance: 800}));
        daysChances.push(ChanceTable({value: 23, chance: 1000}));
        daysChances.push(ChanceTable({value: 25, chance: 1000}));
        daysChances.push(ChanceTable({value: 28, chance: 2000}));
        daysChances.push(ChanceTable({value: 30, chance: 2300}));

        //add roi chance table
        roiChances.push(ChanceTable({value: 20, chance: 2725}));
        roiChances.push(ChanceTable({value: 30, chance: 5000}));
        roiChances.push(ChanceTable({value: 50, chance: 1500}));
        roiChances.push(ChanceTable({value: 100, chance: 500}));
        roiChances.push(ChanceTable({value: 150, chance: 200}));
        roiChances.push(ChanceTable({value: 250, chance: 50}));
        roiChances.push(ChanceTable({value: 500, chance: 25}));

        daysChancesBase = 10000; //Divide base of chance days
        roiChanceBase = 10000; //Divide base of chance roi

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        treasuryAddress = _treasuryAddress;

        bswToken = _bswToken;
        usdtToken = _usdtToken;
    }

    //Modifiers -------------------------------------------------------------------------------------------------------

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    //External function -----------------------------------------------------------------------------------------------

    /**
     * @notice set tokens addresses
     * @dev onlyRole DEFAULT_ADMIN_ROLE
     * @param  _bswToken: price token
     * @param  _usdtToken: usdt token
     */
    function setTokensAddresses(IERC20Upgradeable _bswToken, IERC20Upgradeable _usdtToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_bswToken) != address(0) && address(_usdtToken) != address(0), "Address cant be zero");
        bswToken = _bswToken;
        usdtToken = _usdtToken;
    }

    /**
     * @notice Set treasury address
     * @param  _treasuryAddress: new treasury address
     */
    function setTreasuryAddress(address _treasuryAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasuryAddress != address(0), "Address cant be zero");
        treasuryAddress = _treasuryAddress;
    }

    /**
     * @notice Add new game
     * @dev onlyRole DEFAULT_ADMIN_ROLE
     * @param  _newGame: new game in struct Game
     */
    function addGame(Game calldata _newGame) external onlyRole(DEFAULT_ADMIN_ROLE) {
        games.push(_newGame);
        emit AddNewGame(_newGame);
    }

    /**
     * @notice Disable game
     * @dev game must be enabled. onlyRole DEFAULT_ADMIN_ROLE
     * @param  _gameIndex: index of disabled game
     */
    function disableGame(uint _gameIndex) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_gameIndex < games.length, "Wrong game index");
        require(games[_gameIndex].enabled, "Game already disabled");
        games[_gameIndex].enabled = false;
        emit GameDisable(_gameIndex);
    }

    /**
     * @dev Triggers stopped state.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    //Public function -------------------------------------------------------------------------------------------------

    /**
     * @notice get games info with user data for frontend
     * @param _user: user address. If zero - return only games info
     */
    function getGames(address _user) external view returns(Game[] memory, UserGameFront[] memory){
        Game[] memory _games = new Game[](games.length);
        UserGameFront[] memory _userGamesFront = new UserGameFront[](games.length);
        if(_user != address(0)){
            for(uint i = 0; i < _games.length; i++){
                uint[] memory _rewards = new uint[](games[i].listRewardTokens.length);
                ( , _rewards ) = pendingReward(_user, i);
                _userGamesFront[i] = UserGameFront({
                gameIndex: i,
                priceInBSW: userGames[_user][i].priceInBSW,
                remainBlocks: userGames[_user][i].endBlock > block.number ? userGames[_user][i].endBlock - block.number : 0,
                rewardsTokens: games[i].listRewardTokens,
                rewards: _rewards
                });
            }
        }
        return(_games, _userGamesFront);
    }


    /**
     * @notice Pending Reward by user active games
     * @param _user: user address
     * @param _gameIndex: index game
     * @return _listRewardTokens: Array of reward token addresses
     * @return _rewards: Reward amounts
     */
    function pendingReward(address _user, uint _gameIndex) public view returns (address[] memory, uint[] memory) {
        require(_gameIndex < games.length, "Wrong game index parameter");
        UserGame storage _userGame = userGames[_user][_gameIndex];
        address[] memory _listRewardTokens = games[_gameIndex].listRewardTokens;
        uint[] memory _rewards = new uint[](_listRewardTokens.length);
        for (uint i = 0; i < _listRewardTokens.length; i++) {
            uint multiplier = getMultiplier(_userGame.lastRewardBlock, block.number);
            _rewards[i] = _userGame.rewardPerBlock[_listRewardTokens[i]] * multiplier -
                _userGame.rewardDebt[_listRewardTokens[i]];
        }
        return (_listRewardTokens, _rewards);
    }

    /**
     * @notice Start new game. Only 1 game of each index can be run at same time by each player
     * @dev game must be enabled
     * @param  _gameIndex: index of disabled game
     */
    function startNewGame(uint _gameIndex) public nonReentrant whenNotPaused notContract {
        require(_gameIndex < games.length, "Wrong game index");
        require(games[_gameIndex].enabled, "Game disabled");
        UserGame storage _userGame = userGames[msg.sender][_gameIndex];
        require(_userGame.endBlock == 0, "This game has already been started by this player");

        uint _priceInBSW = _getPriceInBSWToken(games[_gameIndex].priceInUSDT);
        bswToken.safeTransferFrom(msg.sender, address(this), _priceInBSW);

        (uint _days, uint _roi) = _randomGameParameters();
        uint _endBlock = block.number + _days * 28800;
        _userGame.priceInBSW = _priceInBSW;
        _userGame.endBlock = _endBlock;
        _userGame.startBlock = block.number;
        _userGame.lastRewardBlock = block.number;
        uint baseTokenRewardPerBlock = 0;
        address[] memory _listRewardTokens = games[_gameIndex].listRewardTokens; //safe gas
        for (uint i = 0; i < _listRewardTokens.length; i++) {
            if (i == 0) {
                baseTokenRewardPerBlock = ((_priceInBSW * _roi) / 100) / (_days * 28800);
                _userGame.rewardPerBlock[_listRewardTokens[i]] = baseTokenRewardPerBlock;
            } else {
                _userGame.rewardPerBlock[_listRewardTokens[i]] =
                    (baseTokenRewardPerBlock * games[_gameIndex].rewardTokensDistribution[i]) /
                    10000;
            }
        }
        activeGames[_gameIndex] += 1;
        emit GameStart(msg.sender, _gameIndex, _days, _roi);
    }

    /**
     * @notice Withdraw rewards from game before it finished. Take early withdrawal Fee
     * @param _gameIndex: index game
     */
    function earlyWithdrawRewards(uint _gameIndex) public nonReentrant notContract {
        UserGame storage _userGame = userGames[msg.sender][_gameIndex];
        require(_userGame.endBlock > block.number, "Game already finished");
        uint multiplier = getMultiplier(_userGame.lastRewardBlock, block.number);
        require(multiplier > 0, "Wrong multiplier");
        _userGame.lastRewardBlock = block.number;
        uint _fee = games[_gameIndex].earlyWithdrawalFee;
        address[] memory _listRewardTokens = games[_gameIndex].listRewardTokens; //safe gas
        for (uint i = 0; i < _listRewardTokens.length; i++) {
            uint _pending = _userGame.rewardPerBlock[_listRewardTokens[i]] *
                multiplier - _userGame.rewardDebt[_listRewardTokens[i]];
            uint _feeAmount = (_pending * _fee) / 10000;
            _userGame.rewardDebt[_listRewardTokens[i]] = _userGame.rewardPerBlock[_listRewardTokens[i]] * multiplier;
            IERC20Upgradeable(_listRewardTokens[i]).safeTransfer(treasuryAddress, _feeAmount);
            IERC20Upgradeable(_listRewardTokens[i]).safeTransfer(msg.sender, (_pending - _feeAmount));
        }
        emit EarlyWithdraw(msg.sender, _gameIndex);
    }

    /**
     * @notice Claim game (rewards with game price). Call after game finished
     * @param _gameIndex: index game
     */
    function claimGame(uint _gameIndex) public nonReentrant notContract {
        UserGame storage _userGame = userGames[msg.sender][_gameIndex];
        require(_userGame.endBlock <= block.number, "Game not finished. Use earlyWithdrawRewards");
        require(_userGame.lastRewardBlock != 0, "Game was claimed");
        delete _userGame.lastRewardBlock;
        address[] memory _listRewardTokens = games[_gameIndex].listRewardTokens; //safe gas
        uint multiplier = getMultiplier(_userGame.startBlock, _userGame.endBlock);
        delete _userGame.startBlock;
        delete _userGame.endBlock;
        for (uint i = 0; i < _listRewardTokens.length; i++) {
            uint _pending = _userGame.rewardPerBlock[_listRewardTokens[i]] * multiplier -
                _userGame.rewardDebt[_listRewardTokens[i]];
            if (_listRewardTokens[i] == address(bswToken)) {
                _pending += _userGame.priceInBSW;
            }
            IERC20Upgradeable(_listRewardTokens[i]).safeTransfer(msg.sender, _pending);
        }

        activeGames[_gameIndex] -= 1;
        emit GameClaimed(msg.sender, _gameIndex);
    }

    //Internal function -----------------------------------------------------------------------------------------------

    /**
     * @notice get multiplier
     * @param  _from: from block number
     * @param  _to: to block number
     */
    function getMultiplier(uint _from, uint _to) internal pure returns (uint) {
        if (_from < _to) {
            return _to - _from;
        } else {
            return 0;
        }
    }

    /**
     * @notice set tokens addresses
     * @param  _amount: amount to convert to deal token
     */
    function _getPriceInBSWToken(uint _amount) internal view returns (uint) {
        return oracle.consult(address(usdtToken), _amount, address(bswToken));
    }

    /**
     * @dev Returns true if `account` is a contract
     * @param _addr: checked address
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    //Private function ------------------------------------------------------------------------------------------------

    /**
     * @dev Get random and calculate from it days and ROI
     * @return _days for current game
     * @return _roi for current game
     */
    function _randomGameParameters() private view returns (uint _days, uint _roi) {
        ChanceTable[] memory _daysChances = daysChances;
        ChanceTable[] memory _roiChances = roiChances;

        uint _randomForDays = uint(keccak256(abi.encodePacked(blockhash(block.number - 1), gasleft()))) %
            daysChancesBase;
        uint _randomForRoi = uint(keccak256(abi.encodePacked(blockhash(block.number - 1), _randomForDays))) %
            roiChanceBase;

        uint count = 0;
        for (uint i = 0; i < _daysChances.length; i++) {
            count += _daysChances[i].chance;
            if (_randomForDays <= count) {
                _days = _daysChances[i].value;
                count = 0;
                for (uint j = 0; j < _roiChances.length; j++) {
                    count += _roiChances[j].chance;
                    if (_randomForRoi <= count) {
                        _roi = _roiChances[j].value;
                        return (_days, _roi);
                    }
                }
            }
        }
        revert("Cant find random days");
    }
}
