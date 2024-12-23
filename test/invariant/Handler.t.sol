// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { PaymentProcessor } from "../../src/PaymentProcessor.sol";
import { ACCEPTANCE_WINDOW } from "../../src/utils/Constants.sol";

contract Handler is Test {
    PaymentProcessor public pp;
    address owner;
    address public feeReceiver;

    address creator;
    address payer;

    uint256 public balance;
    uint256 public totalInvoiceCreated;

    uint256 constant FEE = 1 ether;
    uint256 constant INVOICE_PRICE = 1000 ether;

    constructor(PaymentProcessor _pp) {
        totalInvoiceCreated = 1;
        owner = makeAddr("owner");
        feeReceiver = makeAddr("feeReceiver");
        creator = makeAddr("creator");
        payer = makeAddr("payer");
        pp = _pp;
    }

    function createInvoice(uint256 _price) public {
        _price = bound(_price, FEE + 1, INVOICE_PRICE);
        vm.prank(creator);
        pp.createInvoice(_price);
        totalInvoiceCreated++;
    }

    function cancelInvoice(uint256 _invoiceId) public {
        _invoiceId = bound(_invoiceId, 1, totalInvoiceCreated);

        vm.prank(creator);
        pp.cancelInvoice(_invoiceId);
    }

    function makePayment(uint256 _invoiceId, uint256 _value) public {
        _value = bound(_value, FEE + 1, INVOICE_PRICE);
        _invoiceId = bound(_invoiceId, 1, totalInvoiceCreated);

        vm.prank(payer);
        vm.deal(payer, INVOICE_PRICE);
        pp.makeInvoicePayment{ value: _value }(_invoiceId);

        balance += FEE;
    }

    function acceptInvoice(uint256 _invoiceId) public {
        _invoiceId = bound(_invoiceId, 1, totalInvoiceCreated);
        vm.prank(creator);
        pp.creatorsAction(_invoiceId, true);
    }

    function rejectInvoice(uint256 _invoiceId) public {
        _invoiceId = bound(_invoiceId, 1, totalInvoiceCreated);
        vm.prank(creator);
        pp.creatorsAction(_invoiceId, true);
    }

    function releaseInvoice(uint256 _invoiceId) public {
        _invoiceId = bound(_invoiceId, 1, totalInvoiceCreated);
        console.log("TIME", block.timestamp);
        vm.assume(block.timestamp > block.timestamp + ACCEPTANCE_WINDOW);
        console.log("TIME AFTER", block.timestamp);
        vm.prank(creator);
        pp.releaseInvoice(_invoiceId);
    }
}
