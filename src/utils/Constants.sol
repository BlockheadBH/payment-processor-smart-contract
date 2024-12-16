// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

uint32 constant CREATED = 1;
uint32 constant ACCEPTED = CREATED + 1;
uint32 constant PAID = ACCEPTED + 1;
uint32 constant REJECTED = PAID + 1;
uint32 constant CANCELLED = REJECTED + 1;
uint256 constant VALID_PERIOD = 180 days;