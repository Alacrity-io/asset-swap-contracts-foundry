// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

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

    // enums return a uint so we can cast them to uint to compare
    enum e_OrderState {
        B_REQUESTED,
        B_DEPOSITED,
        B_CONFIRMED,
        S_CONFIRMED,
        S_CANCELLED,
        B_CANCELLED,
        COMPLETED
    }

    mapping(uint256 => uint256) public orderIds;

    event FundsTransferredToBuyer(address indexed to, uint256 indexed amount);
    event FundsTransferredToSeller(address indexed to, uint256 indexed amount);
    event FundsDeposited(address indexed from, uint256 indexed amount, uint256 indexed orderId);
    event OrderCancelled(address indexed by, uint256 indexed orderId);
    event OrderConfirmed(address indexed by, uint256 indexed orderId);
    event OrderCompleted(uint256 indexed orderId);
    event OrderCreated(address indexed by, uint256 indexed orderId);

    function setUp() public {
        orderM = new OrderManager();
    }

    function testListAsset() public returns (uint256) {
        vm.startPrank(seller);
        uint256 orderId = orderM.ListAsset(buyer, price);
        assertEq(orderM.getOrderById(orderId).owner, seller);
        assertEq(orderM.getOrderById(orderId).buyer, buyer);
        assertEq(orderM.getOrderById(orderId).price, price);
        assertEq(uint256(orderM.getOrderById(orderId).orderState), uint256(e_OrderState.B_REQUESTED));
        vm.stopPrank();
        return orderId;
    }

    function testListAssetCustomAddr(address _buyer, address _seller) public returns (uint256) {
        vm.startPrank(_seller);
        uint256 orderId = orderM.ListAsset(_buyer, price);
        assertEq(orderM.getOrderById(orderId).owner, _seller);
        assertEq(orderM.getOrderById(orderId).buyer, _buyer);
        assertEq(orderM.getOrderById(orderId).price, price);
        assertEq(uint256(orderM.getOrderById(orderId).orderState), uint256(e_OrderState.B_REQUESTED));
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
        assertEq(uint256(orderM.getOrderById(orderId).orderState), uint256(e_OrderState.B_DEPOSITED));
        orderM.cancelOrder(orderId);
        // vm.expectEmit(true, true, true, true);
        // emit OrderManager.FundsTransferredToBuyer(buyer, orderM.getOrderById(orderId).price);
        // emit OrderManager.OrderCancelled(buyer, orderId);
        //since the order is deleted the enum value should default to 0
        assertEq(uint256(orderM.getOrderById(orderId).orderState), 0);
        assertEq(buyer.balance, 10 ether);

        assertEq(orderM.getOrderById(orderId).buyer, address(0));
        vm.stopPrank();
    }

    function testCancelOrderSeller() public {
        uint256 orderId = testListAsset();
        vm.startPrank(buyer);
        vm.deal(buyer, 10 ether);
        orderM.deposit{value: price}(orderId);
        vm.stopPrank();
        vm.startPrank(seller);
        orderM.cancelOrder(orderId);
        // vm.expectEmit(true, true, true, true);
        // emit OrderManager.OrderCancelled(seller, orderId);
        assertEq(uint256(orderM.getOrderById(orderId).orderState), 0);

        assertEq(orderM.getOrderById(orderId).seller, address(0));
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

        // assertEq(uint(orderM.getOrderById(orderId).orderState), uint(e_OrderState.B_CONFIRMED));
        vm.stopPrank();
    }

    function testConfirmOrder() public {
        uint256 orderId = testListAsset();
        vm.startPrank(buyer);
        vm.deal(buyer, 10 ether);
        orderM.deposit{value: price}(orderId);
        orderM.confirmOrder(orderId);
        assertEq(uint256(orderM.getOrderById(orderId).orderState), uint256(e_OrderState.B_CONFIRMED));
        vm.stopPrank();
        vm.startPrank(seller);
        orderM.confirmOrder(orderId);
        assertEq(uint256(orderM.getOrderById(orderId).orderState), uint256(e_OrderState.S_CONFIRMED));
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
        assertEq(uint256(orderM.getOrderById(orderId).orderState), uint256(e_OrderState.COMPLETED));
        address nftContractAddress = orderM.s_nftContractAddress();
        VehicleNFT nft = VehicleNFT(nftContractAddress);
        assertEq(buyer, nft.getOwnerOfTokenById(1));
        assertEq(seller.balance, price);
        assertEq(buyer.balance, 10 ether - price);
        vm.stopPrank();
    }

    // write tests to ensure func for multiple assets and orders being managed like 100 or so
    function testMintNFTFor100Orders() public {
        uint256 length = 100;
        for (uint256 index = 0; index < length; index++) {
            address b = address(uint160(uint256(keccak256(abi.encodePacked(index)))));
            address s = address(uint160(uint256(keccak256(abi.encodePacked(index+length)))));

            uint256 orderId = testListAssetCustomAddr(b, s);
            vm.startPrank(b);
            vm.deal(b, 10 ether);
            orderM.deposit{value: price}(orderId);
            orderM.confirmOrder(orderId);
            vm.stopPrank();

            vm.startPrank(s);
            orderM.confirmOrder(orderId);
            emit log_address(orderM.getOrderById(orderId).seller);
            orderM.mintNftToBuyerAndWithdraw(orderId, "testURI");
            assertEq(uint256(orderM.getOrderById(orderId).orderState), uint256(e_OrderState.COMPLETED));
            address nftContractAddress = orderM.s_nftContractAddress();
            VehicleNFT nft = VehicleNFT(nftContractAddress);
            assertEq(b, nft.getOwnerOfTokenById(index + 1));
            assertEq(s.balance, price);
            assertEq(b.balance, 10 ether - price);
            vm.stopPrank();
        }
    }

    function testMintNFTFor100OrdersAsync() public {
        uint256 length = 100;

        for (uint256 index = 0; index < length; index++) {
            address b = address(uint160(uint256(keccak256(abi.encodePacked(index)))));
            address s = address(uint160(uint256(keccak256(abi.encodePacked(index+length)))));

            uint256 orderId = testListAssetCustomAddr(b, s);
            orderIds[index] = orderId;
            vm.startPrank(b);
            vm.deal(b, 10 ether);
            orderM.deposit{value: price}(orderId);
            orderM.confirmOrder(orderId);
            vm.stopPrank();
        }

        for (uint256 index = 0; index < length; index++) {
            address b = address(uint160(uint256(keccak256(abi.encodePacked(index)))));
            address s = address(uint160(uint256(keccak256(abi.encodePacked(index+length)))));
            emit log_uint(b.balance);
            emit log_uint(s.balance);

            uint256 orderId = orderIds[index];
            vm.startPrank(s);
            orderM.confirmOrder(orderId);
            orderM.mintNftToBuyerAndWithdraw(orderId, "testURI");
            assertEq(uint256(orderM.getOrderById(orderId).orderState), uint256(e_OrderState.COMPLETED));
            address nftContractAddress = orderM.s_nftContractAddress();
            VehicleNFT nft = VehicleNFT(nftContractAddress);
            assertEq(b, nft.getOwnerOfTokenById(index + 1));
            assertEq(s.balance, price);
            assertEq(b.balance, 10 ether - price);
            vm.stopPrank();
        }
    }
}
