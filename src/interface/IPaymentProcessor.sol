// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Invoice } from "../Types/InvoiceType.sol";

interface IPaymentProcessor {
    function createInvoice(uint256 _invoicePrice) external returns (uint256);
    function creatorsAction(uint256 _invoiceId, bool _state) external;
    function makeInvoicePayment(uint256 _invoiceId) external payable returns (address);
    function cancelInvoice(uint256 _invoiceId) external;
    function releaseInvoice(uint256 _invoiceId) external;
    function setHoldPeriod(uint256 _invoiceId, uint32 _holdPeriod) external;
    function setFeeReceiversAddress(address _newFeeReceiver) external;
    function setDefaultHoldPeriod(uint256 _newDefaultHoldPeriod) external;
    function setFee(uint256 _newFee) external;
    function getFee() external view returns (uint256);
    function getFeeReceiver() external view returns (address);
    function getCurrentInvoiceId() external view returns (uint256);
    function getDefaultHoldPeriod() external view returns (uint256);
    function getInvoiceData(uint256 _invoiceId) external view returns (Invoice memory);

    event InvoiceCreated(address indexed creator, uint256 indexed invoiceId, uint256 indexed createdAt);
    event InvoicePaid(address indexed creator, address indexed payer, uint256 indexed amountPayed);
    event InvoiceRejected(address indexed creator, address indexed payer, uint256 indexed invoiceId);

    event InvoiceAccepted(address indexed creator, address indexed payer, uint256 indexed invoiceId);
    event InvoiceCanceled(uint256 indexed invoiceId);
    event InvoiceReleased(uint256 indexed invoiceId);
}
