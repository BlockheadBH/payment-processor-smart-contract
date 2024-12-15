// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "solady/auth/Ownable.sol";
import { CREATE3 } from "solady/utils/CREATE3.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { IEscrow, Escrow } from "./Escrow.sol";
import { IPaymentProcessor } from "./interface/IPaymentProcessor.sol";

// Create3 -> another file

contract PaymentProcessor is Ownable, IPaymentProcessor {
    using SafeCastLib for uint256;

    uint256 public fee;
    address public feeReceiver;
    uint256 public invoiceId;
    uint256 public defaultHoldPeriod;

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
        invoice.creationTime = (block.timestamp).toUint32();
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

        bytes memory constructorArg = abi.encode(invoice.creator, msg.sender, bhFee);
        bytes32 salt = computeSalt(invoice.creator, msg.sender, _invoiceId);

        address escrow = CREATE3.deployDeterministic(
            invoicePaymentValue, abi.encodePacked(type(Escrow).creationCode, constructorArg), salt
        );

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
        IEscrow(invoice.escrow).withdraw(msg.sender);
        emit InvoiceReleased(_invoiceId);
    }

    function computeSalt(address _creator, address _payer, uint256 _invoiceId)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_creator, _payer, _invoiceId));
    }

    function getAddress(bytes32 _salt) external view returns (address) {
        return CREATE3.predictDeterministicAddress(_salt);
    }

    function _acceptInvoice(uint256 _invoiceId, address _payer) internal {
        invoiceData[_invoiceId].status = ACCEPTED;
        emit InvoiceAccepted(msg.sender, _payer, _invoiceId);
    }

    function _rejectInvoice(uint256 _invoiceId, Invoice memory invoice) internal {
        invoiceData[_invoiceId].status = REJECTED;
        IEscrow(invoice.escrow).refund(invoice.payer);
        emit InvoiceRejected(msg.sender, invoice.payer, _invoiceId);
    }

    function setHoldPeriod(uint256 _invoiceId, uint32 _holdPeriod) external onlyOwner {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (invoice.status < CREATED) revert InvoiceDoesNotExist();
        if (_holdPeriod < invoice.holdPeriod) revert HoldPeriodShouldBeGreaterThanDefault();
        invoiceData[_invoiceId].holdPeriod = _holdPeriod;
    }

    // constructor for default
    function setFeeReceiversAddress(address _newFeeReceiver) external onlyOwner {
        feeReceiver = _newFeeReceiver;
    }

    // constructor for default
    function setDefaultHoldPeriod(uint256 _newDefaultHoldPeriod) external onlyOwner {
        defaultHoldPeriod = _newDefaultHoldPeriod;
    }

    // constructor for default
    function setFee(uint256 _newFee) external onlyOwner {
        fee = _newFee;
    }

    function getInvoiceData(uint256 _invoiceId) external view returns (Invoice memory) {
        return invoiceData[_invoiceId];
    }
}
