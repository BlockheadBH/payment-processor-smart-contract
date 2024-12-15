// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CREATE3 } from "solady/utils/CREATE3.sol";

import { Test, console } from "forge-std/Test.sol";
import { PaymentProcessor, IPaymentProcessor } from "../src/PaymentProcessor.sol";

error Unauthorized();

contract PaymentProcessorTest is Test {
    PaymentProcessor pp;

    address owner;
    address feeReceiver;

    address creatorOne;
    address creatorTwo;
    address payerOne;
    address payerTwo;

    uint256 constant FEE = 1 ether;
    uint256 constant DEFAULT_HOLD_PERIOD = 1 days;
    uint256 constant PAYER_ONE_INITIAL_BALANCE = 10_000 ether;
    uint256 constant PAYER_TWO_INITIAL_BALANCE = 5_000 ether;

    function setUp() public {
        owner = makeAddr("owner");
        feeReceiver = makeAddr("feeReceiver");
        creatorOne = makeAddr("creatorOne");
        creatorTwo = makeAddr("creatorTwo");
        payerOne = makeAddr("payerOne");
        payerTwo = makeAddr("payerTwo");

        vm.deal(payerOne, PAYER_ONE_INITIAL_BALANCE);
        vm.deal(payerTwo, PAYER_TWO_INITIAL_BALANCE);

        vm.startPrank(owner);
        pp = new PaymentProcessor();
        pp.setFee(FEE);
        pp.setFeeReceiversAddress(feeReceiver);
        pp.setDefaultHoldPeriod(DEFAULT_HOLD_PERIOD);
        vm.stopPrank();
    }

    function test_storage_state() public view {
        assertEq(pp.fee(), FEE);
        assertEq(pp.feeReceiver(), feeReceiver);
        assertEq(pp.invoiceId(), 1);
        assertEq(pp.defaultHoldPeriod(), DEFAULT_HOLD_PERIOD);
    }

    function test_invoice_creation() public {
        uint256 cOneInvoicePrice = 10;
        vm.startPrank(creatorOne);
        vm.expectRevert();
        pp.createInvoice(cOneInvoicePrice);
        cOneInvoicePrice = 100 ether;
        pp.createInvoice(cOneInvoicePrice);
        vm.stopPrank();

        IPaymentProcessor.Invoice memory invoiceDataOne = pp.getInvoiceData(1);
        assertEq(invoiceDataOne.creator, creatorOne);
        assertEq(invoiceDataOne.creationTime, block.timestamp);
        assertEq(invoiceDataOne.paymentTime, 0);
        assertEq(invoiceDataOne.price, 100 ether);
        assertEq(invoiceDataOne.amountPayed, 0);
        assertEq(invoiceDataOne.payer, address(0));
        assertEq(invoiceDataOne.status, pp.CREATED());
        assertEq(invoiceDataOne.escrow, address(0));
        assertEq(pp.invoiceId(), 2);

        vm.startPrank(creatorTwo);
        pp.createInvoice(25 ether);
        vm.stopPrank();

        IPaymentProcessor.Invoice memory invoiceDataTwo = pp.getInvoiceData(2);
        assertEq(invoiceDataTwo.creator, creatorTwo);
        assertEq(invoiceDataTwo.creationTime, block.timestamp);
        assertEq(invoiceDataTwo.paymentTime, 0);
        assertEq(invoiceDataTwo.price, 25 ether);
        assertEq(invoiceDataTwo.amountPayed, 0);
        assertEq(invoiceDataTwo.payer, address(0));
        assertEq(invoiceDataTwo.status, pp.CREATED());
        assertEq(invoiceDataTwo.escrow, address(0));
        assertEq(pp.invoiceId(), 3);
    }

    function test_cancel_invoice() public {
        uint256 invoicePrice = 100 ether;
        vm.prank(creatorOne);
        uint256 invoiceId = pp.createInvoice(invoicePrice);

        vm.expectRevert(Unauthorized.selector);
        pp.cancelInvoice(invoiceId);

        vm.prank(payerOne);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);

        vm.startPrank(creatorOne);
        vm.expectRevert(IPaymentProcessor.InvoiceAlreadyPaid.selector);
        pp.cancelInvoice(invoiceId);

        uint256 newInvoiceId = pp.createInvoice(invoicePrice);
        pp.cancelInvoice(newInvoiceId);
        vm.stopPrank();

        assertEq(pp.getInvoiceData(newInvoiceId).status, pp.CANCELLED());
    }

    function test_make_invoice_payment() public {
        // CREATE INVOICE
        uint256 invoicePrice = 100 ether;
        vm.prank(creatorOne);
        uint256 invoiceId = pp.createInvoice(invoicePrice);

        // TRY EXCESSIVE PAYMENT
        vm.startPrank(payerOne);
        vm.expectRevert(IPaymentProcessor.ExcessivePayment.selector);
        pp.makeInvoicePayment{ value: invoicePrice + 1 }(invoiceId);

        // TRY EXPIRED INVOICE
        vm.warp(block.timestamp + pp.VALID_PERIOD() + 1);
        vm.expectRevert(IPaymentProcessor.InvoiceIsNoLongerValid.selector);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);

        // MAKE VALID PAYMENT
        vm.warp(block.timestamp - pp.VALID_PERIOD());
        address escrowAddress = pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);

        // TRY ALREADY PAID INVOICE
        vm.expectRevert(IPaymentProcessor.InvalidInvoiceState.selector);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);
        vm.stopPrank();

        address computedAddress = pp.getAddress(pp.computeSalt(creatorOne, payerOne, invoiceId));

        assertEq(escrowAddress, computedAddress);

        IPaymentProcessor.Invoice memory invoiceData = pp.getInvoiceData(invoiceId);

        assertEq(escrowAddress.balance, invoicePrice - FEE);
        assertEq(address(pp).balance, FEE);
        assertEq(escrowAddress.balance + address(pp).balance, invoicePrice);
        assertEq(invoiceData.escrow, escrowAddress);
        assertEq(invoiceData.status, pp.PAID());
        assertEq(invoiceData.payer, payerOne);
    }

    function test_payment_acceptance() public {
        uint256 invoicePrice = 100 ether;
        vm.prank(creatorOne);
        uint256 invoiceId = pp.createInvoice(invoicePrice);

        vm.prank(creatorTwo);
        vm.expectRevert(Unauthorized.selector);
        pp.creatorsAction(invoiceId, false);

        vm.warp(block.number + 10);

        vm.prank(creatorOne);
        vm.expectRevert(IPaymentProcessor.InvoiceNotPaid.selector);
        pp.creatorsAction(invoiceId, true);

        vm.prank(payerOne);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);

        vm.prank(creatorOne);
        pp.creatorsAction(invoiceId, true);
        assertEq(pp.getInvoiceData(invoiceId).status, pp.ACCEPTED());
    }

    function test_payment_rejection() public {
        uint256 invoicePrice = 100 ether;
        vm.prank(creatorOne);
        uint256 invoiceId = pp.createInvoice(invoicePrice);

        vm.prank(payerOne);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);
        uint256 payerOneBalanceAfterPayment = address(payerOne).balance;
        assertEq(payerOneBalanceAfterPayment, PAYER_ONE_INITIAL_BALANCE - invoicePrice);

        vm.prank(creatorOne);
        pp.creatorsAction(invoiceId, false);

        assertEq(pp.getInvoiceData(invoiceId).status, pp.REJECTED());
        assertEq(address(payerOne).balance, payerOneBalanceAfterPayment + invoicePrice - FEE);
    }

    function test_default_hold_release_invoice() public {
        // CREATE
        uint256 invoicePrice = 100 ether;
        vm.prank(creatorOne);
        uint256 invoiceId = pp.createInvoice(invoicePrice);

        // PAY
        vm.prank(payerOne);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);

        // ACCEPT
        vm.prank(creatorOne);
        pp.creatorsAction(invoiceId, true);

        //RELEASE
        vm.expectRevert(Unauthorized.selector);
        pp.releaseInvoice(invoiceId);

        vm.startPrank(creatorOne);
        vm.expectRevert(IPaymentProcessor.HoldPeriodHasNotBeenExceeded.selector);
        pp.releaseInvoice(invoiceId);

        vm.warp(block.timestamp + DEFAULT_HOLD_PERIOD + 1);
        pp.releaseInvoice(invoiceId);
        vm.stopPrank();

        assertEq(creatorOne.balance, invoicePrice - FEE);
    }

    function test_dynamic_hold_release_invoice() public {
        uint32 adminHoldPeriod = 25 days;

        vm.prank(owner);
        vm.expectRevert(IPaymentProcessor.InvoiceDoesNotExist.selector);
        pp.setHoldPeriod(1, adminHoldPeriod);

        // CREATE
        uint256 invoicePrice = 100 ether;
        vm.prank(creatorOne);
        uint256 invoiceId = pp.createInvoice(invoicePrice);

        // PAY
        vm.prank(payerOne);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);

        // ACCEPT
        vm.prank(creatorOne);
        pp.creatorsAction(invoiceId, true);

        vm.startPrank(owner);
        vm.expectRevert(IPaymentProcessor.HoldPeriodShouldBeGreaterThanDefault.selector);
        pp.setHoldPeriod(invoiceId, 5 minutes);
        pp.setHoldPeriod(invoiceId, uint32(adminHoldPeriod + block.timestamp));
        vm.stopPrank();

        vm.warp(block.timestamp + adminHoldPeriod + 1);
        vm.prank(creatorOne);
        pp.releaseInvoice(invoiceId);

        assertEq(creatorOne.balance, invoicePrice - FEE);
    }
}
