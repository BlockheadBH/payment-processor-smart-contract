// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IEscrow {
    error ValueIsTooLow();
    error TransferFailed();

    function withdraw(address _creator) external;
    function refund(address _payer) external;
}
