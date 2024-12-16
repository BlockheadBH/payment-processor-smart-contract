// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "solady/auth/Ownable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { IEscrow, EscrowFactory } from "./EscrowFactory.sol";
import { Invoice, IPaymentProcessor } from "./interface/IPaymentProcessor.sol";
import { CREATED, ACCEPTED, REJECTED, PAID, CANCELLED, VALID_PERIOD } from "./utils/Constants.sol";
import {
    InvoiceNotPaid,
    ExcessivePayment,
    InvoiceAlreadyPaid,
    InvoiceDoesNotExist,
    InvalidInvoiceState,
    InvoicePriceIsTooLow,
    InvoiceIsNoLongerValid,
    HoldPeriodHasNotBeenExceeded,
    HoldPeriodShouldBeGreaterThanDefault
} from "./utils/Errors.sol";

contract PaymentProcessor is Ownable, IPaymentProcessor, EscrowFactory {
    using SafeCastLib for uint256;

    uint256 private fee;
    address private feeReceiver;
    uint256 private currentInvoiceId;
    uint256 private defaultHoldPeriod;

    mapping(uint256 invoiceId => Invoice invoice) private invoiceData;

    constructor(address _receiversAddress, uint256 _fee, uint256 _defaultHoldPeriod) {
        currentInvoiceId = 1;
        _initializeOwner(msg.sender);
        setFee(_fee);
        setDefaultHoldPeriod(_defaultHoldPeriod);
        setFeeReceiversAddress(_receiversAddress);
    }

    function createInvoice(uint256 _invoicePrice) external returns (uint256) {
        if (_invoicePrice <= fee) revert InvoicePriceIsTooLow();
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

    function makeInvoicePayment(uint256 _invoiceId) external payable returns (address) {
        Invoice memory invoice = invoiceData[_invoiceId];
        uint256 bhFee = fee;

        if (msg.value > invoice.price) revert ExcessivePayment();
        if (invoice.status != CREATED) revert InvalidInvoiceState();
        if (block.timestamp > invoice.creationTime + VALID_PERIOD) revert InvoiceIsNoLongerValid();

        address escrow = _create(invoice.creator, _invoiceId, bhFee, msg.value - bhFee);

        invoice.escrow = escrow;
        invoice.payer = msg.sender;
        invoice.status = PAID;
        invoice.paymentTime = (block.timestamp).toUint32();
        invoice.holdPeriod = (defaultHoldPeriod + block.timestamp).toUint32();
        invoiceData[_invoiceId] = invoice;

        emit InvoicePaid(invoice.creator, msg.sender, msg.value);
        return escrow;
    }

    function creatorsAction(uint256 _invoiceId, bool _state) external {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (invoice.creator != msg.sender) revert Unauthorized();
        if (invoice.status != PAID) revert InvoiceNotPaid();
        _state ? _acceptInvoice(_invoiceId, invoice.payer) : _rejectInvoice(_invoiceId, invoice);
    }

    function cancelInvoice(uint256 _invoiceId) external {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (invoice.creator != msg.sender) revert Unauthorized();
        if (invoice.status == PAID) revert InvoiceAlreadyPaid();
        invoiceData[_invoiceId].status = CANCELLED;
        emit InvoiceCanceled(_invoiceId);
    }

    function releaseInvoice(uint256 _invoiceId) external {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (invoice.creator != msg.sender) revert Unauthorized();
        if (block.timestamp < invoice.paymentTime + invoice.holdPeriod) {
            revert HoldPeriodHasNotBeenExceeded();
        }
        IEscrow(invoice.escrow).withdrawToCreator(msg.sender);
        emit InvoiceReleased(_invoiceId);
    }

    function _acceptInvoice(uint256 _invoiceId, address _payer) internal {
        invoiceData[_invoiceId].status = ACCEPTED;
        emit InvoiceAccepted(msg.sender, _payer, _invoiceId);
    }

    function _rejectInvoice(uint256 _invoiceId, Invoice memory invoice) internal {
        invoiceData[_invoiceId].status = REJECTED;
        IEscrow(invoice.escrow).refundToPayer(invoice.payer);
        emit InvoiceRejected(msg.sender, invoice.payer, _invoiceId);
    }

    function setHoldPeriod(uint256 _invoiceId, uint32 _holdPeriod) external onlyOwner {
        Invoice memory invoice = invoiceData[_invoiceId];

        if (invoice.status < CREATED) revert InvoiceDoesNotExist();
        if (_holdPeriod < invoice.holdPeriod) revert HoldPeriodShouldBeGreaterThanDefault();
        invoiceData[_invoiceId].holdPeriod = _holdPeriod;
    }

    function setFeeReceiversAddress(address _newFeeReceiver) public onlyOwner {
        feeReceiver = _newFeeReceiver;
    }

    function setDefaultHoldPeriod(uint256 _newDefaultHoldPeriod) public onlyOwner {
        defaultHoldPeriod = _newDefaultHoldPeriod;
    }

    function setFee(uint256 _newFee) public onlyOwner {
        fee = _newFee;
    }

    function getFee() external view returns (uint256) {
        return fee;
    }

    function getFeeReceiver() external view returns (address) {
        return feeReceiver;
    }

    function getCurrentInvoiceId() external view returns (uint256) {
        return currentInvoiceId;
    }

    function getDefaultHoldPeriod() external view returns (uint256) {
        return defaultHoldPeriod;
    }

    function getInvoiceData(uint256 _invoiceId) external view returns (Invoice memory) {
        return invoiceData[_invoiceId];
    }
}
