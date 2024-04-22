// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract VehicleNFT is ERC721URIStorage {
    uint256 private _tokenId;

    address private s_OrderManagerAddress;
    //tokenId to query their creator address
    mapping(uint256 => address) private _creators;

    event TokenMinted(uint256 indexed tokenId, string tokenURI, address s_OrderManagerAddress);

    modifier onlyOrderManager() {
        require(msg.sender == s_OrderManagerAddress, "Only OrderManager can call this function");
        _;
    }

    constructor(address _orderManagerAddress) ERC721("VehicleNFT", "VHL") {
        //this also means that the orderManagerAddress is the owner of the NFT contract
        //we are tightly coupling the NFT contract with the OrderManager contract
        s_OrderManagerAddress = _orderManagerAddress;
    }

    function mintToken(string memory tokenURI) public onlyOrderManager returns (uint256) {
        ++_tokenId;
        uint256 newItemId = _tokenId;
        _mint(msg.sender, newItemId);
        _creators[newItemId] = msg.sender;
        _setTokenURI(newItemId, tokenURI);

        // Give the marketplace approval to transact NFTs between users
        setApprovalForAll(s_OrderManagerAddress, true);

        emit TokenMinted(newItemId, tokenURI, s_OrderManagerAddress);
        return newItemId;
    }

    function getTokensOwnedByMe() public view returns (uint256[] memory) {
        uint256 numberOfExistingTokens = _tokenId;
        uint256 numberOfTokensOwned = balanceOf(msg.sender);
        uint256[] memory ownedTokenIds = new uint256[](numberOfTokensOwned);

        uint256 currentIndex = 0;
        for (uint256 i = 0; i < numberOfExistingTokens; i++) {
            uint256 tokenId = i + 1;
            if (ownerOf(tokenId) != msg.sender) continue;
            ownedTokenIds[currentIndex] = tokenId;
            currentIndex += 1;
        }

        return ownedTokenIds;
    }

    /// @dev Returns the original creator of the token; which will be the OrderManager contract
    /// @param tokenId : uint256 val of tokenID
    /// @return address the original creator of the token; which will be the OrderManager contract
    function getTokenCreatorById(uint256 tokenId) public view returns (address) {
        return _creators[tokenId];
    }

    /// @dev Returns the current OWNER of the token
    /// @param tokenId : uint256 val of tokenID
    /// @return address the address of the current owner of the token
    function getOwnerOfTokenById(uint256 tokenId) public view returns (address) {
        return ownerOf(tokenId);
    }

    function getTokensCreatedByMe() public view returns (uint256[] memory) {
        uint256 numberOfExistingTokens = _tokenId;
        uint256 numberOfTokensCreated = 0;

        for (uint256 i = 0; i < numberOfExistingTokens; i++) {
            uint256 tokenId = i + 1;
            if (_creators[tokenId] != msg.sender) continue;
            numberOfTokensCreated += 1;
        }

        uint256[] memory createdTokenIds = new uint256[](numberOfTokensCreated);
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < numberOfExistingTokens; i++) {
            uint256 tokenId = i + 1;
            if (_creators[tokenId] != msg.sender) continue;
            createdTokenIds[currentIndex] = tokenId;
            currentIndex += 1;
        }

        return createdTokenIds;
    }
}
