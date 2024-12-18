// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "solady/auth/Ownable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { IEscrow, EscrowFactory } from "./EscrowFactory.sol";
import { Invoice, IPaymentProcessor } from "./interface/IPaymentProcessor.sol";
import {
    CREATED,
    ACCEPTED,
    REJECTED,
    PAID,
    CANCELLED,
    REFUNDED,
    VALID_PERIOD,
    ACCEPTANCE_WINDOW
} from "./utils/Constants.sol";
import {
    ValueIsTooLow,
    TransferFailed,
    InvoiceNotPaid,
    ExcessivePayment,
    InvoiceAlreadyPaid,
    InvoiceDoesNotExist,
    InvalidInvoiceState,
    FeeValueCanNotBeZero,
    InvoicePriceIsTooLow,
    InvoiceIsNoLongerValid,
    HoldPeriodCanNotBeZero,
    ZeroAddressIsNotAllowed,
    AcceptanceWindowExceeded,
    CreatorCannotPayOwnInvoice,
    InvoiceNotEligibleForRefund,
    HoldPeriodHasNotBeenExceeded,
    HoldPeriodShouldBeGreaterThanDefault
} from "./utils/Errors.sol";

// 1. do left over test ✅
// 2. re-read the docs and cross check the code to confirm if it's in line. There are changes start from 1 again
// 3. Is there an invariant ? Yes. Test it else jump over to 3.
// 4. Run slither and aderyn
// 5. Security checks. Are we following CEI ?
// 6. Recheck events
// 7. Let the auditors know custom types were intentionally ignore so simplicity at this stage

// Existing invoice must have a state
// Ensure the contract has fee

contract PaymentProcessor is Ownable, IPaymentProcessor, EscrowFactory {
    using SafeCastLib for uint256;

    /// @notice The fee amount charged for using this service, denominated in wei.
    uint256 private fee;

    /// @notice The address that receives the fees collected for creating invoices.
    address private feeReceiver;

    /// @notice The current invoice ID counter used to assign unique IDs to newly created invoices.s
    uint256 private currentInvoiceId;

    /// @notice The default hold period for funds in escrow, measured in seconds.
    uint256 private defaultHoldPeriod;

    mapping(uint256 invoiceId => Invoice invoice) private invoiceData;

    constructor(address _receiversAddress, uint256 _fee, uint256 _defaultHoldPeriod) {
        currentInvoiceId = 1;
        _initializeOwner(msg.sender);
        setFee(_fee);
        setDefaultHoldPeriod(_defaultHoldPeriod);
        setFeeReceiversAddress(_receiversAddress);
    }

    /// inheritdoc IPaymentProcessor
    function createInvoice(uint256 _invoicePrice) external returns (uint256) {
        if (_invoicePrice <= fee) {
            revert InvoicePriceIsTooLow();
        }
        uint256 thisInvoiceId = currentInvoiceId;
        Invoice memory invoice = invoiceData[thisInvoiceId];
        invoice.creator = msg.sender;
        invoice.creationTime = (block.timestamp).toUint32();
        invoice.price = _invoicePrice;
        invoice.status = CREATED;
        invoiceData[thisInvoiceId] = invoice;
        emit InvoiceCreated(msg.sender, thisInvoiceId, block.timestamp);
        currentInvoiceId++;
        return thisInvoiceId;
    }

    /// inheritdoc IPaymentProcessor
    function makeInvoicePayment(uint256 _invoiceId) external payable returns (address) {
        Invoice memory invoice = invoiceData[_invoiceId];
        uint256 bhFee = fee;

        if (invoice.creator == msg.sender) revert CreatorCannotPayOwnInvoice();

        if (msg.value > invoice.price) {
            revert ExcessivePayment();
        }
        if (invoice.status != CREATED) {
            revert InvalidInvoiceState();
        }
        if (block.timestamp > invoice.creationTime + VALID_PERIOD) {
            revert InvoiceIsNoLongerValid();
        }

        if (msg.value <= bhFee) {
            revert ValueIsTooLow();
        }

        address escrow = _create(invoice.creator, _invoiceId, msg.value - bhFee);

        invoice.escrow = escrow;
        invoice.payer = msg.sender;
        invoice.status = PAID;
        invoice.paymentTime = (block.timestamp).toUint32();
        invoice.holdPeriod = (defaultHoldPeriod + block.timestamp).toUint32();
        invoiceData[_invoiceId] = invoice;

        emit InvoicePaid(invoice.creator, msg.sender, msg.value);
        return escrow;
    }

    /// inheritdoc IPaymentProcessor
    function creatorsAction(uint256 _invoiceId, bool _state) external {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (block.timestamp > invoice.paymentTime + ACCEPTANCE_WINDOW) revert AcceptanceWindowExceeded();
        if (invoice.creator != msg.sender) {
            revert Unauthorized();
        }
        if (invoice.status != PAID) {
            revert InvoiceNotPaid();
        }
        _state ? _acceptInvoice(_invoiceId, invoice.payer) : _rejectInvoice(_invoiceId, invoice);
    }

    /// inheritdoc IPaymentProcessor
    function cancelInvoice(uint256 _invoiceId) external {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (invoice.creator != msg.sender) {
            revert Unauthorized();
        }
        if (invoice.status == PAID) {
            revert InvoiceAlreadyPaid();
        }
        invoiceData[_invoiceId].status = CANCELLED;
        emit InvoiceCanceled(_invoiceId);
    }

    /// inheritdoc IPaymentProcessor
    function releaseInvoice(uint256 _invoiceId) external {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (invoice.creator != msg.sender) {
            revert Unauthorized();
        }
        if (block.timestamp < invoice.paymentTime + invoice.holdPeriod) {
            revert HoldPeriodHasNotBeenExceeded();
        }
        IEscrow(invoice.escrow).withdrawToCreator(msg.sender);
        emit InvoiceReleased(_invoiceId);
    }

    /// inheritdoc IPaymentProcessor
    function refundCreatorAfterWindow(uint256 _invoiceId) external {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (invoice.status != PAID || block.timestamp < invoice.paymentTime + invoice.holdPeriod) {
            revert InvoiceNotEligibleForRefund();
        }

        IEscrow(invoice.escrow).refundToPayer(invoice.payer);
        invoiceData[_invoiceId].status = REFUNDED;
    }

    /**
     * @notice Marks the specified invoice as accepted.
     * @dev This function updates the status of the invoice to `ACCEPTED` and emits the `InvoiceAccepted` event.
     *      It is expected that the creator is approving the payment for the invoice.
     * @param _invoiceId The ID of the invoice being accepted.
     * @param _payer The address of the payer who accepts the invoice.
     */
    function _acceptInvoice(uint256 _invoiceId, address _payer) internal {
        invoiceData[_invoiceId].status = ACCEPTED;
        emit InvoiceAccepted(msg.sender, _payer, _invoiceId);
    }

    /**
     * @notice Marks the specified invoice as rejected and refunds the payer.
     * @dev This function updates the invoice status to `REJECTED`, refunds the payer via the escrow contract,
     *      and emits the `InvoiceRejected` event.
     * @param _invoiceId The ID of the invoice being rejected.
     * @param invoice The `Invoice` struct containing details of the invoice to be rejected, including the escrow
     * address and payer.
     */
    function _rejectInvoice(uint256 _invoiceId, Invoice memory invoice) internal {
        invoiceData[_invoiceId].status = REJECTED;
        IEscrow(invoice.escrow).refundToPayer(invoice.payer);
        emit InvoiceRejected(msg.sender, invoice.payer, _invoiceId);
    }

    /// inheritdoc IPaymentProcessor
    function setInvoiceHoldPeriod(uint256 _invoiceId, uint32 _holdPeriod) external onlyOwner {
        Invoice memory invoice = invoiceData[_invoiceId];

        if (invoice.status < CREATED) {
            revert InvoiceDoesNotExist();
        }
        if (_holdPeriod < invoice.holdPeriod) {
            revert HoldPeriodShouldBeGreaterThanDefault();
        }
        invoiceData[_invoiceId].holdPeriod = _holdPeriod;
    }

    /// inheritdoc IPaymentProcessor
    function withdrawFees() external {
        if (owner() != msg.sender && msg.sender != feeReceiver) {
            revert Unauthorized();
        }
        uint256 balance = address(this).balance;
        (bool success,) = payable(feeReceiver).call{ value: balance }("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /// inheritdoc IPaymentProcessor
    function setFeeReceiversAddress(address _newFeeReceiver) public onlyOwner {
        if (_newFeeReceiver == address(0)) revert ZeroAddressIsNotAllowed();
        feeReceiver = _newFeeReceiver;
    }

    /// inheritdoc IPaymentProcessor
    function setDefaultHoldPeriod(uint256 _newDefaultHoldPeriod) public onlyOwner {
        if (_newDefaultHoldPeriod == 0) revert HoldPeriodCanNotBeZero();
        defaultHoldPeriod = _newDefaultHoldPeriod;
    }

    /// inheritdoc IPaymentProcessor
    function setFee(uint256 _newFee) public onlyOwner {
        if (_newFee == 0) revert FeeValueCanNotBeZero();
        fee = _newFee;
    }

    /// inheritdoc IPaymentProcessor
    function getFee() external view returns (uint256) {
        return fee;
    }

    /// inheritdoc IPaymentProcessor
    function getFeeReceiver() external view returns (address) {
        return feeReceiver;
    }

    /// inheritdoc IPaymentProcessor
    function getCurrentInvoiceId() external view returns (uint256) {
        return currentInvoiceId;
    }

    /// inheritdoc IPaymentProcessor
    function getDefaultHoldPeriod() external view returns (uint256) {
        return defaultHoldPeriod;
    }

    /// inheritdoc IPaymentProcessor
    function getInvoiceData(uint256 _invoiceId) external view returns (Invoice memory) {
        return invoiceData[_invoiceId];
    }
}
