// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IEscrow {
    function refund(address _creator) external;
}
