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

    function lockTokens(uint[] calldata tokenId, uint busyToBlock, uint seDivide) external returns (uint);

    function setGameContract(uint[] calldata tokenId, uint[] calldata contractEndOnBlock) external;

    function squidEnergyDecrease(uint[] calldata tokenId, uint[] calldata deduction) external;

    function squidEnergyIncrease(uint[] calldata tokenId, uint[] calldata addition) external;

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function availableSEAmount(address _user) external view returns(uint amount);
}

interface IOracle {
    function consult(
        address tokenIn,
        uint amountIn,
        address tokenOut
    ) external view returns (uint amountOut);
}

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
        uint32 level; //Desired value
        uint64 chance; // Probability
    }

    struct ChanceTablePlayer {
        uint rarity;
        uint maxValue;
        uint minValue;
        uint chance;
    }

    ChanceTableBus[] public busChance; //value: Bus level
    ChanceTablePlayer[] public playerChance; //Player chance table

    event BusMinted(address user, uint busLevel);
    event PlayerMinted(address user, uint rarity, uint squidEnergy);

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
        busChancesBase = 100;
        busPriceInUSD = _busPriceInUSD;
        playerPriceInUSD = _playerPriceInUSD;

        playerChancesBase = 1000;

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
            _busChancesBase = _newBusChanceTable[i].chance;
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
            _playerChancesBase = _newPlayerChanceTable[i].chance;
            playerChance.push(_newPlayerChanceTable[i]);
        }
        playerChancesBase = _playerChancesBase;
    }

    //Public functions ----------------------------------------------------------------------------------------------

    function buyBus() public notContract nonReentrant whenNotPaused {
        require(busNFT.allowedUserToMintBus(msg.sender), "Mint bus not allowed. Balance over limit");
        uint priceInBSW = _getPriceInBSW(busPriceInUSD);
        bswToken.safeTransferFrom(msg.sender, treasuryAddressBus, priceInBSW);

        uint busLevel = _randomBusLevel();

        busNFT.mint(msg.sender, busLevel);
        emit BusMinted(msg.sender, busLevel);
    }

    function buyPlayer() public notContract nonReentrant whenNotPaused {
        require(busNFT.seatsInBuses(msg.sender) > playerNFT.balanceOf(msg.sender), "No free places in buses");
        uint priceInBSW = _getPriceInBSW(playerPriceInUSD);
        bswToken.safeTransferFrom(msg.sender, treasuryAddressPlayer, priceInBSW);

        (uint rarity, uint squidEnergy) = _getRandomPlayer();
        playerNFT.mint(msg.sender, rarity, 0, squidEnergy);
        emit PlayerMinted(msg.sender, rarity, squidEnergy);
    }

    //Internal functions --------------------------------------------------------------------------------------------

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

    function _getRandomPlayer() private view returns (uint, uint) {
        ChanceTablePlayer[] memory _playerChance = playerChance;
        uint _randomForRarity = _getRandomMinMax(1, playerChancesBase);
        uint count = 0;
        for (uint i = 0; i < _playerChance.length; i++) {
            count += _playerChance[i].chance;
            if (_randomForRarity <= count) {
                uint rarity = _playerChance[i].rarity;
                uint squidEnergy = _getRandomMinMax(_playerChance[i].minValue, _playerChance[i].maxValue);
                return (rarity, squidEnergy);
            }
        }
        revert("Cant find random level");
    }

    function _getRandomMinMax(uint _min, uint _max) private view returns (uint random) {
        uint diff = (_max - _min) + 1;
        random = (uint(keccak256(abi.encodePacked(blockhash(block.number - 1), gasleft()))) % diff) + _min;
    }

    function _randomBusLevel() private view returns (uint) {
        ChanceTableBus[] memory _busChance = busChance;

        uint _randomForLevel = _getRandomMinMax(1, busChancesBase);
        uint count = 0;
        for (uint i = 0; i < _busChance.length; i++) {
            count += _busChance[i].chance;
            if (_randomForLevel <= count) {
                return (_busChance[i].level);
            }
        }
        revert("Cant find random level");
    }
}
