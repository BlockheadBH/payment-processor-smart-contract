// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IEscrow {
    function refundToPayer(address _payer) external;
    function withdrawToCreator(address _creator) external;

    event FundsWithdrawn(address indexed creator, uint256 indexed amount);
    event FundsRefunded(address indexed payer, uint256 indexed amount);
    event FundsDeposited(uint256 indexed invoiceId, uint256 indexed value);
}
