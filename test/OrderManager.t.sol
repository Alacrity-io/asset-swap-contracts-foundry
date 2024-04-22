// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {OrderManager} from "../src/OrderManager.sol";
import {VehicleNFT} from "../src/VehicleNFT.sol";

contract OrderManagerTest is Test {
    OrderManager public orderM;
    //addresses
    address buyer = (0xA6466D12A42B4496CD8ce61343aF392A8d7Bd871);
    address seller = (0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
    address newBuyer = (0xaC8683f64D9C6D1ECF9b849aE677DD3315835cb2);
    uint256 price = 0.2 * 1e18;

    function setUp() public {
        orderM = new OrderManager();
    }

    function testListAsset() public returns (uint256) {
        vm.startPrank(seller);
        uint256 orderId = orderM.ListAsset(buyer, price);
        assertEq(orderM.getOrderById(orderId).owner, seller);
        assertEq(orderM.getOrderById(orderId).buyer, buyer);
        assertEq(orderM.getOrderById(orderId).price, price);
        // assertEq(orderM.getOrderById(orderId).orderState, orderM.OrderState.B_REQUESTED);
        vm.stopPrank();
        return orderId;
    }

    function testDeposit() public {
        // Deposit into OrderManager contract
        uint256 orderId = testListAsset();

        vm.startPrank(buyer);
        vm.deal(buyer, 10 ether);
        // Ensure the buyer has the expected balance
        uint256 buyerBalanceBefore = address(buyer).balance;
        assertEq(buyerBalanceBefore, 10 ether);
        orderM.deposit{value: price}(orderId);

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

    function testDepositFailWhenAnyoneExceptBuyerCallsIt() public {
        uint256 orderId = testListAsset();
        vm.startPrank(seller);
        vm.expectRevert();
        orderM.deposit{value: price}(orderId);
    }

    function testCancelOrderBuyer() public {
        uint256 orderId = testListAsset();
        vm.startPrank(buyer);
        vm.deal(buyer, 10 ether);
        orderM.deposit{value: price}(orderId);
        orderM.cancelOrder(orderId);
        assertEq(buyer.balance, 10 ether);

        // assertEq(orderM.getOrderById(orderId).orderState, orderM.OrderState.B_CANCELLED);
        assertEq(orderM.getOrderById(orderId).buyer, address(0));
        vm.stopPrank();
    }

    function testConfirmOrderSellerPreMatureConfirmation() public {
        uint256 orderId = testListAsset();
        vm.startPrank(buyer);
        vm.deal(buyer, 10 ether);
        orderM.deposit{value: price}(orderId);
        vm.stopPrank();
        vm.startPrank(seller);
        vm.expectRevert();
        orderM.confirmOrder(orderId);
        // assertEq(orderM.getOrderById(orderId).orderState, orderM.OrderState.B_CONFIRMED);
        vm.stopPrank();
    }

    function testConfirmOrder() public {
        uint256 orderId = testListAsset();
        vm.startPrank(buyer);
        vm.deal(buyer, 10 ether);
        orderM.deposit{value: price}(orderId);
        orderM.confirmOrder(orderId);
        vm.stopPrank();
        vm.startPrank(seller);
        orderM.confirmOrder(orderId);
        // assertEq(orderM.getOrderById(orderId).orderState, orderM.OrderState.B_CONFIRMED);
        vm.stopPrank();
    }

    // transfering ownership of the NFT to the buyer
    function testMintNftToBuyerAndWithdraw() public {
        uint256 orderId = testListAsset();
        vm.startPrank(buyer);
        vm.deal(buyer, 10 ether);
        orderM.deposit{value: price}(orderId);
        orderM.confirmOrder(orderId);
        vm.stopPrank();

        vm.startPrank(seller);
        orderM.confirmOrder(orderId);
        emit log_address(orderM.getOrderById(orderId).seller);
        orderM.mintNftToBuyerAndWithdraw(orderId, "testURI");
        // assertEq(orderM.getOrderById(orderId).orderState, orderM.OrderState.S_CONFIRMED);
        address nftContractAddress = orderM.s_nftContractAddress();
        VehicleNFT nft = VehicleNFT(nftContractAddress);
        assertEq(buyer, nft.getOwnerOfTokenById(1));
        assertEq(seller.balance,  price);
        vm.stopPrank();
    }
}
