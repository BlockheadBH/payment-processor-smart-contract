// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { IPaymentProcessorV1 } from "../src/interface/IPaymentProcessorV1.sol";

contract Scr is Script {
    function run() public {
        vm.startBroadcast();

        IPaymentProcessorV1(0x31CA89Eea4DdE88F8B044106117994a7fABB46b6).releaseInvoice(1);

        vm.stopBroadcast();
    }
}
