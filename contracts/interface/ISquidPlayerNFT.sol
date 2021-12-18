// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISquidPlayerNFT {
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

    function getToken(uint _tokenId) external view returns (TokensViewFront memory);

    function mint(
        address to,
        uint128 squidEnergy,
        uint32 contractEndTimestamp,
        uint8 rarity
    ) external;

    function lockTokens(
        uint[] calldata tokenId,
        uint32 busyTo,
        bool willDecrease, //will decrease SE or not
        address user
    ) external returns (uint128);

    function setPlayerContract(uint[] calldata tokenId, uint32 contractEndTimestamp, address user) external;

    function squidEnergyDecrease(uint[] calldata tokenId, uint128[] calldata deduction, address user) external;

    function squidEnergyIncrease(uint[] calldata tokenId, uint128[] calldata addition, address user) external;

    function tokenOfOwnerByIndex(address owner, uint index) external view returns (uint tokenId);

    function arrayUserPlayers(address _user) external view returns (TokensViewFront[] memory);

    function balanceOf(address owner) external view returns (uint balance);

    function ownerOf(uint tokenId) external view returns (address owner);

    function availableSEAmount(address _user) external view returns (uint128 amount);

    function totalSEAmount(address _user) external view returns (uint128 amount);


}
