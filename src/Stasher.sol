// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMultiSigWallet} from "src/interfaces/IMultiSigWallet.sol";
import {Transaction, TransactionStatus} from "src/models/Transaction.sol";
import {AggregatorV2V3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";

contract Stasher is IMultiSigWallet {

    error Stasher__NotAnAuthorizedSigner();
    error Stasher__TooManySigners();
    error Stasher__InsufficientFunds();
    error Stasher__InvalidAddress();
    error Stasher__InvalidTransaction();
    error Stasher__InvalidAmount();
    error Stasher__TransactionAlreadyExists();
    error Stasher__SignerAlreadySigned();
    error Stasher__NotEnoughSignatories();
    error Stasher__TransactionFailed();

    event TransactionProposal(
        uint256 indexed transactionId,
        address indexed proposer,
        address indexed destinationAddress,
        uint256 amount
    );

    event SignTransaction(
        address indexed signer,
        uint256 indexed transactionId
    );

    event TransactionStatusChange(
        uint256 indexed transactionId,
        TransactionStatus indexed status
    );

    modifier authorizedSigner() {
        if (!authorizedSigners[msg.sender]) revert Stasher__NotAnAuthorizedSigner();
        _;
    }
    modifier limitSigners() {
        if (numberOfRequiredSignatures + 1 > MAX_SIGNERS) revert Stasher__TooManySigners();
        _;
    }
    modifier checkNonZeroBalance() {
        if (address(this).balance <= 0) revert Stasher__InsufficientFunds();
        _;
    }

    mapping(address => bool) private authorizedSigners;
    uint256 private numberOfRequiredSignatures;
    uint256 private constant MAX_SIGNERS = 5;
    uint256 private constant MINIMUN_SIGNERS_FOR_A_TRANSACTION = 3;
    mapping(uint256 txnId => Transaction) private transactions;
    mapping(uint256 txnId => mapping(address => bool)) transactionSignatories;
    uint256 transactionCount;
    address private ethUsdPriceFeed;
    uint256 balanceInUsd;
    uint256 private constant PRECISION_PADDING = 10e10;
    uint256 private constant PRECISION = 10e18;

    constructor(address priceFeed) {
        ethUsdPriceFeed = priceFeed;
        balanceInUsd = getAmountInUSD(address(this).balance);
    }

    function addSigner(address signer) override external limitSigners {
        if (!authorizedSigners[signer]) {
            authorizedSigners[signer] = true;
            numberOfRequiredSignatures++;
        }
    }

    function removeSigner(address signer) override external {
        if (authorizedSigners[signer]) {
            authorizedSigners[signer] = false;
            numberOfRequiredSignatures--;
        }
    }

    function proposeTransaction(
        address destination, uint256 amount
    ) override external
        authorizedSigner
        checkNonZeroBalance
        returns (uint256 transactionId) {
            Transaction memory txn = Transaction({
                destination: destination,
                amount: amount,
                transactionId: ++transactionCount,
                timestamp: block.timestamp,
                status: TransactionStatus.PROPOSED,
                confirmations: 0
            });
            _validateTransaction(txn);
            transactions[txn.transactionId] = txn;
            signTransaction(txn.transactionId);
            emit TransactionProposal(txn.transactionId, msg.sender, txn.destination, txn.amount);
            transactionId = txn.transactionId;
            return transactionId;
    }

    function signTransaction(uint256 transactionId) override public authorizedSigner {
        Transaction storage txn = transactions[transactionId];
        if (transactionSignatories[transactionId][msg.sender]) revert Stasher__SignerAlreadySigned();
        transactionSignatories[transactionId][msg.sender] = true;
        txn.confirmations++;
        emit SignTransaction(msg.sender, transactionId);
    }

    function sendTransaction(uint256 transactionId) override public {
        Transaction storage txn = transactions[transactionId];
        if (txn.confirmations < MINIMUN_SIGNERS_FOR_A_TRANSACTION) revert Stasher__NotEnoughSignatories();
        txn.status = TransactionStatus.PENDING;
        emit TransactionStatusChange(txn.transactionId, txn.status);
        (bool isSuccess, ) = payable(txn.destination).call {
            value: txn.amount
        }("");

        if (!isSuccess) revert Stasher__TransactionFailed();
        else {
            txn.status = TransactionStatus.SENT;
            balanceInUsd = getAmountInUSD(address(this).balance);
            emit TransactionStatusChange(txn.transactionId, txn.status);
        }
    }

    function getAmountInUSD(uint256 amount) public view returns (uint256) {
        AggregatorV2V3Interface priceFeedAggregator = AggregatorV2V3Interface(ethUsdPriceFeed);
        (, int256 price,,,) = priceFeedAggregator.latestRoundData();
        uint256 convertedAmount = (uint256(price) * PRECISION_PADDING * amount) / PRECISION;
        return convertedAmount;
    }

    function _validateTransaction(Transaction memory txn) private view {
        if (txn.transactionId == 0) revert Stasher__InvalidTransaction();
        if (transactions[txn.transactionId].transactionId != 0) revert Stasher__TransactionAlreadyExists();
        if (txn.amount <= 0) revert Stasher__InvalidAmount();
        if (txn.amount > address(this).balance) revert Stasher__InsufficientFunds();
        if (txn.destination == address(0)) revert Stasher__InvalidAddress();
    }

    function isAddressAuthorized(address signer) public view returns(bool) {
        return authorizedSigners[signer];
    }

    function getNumberOfSignatures() public view returns(uint256) {
        return numberOfRequiredSignatures;
    }

    function getTransactionById(uint256 txnId) external view returns(Transaction memory) {
        return transactions[txnId];
    }

    function hasUserSignedTransaction(address signer, uint256 transactionId) external view returns(bool) {
        return transactionSignatories[transactionId][signer];
    }
}