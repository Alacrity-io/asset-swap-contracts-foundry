// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// CarNFT contract
contract CarNFT is ERC721URIStorage, Ownable {
    uint256 public nextTokenId = 0;
    uint256 public constant MAX_TOKENS = 1;
    uint256 public constant MAX_MINT_PER_TX = 1;
    uint256 public price;
    address public buyer;
    address public seller;

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
        require(msg.sender == buyer, "Only buyer can call this function");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }
    //getters

    function getBuyer() external view returns (address) {
        return buyer;
    }

    function getSeller() external view returns (address) {
        return seller;
    }

    function getPrice() external view returns (uint256) {
        return price;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getNftID() external view returns (uint256) {
        return nextTokenId;
    }

    function mint(address to, string calldata _tokenUri) external onlySeller {
        require(nextTokenId < MAX_TOKENS, "Max tokens reached");
        _safeMint(to, nextTokenId);
        _setTokenURI(nextTokenId, _tokenUri);
        nextTokenId++;
    }

    function withdraw() external onlySeller {
        uint256 balance = address(this).balance;
        require(payable(seller).send(balance), "Withdrawal failed");
    }
}
