//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/ISquidBusNFT.sol";
import "./interface/ISquidPlayerNFT.sol";
import "./interface/IOracle.sol";


/**
 * @title Squid game NFT Mystery box Launchpad
 * @notice Sell Mystery boxes with NFT`s
 */
contract LaunchpadNftMysteryBoxes is Ownable, Pausable {
    using SafeERC20 for IERC20;

    ISquidPlayerNFT squidPlayerNFT;
    ISquidBusNFT squidBusNFT;

    address public treasuryAddress;
    IERC20 public immutable dealToken;

    uint public immutable probabilityBase;

    uint boxAmount = 10000;
    uint boxPrice = 60 ether;
    uint maxToUser = 1;
    uint boxSold;
    uint[] probability;

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
        address _treasuryAddress
    ) {
        squidPlayerNFT = _squidPlayerNFT;
        squidBusNFT = _squidBusNFT;
        dealToken = _dealToken;
        treasuryAddress = _treasuryAddress;

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



    probability = [2500, 2500, 2000, 1600, 600, 500, 125, 125, 40, 10];

        require(probability.length == boxes.length, "Wrong arrays length");
        uint _base;
        for (uint i = 0; i < probability.length; i++) {
            _base += probability[i];
        }
        probabilityBase = _base;
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
     * @notice Buy Mystery box from launch
     * @dev Callable by user
     */
    function buyBOX() external whenNotPaused notContract {
        require(userBoughtCount[msg.sender] < maxToUser, "Limit by User reached");
        require(boxSold < boxAmount, "Box sold out");

        dealToken.safeTransferFrom(msg.sender, treasuryAddress, boxPrice);
        userBoughtCount[msg.sender] += 1;
        boxSold += 1;

        uint _index = getRandomBoxIndex();

        Box memory _box = boxes[_index];

        if (_box.busNFTEntity.length > 0) {
            for (uint i = 0; i < _box.busNFTEntity.length; i++) {
                squidBusNFT.mint(msg.sender, _box.busNFTEntity[i].busLevel);
            }
        }
        if (_box.playerNFTEntity.length > 0) {
            for (uint i = 0; i < _box.playerNFTEntity.length; i++) {
                squidPlayerNFT.mint(msg.sender, _box.playerNFTEntity[i].squidEnergy, 0, _box.playerNFTEntity[i].rarity - 1);
            }
        }

        emit LaunchpadExecuted(msg.sender, _index);
    }

    /*
     * @notice Get info
     * @param user: User address
     */
    function getInfo(address user) public view
    returns
    (
        uint _boxAmount,
        uint _boxPrice,
        uint _maxToUser,
        uint _boxSold,
        uint _userBoughtCount
    ) {
        _boxAmount = boxAmount;
        _boxPrice = boxPrice;
        _maxToUser = maxToUser;
        _boxSold = boxSold;
        _userBoughtCount = userBoughtCount[user];
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
    function getRandomBoxIndex() private view returns (uint) {
        uint min = 1;
        uint max = probabilityBase;
        uint diff = (max - min) + 1;
        uint random = (uint(keccak256(abi.encodePacked(blockhash(block.number - 1), gasleft(), boxSold))) % diff) + min;
        uint count = 0;
        for (uint i = 0; i < probability.length; i++) {
            count += probability[i];
            if (random <= count) {
                return (i);
            }
        }
        revert("Wrong random received");
    }
}
