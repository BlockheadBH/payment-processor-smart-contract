// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPaymentProcessor {
    // s file ?
    error InvoicePriceIsTooLow();
    error ExcessivePayment();
    error InvalidInvoiceState();
    error InvoiceIsNoLongerValid();

    // t file ?
    struct Invoice {
        address creator; // 160
        uint48 creationTime; // 48
        uint48 paymentTime; // 48
        uint256 price; // 256
        uint256 amountPayed; // 256
        address payer; // 160
        uint8 status; // 8
        address escrow; // 160
    }

    function createInvoice(uint256 _invoicePrice) external returns (uint256);

    event InvoiceCreated(
        address indexed creator, uint256 indexed invoiceId, uint256 indexed createdAt
    );
    event InvoicePaid(address indexed creator, address indexed payer, uint256 indexed amountPayed);
    event InvoiceRejected(
        address indexed creator, address indexed payer, uint256 indexed invoiceId
    );

    event InvoiceAccepted(
        address indexed creator, address indexed payer, uint256 indexed invoiceId
    );
    event InvoiceCanceled(uint256 indexed invoiceId);
}
