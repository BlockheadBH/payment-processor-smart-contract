// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { Invoice } from "../../src/Types/InvoiceType.sol";
import { PaymentProcessor } from "../../src/PaymentProcessor.sol";
import { CREATED, ACCEPTED, REJECTED, PAID, CANCELLED, VALID_PERIOD } from "../../src/utils/Constants.sol";
import {
    Unauthorized,
    ValueIsTooLow,
    InvoiceNotPaid,
    ExcessivePayment,
    InvoiceAlreadyPaid,
    InvoiceDoesNotExist,
    InvalidInvoiceState,
    FeeValueCanNotBeZero,
    InvoicePriceIsTooLow,
    HoldPeriodCanNotBeZero,
    InvoiceIsNoLongerValid,
    ZeroAddressIsNotAllowed,
    CreatorCannotPayOwnInvoice,
    HoldPeriodHasNotBeenExceeded,
    HoldPeriodShouldBeGreaterThanDefault
} from "../../src/utils/Errors.sol";

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

        vm.prank(owner);
        pp = new PaymentProcessor(feeReceiver, FEE, DEFAULT_HOLD_PERIOD);
        vm.stopPrank();
    }

    function test_storage_state() public view {
        assertEq(pp.getFee(), FEE);
        assertEq(pp.getFeeReceiver(), feeReceiver);
        assertEq(pp.getCurrentInvoiceId(), 1);
        assertEq(pp.getDefaultHoldPeriod(), DEFAULT_HOLD_PERIOD);
    }

    function test_setters() public {
        vm.startPrank(owner);

        vm.expectRevert(FeeValueCanNotBeZero.selector);
        pp.setFee(0);

        vm.expectRevert(HoldPeriodCanNotBeZero.selector);
        pp.setDefaultHoldPeriod(0);

        vm.expectRevert(ZeroAddressIsNotAllowed.selector);
        pp.setFeeReceiversAddress(address(0));
        vm.stopPrank();
    }

    function test_invoice_creation() public {
        uint256 cOneInvoicePrice = 10;
        vm.startPrank(creatorOne);
        vm.expectRevert();
        pp.createInvoice(cOneInvoicePrice);
        cOneInvoicePrice = 100 ether;
        pp.createInvoice(cOneInvoicePrice);
        vm.stopPrank();

        Invoice memory invoiceDataOne = pp.getInvoiceData(1);
        assertEq(invoiceDataOne.creator, creatorOne);
        assertEq(invoiceDataOne.creationTime, block.timestamp);
        assertEq(invoiceDataOne.paymentTime, 0);
        assertEq(invoiceDataOne.price, 100 ether);
        assertEq(invoiceDataOne.amountPayed, 0);
        assertEq(invoiceDataOne.payer, address(0));
        assertEq(invoiceDataOne.status, CREATED);
        assertEq(invoiceDataOne.escrow, address(0));
        assertEq(pp.getCurrentInvoiceId(), 2);

        vm.prank(creatorTwo);
        pp.createInvoice(25 ether);

        Invoice memory invoiceDataTwo = pp.getInvoiceData(2);
        assertEq(invoiceDataTwo.creator, creatorTwo);
        assertEq(invoiceDataTwo.creationTime, block.timestamp);
        assertEq(invoiceDataTwo.paymentTime, 0);
        assertEq(invoiceDataTwo.price, 25 ether);
        assertEq(invoiceDataTwo.amountPayed, 0);
        assertEq(invoiceDataTwo.payer, address(0));
        assertEq(invoiceDataTwo.status, CREATED);
        assertEq(invoiceDataTwo.escrow, address(0));
        assertEq(pp.getCurrentInvoiceId(), 3);
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
        vm.expectRevert(InvoiceAlreadyPaid.selector);
        pp.cancelInvoice(invoiceId);

        uint256 newInvoiceId = pp.createInvoice(invoicePrice);
        pp.cancelInvoice(newInvoiceId);
        vm.stopPrank();

        assertEq(pp.getInvoiceData(newInvoiceId).status, CANCELLED);
    }

    function test_make_invoice_payment() public {
        // CREATE INVOICE
        uint256 invoicePrice = 100 ether;
        deal(creatorOne, 1);
        vm.startPrank(creatorOne);
        uint256 invoiceId = pp.createInvoice(invoicePrice);

        vm.expectRevert(CreatorCannotPayOwnInvoice.selector);
        pp.makeInvoicePayment{ value: 1 }(invoiceId);
        vm.stopPrank();

        vm.startPrank(payerOne);
        // TRY VERY LOW PAYMENT
        vm.expectRevert(ValueIsTooLow.selector);
        pp.makeInvoicePayment{ value: FEE }(invoiceId);

        // TRY EXCESSIVE PAYMENT

        vm.expectRevert(ExcessivePayment.selector);
        pp.makeInvoicePayment{ value: invoicePrice + 1 }(invoiceId);

        // TRY EXPIRED INVOICE
        vm.warp(block.timestamp + VALID_PERIOD + 1);
        vm.expectRevert(InvoiceIsNoLongerValid.selector);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);

        // MAKE VALID PAYMENT
        vm.warp(block.timestamp - VALID_PERIOD);
        address escrowAddress = pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);

        // TRY ALREADY PAID INVOICE
        vm.expectRevert(InvalidInvoiceState.selector);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);
        vm.stopPrank();

        address computedAddress = pp.getPredictedAddress(pp.computeSalt(creatorOne, payerOne, invoiceId));

        assertEq(escrowAddress, computedAddress);

        Invoice memory invoiceData = pp.getInvoiceData(invoiceId);

        assertEq(escrowAddress.balance, invoicePrice - FEE);
        assertEq(address(pp).balance, FEE);
        assertEq(escrowAddress.balance + address(pp).balance, invoicePrice);
        assertEq(invoiceData.escrow, escrowAddress);
        assertEq(invoiceData.status, PAID);
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
        vm.expectRevert(InvoiceNotPaid.selector);
        pp.creatorsAction(invoiceId, true);

        vm.prank(payerOne);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);

        vm.prank(creatorOne);
        pp.creatorsAction(invoiceId, true);
        assertEq(pp.getInvoiceData(invoiceId).status, ACCEPTED);
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

        assertEq(pp.getInvoiceData(invoiceId).status, REJECTED);
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
        vm.expectRevert(HoldPeriodHasNotBeenExceeded.selector);
        pp.releaseInvoice(invoiceId);

        vm.warp(block.timestamp + DEFAULT_HOLD_PERIOD + 1);
        pp.releaseInvoice(invoiceId);
        vm.stopPrank();

        assertEq(creatorOne.balance, invoicePrice - FEE);
    }

    function test_dynamic_hold_release_invoice() public {
        uint32 adminHoldPeriod = 25 days;

        vm.prank(owner);
        vm.expectRevert(InvoiceDoesNotExist.selector);
        pp.setInvoiceHoldPeriod(1, adminHoldPeriod);

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
        vm.expectRevert(HoldPeriodShouldBeGreaterThanDefault.selector);
        pp.setInvoiceHoldPeriod(invoiceId, 5 minutes);
        pp.setInvoiceHoldPeriod(invoiceId, uint32(adminHoldPeriod + block.timestamp));
        vm.stopPrank();

        vm.warp(block.timestamp + adminHoldPeriod + 1);
        vm.prank(creatorOne);
        pp.releaseInvoice(invoiceId);

        assertEq(creatorOne.balance, invoicePrice - FEE);
    }

    function test_Ether_Withdrawal() public {
        // CREATE INVOICE
        uint256 invoicePrice = 100 ether;
        vm.prank(creatorOne);
        uint256 invoiceIdOne = pp.createInvoice(invoicePrice);

        pp.makeInvoicePayment{ value: invoicePrice }(invoiceIdOne);

        vm.expectRevert(Unauthorized.selector);
        pp.withdrawFees();

        vm.prank(feeReceiver);
        pp.withdrawFees();
        assertEq(address(feeReceiver).balance, FEE);

        vm.prank(creatorTwo);
        uint256 invoiceIdTwo = pp.createInvoice(invoicePrice);

        pp.makeInvoicePayment{ value: invoicePrice }(invoiceIdTwo);

        uint256 receiversBalanceBefore = address(feeReceiver).balance;
        vm.prank(owner);
        pp.withdrawFees();
        assertEq(address(feeReceiver).balance, FEE + receiversBalanceBefore);
    }
}