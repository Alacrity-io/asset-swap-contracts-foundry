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

    // if the person is minting an NFT of the asset for the first time, we'll deploy the contract and then provide it via this setter
    function setNftAddress(address _nftContractAddress) public onlySeller {
        nftContractAddress = _nftContractAddress;
    }

    function deposit() external payable onlyBuyer {
        // Buyer deposits funds
        require(msg.value == price, "Incorrect deposit amount");
    }


    function transfer() external onlySeller {
        CarNFT carNFT;

        if (existingNftContractAddress != address(0)) {
            // If an existing NFT contract exists, use it
            carNFT = CarNFT(existingNftContractAddress);
        } else {
            // Deploy a new instance of CarNFT if no existing contract
            carNFT = new CarNFT(price, buyer, seller, buyer);

            // Mint the NFT to the buyer for a new contract
            carNFT.mint(buyer, "testing uri");
        }

        setNftAddress(address(carNFT));
        // Call the deposit function in the NFT contract
        (bool depositSuccess,) = address(carNFT).call{value: price}("");
        require(depositSuccess, "NFT deposit failed");

        // Withdraw funds from the NFT contract to the seller
        carNFT.withdraw();

        if (existingNftContractAddress == address(0)) {
            // Transfer ownership of the NFT to the buyer only if a new contract was deployed
            carNFT.transferFrom(address(this), buyer, carNFT.nextTokenId() - 1);
        }
    }
}
