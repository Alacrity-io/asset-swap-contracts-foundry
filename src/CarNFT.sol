// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/// SO FUCking INSECURE!~!!!!!!!

contract NftEvents {
    event LogMsgSender(address indexed from);
    event ContractBalance(uint256 balance);
}

// CarNFT contract
contract CarNFT is ERC721URIStorage, NftEvents {
    uint256 public price;
    address public buyer;
    address public owner;
    address public seller;
    uint256 public nextTokenId = 0;
    uint256 public constant MAX_TOKENS = 1;
    uint256 public constant MAX_MINT_PER_TX = 1;

    constructor(uint256 setPrice, address _buyer, address _seller) ERC721("CarNFT", "CAR") {
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
        owner = _newOwner;
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

    //rentrancy guard
    bool private _locked;

    modifier noReentrancy() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    function mint(address to, string memory _tokenUri) public noReentrancy onlyOwner {
        emit LogMsgSender(seller);
        emit LogMsgSender(tx.origin);
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

    // function deposit() external payable noReentrancy onlyOwner {
    //     // Buyer deposits funds
    //     emit ContractBalance(msg.value);
    //     require(msg.value == price, "Incorrect deposit amount");
    //     emit ContractBalance(address(this).balance);
    // }

    // function withdraw() public noReentrancy onlyOwner {
    //     uint256 balance = address(this).balance;
    //     emit LogMsgSender(seller);
    //     emit LogMsgSender(tx.origin);
    //     address payable receiver = payable(seller);
    //     (bool sent,) = receiver.call{value: balance}("");
    //     require(sent, "Failed to send Ether");
    // }

    function transferNFT(address from, address to, uint256 tokenId) external onlyOwner {
        // from will be equal to msg.sender which will be the owner
        require(ownerOf(tokenId) == from, "Not the owner of the NFT");

        // Perform the transfer
        safeTransferFrom(from, to, tokenId);
    }
}

// caller is the sc addr of Order manager
//
