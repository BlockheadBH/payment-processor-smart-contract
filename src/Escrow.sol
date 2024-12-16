// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IEscrow } from "./interface/IEscrow.sol";
import { Unauthorized, ValueIsTooLow, TransferFailed } from "./utils/Errors.sol";

contract Escrow is IEscrow {
    /// @notice The initial balance deposited into the contract.
    uint256 public immutable balance;

    /// @notice The address of the payer associated with this escrow.
    address public immutable payer;

    /// @notice The address of the creator associated with this escrow.
    address public immutable creator;

    /// @notice The address of the controller authorized to manage this escrow.
    address public immutable controller;

    /// @notice The invoice ID associated with the escrow.
    uint256 public immutable invoiceId;

    modifier onlyController() {
        _onlyController();
        _;
    }

    receive() external payable {
        if (msg.sender != creator) revert();
    }

    constructor(address _creator, address _payer, uint256 _fee, uint256 _invoiceId, address _escrow) payable {
        if (msg.value <= _fee) revert ValueIsTooLow();
        creator = _creator;
        payer = _payer;
        controller = _escrow;
        invoiceId = _invoiceId;
        emit FundsDeposited(_invoiceId, msg.value);
    }

    /// @inheritdoc IEscrow
    function withdrawToCreator(address _creator) external onlyController {
        uint256 bal = _withdraw(_creator);
        emit FundsWithdrawn(invoiceId, _creator, bal);
    }

    /// @inheritdoc IEscrow
    function refundToPayer(address _payer) external onlyController {
        uint256 bal = _withdraw(_payer);
        emit FundsRefunded(invoiceId, _payer, bal);
    }

    /**
     * @notice Withdraws the entire balance of the contract to a specified address.
     * @dev This function attempts to transfer the full balance of the contract to the provided address.
     *      The balance is returned to provide feedback on the transaction.
     * @param _to The address to which the funds should be sent.
     * @return The amount of funds (in wei) that was transferred.
     */
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
