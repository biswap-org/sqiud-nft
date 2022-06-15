//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interface/ISquidBusNFT.sol";

interface IOracle {
    function consult(
        address tokenIn,
        uint amountIn,
        address tokenOut
    ) external view returns (uint amountOut);
}

interface IautoBsw {
    function balanceOf() external view returns (uint);

    function totalShares() external view returns (uint);

    struct UserInfo {
        uint shares; // number of shares for a user
        uint lastDepositedTime; // keeps track of deposited time for potential penalty
        uint BswAtLastUserAction; // keeps track of Bsw deposited at the last user action
        uint lastUserActionTime; // keeps track of the last user action time
    }

    function userInfo(address user) external view returns (UserInfo memory);
}


contract SquidWorkerGame is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct Worker {
        uint32 startBlock;
        uint32 finishBlock;
        uint32 roi;
        uint128 price;
    }

    struct InfoWorker {
        uint32 startTimestamp;
        uint32 endTimestamp;
        uint price;
        uint32 apr;
        uint32 roi;
        uint pendingReward;
    }

    struct UserInfoFront {
        uint earlyWithdrawalFee;
        uint price;
        uint priceInUSDT;
        uint minStakedAmount;
        uint userStakedAmount;
        uint maxWorkersPerUser;
        uint totalHireWorkers;
        uint totalWorkersLimit;
        uint timeLeft;
        InfoWorker[] userWorkers;
        bool inQueue;
    }

    struct ChanceTable {
        uint32 value; // Desired value
        uint64 chance; // Probability
    }

    struct Queue {
        address caller;
        uint32 blockNumber;
        uint128 price;
    }

    ChanceTable[] public daysChances;
    ChanceTable[] public roiChances;
    Queue[] queue; //Queue of workers

    uint128 price;
    uint minStakeAmount; //min staked amount in BSW
    uint earlyWithdrawalFee; //early withdrawal fee in base 10000
    uint maxWorkersPerUser;
    uint daysChancesBase; //Divide base of chance days
    uint roiChanceBase; //Divide base of chance roi
    address public treasuryAddress;

    IautoBsw public autoBsw;
    IOracle oracle;
    IERC20Upgradeable public bswToken;
    address public constant USDTokenAddress = 0x55d398326f99059fF775485246999027B3197955;


    //User workers: user address => workers[]
    mapping(address => Worker[]) workers;
    mapping(uint => uint) totalHireWorkers; //Total hire workers by week
    mapping(address => bool) public userQueues; //User queues user => gameIndex => inQueue
    mapping(uint => uint) minStakedAmount; //min staked amount in game index
    mapping(address => uint) userIndex; //Index of user queue
    mapping(uint => uint) public weeklyWorkersLimit; //workersLimit of each week

    event PushWorkerToQueue(address indexed user, uint blockNumber);
    event WorkerHired(address indexed user, uint roi, uint term);
    event EarlyWorkerClaimed(address indexed user, uint128 price, uint earlyWithdrawalFee);
    event WorkerClaimed(address indexed user, uint128 price, uint reward);

    //Initialize function ---------------------------------------------------------------------------------------------

    function initialize(
        address _treasuryAddress,
        IERC20Upgradeable _bswToken,
        IautoBsw _autoBsw,
        IOracle _oracle,
        uint128 _price,
        uint _minStakeAmount,
        uint _earlyWithdrawalFee,
        uint _maxWorkersPerUser
    ) public initializer {
        require(
            _treasuryAddress != address(0)
            && address(_bswToken) != address(0)
            && address(_autoBsw) != address(0)
        , "Address cant be zero"
        );
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();
        __Pausable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        treasuryAddress = _treasuryAddress;
        bswToken = _bswToken;
        autoBsw = _autoBsw;
        oracle = _oracle;
        price = _price;
        minStakeAmount = _minStakeAmount;
        earlyWithdrawalFee = _earlyWithdrawalFee;
        maxWorkersPerUser = _maxWorkersPerUser;

        //Add days chance table
        daysChances.push(ChanceTable({value: 10, chance: 500}));
        daysChances.push(ChanceTable({value: 15, chance: 1000}));
        daysChances.push(ChanceTable({value: 20, chance: 1500}));
        daysChances.push(ChanceTable({value: 25, chance: 2000}));
        daysChances.push(ChanceTable({value: 30, chance: 5000}));

        //add roi chance table
        roiChances.push(ChanceTable({value: 15, chance: 5500}));
        roiChances.push(ChanceTable({value: 20, chance: 3000}));
        roiChances.push(ChanceTable({value: 25, chance: 700}));
        roiChances.push(ChanceTable({value: 30, chance: 300}));
        roiChances.push(ChanceTable({value: 50, chance: 150}));
        roiChances.push(ChanceTable({value: 75, chance: 125}));
        roiChances.push(ChanceTable({value: 100, chance: 100}));
        roiChances.push(ChanceTable({value: 150, chance: 75}));
        roiChances.push(ChanceTable({value: 200, chance: 30}));
        roiChances.push(ChanceTable({value: 270, chance: 20}));

        daysChancesBase = 10000; //Divide base of chance days
        roiChanceBase = 10000; //Divide base of chance roi
    }

    //Modifiers -------------------------------------------------------------------------------------------------------

    modifier notContract() {
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        require(msg.sender.code.length == 0, "Contract not allowed");
        _;
    }

    modifier holderPoolCheck(){
        uint autoBswBalance = autoBsw.balanceOf() * autoBsw.userInfo(msg.sender).shares / autoBsw.totalShares();
        require(autoBswBalance >= minStakeAmount, "Need more stake in holder pool");
        _;
    }

    //External function -----------------------------------------------------------------------------------------------

    function setWeeklyWorkersLimit(uint[] calldata _weeks, uint[] calldata _limits) external onlyRole(DEFAULT_ADMIN_ROLE){
        require(_weeks.length == _limits.length, "Wrong array size");
        for(uint i = 0; i < _weeks.length; i++){
            weeklyWorkersLimit[_weeks[i]] = _limits[i];
        }
    }

    function getCurrentWeek() public view returns(uint){
        return block.timestamp/7 days;
    }

    function closeQueueByIndex(uint[] memory _index) external nonReentrant whenNotPaused notContract {
        require(_index.length <= queue.length, "too many elements");
        for(uint i = 0; i < _index.length; i++){
            require(_index[i] < queue.length);
            _closeQueueByIndex(_index[i]);
        }
    }

    function getUserWorkers(address user) external view returns(Worker[] memory){
        return workers[user];
    }

    function getQueue(uint limit) external view returns(Queue[] memory _queue){
        limit = limit > queue.length || limit == 0 ? queue.length : limit;
        _queue = new Queue[](limit);
        for(uint i = 0; i < limit; i++){
            _queue[i] = queue[i];
        }
    }

    function setOracle(IOracle _oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        oracle = _oracle;
    }

    function setGameParams(
        IERC20Upgradeable _bswToken,
        uint128 _price,
        uint _minStakeAmount,
        uint _earlyWithdrawalFee,
        uint _maxWorkersPerUser
    )
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(_bswToken) != address(0), "Address cant be zero");
        bswToken = _bswToken;
        price = _price;
        minStakeAmount = _minStakeAmount;
        earlyWithdrawalFee = _earlyWithdrawalFee;
        maxWorkersPerUser = _maxWorkersPerUser;
    }

    function setTreasuryAddress(address _treasuryAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasuryAddress != address(0), "Address cant be zero");
        treasuryAddress = _treasuryAddress;
    }

    function setAutoBsw(IautoBsw _autoBsw) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(_autoBsw) != address(0), "Address cant be zero");
        autoBsw = _autoBsw;
    }

    function setDaysChances(ChanceTable[] calldata _daysChances) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_daysChances.length > 0, "Length must be greater than zero");
        uint base = 0;
        delete daysChances;
        for (uint i = 0; i < _daysChances.length; i++) {
            bool checkValue = i == 0 ? true : _daysChances[i].value >= _daysChances[i - 1].value;
            require(checkValue, "value must be sorted from min to max");
            daysChances.push(_daysChances[i]);
            base += _daysChances[i].chance;
        }
        daysChancesBase = base;
    }

    function setRoiChances(ChanceTable[] calldata _roiChances) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_roiChances.length > 0, "Length must be greater than zero");
        uint base = 0;
        delete roiChances;
        for (uint i = 0; i < _roiChances.length; i++) {
            bool checkValue = i == 0 ? true : _roiChances[i].value >= _roiChances[i - 1].value;
            require(checkValue, "value must be sorted from min to max");
            roiChances.push(_roiChances[i]);
            base += _roiChances[i].chance;
        }
        roiChanceBase = base;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function getChances() external view returns (ChanceTable[] memory _daysChances, ChanceTable[] memory _roiChances) {
        _daysChances = daysChances;
        _roiChances = roiChances;
    }

    function getQueueSize() external view returns (uint) {
        return queue.length;
    }

    function manuallyCloseQueue(uint limit) external nonReentrant whenNotPaused notContract {
        closeQueue(limit);
    }

    function getUserInfo(address _user) external view returns(UserInfoFront memory info, InfoWorker memory pendingWorker) {
        info.price = price;
        info.priceInUSDT = _getPriceInUSDT(price);
        info.totalWorkersLimit = getAdjustedPeriodLimit();//weeklyWorkersLimit[block.timestamp / 7 days];
        info.totalHireWorkers = totalHireWorkers[block.timestamp / 7 days];
        info.maxWorkersPerUser = maxWorkersPerUser;
        info.timeLeft = getTimeLeftForNewLimit();//7 days - block.timestamp % 7 days;
        info.earlyWithdrawalFee = earlyWithdrawalFee;
        info.minStakedAmount = minStakeAmount;
        info.userStakedAmount =  autoBsw.balanceOf() * autoBsw.userInfo(_user).shares / autoBsw.totalShares();
        info.inQueue = userQueues[_user] ? viewWorkerOnQueue(_user).startBlock >= block.number ? true : false : false;
        info.userWorkers = new InfoWorker[](workers[_user].length);
        uint[] memory _pendingRewards = pendingReward(_user);
        for(uint i = 0; i < workers[_user].length; i++){
            Worker memory currentWorker = workers[_user][i];
            info.userWorkers[i].pendingReward = _pendingRewards[i];
            info.userWorkers[i].price = currentWorker.price;
            info.userWorkers[i].roi = currentWorker.roi;
            info.userWorkers[i].endTimestamp = uint32(block.number > currentWorker.finishBlock ?
                0 : block.timestamp + (currentWorker.finishBlock - block.number) * 3);
            info.userWorkers[i].startTimestamp = uint32(info.userWorkers[i].endTimestamp == 0 ?
                0 : info.userWorkers[i].endTimestamp - (currentWorker.finishBlock - currentWorker.startBlock) * 3);
            info.userWorkers[i].apr = calculateApr(currentWorker.finishBlock, currentWorker.startBlock, currentWorker.roi);
        }
        Worker memory _pendingWorker = viewWorkerOnQueue(_user);
        if(userQueues[_user] && _pendingWorker.startBlock + 255 > block.number){
            pendingWorker.price = _pendingWorker.price;
            pendingWorker.roi = _pendingWorker.roi;
            pendingWorker.pendingReward = 0;
            pendingWorker.endTimestamp = uint32(block.number > _pendingWorker.finishBlock ?
                0 : block.timestamp + (_pendingWorker.finishBlock - block.number) * 3);
            pendingWorker.apr = calculateApr(_pendingWorker.finishBlock, _pendingWorker.startBlock, _pendingWorker.roi);
            pendingWorker.startTimestamp = uint32(pendingWorker.endTimestamp == 0 ?
                0 : pendingWorker.endTimestamp - (_pendingWorker.finishBlock - _pendingWorker.startBlock) * 3);
        }
        return (info, pendingWorker);
    }

    function hireWorker() external nonReentrant notContract whenNotPaused holderPoolCheck {
        if(userQueues[msg.sender]){
            require(selfClaimQueue(), "Cant close previous user Queue. Wait next block");
            closeQueue(1);
        } else {
            closeQueue(2);
        }
        require(workers[msg.sender].length < maxWorkersPerUser, "Workers by user over limit");
        require(totalHireWorkers[block.timestamp / 7 days] < getAdjustedPeriodLimit(), "Workers over limit by current period");
        totalHireWorkers[block.timestamp / 7 days] += 1;
        uint128 currentPrice = price;
        bswToken.safeTransferFrom(msg.sender, address(this), currentPrice);
        userQueues[msg.sender] = true;
        userIndex[msg.sender] = queue.length;
        queue.push(Queue({caller: msg.sender, blockNumber: uint32(block.number), price: currentPrice}));
        emit PushWorkerToQueue(msg.sender, block.number);
    }

    function getAdjustedPeriodLimit() public view returns (uint) {
        uint thisWeekLimit = weeklyWorkersLimit[getCurrentWeek()];
        uint adjustedPeriod = ((block.timestamp % 7 days) / 12 hours) + 1; //1,2,3,4, ...
        return adjustedPeriod > 1 ? thisWeekLimit : adjustedPeriod * thisWeekLimit / 2;
    }

    function getTimeLeftForNewLimit() public view returns(uint){
        uint secondsOfCurrentWeek = block.timestamp % 7 days;
        uint adjustedPeriod = (secondsOfCurrentWeek / 12 hours) + 1; //1,2,3,4, ...
        return adjustedPeriod > 1 ? 7 days - secondsOfCurrentWeek : adjustedPeriod * 12 hours - secondsOfCurrentWeek;
    }

    function claimWorker(uint _index) external nonReentrant notContract whenNotPaused holderPoolCheck {
        require(_index < workers[msg.sender].length, "Index out of bound");
        Worker memory currentWorker = workers[msg.sender][_index];
        require(currentWorker.finishBlock <= block.number, "Worker hasn`t finished his work");
        workers[msg.sender][_index] = workers[msg.sender][workers[msg.sender].length - 1];
        workers[msg.sender].pop();
        closeQueue(2);
        uint reward = currentWorker.price * currentWorker.roi / 100;
        bswToken.safeTransfer(msg.sender, reward + currentWorker.price);
        emit WorkerClaimed(msg.sender, currentWorker.price, reward);
    }

    function earlyClaimWorker(uint _index) external nonReentrant notContract whenNotPaused holderPoolCheck {
        require(_index < workers[msg.sender].length, "Index out of bound");
        Worker memory currentWorker = workers[msg.sender][_index];
        require(currentWorker.finishBlock > block.number, "Worker has finished his work");
        workers[msg.sender][_index] = workers[msg.sender][workers[msg.sender].length - 1];
        workers[msg.sender].pop();
        closeQueue(2);
        uint earlyFee = currentWorker.price * earlyWithdrawalFee / 10000;
        bswToken.safeTransfer(msg.sender, currentWorker.price - earlyFee);
        bswToken.safeTransfer(treasuryAddress, earlyFee);
        emit EarlyWorkerClaimed(msg.sender, currentWorker.price, earlyFee);
    }

    //Public function -------------------------------------------------------------------------------------------------

    function selfClaimQueue() public notContract whenNotPaused returns(bool) {
        if(userQueues[msg.sender]){
            return _closeQueueByIndex(userIndex[msg.sender]);
        }
        return false;
    }

    function pendingReward(address _user) public view returns (uint[] memory _rewards) {
        _rewards = new uint[](workers[_user].length);
        for (uint i = 0; i < _rewards.length; i++) {
            Worker memory currentWorker = workers[_user][i];
            uint multiplier = getMultiplier(currentWorker.startBlock, currentWorker.finishBlock);
            _rewards[i] = (currentWorker.price * currentWorker.roi / 100) /
            (currentWorker.finishBlock - currentWorker.startBlock) * multiplier;
        }
    }

    function viewWorkerOnQueue(address _user) public view returns(Worker memory _worker){
        if(_user == address(0) || !userQueues[_user]) return _worker;

        Queue memory _queue = queue[userIndex[_user]];
        if(_queue.blockNumber >= block.number || _queue.blockNumber + 255 < block.number ) return _worker;
        (uint _days, uint32 _roi) = _randomGameParameters(
            keccak256(abi.encodePacked(_user, blockhash(_queue.blockNumber))));
        _worker.price = _queue.price;
        _worker.startBlock = _queue.blockNumber;
        _worker.finishBlock = uint32(_queue.blockNumber + _days * 28800);
        _worker.roi = _roi;

        return _worker;
    }

    //Internal function -----------------------------------------------------------------------------------------------

    function calculateApr(uint32 finishBlock, uint32 startBlock, uint32 roi) internal pure returns(uint32){
        return 365 * 28800 * roi / (finishBlock - startBlock);
    }

    function getMultiplier(uint _startBlock, uint _finishBlock) internal view returns (uint) {
        if (_startBlock >= block.number || _startBlock == 0 || _finishBlock == 0) {
            return 0;
        } else if (block.number < _finishBlock) {
            return block.number - _startBlock;
        } else {
            return _finishBlock - _startBlock;
        }
    }

    function closeQueue(uint limit) internal {
        uint queueLength = queue.length;
        if (queueLength == 0) return;
        limit = limit == 0 || limit > queueLength ? queueLength : limit;
        uint i = 0;
        while (i < queueLength && limit > 0) {
            if (_closeQueueByIndex(i)) {
                limit--;
                queueLength--;
            } else {
                i++;
            }
        }
    }

    function _getPriceInUSDT(uint _amount) internal view returns (uint) {
        return oracle.consult(address(bswToken), _amount, USDTokenAddress);
    }

    //Private function ------------------------------------------------------------------------------------------------

    function _closeQueueByIndex(uint index) private returns (bool) {
        Queue memory _queue = queue[index];
        if (_queue.blockNumber >= block.number) {
            return false;
        }
        if (block.number > _queue.blockNumber + 255) {
            queue[index].blockNumber = uint32(block.number);
            return false;
        }
        userIndex[queue[queue.length - 1].caller] = index;
        queue[index] = queue[queue.length - 1];
        queue.pop();
        _hireNewWorker(_queue.caller, _queue.blockNumber, _queue.price);
        userQueues[_queue.caller] = false;
        return true;
    }

    function _randomGameParameters(bytes32 _hash) private view returns (uint _days, uint32 _roi) {
        ChanceTable[] memory _daysChances = daysChances;
        ChanceTable[] memory _roiChances = roiChances;

        uint _randomForDays = uint(_hash) % daysChancesBase;
        uint _randomForRoi = uint(keccak256(abi.encode(_randomForDays, _hash))) % roiChanceBase;

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
        revert("Cant find correct random");
    }

    function _hireNewWorker(address _user, uint32 _blockNumber, uint128 _price) private {
        (uint _days, uint32 _roi) = _randomGameParameters(
            keccak256(abi.encodePacked(_user, blockhash(_blockNumber)))
        );
        workers[_user].push(Worker({
            startBlock : _blockNumber,
            finishBlock : uint32(_blockNumber + _days * 28800),
            roi : _roi,
            price : _price
        }));
        emit WorkerHired(_user, _roi, _days);
    }

}
