// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Invoice } from "../Types/InvoiceType.sol";

/**
 * @title Payment processor interface
 * @notice @notice This interface provides functionality for creating and managing invoices.
 */
interface IPaymentProcessor {
    /**
     * @notice Creates a new invoice with a specified price.
     * @param _invoicePrice The price of the invoice in wei.
     * @return The ID of the newly created invoice.
     */
    function createInvoice(uint256 _invoicePrice) external returns (uint256);

    /**
     * @notice Makes a payment for a specific invoice.
     * @param _invoiceId The ID of the invoice being paid.
     * @return The address of the escrow contract managing the payment.
     */
    function makeInvoicePayment(uint256 _invoiceId) external payable returns (address);

    /**
     * @notice Allows the creator of the invoice to accept or reject it.
     * @param _invoiceId The ID of the invoice.
     * @param _state True to accept the invoice, false to reject.
     */
    function creatorsAction(uint256 _invoiceId, bool _state) external;

    /**
     * @notice Cancels an existing invoice.
     * @dev Only callable by the invoice creator.
     * @param _invoiceId The ID of the invoice to cancel.
     */
    function cancelInvoice(uint256 _invoiceId) external;

    /**
     * @notice Releases the funds held in escrow for a specific invoice to the creator.
     * @param _invoiceId The ID of the invoice for which funds are released.
     */
    function releaseInvoice(uint256 _invoiceId) external;

    /**
     * @notice Sets a custom hold period for a specific invoice.
     * @dev Overrides the default hold period for this invoice.
     * @param _invoiceId The ID of the invoice.
     * @param _holdPeriod The new hold period in seconds.
     */
    function setInvoiceHoldPeriod(uint256 _invoiceId, uint32 _holdPeriod) external;

    /**
     * @notice Updates the address of the fee receiver.
     * @dev Only callable by the contract owner.
     * @param _newFeeReceiver The new address to receive fees.
     */
    function setFeeReceiversAddress(address _newFeeReceiver) external;

    /**
     * @notice Refunds the creator of a specific invoice.
     * @dev This function allows the creator to be refund if the acceptance window has not been exceeded
     *      and the invoice is eligible for a refund. The refund will be processed through the escrow contract.
     * @param _invoiceId The ID of the invoice to be refunded.
     *
     */
    function refundCreatorAfterWindow(uint256 _invoiceId) external;

    /**
     * @notice Updates the default hold period for all new invoices.
     * @dev Only callable by the contract owner.
     * @param _newDefaultHoldPeriod The new default hold period in seconds.
     */
    function setDefaultHoldPeriod(uint256 _newDefaultHoldPeriod) external;

    /**
     * @notice Updates the fee for invoice creation.
     * @dev Only callable by the contract owner.
     * @param _newFee The new fee amount in wei.
     */
    function setFee(uint256 _newFee) external;

    /**
     * @notice Gets the current fee for invoice creation.
     * @return The fee amount in wei.
     */
    function getFee() external view returns (uint256);

    /**
     * @notice Gets the current fee receiver address.
     * @return The address of the fee receiver.
     */
    function getFeeReceiver() external view returns (address);

    /**
     * @notice Gets the current invoice ID counter.
     * @return The current invoice ID.
     */
    function getCurrentInvoiceId() external view returns (uint256);

    /**
     * @notice Gets the default hold period for invoices.
     * @return The default hold period in seconds.
     */
    function getDefaultHoldPeriod() external view returns (uint256);

    /**
     * @notice Retrieves detailed data for a specific invoice.
     * @param _invoiceId The ID of the invoice.
     * @return A struct containing the invoice's details.
     */
    function getInvoiceData(uint256 _invoiceId) external view returns (Invoice memory);

    /**
     * @notice Allows the fee receiver to withdraw the contract's balance.
     * @dev The caller must be either the contract owner or the fee receiver.
     */
    function withdrawFees() external;

    /**
     * @notice Emitted when a new invoice is created.
     * @param creator The address of the invoice creator.
     * @param invoiceId The unique ID of the created invoice.
     * @param createdAt The timestamp when the invoice was created.
     */
    event InvoiceCreated(address indexed creator, uint256 indexed invoiceId, uint256 indexed createdAt);

    /**
     * @notice Emitted when an invoice payment is made.
     * @param creator The address of the invoice creator.
     * @param payer The address of the payer who made the payment.
     * @param amountPayed The amount paid towards the invoice in wei.
     */
    event InvoicePaid(address indexed creator, address indexed payer, uint256 indexed amountPayed);

    /**
     * @notice Emitted when an invoice is rejected by the creator.
     * @param creator The address of the invoice creator.
     * @param payer The address of the payer associated with the invoice.
     * @param invoiceId The unique ID of the rejected invoice.
     */
    event InvoiceRejected(address indexed creator, address indexed payer, uint256 indexed invoiceId);

    /**
     * @notice Emitted when an invoice is accepted by the creator.
     * @param creator The address of the invoice creator.
     * @param payer The address of the payer associated with the invoice.
     * @param invoiceId The unique ID of the accepted invoice.
     */
    event InvoiceAccepted(address indexed creator, address indexed payer, uint256 indexed invoiceId);

    /**
     * @notice Emitted when an invoice is canceled.
     * @param invoiceId The unique ID of the canceled invoice.
     */
    event InvoiceCanceled(uint256 indexed invoiceId);

    /**
     * @notice Emitted when an invoice is released (funds disbursed from escrow).
     * @param invoiceId The unique ID of the released invoice.
     */
    event InvoiceReleased(uint256 indexed invoiceId);
}
