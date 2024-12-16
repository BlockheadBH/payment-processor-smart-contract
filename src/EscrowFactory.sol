// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IEscrow, Escrow } from "./Escrow.sol";
import { CREATE3 } from "solady/utils/CREATE3.sol";
import { IEscrowFactory } from "./interface/IEscrowFactory.sol";

abstract contract EscrowFactory is IEscrowFactory {
    function computeSalt(address _creator, address _payer, uint256 _invoiceId) public pure returns (bytes32) {
        return keccak256(abi.encode(_creator, _payer, _invoiceId));
    }

    function getPredictedAddress(bytes32 _salt) public view returns (address) {
        return CREATE3.predictDeterministicAddress(_salt);
    }

    function _create(address _creator, uint256 _invoiceId, uint256 _fee, uint256 _invoicePaymentValue)
        internal
        returns (address)
    {
        bytes memory constructorArg = abi.encode(_creator, msg.sender, _fee, _invoiceId, address(this));
        bytes32 salt = computeSalt(_creator, msg.sender, _invoiceId);

        return CREATE3.deployDeterministic(
            _invoicePaymentValue, abi.encodePacked(type(Escrow).creationCode, constructorArg), salt
        );
    }
}
