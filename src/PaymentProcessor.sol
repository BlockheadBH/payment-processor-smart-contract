// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "solady/auth/Ownable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { IEscrow, Escrow } from "./Escrow.sol";
import { IPaymentProcessor } from "./interface/IPaymentProcessor.sol";
import { CREATE3 } from "solady/utils/CREATE3.sol";

error InvoicePriceIsTooLow();

contract PaymentProcessor is Ownable, IPaymentProcessor {
    using SafeCastLib for uint256;

    uint256 public fee;
    address public feeReceiver;
    uint256 public invoiceId;

    uint8 public constant CREATED = 1;
    uint8 public constant ACCEPTED = CREATED + 1;
    uint8 public constant PAID = ACCEPTED + 1;
    uint8 public constant REJECTED = PAID + 1;
    uint8 public constant CANCELLED = REJECTED + 1;

    uint256 public constant VALID_PERIOD = 180 days;

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

    mapping(uint256 invoiceId => Invoice invoice) public invoiceData;

    constructor() {
        invoiceId = 1;
        _initializeOwner(msg.sender);
    }

    function createInvoice(uint256 _invoicePrice) external {
        if (_invoicePrice <= fee) revert InvoicePriceIsTooLow();
        Invoice memory invoice = invoiceData[invoiceId];
        invoice.creator = msg.sender;
        invoice.creationTime = (block.timestamp).toUint48();
        invoice.price = _invoicePrice;
        invoice.status = CREATED;
        invoiceData[invoiceId] = invoice;
        emit InvoiceCreated(msg.sender, invoiceId);
        invoiceId++;
    }

    function payInvoice(uint256 _invoiceId) external payable {
        Invoice memory invoice = invoiceData[_invoiceId];
        if (msg.value > invoice.price) revert();
        if (invoice.status != CREATED) revert();
        if (invoice.status == PAID) revert();
        if (invoice.creationTime + VALID_PERIOD > block.timestamp) revert();
        uint256 invoicePaymentValue = msg.value - fee;

        bytes memory constructorArg = abi.encode(invoice.creator, invoice.payer);
        address escrow = CREATE3.deployDeterministic(
            invoicePaymentValue, abi.encodePacked(type(Escrow).creationCode, constructorArg), ""
        );

        invoice.escrow = escrow;
        invoice.payer = msg.sender;
        invoice.status = PAID;
        invoice.paymentTime = (block.timestamp).toUint48();
        invoiceData[_invoiceId] = invoice;

        emit InvoicePaid(invoice.creator, msg.sender, msg.value);
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
    }

    function releaseInvoice() external { }

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

    event InvoiceCreated(address indexed creator, uint256 indexed invoiceId);
    event InvoicePaid(address indexed creator, address indexed payer, uint256 indexed amountPayed);
    event InvoiceRejected(
        address indexed creator, address indexed payer, uint256 indexed invoiceId
    );

    event InvoiceAccepted(
        address indexed creator, address indexed payer, uint256 indexed invoiceId
    );
}
