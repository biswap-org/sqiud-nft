// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/ISquidPlayerNFT.sol";
import "./interface/IBNFT.sol";

contract NFTClaimer is Ownable, Pausable, ReentrancyGuard {

    uint public playerChancesBase;

    ISquidPlayerNFT public playerNFT;
    IBNFT public vouchers;
    bytes32 salt;
    uint deployBlockNumber;

    struct ChanceTablePlayer {
        uint8 rarity;
        uint128 maxValue;
        uint128 minValue;
        uint32 chance;
    }

    ChanceTablePlayer[] public playerChance; //Player chance table
    mapping(uint => bool) claimedVouchers; //Claimed tokens

    event VoucherExchanged(address user, uint voucherId, uint squidEnergy, uint rarity);

    //Initialize function --------------------------------------------------------------------------------------------

    constructor(ISquidPlayerNFT _playerNFT, IBNFT _vouchers) {

        playerNFT = _playerNFT;
        vouchers = _vouchers;
        deployBlockNumber = block.number;

        playerChancesBase = 1000;

        playerChance.push(ChanceTablePlayer({rarity: 1, maxValue: 500, minValue: 400, chance: 450}));
        playerChance.push(ChanceTablePlayer({rarity: 2, maxValue: 1200, minValue: 600, chance: 370}));
        playerChance.push(ChanceTablePlayer({rarity: 3, maxValue: 1700, minValue: 1300, chance: 120}));
        playerChance.push(ChanceTablePlayer({rarity: 4, maxValue: 2300, minValue: 1800, chance: 50}));
        playerChance.push(ChanceTablePlayer({rarity: 5, maxValue: 3000, minValue: 2400, chance: 10}));
    }

    //Modifiers -------------------------------------------------------------------------------------------------------
    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }
    //External functions --------------------------------------------------------------------------------------------
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function recordSalt() external onlyOwner {
        require(block.number > deployBlockNumber, "too early");
        require(salt == 0, "salt recorded");
        salt = blockhash(deployBlockNumber);
    }

    function setPlayerChanceTable(ChanceTablePlayer[] calldata _newPlayerChanceTable)
        external
        onlyOwner
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

    function userInfo(address _user) public view returns (uint, uint[] memory) {
        uint balance = vouchers.balanceOf(_user);
        uint dis;
        if (balance > 0) {
            for (uint i = 0; i < balance; i++)
                if(claimedVouchers[vouchers.tokenOfOwnerByIndex(_user, i)]) dis++;
        }
        uint[] memory allTokensId = new uint[](dis);
        uint index = dis;
        for(uint i = 0; i < balance; i++){
            if(claimedVouchers[vouchers.tokenOfOwnerByIndex(_user, i)]){
                allTokensId[--index] = vouchers.tokenOfOwnerByIndex(_user, i);
            }

        }
        return (dis, allTokensId);
    }

    function exchangeAllVouchers() public whenNotPaused {
        for (uint i = vouchers.balanceOf(msg.sender); i > 0; i--) {
            if(claimedVouchers[vouchers.tokenOfOwnerByIndex(msg.sender, i-1)]){
                exchangeVoucher(vouchers.tokenOfOwnerByIndex(msg.sender, i-1));
            }
        }
    }

    function exchangeVoucher(uint voucherId) public whenNotPaused notContract {
        require(msg.sender != vouchers.admin(), "Admin cant exchange voucher");
        require(vouchers.ownerOf(voucherId) == msg.sender, "Not owner of token");
        require(claimedVouchers[voucherId], "Token was claimed or not squidNFT");
        vouchers.safeTransferFrom(msg.sender, address(this), voucherId);
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) public nonReentrant whenNotPaused returns (bytes4) {
        require(_operator == address(this), "Only this contract can send token");
        require(address(msg.sender) == address(vouchers), "Token not allowed");
        require(claimedVouchers[_tokenId], "Token was claimed or not squidNFT");
        require(salt != 0, "salt not record");
        bytes32 hash = keccak256(abi.encodePacked(_tokenId, salt));
        claimedVouchers[_tokenId] = false;
        (uint8 rarity, uint128 squidEnergy) = _getRandomPlayer(hash);
        playerNFT.mint(_from, squidEnergy * 1e18, 0, rarity - 1);

        emit VoucherExchanged(_from, _tokenId, squidEnergy * 1e18, rarity - 1);

        return IBNFT.onERC721Received.selector;
    }

    function setVouchersId(uint[] calldata vouchersId) external onlyOwner {
        for(uint i = 0; i < vouchersId.length; i++){
            claimedVouchers[vouchersId[i]] = true;
        }
    }

    //Internal functions --------------------------------------------------------------------------------------------
    function _isContract(address _addr) internal view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
    //Private functions --------------------------------------------------------------------------------------------

    function _getRandomPlayer(bytes32 _hash) private view returns (uint8, uint128) {
        ChanceTablePlayer[] memory _playerChance = playerChance;
        uint _randomForRarity = _getRandomMinMax(1, playerChancesBase, _hash);
        uint count = 0;
        for (uint i = 0; i < _playerChance.length; i++) {
            count += _playerChance[i].chance;
            if (_randomForRarity <= count) {
                uint8 rarity = _playerChance[i].rarity;
                uint128 squidEnergy = uint128(_getRandomMinMax(_playerChance[i].minValue, _playerChance[i].maxValue, _hash));
                return (rarity, squidEnergy);
            }
        }
        revert("Cant find random level");
    }

    function _getRandomMinMax(uint _min, uint _max, bytes32 _hash) private pure returns (uint random) {
        uint diff = (_max - _min) + 1;
        random = (uint(_hash) % diff) + _min;
    }
}
