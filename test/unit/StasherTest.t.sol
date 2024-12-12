// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {WalletDeployer} from "script/WalletDeployer.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Stasher} from "src/Stasher.sol";
import {TransactionStatus} from "src/models/Transaction.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract StasherTest is Test {

    error Stasher__NotAnAuthorizedSigner();
    error Stasher__InsufficientFunds();
    error Stasher__InvalidAmount();
    error Stasher__InvalidAddress();
    error Stasher__SignerAlreadySigned();
    error Stasher__NotEnoughSignatories();

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

    Stasher wallet;
    HelperConfig.NetworkConfig config;

    address user = makeAddr("some_user");

    uint256 private constant MINIMUN_SIGNERS_FOR_A_TRANSACTION = 3;

    modifier proposeTxn {
        wallet.addSigner(user);
        vm.deal(address(wallet), 10 ether);
        address destinationAddress = makeAddr("destinationAddress");
        uint256 transactionAmount = 5 ether;
        vm.startPrank(user);
        wallet.proposeTransaction(destinationAddress, transactionAmount);
        vm.stopPrank();
        _;
    }

    modifier proposeTxnWithSufficientSigners {
        wallet.addSigner(user);
        vm.deal(address(wallet), 10 ether);
        address destinationAddress = makeAddr("destinationAddress");
        uint256 transactionAmount = 5 ether;

        for (uint256 i = 0; i < MINIMUN_SIGNERS_FOR_A_TRANSACTION ; ++i) {
            user = makeAddr(Strings.toString(i));
            vm.startPrank(user);
            wallet.addSigner(user);
            if (i == 0) wallet.proposeTransaction(destinationAddress, transactionAmount);
            else wallet.signTransaction(1);
            vm.stopPrank();
        }
        _;
    }

    function setUp() public {
        (wallet, config) = (new WalletDeployer()).run();
    }

    function testAddSigner() external {
        wallet.addSigner(user);

        assertEq(wallet.isAddressAuthorized(user), true);
    }

    function testNumberOfSignaturesIsCorrectWhenSignatureIsAddedOrRemoved() external {
        wallet.addSigner(user);
        user = makeAddr("another-user");
        wallet.addSigner(user);
        wallet.removeSigner(user);

        assertEq(wallet.getNumberOfSignatures(), 1);
    }

    function testOnlyAuthorizedSignerCanProposeATransaction() external {
        wallet.addSigner(user);
        address user2 = makeAddr("new_user_2");
        vm.expectRevert(Stasher__NotAnAuthorizedSigner.selector);
        vm.startPrank(user2);
        wallet.proposeTransaction(makeAddr("destinationAddress"), 5 ether);
        vm.stopPrank();
    }

    function testWalletMustHaveNonZeroBalance() external {
        wallet.addSigner(user);
        vm.expectRevert(Stasher__InsufficientFunds.selector);
        vm.startPrank(user);
        wallet.proposeTransaction(makeAddr("destinationAddress"), 5 ether);
        vm.stopPrank();
    }

    function testBalaceIsGreaterThanTransactionAmount() external {
        wallet.addSigner(user);
        vm.deal(address(wallet), 4 ether);
        vm.expectRevert(Stasher__InsufficientFunds.selector);
        vm.startPrank(user);
        wallet.proposeTransaction(makeAddr("destinationAddress"), 5 ether);
        vm.stopPrank();
    }

    function testCannotPerformZeroAmountTransaction() external {
        wallet.addSigner(user);
        vm.deal(address(wallet), 10 ether);
        vm.expectRevert(Stasher__InvalidAmount.selector);
        vm.startPrank(user);
        wallet.proposeTransaction(makeAddr("destinationAddress"), 0);
        vm.stopPrank();
    }

    function testCannotTransferToZeroAddress() external {
        wallet.addSigner(user);
        vm.deal(address(wallet), 10 ether);
        vm.expectRevert(Stasher__InvalidAddress.selector);
        vm.startPrank(user);
        wallet.proposeTransaction(address(0), 5 ether);
        vm.stopPrank();
    }

    function testTransactionProposalEventIsEmited() external {
        wallet.addSigner(user);
        vm.deal(address(wallet), 10 ether);
        address destinationAddress = makeAddr("destinationAddress");
        uint256 transactionAmount = 5 ether;
        vm.expectEmit(true, true, true, false, address(wallet));
        emit TransactionProposal(
            1, user, destinationAddress, transactionAmount
        );
        vm.startPrank(user);
        wallet.proposeTransaction(destinationAddress, transactionAmount);
        vm.stopPrank();
    }

    function testTransactionStatusIsProposedAfterTransactionProposal() external proposeTxn {
        assert(wallet.getTransactionById(1).status == TransactionStatus.PROPOSED);
    }

    function testSigningTransactionIncreasesTransactionConfirmationCount() external proposeTxn {
        assertEq(wallet.getTransactionById(1).confirmations, 1);
    }

    function testUserHasBeenAddedToListOfTransactionSigners() external proposeTxn {
        assertEq(wallet.hasUserSignedTransaction(user, 1), true);
    }

    function testSignerCannotSignAlreadySignedTransaction() external proposeTxn {
        vm.expectRevert(Stasher__SignerAlreadySigned.selector);
        vm.prank(user);
        wallet.signTransaction(1);
        vm.stopPrank();
    }

    function testSignTransactionEventIsEmmited() external proposeTxn {
        address newUser = makeAddr("new-user");
        wallet.addSigner(newUser);
        vm.expectEmit(true, true, false, false, address(wallet));
        emit SignTransaction(newUser, 1);
        vm.prank(newUser);
        wallet.signTransaction(1);
    }

    function testSendTransactionFailsWhenThresholdIsntReached() external proposeTxn {
        address anotherUser = makeAddr("another-user");
        vm.startPrank(anotherUser);
        wallet.addSigner(anotherUser);
        wallet.signTransaction(1);
        vm.expectRevert(Stasher__NotEnoughSignatories.selector);
        wallet.sendTransaction(1);
        vm.stopPrank();
    }

    function testSendTransactionPassesWhenThresholdIsReached() external proposeTxn {
        address anotherUser = makeAddr("another-user");
        vm.startPrank(anotherUser);
        wallet.addSigner(anotherUser);
        wallet.signTransaction(1);
        vm.stopPrank();

        address user3 = makeAddr("user3");
        vm.startPrank(user3);
        wallet.addSigner(user3);
        wallet.signTransaction(1);
        wallet.sendTransaction(1);
        vm.stopPrank();

        assert(wallet.getTransactionById(1).status == TransactionStatus.SENT);
    }

    function testSendTransactionSuccessEmitsTransactionSentStatus() external proposeTxnWithSufficientSigners {
        vm.expectEmit(true, true, false, false, address(wallet));
        emit TransactionStatusChange(1, TransactionStatus.SENT);
        vm.startPrank(user);
        wallet.sendTransaction(1);
        vm.stopPrank();
    }

}