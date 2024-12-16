// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IEscrow } from "./interface/IEscrow.sol";
import { Unauthorized, ValueIsTooLow, TransferFailed } from "./utils/Errors.sol";

contract Escrow is IEscrow {
    uint256 public immutable balance;
    address public immutable payer;
    address public immutable creator;
    address public immutable controller;

    modifier onlyController() {
        _onlyController();
        _;
    }

    receive() external payable {
        if (msg.sender != creator) revert();
    }

    constructor(address _creator, address _payer, uint256 _fee, uint256 _invoiceId, address _escrow) payable {
        if (msg.value <= _fee) revert ValueIsTooLow();
        payer = _payer;
        creator = _creator;
        controller = _escrow;
        emit FundsDeposited(_invoiceId, msg.value);
    }

    function withdrawToCreator(address _creator) external onlyController {
        uint256 bal = _withdraw(_creator);
        emit FundsWithdrawn(_creator, bal);
    }

    function refundToPayer(address _payer) external onlyController {
        uint256 bal = _withdraw(_payer);
        emit FundsRefunded(_payer, bal);
    }

    function _withdraw(address _to) internal returns (uint256) {
        uint256 bal = address(this).balance;
        (bool success,) = payable(_to).call{ value: address(this).balance }("");
        if (!success) revert TransferFailed();
        return bal;
    }

    function _onlyController() internal view {
        if (msg.sender != controller) revert Unauthorized();
    }
}
