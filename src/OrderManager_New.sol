// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CarNFT} from "./CarNFT.sol";

contract OrderManager_New {
    // Errors
    error OrderManagerWithdrawFailed();
    error OrderManagerDepositAmtInsufficient();

    // struct MetaData of the Asset

    //structs
    enum OrderState {
        B_REQUESTED,
        B_DEPOSITED,
        B_CONFIRMED,
        S_CONFIRMED,
        S_CANCELLED,
        B_CANCELLED,
        COMPLETED
    }

    struct Order {
        address owner;
        address buyer;
        address seller;
        uint256 price;
        address nftContractAddress;
        OrderState orderState;
        bool hasDeposited;
    }

    //state_vars
    mapping(uint256 => Order) public s_Orders;
    uint256 public s_orderCount = 0;
    address public s_nftContractAddress;

    // Events
    event LogMsgSender(address indexed from);
    event FundsTransferredToBuyer(address indexed to, uint256 indexed amount);
    event FundsTransferredToSeller(address indexed to, uint256 indexed amount);
    event FundsDeposited(address indexed from, uint256 indexed amount, uint256 indexed orderId);

    // Modifiers
    modifier onlyBuyer(uint256 _orderId, address msgSender) {
        Order memory order = s_Orders[_orderId];
        require(msgSender == order.buyer, "Only buyer can call this function");
        _;
    }

    modifier onlySeller(uint256 _orderId, address msgSender) {
        Order memory order = s_Orders[_orderId];
        require(msgSender == order.buyer, "Only seller can call this function");
        _;
    }

    modifier onlyParticipants(uint256 _orderId, address msgSender) {
        Order memory order = s_Orders[_orderId];
        require(msgSender == order.buyer || msgSender == order.seller, "Only buyer or seller can call this function");
        _;
    }

    // Functions
    // we can set the nftContractAddress for the assets in the constructor
    constructor(address nftContractAddress) {
        s_nftContractAddress = nftContractAddress;
    }

    // External

    /// @notice func to create a listed of an advertised asset
    /// @dev    the owner of the asset is the seller of the asset
    /// @param _buyer : the buyer of the asset; _price: the price of the asset; msg.sender is the seller  and the owner of the asset; s_nftContractAddress is the address of the nft contract which would have been set in the constructor
    /// @return uin256 orderID: the unique identifier of the order
    function ListAsset(address _buyer, uint256 _price) external returns (uint256) {
        Order memory newOrder = Order(msg.sender, _buyer, msg.sender, _price, s_nftContractAddress, OrderState.B_REQUESTED, false);
        s_Orders[++s_orderCount] = newOrder;
        return s_orderCount;
    }

    // installment support
    function deposit(uint256 _orderId) external payable onlyBuyer(_orderId, msg.sender) {
        Order storage order = s_Orders[_orderId];
        if (msg.value != order.price) {
            revert OrderManagerDepositAmtInsufficient();
        }
        order.orderState = OrderState.B_DEPOSITED;
        order.hasDeposited = true;
        emit FundsDeposited(msg.sender, msg.value, _orderId);
    }

    function withdraw(uint256 _orderId) external onlySeller(_orderId, msg.sender) {
        Order storage order = s_Orders[_orderId];

        //if this func is called after deposition of funds
        require(order.hasDeposited == true, "Funds have not been deposited in the contract just yet!");

        uint256 balance = order.price;
        address payable receiver = payable(order.seller);
        (bool sent,) = receiver.call{value: balance}("");
        if (!sent) {
            revert OrderManagerWithdrawFailed();
        }
        order.orderState = OrderState.S_CONFIRMED;
        emit FundsTransferredToSeller(receiver, balance);
    }

    /// @notice cancelOrder: order could be cancelled by either buyer or seller
    /// @dev if a buyer cancels then : their funds are returned and order is cancelled and order is deleted from the mapping; if a seller cancels then : if there are funds;then they are retureed; if not the order state is just cancelled; and if canelled it can't be modifed again
    /// @param _orderId: the unique identifier of the order
    function cancelOrder(uint256 _orderId) external onlyParticipants(_orderId, msg.sender) {
        Order storage order = s_Orders[_orderId];

        //if this func is called after deposition of funds
        require(order.hasDeposited == true, "Funds have not been deposited in the contract just yet!");

        // If the buyer cancels the order, they can withdraw their funds
        uint256 balance = order.price;
        address payable receiver = payable(order.buyer);
        (bool sent,) = receiver.call{value: balance}("");
        if (!sent) {
            revert OrderManagerWithdrawFailed();
        }
        if (msg.sender == order.seller) {
            order.orderState = OrderState.S_CANCELLED;
        }
        order.orderState = OrderState.B_CANCELLED;
        //delete the order from the mapping
        delete s_Orders[_orderId];
        emit FundsTransferredToBuyer(receiver, balance);
    }

    /// @notice confirmOrder: order could be confirmed by either buyer or seller
    /// @dev modifer onlyParticipants: only buyer or seller can call this function
    /// @param _orderId: the unique identifier of the order
    function confirmOrder(uint256 _orderId) external onlyParticipants(_orderId, msg.sender) {
        Order storage order = s_Orders[_orderId];
        require(order.hasDeposited == true, "Funds have not been deposited in the contract just yet!");
        if (msg.sender == order.buyer) {
            order.orderState = OrderState.B_CONFIRMED;
        } else {
            order.orderState = OrderState.S_CONFIRMED;
        }
    }

}
