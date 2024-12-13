// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

error ValueIsTooLow();
error TransferFailed();

import { IEscrow } from "./interface/IEscrow.sol";

contract Escrow is IEscrow {
    uint256 public balance;
    address public payer;
    address public creator;

    receive() external payable { }

    constructor(address _creator, address _payer, uint256 _fee) payable {
        if (msg.value <= _fee) revert ValueIsTooLow();
        payer = _payer;
        creator = _creator;
    }

    function withdraw() external {
        // is it eligible for withdrawal
        if (msg.sender != creator) revert();
        (bool success,) = payable(msg.sender).call{ value: address(this).balance }("");
        if (!success) revert TransferFailed();
        // Only the creator
        // Only when the conditions are met
    }

    function refund(address _creator) external {
        // Only the payment processor contract is allowed to call
        (bool success,) = payable(_creator).call{ value: address(this).balance }("");
        if (!success) revert TransferFailed();
    }
}
