// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./GamePositions.sol";

contract OrderBook {
    uint public orderIdCounter;

    enum OrderType { Buy, Sell }

    struct Order {
        uint id;
        address creator;
        OrderType orderType;
        string optionName;
        uint price; // Price in wei
        uint quantity;
        uint remainingQuantity;
        bool isFilled;
    }

    GamePositions public positions;
    mapping(uint => Order) public orders;
    mapping(address => uint[]) public userOrders;

    event OrderPlaced(uint orderId, address indexed creator, OrderType orderType, string optionName, uint price, uint quantity);
    event OrderFilled(uint orderId, address indexed fulfiller, uint amountFilled, uint remainingQuantity, bool fullyFilled);
    event OrderCancelled(uint orderId, address indexed creator);

    constructor(GamePositions _positions) {
        positions = _positions;
    }

    function placeBuyOrder(string memory optionName, uint quantity) external payable {
        require(msg.value > 0, "Price must be greater than 0");
        uint price = msg.value / quantity;
        uint orderId = _createOrder(OrderType.Buy, optionName, price, quantity);
        emit OrderPlaced(orderId, msg.sender, OrderType.Buy, optionName, price, quantity);
    }

    function placeSellOrder(string memory optionName, uint price, uint quantity) external {
        uint tokenId = positions.getTokenId(optionName);
        require(positions.balanceOf(msg.sender, tokenId) >= quantity, "Insufficient token balance");

        uint orderId = _createOrder(OrderType.Sell, optionName, price, quantity);
        positions.safeTransferFrom(msg.sender, address(this), tokenId, quantity, "");
        emit OrderPlaced(orderId, msg.sender, OrderType.Sell, optionName, price, quantity);
    }

    function fillOrder(uint orderId, uint amountToFill) external payable {
        Order storage order = orders[orderId];
        require(!order.isFilled, "Order is already filled");
        require(amountToFill > 0 && amountToFill <= order.remainingQuantity, "Invalid amount to fill");

        uint totalCost = order.price * amountToFill;

        if (order.orderType == OrderType.Sell) {
            require(msg.value >= totalCost, "Insufficient ETH sent");
            payable(order.creator).transfer(totalCost);
            uint tokenId = positions.getTokenId(order.optionName);
            positions.safeTransferFrom(address(this), msg.sender, tokenId, amountToFill, "");
            
            // Return excess ETH if any
            if (msg.value > totalCost) {
                payable(msg.sender).transfer(msg.value - totalCost);
            }
        } else if (order.orderType == OrderType.Buy) {
            uint tokenId = positions.getTokenId(order.optionName);
            require(positions.balanceOf(msg.sender, tokenId) >= amountToFill, "Insufficient token balance");
            positions.safeTransferFrom(msg.sender, order.creator, tokenId, amountToFill, "");
            payable(msg.sender).transfer(totalCost);
        }

        order.remainingQuantity -= amountToFill;
        bool fullyFilled = order.remainingQuantity == 0;
        if (fullyFilled) {
            order.isFilled = true;
        }

        emit OrderFilled(orderId, msg.sender, amountToFill, order.remainingQuantity, fullyFilled);
    }

    function cancelOrder(uint orderId) external {
        Order storage order = orders[orderId];
        require(order.creator == msg.sender, "Only creator can cancel this order");
        require(!order.isFilled, "Order is already filled");

        if (order.orderType == OrderType.Sell) {
            uint tokenId = positions.getTokenId(order.optionName);
            positions.safeTransferFrom(address(this), order.creator, tokenId, order.remainingQuantity, "");
        } else if (order.orderType == OrderType.Buy) {
            uint refundAmount = order.remainingQuantity * order.price;
            payable(order.creator).transfer(refundAmount);
        }

        order.isFilled = true;
        emit OrderCancelled(orderId, msg.sender);
    }

    function _createOrder(OrderType orderType, string memory optionName, uint price, uint quantity) internal returns (uint) {
        uint orderId = orderIdCounter;
        orders[orderId] = Order({
            id: orderId,
            creator: msg.sender,
            orderType: orderType,
            optionName: optionName,
            price: price,
            quantity: quantity,
            remainingQuantity: quantity,
            isFilled: false
        });

        userOrders[msg.sender].push(orderId);
        orderIdCounter++;
        return orderId;
    }

    function getUserOrders(address user) external view returns (uint[] memory) {
        return userOrders[user];
    }

    function getOrderDetails(uint orderId) external view returns (Order memory) {
        return orders[orderId];
    }
}