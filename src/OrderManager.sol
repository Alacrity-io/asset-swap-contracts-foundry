// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VehicleNFT} from "./VehicleNFT.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract OrderManager is ReentrancyGuard {
    //----------------------------------ERRORS----------------------------------------------
    error OrderManagerWithdrawFailed();
    error OrderManagerDepositAmtInsufficient();

    //----------------------------------STATE VARS----------------------------------------------
    enum e_OrderState {
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
        uint256 tokenId;
        e_OrderState orderState;
        bool hasDeposited;
    }

    mapping(uint256 => Order) public m_Orders;
    uint256 public s_orderCount = 0;
    address public s_nftContractAddress;

    //----------------------------------EVENTS----------------------------------------------
    event LogMsgSender(address indexed from);
    event FundsTransferredToBuyer(address indexed to, uint256 indexed amount);
    event FundsTransferredToSeller(address indexed to, uint256 indexed amount);
    event FundsDeposited(address indexed from, uint256 indexed amount, uint256 indexed orderId);

    //----------------------------------MODIFIERS----------------------------------------------
    modifier onlyBuyer(uint256 _orderId, address msgSender) {
        require(msgSender == m_Orders[_orderId].buyer, "Only buyer can call this function");
        _;
    }

    modifier onlySeller(uint256 _orderId, address msgSender) {
        require(msgSender == m_Orders[_orderId].seller, "Only seller can call this function");
        _;
    }

    modifier onlyParticipants(uint256 _orderId, address msgSender) {
        Order memory order = m_Orders[_orderId];
        require(msgSender == order.buyer || msgSender == order.seller, "Only buyer or seller can call this function");
        _;
    }

    /// @dev constructor sets the address of the NFT contract
    constructor() {
        VehicleNFT vNft = new VehicleNFT(address(this));
        s_nftContractAddress = address(vNft);
    }

    //----------------------------------EXTERNAL FUNCTIONS----------------------------------------------

    /// @notice func to create a listed of an advertised asset
    /// @dev    the owner of the asset is the seller of the asset
    /// @param _buyer : the buyer of the asset; _price: the price of the asset; msg.sender is the seller 
    /// and the owner of the asset; s_nftContractAddress is the address of the nft contract which would have been set in the constructor
    /// @return uin256 orderID: the unique identifier of the order
    function ListAsset(address _buyer, uint256 _price) external returns (uint256) {
        m_Orders[++s_orderCount] =
            Order(msg.sender, _buyer, msg.sender, _price, s_nftContractAddress, 0, e_OrderState.B_REQUESTED, false);
        return s_orderCount;
    }

    // TODO: installment support
    /// @notice func for the buyer to deposit the funds for the asset
    /// @dev changes the state of the order to B_DEPOSITED
    /// @param _orderId : the orderID of the asset; msg.value is the amount deposited by the buyer
    function deposit(uint256 _orderId) external payable onlyBuyer(_orderId, msg.sender) {
        Order storage order = m_Orders[_orderId];
        if (msg.value != order.price) {
            revert OrderManagerDepositAmtInsufficient();
        }
        order.orderState = e_OrderState.B_DEPOSITED;
        order.hasDeposited = true;
        emit FundsDeposited(msg.sender, msg.value, _orderId);
    }

    /// @notice cancelOrder: order could be cancelled by either buyer or seller
    /// @dev if a buyer cancels then : their funds are returned and order is cancelled and order is deleted from the mapping; 
    /// if a seller cancels then : if there are funds;then they are retureed; if not the order state is just cancelled;
    /// and if canelled it can't be modifed again
    /// @dev re-entry guard is used to prevent re-entrancy such as participants cancelling the order in 
    /// the middle of exuction of the function and draining the contract's funds
    /// @param _orderId: the unique identifier of the order
    function cancelOrder(uint256 _orderId) external onlyParticipants(_orderId, msg.sender) nonReentrant {
        Order storage order = m_Orders[_orderId];

        //if this func is called after deposition of funds
        require(order.hasDeposited == true, "Funds have not been deposited in the contract just yet!");

        // If the buyer cancels the order, they can withdraw their funds
        uint256 balance = order.price;
        if (msg.sender == order.buyer) {
            address payable receiver = payable(order.buyer);
            (bool sent,) = receiver.call{value: balance}("");
            if (!sent) {
                revert OrderManagerWithdrawFailed();
            }
            order.orderState = e_OrderState.B_CANCELLED;

            //delete the order from the mapping
            delete m_Orders[_orderId];

            emit FundsTransferredToBuyer(msg.sender, balance);
            //Early return if buyer cancels
            return;
        }
        order.orderState = e_OrderState.S_CANCELLED;
        // TODO: we could penalize the Seller for cancelling the order

        //delete the order from the mapping
        delete m_Orders[_orderId];
        emit FundsTransferredToSeller(msg.sender, balance);
    }

    /// @notice confirmOrder: order could be confirmed by either buyer or seller
    /// @dev modifer onlyParticipants: only buyer or seller can call this function
    /// @param _orderId: the unique identifier of the order
    function confirmOrder(uint256 _orderId) external onlyParticipants(_orderId, msg.sender) {
        Order storage order = m_Orders[_orderId];
        require(order.hasDeposited == true, "Funds have not been deposited in the contract just yet!");
        if (msg.sender == order.buyer) {
            order.orderState = e_OrderState.B_CONFIRMED;
        } else {
            if (order.orderState != e_OrderState.B_CONFIRMED) {
                revert("Buyer has not confirmed the order yet!");
            }
            order.orderState = e_OrderState.S_CONFIRMED;
        }
    }

    /// @notice minftNftToBuyerAndWithdraw: mint the NFT to the buyer and withdraw the funds to the seller
    /// @dev Does two things: 1. mints the NFT to the buyer, 2. transfers the funds to the seller
    /// @param _orderId: the unique identifier of the order
    /// @param _tokenUri: FileCoin tokenURI of the NFT
    // TODO : check if the nft already exists; in that case no need to mint a new one ; just transfer the ownership
    function mintNftToBuyerAndWithdraw(uint256 _orderId, string memory _tokenUri)
        external
        onlySeller(_orderId, msg.sender)
        nonReentrant
    {
        require(
            m_Orders[_orderId].orderState == e_OrderState.S_CONFIRMED, "Order has not been confirmed by the buyer yet!"
        );
        Order storage order = m_Orders[_orderId];
        VehicleNFT nft = VehicleNFT(order.nftContractAddress);
        //minting nft token
        uint256 tokenId = nft.mintToken(_tokenUri);
        order.tokenId = tokenId;

        //trasnsferring ownership to buyer
        // during minting we have given the orderManager contract the approval to transfer the NFTs
        nft.transferFrom(address(this), order.buyer, tokenId);

        //withdraw the funds to the seller
        withdrawFundsToSellerAddress(_orderId);
    }

    //----------------------------------INTERNAL FUNCTIONS----------------------------------------------

    /// @notice  withdraw: the seller can withdraw the funds after the buyer has confirmed the order
    /// @dev will be called internally after the order has been confirmed by both the parties
    /// @param _orderId: the unique identifier of the order
    function withdrawFundsToSellerAddress(uint256 _orderId) internal {
        Order storage order = m_Orders[_orderId];

        //if this func is called after deposition of funds
        require(order.hasDeposited == true, "Funds have not been deposited in the contract just yet!");

        uint256 balance = order.price;
        order.orderState = e_OrderState.COMPLETED;
        address payable receiver = payable(order.seller);
        (bool sent,) = receiver.call{value: balance}("");
        if (!sent) {
            revert OrderManagerWithdrawFailed();
        }
        emit FundsTransferredToSeller(receiver, balance);
    }

    // getters
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getBuyer(uint256 _orderId) external view returns (address) {
        return m_Orders[_orderId].buyer;
    }

    function getSeller(uint256 _orderId) external view returns (address) {
        return m_Orders[_orderId].seller;
    }

    function getPrice(uint256 _orderId) external view returns (uint256) {
        return m_Orders[_orderId].price;
    }

    function getOrderById(uint256 _orderId) external view returns (Order memory) {
        return m_Orders[_orderId];
    }

    function getNftTokenByOrderId(uint256 _orderId) external view returns (uint256) {
        Order storage order = m_Orders[_orderId];
        return order.tokenId;
    }
}
