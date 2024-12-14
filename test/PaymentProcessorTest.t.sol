// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CREATE3 } from "solady/utils/CREATE3.sol";

import { Test, console } from "forge-std/Test.sol";
import { PaymentProcessor, IPaymentProcessor } from "../src/PaymentProcessor.sol";

contract PaymentProcessorTest is Test {
    PaymentProcessor pp;

    address owner;
    address feeReceiver;

    address creatorOne;
    address creatorTwo;
    address payerOne;
    address payerTwo;

    uint256 constant FEE = 1 ether;
    uint256 constant PAYER_ONE_INITIAL_BALANCE = 10_000 ether;
    uint256 constant PAYER_TWO_INITIAL_BALANCE = 5_000 ether;

    modifier CreateInvoice(address _creator, uint256 _invoiceAmount) {
        _createInvoice(_creator, _invoiceAmount);
        _;
    }

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
        vm.stopPrank();
    }

    function test_storage_state() public view {
        assertEq(pp.fee(), FEE);
        assertEq(pp.feeReceiver(), feeReceiver);
        assertEq(pp.invoiceId(), 1);
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

    function test_make_invoice_payment() public {
        uint256 invoicePrice = 100 ether;
        vm.prank(creatorOne);
        uint256 invoiceId = pp.createInvoice(invoicePrice);

        vm.startPrank(payerOne);
        vm.expectRevert(IPaymentProcessor.ExcessivePayment.selector);
        pp.makeInvoicePayment{ value: invoicePrice + 1 }(invoiceId);

        vm.warp(block.timestamp + pp.VALID_PERIOD() + 1);
        vm.expectRevert(IPaymentProcessor.InvoiceIsNoLongerValid.selector);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);

        vm.warp(block.timestamp - pp.VALID_PERIOD());

        address escrowAddress = pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);


        vm.expectRevert(IPaymentProcessor.InvalidInvoiceState.selector);
        pp.makeInvoicePayment{ value: invoicePrice }(invoiceId);
        vm.stopPrank();

        assertEq(escrowAddress, _getAddress());
        assertEq(escrowAddress.balance, invoicePrice - FEE);
        assertEq(address(pp).balance, FEE);
        assertEq(escrowAddress.balance + address(pp).balance, invoicePrice);
    }

    function _createInvoice(address _creator, uint256 _invoiceAmount) internal {
        vm.prank(_creator);
        pp.createInvoice(_invoiceAmount);
    }


    // FIX SALT
    function _getAddress() internal view returns (address) {
        return CREATE3.predictDeterministicAddress("", address(pp));
    }
}
