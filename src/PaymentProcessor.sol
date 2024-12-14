// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "solady/auth/Ownable.sol";
import { CREATE3 } from "solady/utils/CREATE3.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { IEscrow, Escrow } from "./Escrow.sol";
import { IPaymentProcessor } from "./interface/IPaymentProcessor.sol";

contract PaymentProcessor is Ownable, IPaymentProcessor {
    using SafeCastLib for uint256;

    uint256 public fee;
    address public feeReceiver;
    uint256 public invoiceId;
    uint256 public holdPeriod;

    uint8 public constant CREATED = 1;
    uint8 public constant ACCEPTED = CREATED + 1;
    uint8 public constant PAID = ACCEPTED + 1;
    uint8 public constant REJECTED = PAID + 1;
    uint8 public constant CANCELLED = REJECTED + 1;

    uint256 public constant VALID_PERIOD = 180 days;

    mapping(uint256 invoiceId => Invoice invoice) private invoiceData;

    constructor() {
        invoiceId = 1;
        _initializeOwner(msg.sender);
    }

    function createInvoice(uint256 _invoicePrice) external returns (uint256) {
        if (_invoicePrice <= fee) revert InvoicePriceIsTooLow();
        uint256 thisInvoiceId = invoiceId;
        Invoice memory invoice = invoiceData[thisInvoiceId];
        invoice.creator = msg.sender;
        invoice.creationTime = (block.timestamp).toUint48();
        invoice.price = _invoicePrice;
        invoice.status = CREATED;
        invoiceData[thisInvoiceId] = invoice;
        emit InvoiceCreated(msg.sender, invoiceId, block.timestamp);
        invoiceId++;
        return thisInvoiceId;
    }

    function makeInvoicePayment(uint256 _invoiceId) external payable returns (address) {
        Invoice memory invoice = invoiceData[_invoiceId];
        uint256 bhFee = fee;
        if (msg.value > invoice.price) revert ExcessivePayment();
        if (invoice.status != CREATED) revert InvalidInvoiceState();
        if (block.timestamp > invoice.creationTime + VALID_PERIOD) revert InvoiceIsNoLongerValid();
        uint256 invoicePaymentValue = msg.value - bhFee;

        bytes memory constructorArg = abi.encode(invoice.creator, invoice.payer, bhFee);
        // FIX SALT
        address escrow = CREATE3.deployDeterministic(
            invoicePaymentValue, abi.encodePacked(type(Escrow).creationCode, constructorArg), ""
        );

        invoice.escrow = escrow;
        invoice.payer = msg.sender;
        invoice.status = PAID;
        invoice.paymentTime = (block.timestamp).toUint48();
        invoiceData[_invoiceId] = invoice;

        emit InvoicePaid(invoice.creator, msg.sender, msg.value);
        return escrow;
    }

    function creatorsAction(uint256 _invoiceId, bool _state) external {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (invoice.creator != msg.sender) revert();
        if (invoice.status != PAID) revert();
        _state ? _acceptInvoice(_invoiceId, invoice.payer) : _rejectInvoice(_invoiceId, invoice);
    }

    function cancelInvoice(uint256 _invoiceId) external {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (invoice.creator != msg.sender) revert();
        if (invoice.status == PAID) revert();
        invoiceData[_invoiceId].status = CANCELLED;
        emit InvoiceCanceled(_invoiceId);
    }

    function releaseInvoice(uint256 _invoiceId) external {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (invoice.creator != msg.sender) revert();
        if (block.timestamp < invoice.paymentTime + holdPeriod) revert();
        IEscrow(invoice.escrow).withdraw();
    }

    function _acceptInvoice(uint256 _invoiceId, address _payer) internal {
        invoiceData[_invoiceId].status = ACCEPTED;
        emit InvoiceAccepted(msg.sender, _payer, _invoiceId);
    }

    function _rejectInvoice(uint256 _invoiceId, Invoice memory invoice) internal {
        invoiceData[_invoiceId].status = ACCEPTED;
        IEscrow(invoice.escrow).refund(invoice.creator);
        emit InvoiceRejected(msg.sender, invoice.payer, _invoiceId);
    }

    function setFeeReceiversAddress(address _newFeeReceiver) external onlyOwner {
        feeReceiver = _newFeeReceiver;
    }

    function setFee(uint256 _newFee) external onlyOwner {
        fee = _newFee;
    }

    function getInvoiceData(uint256 _invoiceId) external view returns (Invoice memory) {
        return invoiceData[_invoiceId];
    }
}
