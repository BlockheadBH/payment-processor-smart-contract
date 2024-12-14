// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IEscrow {
    function withdraw() external;
    function refund(address _creator) external;
}
