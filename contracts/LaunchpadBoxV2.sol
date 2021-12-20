//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/ISquidBusNFT.sol";
import "./interface/ISquidPlayerNFT.sol";
import "./interface/IOracle.sol";

interface IBiswapNFT {
    function getRbBalance(address user) external view returns (uint);

    function balanceOf(address user) external view returns (uint);
}

interface IMasterChef {
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }

    function userInfo(uint _pid, address _user) external view returns (UserInfo memory);
}

interface IautoBsw {
    struct UserInfo {
        uint shares; // number of shares for a user
        uint lastDepositedTime; // keeps track of deposited time for potential penalty
        uint BswAtLastUserAction; // keeps track of Bsw deposited at the last user action
        uint lastUserActionTime; // keeps track of the last user action time
    }

    function userInfo(address user) external view returns (UserInfo memory);
}

/**
 * @title Squid game NFT Mystery box Launchpad
 * @notice Sell Mystery boxes with NFT`s
 */
contract LaunchpadMysteryBoxV2 is Ownable, Pausable {
    using SafeERC20 for IERC20;

    ISquidPlayerNFT public immutable squidPlayerNFT;
    ISquidBusNFT public immutable squidBusNFT;
    IMasterChef public immutable masterChef;
    IautoBsw public immutable autoBsw;
    IBiswapNFT public immutable biswapNFT;

    address public treasuryAddress;
    IERC20 public immutable dealToken;

    uint public totalBoxAmount = 20000;
    uint public boxPrice = 60 ether;
    uint public maxToUser = 1;
    uint public boxSold;
    uint[] public probability;
    uint public startBlock;

    uint public minStakeAmount = 100 ether;
    uint public minRBAmount = 5 ether;
    uint public minNFTBalance = 1;

    struct UserVerification {
        uint minStakeAmount;
        uint userStakeBalance;
        uint minRBAmount;
        uint userRBBalance;
        uint minNFTBalance;
        uint userNFTBalance;
    }

    struct PlayerNFTEntity {
        uint128 squidEnergy;
        uint8 rarity;
    }

    struct BusNFTEntity {
        uint8 busLevel;
    }

    struct Box {
        PlayerNFTEntity[] playerNFTEntity;
        BusNFTEntity[] busNFTEntity;
    }

    Box[10] boxes;
    mapping(address => uint) public userBoughtCount; //Bought boxes by user: address => count

    event LaunchpadExecuted(address indexed user, uint boxIndex);

    /**
     * @notice Constructor
     * @dev In constructor initialise Boxes
     * @param _squidPlayerNFT: squid player nft contract
     * @param _squidBusNFT: squid bus NFT contract
     * @param _dealToken: deal token contract
     * @param _treasuryAddress: treasury address
     */
    constructor(
        ISquidPlayerNFT _squidPlayerNFT,
        ISquidBusNFT _squidBusNFT,
        IERC20 _dealToken,
        IMasterChef _masterChef,
        IautoBsw _autoBsw,
        IBiswapNFT _biswapNFT,
        uint _startBlock,
        address _treasuryAddress
    ) {
        squidPlayerNFT = _squidPlayerNFT;
        squidBusNFT = _squidBusNFT;
        dealToken = _dealToken;
        masterChef = _masterChef;
        autoBsw = _autoBsw;
        biswapNFT = _biswapNFT;
        treasuryAddress = _treasuryAddress;
        startBlock = _startBlock;

        pause();

        //BOX 1 ----------------------------------------------------------------------------
        boxes[0].busNFTEntity.push(BusNFTEntity({busLevel: 2}));
        boxes[0].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 400 ether, rarity: 1}));

        //BOX 2 ----------------------------------------------------------------------------
        boxes[1].busNFTEntity.push(BusNFTEntity({busLevel: 3}));
        boxes[1].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 700 ether, rarity: 2}));

        //BOX 3 ----------------------------------------------------------------------------
        boxes[2].busNFTEntity.push(BusNFTEntity({busLevel: 3}));
        boxes[2].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 400 ether, rarity: 1}));
        boxes[2].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 400 ether, rarity: 1}));
        boxes[2].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 400 ether, rarity: 1}));
        boxes[2].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 400 ether, rarity: 1}));

        //BOX 4 ----------------------------------------------------------------------------
        boxes[3].busNFTEntity.push(BusNFTEntity({busLevel: 4}));
        boxes[3].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 1000 ether, rarity: 2}));

        //BOX 5 ----------------------------------------------------------------------------
        boxes[4].busNFTEntity.push(BusNFTEntity({busLevel: 3}));
        boxes[4].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 800 ether, rarity: 2}));
        boxes[4].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 800 ether, rarity: 2}));

        //BOX 6 ----------------------------------------------------------------------------
        boxes[5].busNFTEntity.push(BusNFTEntity({busLevel: 2}));
        boxes[5].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 1000 ether, rarity: 2}));
        boxes[5].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 1000 ether, rarity: 2}));
        boxes[5].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 1000 ether, rarity: 2}));

        //BOX 7 ----------------------------------------------------------------------------
        boxes[6].busNFTEntity.push(BusNFTEntity({busLevel: 3}));
        boxes[6].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 1300 ether, rarity: 3}));
        boxes[6].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 1300 ether, rarity: 3}));
        boxes[6].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 1300 ether, rarity: 3}));

        //BOX 8 ----------------------------------------------------------------------------
        boxes[7].busNFTEntity.push(BusNFTEntity({busLevel: 2}));
        boxes[7].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 1700 ether, rarity: 4}));
        boxes[7].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 1700 ether, rarity: 4}));

        //BOX 9 ----------------------------------------------------------------------------
        boxes[8].busNFTEntity.push(BusNFTEntity({busLevel: 4}));
        boxes[8].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 700 ether, rarity: 2}));
        boxes[8].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 700 ether, rarity: 2}));
        boxes[8].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 700 ether, rarity: 2}));
        boxes[8].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 700 ether, rarity: 2}));
        boxes[8].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 700 ether, rarity: 2}));

        //BOX 10 ----------------------------------------------------------------------------
        boxes[9].busNFTEntity.push(BusNFTEntity({busLevel: 5}));
        boxes[9].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 3000 ether, rarity: 5}));
        boxes[9].playerNFTEntity.push(PlayerNFTEntity({squidEnergy: 3000 ether, rarity: 5}));

        probability = [5000, 5000, 4000, 3200, 1200, 1000, 250, 250, 80, 20];

        require(probability.length == boxes.length, "Wrong arrays length");
        uint _base;
        for (uint i = 0; i < probability.length; i++) {
            _base += probability[i];
        }
        require(_base == totalBoxAmount, "Wrong probability");
    }

    /**
     * @notice Checks if the msg.sender is a contract or a proxy
     */
    modifier notContract() {
        require(!_isContract(msg.sender), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    /**
     * @notice Set check parameters
     * @param _minStakeAmount: min stake amount user must have to buy BOX
     * @param _minRBAmount: min RB amount user must have to buy BOX
     * @param _minNFTBalance: Check if user have Robi NFT on balance
     */
    function setValidationParameters(
        uint _minStakeAmount,
        uint _minRBAmount,
        uint _minNFTBalance,
        uint _startBlock
    ) public onlyOwner {
        minStakeAmount = _minStakeAmount;
        minRBAmount = _minRBAmount;
        minNFTBalance = _minNFTBalance;
        startBlock = _startBlock;
    }

    /**
     * @notice Buy Mystery box from launch
     * @dev Callable by user
     */
    function buyBOX() external whenNotPaused notContract {
        require(block.number >= startBlock, "Current block number less than start block");
        require(userBoughtCount[msg.sender] < maxToUser, "Limit by User reached");
        require(boxSold < totalBoxAmount, "Box sold out");
        (bool stakeAmountVerified, bool rbBalanceVerified, bool nftBalanceVerified) = checkUserValidation(msg.sender);
        require(stakeAmountVerified, "Not enough stake balance");
        if (minNFTBalance > 0 && minRBAmount > 0) {
            require(rbBalanceVerified || nftBalanceVerified, "Not enough rb balance or no Robi NFT");
        } else {
            require(rbBalanceVerified && nftBalanceVerified, "Not enough rb balance or no Robi NFT");
        }

        dealToken.safeTransferFrom(msg.sender, treasuryAddress, boxPrice);
        userBoughtCount[msg.sender] += 1;

        uint _index = getRandomBoxIndex();
        boxSold += 1;

        Box memory _box = boxes[_index];

        if (_box.busNFTEntity.length > 0) {
            for (uint i = 0; i < _box.busNFTEntity.length; i++) {
                squidBusNFT.mint(msg.sender, _box.busNFTEntity[i].busLevel);
            }
        }
        if (_box.playerNFTEntity.length > 0) {
            for (uint i = 0; i < _box.playerNFTEntity.length; i++) {
                squidPlayerNFT.mint(
                    msg.sender,
                    _box.playerNFTEntity[i].squidEnergy,
                    0,
                    _box.playerNFTEntity[i].rarity - 1
                );
            }
        }

        emit LaunchpadExecuted(msg.sender, _index);
    }

    function checkUserValidation(address _user)
        internal
        view
        returns (
            bool stakeAmountVerified,
            bool rbBalanceVerified,
            bool nftBalanceVerified
        )
    {
        uint stakedAmount = masterChef.userInfo(0, _user).amount + autoBsw.userInfo(_user).BswAtLastUserAction;
        uint rbBalance = biswapNFT.getRbBalance(_user);
        uint nftBalance = biswapNFT.balanceOf(_user);
        stakeAmountVerified = stakedAmount >= minStakeAmount;
        rbBalanceVerified = rbBalance >= minRBAmount;
        nftBalanceVerified = nftBalance >= minNFTBalance;
    }

    /*
     * @notice Get info
     * @param _user: User address
     */
    function getInfo(address _user)
        public
        view
        returns (
            uint _boxAmount,
            uint _boxPrice,
            uint _maxToUser,
            uint _boxSold,
            uint _userBoughtCount,
            UserVerification memory verif
        )
    {
        _boxAmount = totalBoxAmount;
        _boxPrice = boxPrice;
        _maxToUser = maxToUser;
        _boxSold = boxSold;
        _userBoughtCount = userBoughtCount[_user];

        verif.minNFTBalance = minNFTBalance;
        verif.minRBAmount = minRBAmount;
        verif.minStakeAmount = minStakeAmount;

        verif.userNFTBalance = _user == address(0) ? 0 : biswapNFT.balanceOf(_user);
        verif.userRBBalance = _user == address(0) ? 0 : biswapNFT.getRbBalance(_user);
        verif.userStakeBalance = _user == address(0)
            ? 0
            : masterChef.userInfo(0, _user).amount + autoBsw.userInfo(_user).BswAtLastUserAction;
        return (_boxAmount, _boxPrice, _maxToUser, _boxSold, _userBoughtCount, verif);
    }

    /*
     * @notice Pause a contract
     * @dev Callable by contract owner
     */
    function pause() public onlyOwner {
        _pause();
    }

    /*
     * @notice Unpause a contract
     * @dev Callable by contract owner
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @notice Set treasury address to accumulate deal tokens from sells
     * @dev Callable by contract owner
     * @param _treasuryAddress: Treasury address
     */
    function setTreasuryAddress(address _treasuryAddress) public onlyOwner {
        require(_treasuryAddress != address(0), "Address cant be zero");
        treasuryAddress = _treasuryAddress;
    }

    /**
     * @notice Checks if address is a contract
     * @dev It prevents contract from being targeted
     */
    function _isContract(address addr) internal view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    /**
     * @notice Generate random and find box index
     */
    function getRandomBoxIndex() private returns (uint) {
        uint min = 1;
        uint max = totalBoxAmount - boxSold;
        uint diff = (max - min) + 1;
        uint random = (uint(keccak256(abi.encodePacked(blockhash(block.number - 1), gasleft(), boxSold))) % diff) + min;
        uint count = 0;
        for (uint i = 0; i < probability.length; i++) {
            count += probability[i];
            if (random <= count) {
                probability[i] -= 1;
                return (i);
            }
        }
        revert("Wrong random received");
    }
}
