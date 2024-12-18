// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Thrown when an unauthorized address attempts to perform a restricted action.
error Unauthorized();

/// @notice Thrown when the provided value is lower than the required minimum.
error ValueIsTooLow();

/// @notice Thrown when a fund transfer fails.
error TransferFailed();

/// @notice Thrown when an action is attempted on an invoice that has not been paid.
error InvoiceNotPaid();

/// @notice Thrown when the payment amount exceeds the required invoice amount.
error ExcessivePayment();

/// @notice Thrown when the fee value provided is zero.
error FeeValueCanNotBeZero();

/// @notice Thrown when the hold period provided is zero, which is invalid.
error HoldPeriodCanNotBeZero();

/// @notice Thrown when a zero address (`address(0)`) is provided.
error ZeroAddressIsNotAllowed();

/// @notice Thrown when the invoice price is below the allowed minimum.
error InvoicePriceIsTooLow();

/// @notice Thrown when the invoice is in an invalid state for the requested action.
error InvalidInvoiceState();

/// @notice Thrown when the invoice is no longer valid (e.g., cancelled or expired).
error InvoiceIsNoLongerValid();

/// @notice Thrown when an invoice that has already been fully paid is attempted to be paid again.
error InvoiceAlreadyPaid();

/// @notice Thrown when an action is attempted on a non-existent invoice.
error InvoiceDoesNotExist();

/// @notice Thrown when the creator attempts to take action on an invoice after the acceptance window has expired.
error AcceptanceWindowExceeded();

/// @notice Thrown when the creator of an invoice attempts to pay for their own invoice.
error CreatorCannotPayOwnInvoice();

/// @notice Reverts when an invoice is not eligible for a refund to the creator.
error InvoiceNotEligibleForRefund();

/// @notice Thrown when the hold period for an invoice has not yet been exceeded.
error HoldPeriodHasNotBeenExceeded();

/// @notice Thrown when attempting to set a custom hold period that is less than the default hold period.
error HoldPeriodShouldBeGreaterThanDefault();
