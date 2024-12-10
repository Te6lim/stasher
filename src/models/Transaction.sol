// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct Transaction {
    address destination;
    uint256 amount;
    uint256 transactionId;
    uint256 timestamp;
    TransactionStatus status;
    uint256 confirmations;
}

enum TransactionStatus {
    PENDING, PROPOSED, SENT
}