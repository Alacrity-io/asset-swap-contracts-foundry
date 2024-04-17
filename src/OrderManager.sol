// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {CarNFT} from "./CarNFT.sol";

contract OrderManager {
    // Errors
    error OrderManagerWithdrawFailed();
    error OrderManagerDepositAmtInsufficient();

    address public buyer;
    address public seller;
    uint256 public price;
    address public nftContractAddress;
    address public existingNftContractAddress;

    // Events
    event LogMsgSender(address indexed from);
    event FundsTransferredToBuyer(address indexed to, uint256 indexed amount);
    event FundsTransferredToSeller(address indexed to, uint256 indexed amount);
    event FundsDeposited(address indexed from, uint256 indexed amount);

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer can call this function");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }

    modifier onlyParticipants() {
        require(msg.sender == buyer || msg.sender == seller, "Only buyer or seller can call this function");
        _;
    }

    // Price in wei
    constructor(address _buyer, address _seller, uint256 _price) payable {
        buyer = _buyer;
        seller = _seller;
        price = _price;
    }

    function deposit() external payable onlyBuyer {
        // Buyer deposits funds
        if (msg.value != price) {
            revert OrderManagerDepositAmtInsufficient();
        }
        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdraw() public onlySeller {
        uint256 balance = address(this).balance;
        address payable receiver = payable(seller);
        (bool sent,) = receiver.call{value: balance}("");
        if (!sent) {
            revert OrderManagerWithdrawFailed();
        }
        emit FundsTransferredToSeller(receiver, balance);
    }

    function cancelOrder() external onlyParticipants {
        // If the buyer cancels the order, they can withdraw their funds
        uint256 balance = address(this).balance;
        address payable receiver = payable(buyer);
        (bool sent,) = receiver.call{value: balance}("");
        if (!sent) {
            revert OrderManagerWithdrawFailed();
        }
        emit FundsTransferredToBuyer(receiver, balance);
    }

    // Getters
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

    function getNftAddress() external view returns (address) {
        return nftContractAddress;
    }

    // Setters
    // If the person already possesses an NFT of the asset, they would point to its address via this setter
    function setExistingNftAddress(address _nftContractAddress) external onlySeller {
        existingNftContractAddress = _nftContractAddress;
    }

    // If the person is minting an NFT of the asset for the first time, we'll deploy the contract and then provide it via this setter
    function setNftAddress(address _nftContractAddress) public {
        nftContractAddress = _nftContractAddress;
    }
}
