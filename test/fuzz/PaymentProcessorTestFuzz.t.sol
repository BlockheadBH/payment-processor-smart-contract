// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { Invoice } from "../../src/Types/InvoiceType.sol";
import { PaymentProcessor } from "../../src/PaymentProcessor.sol";
import { CREATED, ACCEPTED, REJECTED, PAID, CANCELLED, VALID_PERIOD } from "../../src/utils/Constants.sol";
import { ValueIsTooLow, ExcessivePayment } from "../../src/utils/Errors.sol";

contract PaymentProcessorTest is Test {
    PaymentProcessor pp;

    address owner;
    address feeReceiver;

    address creator;
    address payer;

    uint256 constant FEE = 1 ether;
    uint256 constant DEFAULT_HOLD_PERIOD = 1 days;
    uint256 constant PAYER_ONE_INITIAL_BALANCE = 10_000 ether;

    function setUp() public {
        owner = makeAddr("owner");
        feeReceiver = makeAddr("feeReceiver");
        creator = makeAddr("creator");
        payer = makeAddr("payer");
        vm.deal(payer, PAYER_ONE_INITIAL_BALANCE);
        vm.prank(owner);
        pp = new PaymentProcessor(feeReceiver, FEE, DEFAULT_HOLD_PERIOD);
    }

    function testFuzz_invoice_creation(uint256 _amount) public {
        vm.assume(_amount > FEE);
        vm.prank(creator);
        pp.createInvoice(_amount);
        Invoice memory invoiceData = pp.getInvoiceData(1);
        assertEq(invoiceData.creator, creator);
        assertEq(invoiceData.creationTime, block.timestamp);
        assertEq(invoiceData.paymentTime, 0);
        assertEq(invoiceData.price, _amount);
        assertEq(invoiceData.amountPayed, 0);
        assertEq(invoiceData.payer, address(0));
        assertEq(invoiceData.status, CREATED);
        assertEq(invoiceData.escrow, address(0));
        assertEq(pp.getCurrentInvoiceId(), 2);
    }

    function testFuzz_makeInvoicePayment(uint256 _paymentAmount) public {
        _paymentAmount = bound(_paymentAmount, 0, address(payer).balance);
        uint256 invoicePrice = 100 ether;
        vm.startPrank(creator);
        uint256 invoiceId = pp.createInvoice(invoicePrice);
        vm.stopPrank();

        vm.startPrank(payer);
        if (_paymentAmount <= FEE) {
            vm.expectRevert(ValueIsTooLow.selector);
            pp.makeInvoicePayment{ value: _paymentAmount }(invoiceId);
        } else if (_paymentAmount > invoicePrice) {
            vm.expectRevert(ExcessivePayment.selector);
            pp.makeInvoicePayment{ value: _paymentAmount }(invoiceId);
        } else {
            pp.makeInvoicePayment{ value: _paymentAmount }(invoiceId);
            Invoice memory invoice = pp.getInvoiceData(invoiceId);
            assertEq(invoice.status, PAID);
        }
        vm.stopPrank();
    }
}
