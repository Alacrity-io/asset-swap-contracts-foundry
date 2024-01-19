// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {OrderManager} from "../src/OrderManager.sol";
import {CarNFT} from "../src/CarNFT.sol";
import {NftEvents} from "../src/CarNFT.sol";

contract OrderManagerTest is Test, NftEvents {
    OrderManager public orderM;
    //addresses
    address buyer = (0xA6466D12A42B4496CD8ce61343aF392A8d7Bd871);
    address seller = (0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
    address newBuyer = (0xaC8683f64D9C6D1ECF9b849aE677DD3315835cb2);
    uint256 price = 0.2 * 1e18;

    function setUp() public {
        orderM = new OrderManager(buyer, seller, price);
    }

    function testConstructor() public {
        assertEq(orderM.getBuyer(), buyer);
        assertEq(orderM.getSeller(), seller);
        assertEq(orderM.getPrice(), price);
        emit log_named_uint("the contracts' balance is ", price);
    }

    function testDeposit() public {
        // Assuming startPrank, deal, and stopPrank functions work as expected
        vm.startPrank(buyer);
        vm.deal(buyer, 10 ether);

        // Ensure the buyer has the expected balance
        uint256 buyerBalanceBefore = address(buyer).balance;
        assertEq(buyerBalanceBefore, 10 ether);

        // Deposit into OrderManager contract
        orderM.deposit{value: 0.2 ether}();

        // Ensure the balance of the OrderManager contract is updated
        uint256 contractBalance = orderM.getBalance();
        emit log_named_uint("Contract's balance is", contractBalance);
        assertEq(price, contractBalance);

        // Ensure the buyer's balance has been reduced by the deposited amount
        uint256 buyerBalanceAfter = address(buyer).balance;
        emit log_named_uint("Buyer's balance after deposit is", buyerBalanceAfter);
        assertEq(buyerBalanceBefore - price, buyerBalanceAfter);

        vm.stopPrank();
    }

    /*
    1- new nft minted
        nft mint, and testing if the balance from the sc goes to the seller
        and the buyer has recevied the nft in their accnt

    2- already existing nft minted
        safetrasnfer the ownesrhip of nft with tokenID 0 to the buyer from the seller 
        AND THE money is properly transferred to the seller
    */

    function deposit(OrderManager order, address prankAddr) internal {
        vm.startPrank(prankAddr);
        vm.deal(prankAddr, 0.2 ether);
        order.deposit{value: 0.2 ether}();
        vm.stopPrank();
    }

    function simulateTransfer() internal returns (CarNFT) {
        deposit(orderM, buyer);
        vm.startPrank(seller);
        CarNFT nft = new CarNFT(price, buyer, seller);
        //the owner is the seller
        nft.mint(buyer, "sending it to buyer");
        nft.resetOwner(buyer);
        orderM.withdraw();
        vm.stopPrank();
        return nft;
    }

    function testNewTransfer() public {
        deposit(orderM, buyer);
        uint256 contractBalance = address(orderM).balance;
        vm.startPrank(seller);
        CarNFT nft = new CarNFT(price, buyer, seller);
        //the owner is the seller
        nft.mint(buyer, "sending it to buyer");
        nft.resetOwner(buyer);
        orderM.withdraw();
        vm.stopPrank();
        assertEq(address(seller).balance, contractBalance);
        assertEq(buyer, nft.ownerOfToken(0));
    }

    function testOldTransfer() public {
        //nft transferred to buyer
        CarNFT existingNft = simulateTransfer();
        vm.startPrank(buyer);
        OrderManager newOrder = new OrderManager(newBuyer, buyer, price);
        //now transferring nft to newbuyer
        vm.stopPrank();
        deposit(newOrder, newBuyer);
        vm.startPrank(buyer);
        uint256 contractBalance = address(newOrder).balance;
        existingNft.transferNFT(buyer, newBuyer, 0);
        existingNft.resetOwner(newBuyer);
        newOrder.withdraw();
        assertEq(address(buyer).balance, contractBalance);
        assertEq(newBuyer, existingNft.ownerOfToken(0));
        vm.stopPrank();
    }
}
