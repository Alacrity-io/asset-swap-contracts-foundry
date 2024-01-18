// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {OrderManager} from "../src/OrderManager.sol";
import {CarNFT} from "../src/CarNFT.sol";

contract OrderManagerTest is Test {
    OrderManager public orderM;
    //addresses
    address buyer = address(0x0);
    address seller = address(0x1);
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
    function testTransfer() public {
        vm.startPrank(seller);
    }
}
