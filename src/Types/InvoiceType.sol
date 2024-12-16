// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// lot of address, custom type?
struct Invoice {
    address creator;
    address payer;
    address escrow;
    uint256 price;
    uint256 amountPayed;
    uint32 creationTime;
    uint32 paymentTime;
    uint32 holdPeriod;
    uint32 status;
}
