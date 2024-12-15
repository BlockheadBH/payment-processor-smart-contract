// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPaymentProcessor {
    // s file ?
    error InvoicePriceIsTooLow();
    error ExcessivePayment();
    error InvalidInvoiceState();
    error InvoiceIsNoLongerValid();
    error InvoiceNotPaid();
    error InvoiceDoesNotExist();
    error HoldPeriodShouldBeGreaterThanDefault();
    error HoldPeriodHasNotBeenExceeded();
    error InvoiceAlreadyPaid();

    // t file ?
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
    event InvoiceReleased(uint256 indexed invoiceId);
}
