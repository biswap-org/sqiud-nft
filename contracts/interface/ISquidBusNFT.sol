// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISquidBusNFT {
    function getToken(uint _tokenId)
    external
    view
    returns (
        uint tokenId,
        address tokenOwner,
        uint8 level,
        uint32 createTimestamp,
        string memory uri
    );

    function mint(address to, uint8 busLevel) external;

    function secToNextBus(address _user) external view returns(uint);

    function allowedBusBalance(address user) external view returns (uint);

    function allowedUserToMintBus(address user) external view returns (bool);

    function firstBusTimestamp(address user) external;

    function seatsInBuses(address user) external view returns (uint);

    function tokenOfOwnerByIndex(address owner, uint index) external view returns (uint tokenId);

    function balanceOf(address owner) external view returns (uint balance);

    function ownerOf(uint tokenId) external view returns (address owner);

    event Initialize(string baseURI);
    event TokenMint(address indexed to, uint indexed tokenId, uint8 level);

}
