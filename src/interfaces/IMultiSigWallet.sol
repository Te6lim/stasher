// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Transaction} from "src/models/Transaction.sol";

interface IMultiSigWallet {
    
    function addSigner(address signer) external;

    function removeSigner(address signer) external;

    function proposeTransaction(address destination, uint256 amount) external returns (uint256 transactionId);

    function signTransaction(uint256 transactionId) external;

    function sendTransaction(uint256 transactionId) external;
}