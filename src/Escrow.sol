// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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

    // Event? the single fn

    function withdraw(address _creator) external {
        // Restriction!
        (bool success,) = payable(_creator).call{ value: address(this).balance }("");
        if (!success) revert TransferFailed();
    }

    function refund(address _payer) external {
        // Restriction!
        // Only the payment processor contract is allowed to call
        (bool success,) = payable(_payer).call{ value: address(this).balance }("");
        if (!success) revert TransferFailed();
    }
}
