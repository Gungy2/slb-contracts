// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IOrderBook} from "./interfaces/IOrderBook.sol";
import {SLB_Bond} from "./SLB_Bond.sol";

/// @title Order Book Solidity
/// @author sondotpin [Son Pin]
/// @notice Original source: https://github.com/sondotpin/orderbook
/// @dev Source code has been modified accordingly to be usable with SLBs
contract OrderBook is IOrderBook, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for SLB_Bond;

    SLB_Bond public slbToken;
    IERC20 public baseToken;

    mapping(uint256 => mapping(uint8 => Order)) public buyOrdersInStep;
    mapping(uint256 => Step) public buySteps;
    mapping(uint256 => uint8) public buyOrdersInStepCounter;
    uint256 public maxBuyPrice;

    mapping(uint256 => mapping(uint8 => Order)) public sellOrdersInStep;
    mapping(uint256 => Step) public sellSteps;
    mapping(uint256 => uint8) public sellOrdersInStepCounter;
    uint256 public minSellPrice;

    /**
     * @notice Constructor
     */
    constructor(address _slbToken, address _baseToken) {
        slbToken = SLB_Bond(_slbToken);
        baseToken = IERC20(_baseToken);
    }

    /**
     * @notice Place buy order.
     */
    function placeBuyOrder(
        uint256 price,
        uint256 amountOfSlbToken
    ) external override nonReentrant {
        baseToken.safeTransferFrom(
            msg.sender,
            address(this),
            price * amountOfSlbToken
        );
        emit PlaceBuyOrder(msg.sender, price, amountOfSlbToken);

        /**
         * @notice if has order in sell book, and price >= min sell price
         */
        uint256 sellPricePointer = minSellPrice;
        uint256 amountReflect = amountOfSlbToken;
        if (minSellPrice > 0 && price >= minSellPrice) {
            while (
                amountReflect > 0 &&
                sellPricePointer <= price &&
                sellPricePointer != 0
            ) {
                uint8 i = 1;
                uint256 higherPrice = sellSteps[sellPricePointer].higherPrice;
                while (
                    i <= sellOrdersInStepCounter[sellPricePointer] &&
                    amountReflect > 0
                ) {
                    if (
                        amountReflect >=
                        sellOrdersInStep[sellPricePointer][i].amount
                    ) {
                        //if the last order has been matched, delete the step
                        if (i == sellOrdersInStepCounter[sellPricePointer]) {
                            if (higherPrice > 0)
                                sellSteps[higherPrice].lowerPrice = 0;
                            delete sellSteps[sellPricePointer];
                            minSellPrice = higherPrice;
                        }

                        Order memory order = sellOrdersInStep[sellPricePointer][
                            i
                        ];

                        amountReflect -= order.amount;

                        // settle trade
                        slbToken.safeTransfer(msg.sender, order.amount);
                        baseToken.safeTransfer(
                            order.maker,
                            order.amount * sellPricePointer
                        );

                        // delete order from storage
                        delete sellOrdersInStep[sellPricePointer][i];
                        sellOrdersInStepCounter[sellPricePointer] -= 1;
                    } else {
                        Order memory order = sellOrdersInStep[sellPricePointer][
                            i
                        ];

                        sellSteps[sellPricePointer].amount -= amountReflect;
                        sellOrdersInStep[sellPricePointer][i]
                            .amount -= amountReflect;
                        amountReflect = 0;

                        // settle trade
                        slbToken.safeTransfer(msg.sender, order.amount);
                        baseToken.safeTransfer(
                            order.maker,
                            order.amount * sellPricePointer
                        );
                    }
                    i += 1;
                }
                sellPricePointer = higherPrice;
            }
        }
        /**
         * @notice draw to buy book the rest
         */
        if (amountReflect > 0) {
            _drawToBuyBook(price, amountReflect);
        }
    }

    /**
     * @notice Place buy order.
     */
    function placeSellOrder(
        uint256 price,
        uint256 amountOfSlbToken
    ) external override nonReentrant {
        slbToken.safeTransferFrom(msg.sender, address(this), amountOfSlbToken);
        emit PlaceSellOrder(msg.sender, price, amountOfSlbToken);

        /**
         * @notice if has order in buy book, and price <= max buy price
         */
        uint256 buyPricePointer = maxBuyPrice;
        uint256 amountReflect = amountOfSlbToken;
        if (maxBuyPrice > 0 && price <= maxBuyPrice) {
            while (
                amountReflect > 0 &&
                buyPricePointer >= price &&
                buyPricePointer != 0
            ) {
                uint8 i = 1;
                uint256 lowerPrice = buySteps[buyPricePointer].lowerPrice;
                while (
                    i <= buyOrdersInStepCounter[buyPricePointer] &&
                    amountReflect > 0
                ) {
                    if (
                        amountReflect >=
                        buyOrdersInStep[buyPricePointer][i].amount
                    ) {
                        //if the last order has been matched, delete the step
                        if (i == buyOrdersInStepCounter[buyPricePointer]) {
                            if (lowerPrice > 0)
                                buySteps[lowerPrice].higherPrice = 0;
                            delete buySteps[buyPricePointer];
                            maxBuyPrice = lowerPrice;
                        }

                        Order memory order = buyOrdersInStep[buyPricePointer][
                            i
                        ];

                        amountReflect -= order.amount;

                        // settle trade
                        slbToken.safeTransfer(order.maker, order.amount);
                        baseToken.safeTransfer(
                            msg.sender,
                            order.amount * buyPricePointer
                        );

                        // delete order from storage
                        delete buyOrdersInStep[buyPricePointer][i];
                        buyOrdersInStepCounter[buyPricePointer] -= 1;
                    } else {
                        Order memory order = buyOrdersInStep[buyPricePointer][
                            i
                        ];

                        buySteps[buyPricePointer].amount -= amountReflect;
                        buyOrdersInStep[buyPricePointer][i]
                            .amount -= amountReflect;
                        amountReflect = 0;

                        // settle trade
                        slbToken.safeTransfer(order.maker, order.amount);
                        baseToken.safeTransfer(
                            msg.sender,
                            order.amount * buyPricePointer
                        );
                    }
                    i += 1;
                }
                buyPricePointer = lowerPrice;
            }
        }
        /**
         * @notice draw to buy book the rest
         */
        if (amountReflect > 0) {
            _drawToSellBook(price, amountReflect);
        }
    }

    /**
     * @notice draw buy order.
     */
    function _drawToBuyBook(uint256 price, uint256 amount) internal {
        require(price > 0, "Can not place order with price equal 0");

        buyOrdersInStepCounter[price] += 1;
        buyOrdersInStep[price][buyOrdersInStepCounter[price]] = Order(
            msg.sender,
            amount
        );
        buySteps[price].amount += amount;
        emit DrawToBuyBook(msg.sender, price, amount);

        if (maxBuyPrice == 0) {
            maxBuyPrice = price;
            return;
        }

        if (price > maxBuyPrice) {
            buySteps[maxBuyPrice].higherPrice = price;
            buySteps[price].lowerPrice = maxBuyPrice;
            maxBuyPrice = price;
            return;
        }

        if (price == maxBuyPrice) {
            return;
        }

        uint256 buyPricePointer = maxBuyPrice;
        while (price <= buyPricePointer) {
            buyPricePointer = buySteps[buyPricePointer].lowerPrice;
        }

        if (price < buySteps[buyPricePointer].higherPrice) {
            buySteps[price].higherPrice = buySteps[buyPricePointer].higherPrice;
            buySteps[price].lowerPrice = buyPricePointer;

            buySteps[buySteps[buyPricePointer].higherPrice].lowerPrice = price;
            buySteps[buyPricePointer].higherPrice = price;
        }
    }

    /**
     * @notice draw sell order.
     */
    function _drawToSellBook(uint256 price, uint256 amount) internal {
        require(price > 0, "Can not place order with price equal 0");

        sellOrdersInStepCounter[price] += 1;
        sellOrdersInStep[price][sellOrdersInStepCounter[price]] = Order(
            msg.sender,
            amount
        );
        sellSteps[price].amount += amount;
        emit DrawToSellBook(msg.sender, price, amount);

        if (minSellPrice == 0) {
            minSellPrice = price;
            return;
        }

        if (price < minSellPrice) {
            sellSteps[minSellPrice].lowerPrice = price;
            sellSteps[price].higherPrice = minSellPrice;
            minSellPrice = price;
            return;
        }

        if (price == minSellPrice) {
            return;
        }

        uint256 sellPricePointer = minSellPrice;
        while (
            price >= sellPricePointer &&
            sellSteps[sellPricePointer].higherPrice != 0
        ) {
            sellPricePointer = sellSteps[sellPricePointer].higherPrice;
        }

        if (sellPricePointer < price) {
            sellSteps[price].lowerPrice = sellPricePointer;
            sellSteps[sellPricePointer].higherPrice = price;
        }

        if (
            sellPricePointer > price &&
            price > sellSteps[sellPricePointer].lowerPrice
        ) {
            sellSteps[price].lowerPrice = sellSteps[sellPricePointer]
                .lowerPrice;
            sellSteps[price].higherPrice = sellPricePointer;

            sellSteps[sellSteps[sellPricePointer].lowerPrice]
                .higherPrice = price;
            sellSteps[sellPricePointer].lowerPrice = price;
        }
    }
}
