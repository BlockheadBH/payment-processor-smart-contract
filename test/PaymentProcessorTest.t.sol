// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CREATE3 } from "solady/utils/CREATE3.sol";

import { Test } from "forge-std/Test.sol";
import { PaymentProcessor } from "../src/PaymentProcessor.sol";

contract PaymentProcessorTest is Test {
    PaymentProcessor pp;

    address owner;

    address creatorOne;
    address creatorTwo;
    address payerOne;
    address payerTwo;

    uint256 constant FEE = 1 ether;

    function setUp() public {
        owner = makeAddr("owner");
        creatorOne = makeAddr("creatorOne");
        creatorTwo = makeAddr("creatorTwo");
        payerOne = makeAddr("payerOne");
        payerTwo = makeAddr("payerTwo");

        vm.startPrank(owner);
        pp = new PaymentProcessor();
        pp.setFee(FEE);
        vm.stopPrank();
    }

    function test_fee() public view {
        assertEq(pp.fee(), FEE);
    }

    function getAddress() internal view returns (address) {
        return CREATE3.predictDeterministicAddress("", address(pp));
    }
}
