// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NftEvents {
    event LogMsgSender(address indexed from);
    event ContractBalance(uint256 balance);
}


// CarNFT contract
contract CarNFT is ERC721URIStorage, NftEvents {
    uint256 private price;
    address private buyer;
    address private owner;
    address private seller;
    uint256 public nextTokenId = 0;
    uint256 public constant MAX_TOKENS = 1;
    uint256 public constant MAX_MINT_PER_TX = 1;

    constructor(uint256 setPrice, address _buyer, address _seller) ERC721("CarNFT", "CAR") {
        require(_buyer != address(0), "Buyer address cannot be zero");
        require(_seller != address(0), "Seller address cannot be zero");
        price = setPrice;
        buyer = _buyer;
        seller = _seller;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only nft owner can call this function");
        _;
    }

    function resetOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner address cannot be zero");
        owner = _newOwner;
    }

    //rentrancy guard
    bool private _locked;

    modifier noReentrancy() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    function mint(address to, string memory _tokenUri) public noReentrancy onlyOwner {
        require(to != address(0), "Recipient address cannot be zero");
        require(nextTokenId < MAX_TOKENS, "Max tokens reached");
        _safeMint(to, nextTokenId);
        _setTokenURI(nextTokenId, _tokenUri);
        nextTokenId++;
    }

    function ownerOfToken(uint256 tokenId) public view returns (address) {
        require(tokenId < nextTokenId, "Token ID does not exist");
        return ownerOf(tokenId);
    }

    function transferNFT(address from, address to, uint256 tokenId) external onlyOwner noReentrancy {
        require(from != address(0), "From address cannot be zero");
        require(to != address(0), "To address cannot be zero");
        require(ownerOf(tokenId) == from, "Not the owner of the NFT");

        // Perform the transfer
        safeTransferFrom(from, to, tokenId);
    }

    //getters

    function getBuyer() public view returns (address) {
        return buyer;
    }

    function getSeller() public view returns (address) {
        return seller;
    }

    function getPrice() public view returns (uint256) {
        return price;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getNftID() public view returns (uint256) {
        return nextTokenId;
    }

    function getOwner() public view returns (address) {
        return owner;
    }
}
