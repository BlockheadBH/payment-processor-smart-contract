// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPaymentProcessor {
    function createInvoice(uint256 _invoicePrice) external;
}
