// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IEscrowFactory {
    function computeSalt(address _creator, address _payer, uint256 _invoiceId) external pure returns (bytes32);
    function getPredictedAddress(bytes32 _salt) external view returns (address);
}
