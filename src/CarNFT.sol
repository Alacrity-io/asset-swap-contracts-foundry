// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NftEvents {
    event LogMsgSender(address indexed from);
    event ContractBalance(uint256 balance);
}

// CarNFT contract
contract CarNFT is ERC721URIStorage, Ownable, NftEvents {
    uint256 public price;
    address public buyer;
    address public seller;
    uint256 public nextTokenId = 0;
    uint256 public constant MAX_TOKENS = 1;
    uint256 public constant MAX_MINT_PER_TX = 1;

    constructor(uint256 setPrice, address _buyer, address _seller, address initialOwner)
        ERC721("CarNFT", "CAR")
        Ownable(initialOwner)
    {
        price = setPrice;
        buyer = _buyer;
        seller = _seller;
        initialOwner = _seller;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only nft buyer can call this function");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only nft seller can call this function");
        _;
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

    //rentrancy guard
    bool private _locked;

    modifier noReentrancy() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    function mint(address to, string calldata _tokenUri) public {
        emit LogMsgSender(msg.sender);
        require(nextTokenId < MAX_TOKENS, "Max tokens reached");
        _safeMint(to, nextTokenId);
        _setTokenURI(nextTokenId, _tokenUri);
        nextTokenId++;
    }

    function ownerOfToken(uint256 tokenId) public view returns (address) {
        require(tokenId < nextTokenId, "Token ID does not exist");
        return ownerOf(tokenId);
    }

    function deposit() external payable {
        // Buyer deposits funds
        require(msg.value == price, "Incorrect deposit amount");
        emit ContractBalance(address(this).balance);
    }

    function withdraw() public noReentrancy {
        uint256 balance = address(this).balance;
        emit LogMsgSender(seller);
        address payable receiver = payable(seller);
        (bool sent,) = receiver.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }
}
