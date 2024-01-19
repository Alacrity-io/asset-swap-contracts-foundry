// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CarNFT} from "./CarNFT.sol";
// OrderManager contract

contract OrderManager {
    address public buyer;
    address public seller;
    uint256 public price;
    address public nftContractAddress;
    address public existingNftContractAddress;

    //events
    event LogMsgSender(address indexed from);

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer can call this function");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }

    //price in wei
    constructor(address _buyer, address _seller, uint256 _price) payable {
        buyer = _buyer;
        seller = _seller;
        price = _price;
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

    //if the person already possess an NFT of the asset they would point to its address via this setter
    function setExistingNftAddress(address _nftContractAddress) external onlySeller {
        existingNftContractAddress = _nftContractAddress;
    }

    function getNftAddress() external view returns (address) {
        return nftContractAddress;
    }

    // if the person is minting an NFT of the asset for the first time, we'll deploy the contract and then provide it via this setter
    function setNftAddress(address _nftContractAddress) public {
        nftContractAddress = _nftContractAddress;
    }

    function deposit() external payable onlyBuyer {
        // Buyer deposits funds
        require(msg.value == price, "Incorrect deposit amount");
    }

    function transfer() public onlySeller {
        CarNFT carNFT;
        emit LogMsgSender(msg.sender);

        if (existingNftContractAddress != address(0)) {
            // If an existing NFT contract exists, use it
            carNFT = CarNFT(existingNftContractAddress);
        } else {
            //nft deployed sc address would already be set before this func is called
            carNFT = CarNFT(nftContractAddress);
            // Mint the NFT to the buyer for a new contract
            carNFT.mint(buyer, "testing uri", msg.sender);
        }

        setNftAddress(address(carNFT));
        // Call the deposit function in the NFT contract
        carNFT.deposit{value: address(this).balance}(msg.sender);

        // Withdraw funds from the NFT contract to the seller
        carNFT.withdraw(msg.sender);

        if (existingNftContractAddress != address(0)) {
            // Transfer ownership of the NFT to the buyer only if a new contract was deployed
            carNFT.transferFrom(address(this), buyer, carNFT.nextTokenId() - 1);
        }
    }
}
