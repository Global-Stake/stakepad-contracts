// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import "./Utils.t.sol";
import "../src/RewardReceiver.sol";

contract ContractWithdrawerNoReceive {}

contract ContractWithdrawerReceive {
    receive() external payable {}
}

contract SampleAttackContract {
    receive() external payable {
        RewardReceiver(payable(msg.sender)).withdraw();
    }
}

contract RewardReceiverTest is TestUtils {
    RewardReceiver public rewardReceiver;

    function setUp() public {
        _fundEther();

        // perform operations from owner
        vm.startPrank(owner);
        rewardReceiver = new RewardReceiver();
        rewardReceiver.initialize(client, provider, commission, testStakePad);
        vm.stopPrank();
    }

    function testContractInitializedCorrectly() public {
        require(rewardReceiver.client() == client, "client not set correctly");
        require(
            rewardReceiver.provider() == provider,
            "provider not set correctly"
        );
        require(
            rewardReceiver.commission() == commission,
            "commission not set correctly"
        );
    }

    function testTransferOwnership() public {
        // fails to transfer ownership when not the owner
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(0x118cdaa7, client));
        rewardReceiver.transferOwnership(account1);

        // fails to transfer ownership to the zero address
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(0x1e4fbdf7, address(0)));
        rewardReceiver.transferOwnership(address(0));

        // succeeds to transfer ownership to a new address
        vm.prank(owner);
        rewardReceiver.transferOwnership(account1);
        require(
            rewardReceiver.owner() == account1,
            "owner not updated correctly"
        );

        //fails to renounce ownership
        vm.prank(owner);
        vm.expectRevert("RewardReceiver: renounceOwnership is disabled");
        rewardReceiver.renounceOwnership();
    }

    function testCannotInitializeTwice() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(0xf92ee8a9));
        rewardReceiver.initialize(client, provider, commission, testStakePad);
        vm.stopPrank();
    }

    function testCannotInitializeWithWrongParams() public {
        RewardReceiver testRewardReceiver = new RewardReceiver();

        vm.startPrank(owner);
        vm.expectRevert("RewardReceiver: client is the zero address");
        testRewardReceiver.initialize(
            address(0),
            provider,
            commission,
            testStakePad
        );
        vm.expectRevert("RewardReceiver: provider is the zero address");
        testRewardReceiver.initialize(
            client,
            address(0),
            commission,
            testStakePad
        );
        vm.expectRevert("RewardReceiver: invalid percentage");
        testRewardReceiver.initialize(client, provider, 10001, testStakePad);
        vm.expectRevert("RewardReceiver: invalid percentage");
        testRewardReceiver.initialize(client, provider, 0, testStakePad);
        vm.expectRevert("RewardReceiver: stakePad is the zero address");
        testRewardReceiver.initialize(client, provider, commission, address(0));

        // passing correct params should work
        testRewardReceiver.initialize(
            client,
            provider,
            commission,
            testStakePad
        );
    }

    function testMigrateCommission() public {
        // fails to propose a newCommission when not the owner or provider
        vm.prank(client);
        vm.expectRevert("RewardReceiver: caller is not the owner or provider");
        rewardReceiver.proposeNewCommission(commission * 2);

        // fails to propose a newCommission when new commission is 0
        vm.prank(owner);
        vm.expectRevert("RewardReceiver: invalid percentage");
        rewardReceiver.proposeNewCommission(0);

        // fails to propose a newCommission when new commission more than 100%
        vm.prank(owner);
        vm.expectRevert("RewardReceiver: invalid percentage");
        rewardReceiver.proposeNewCommission(10001);

        // faiils to accept a commission when the commission is 0
        vm.prank(client);
        vm.expectRevert("RewardReceiver: invalid percentage");
        rewardReceiver.acceptNewCommission();

        // accepts a new incoming commission
        uint256 ss = vm.snapshot();
        vm.prank(owner);
        rewardReceiver.proposeNewCommission(commission * 2);
        vm.prank(client);
        rewardReceiver.acceptNewCommission();

        require(
            rewardReceiver.commission() == commission * 2,
            "commission not updated correctly"
        );

        // allows provider to also propose new commission
        vm.revertTo(ss);
        vm.prank(provider);
        rewardReceiver.proposeNewCommission(commission * 2);
        vm.prank(client);
        rewardReceiver.acceptNewCommission();

        require(
            rewardReceiver.commission() == commission * 2,
            "commission not updated correctly"
        );
    }

    function testMigrateWithdrawalThreshold() public {
        // fails to propose a newWithdrawalThreshold when not the owner or provider
        vm.prank(client);
        vm.expectRevert("RewardReceiver: caller is not the owner or provider");
        rewardReceiver.proposeNewWithdrawalThreshold(
            TEST_WITHDRAWAL_THRESHOLD * 2
        );

        // fails to propose a newWithdrawalThreshold if this is 0
        vm.prank(owner);
        vm.expectRevert("RewardReceiver: invalid withdrawal threshold");
        rewardReceiver.proposeNewWithdrawalThreshold(0);

        // faiils to accept a newWithdrawalThreshold when the newWithdrawalThreshold is 0
        vm.prank(client);
        vm.expectRevert("RewardReceiver: invalid withdrawal threshold");
        rewardReceiver.acceptNewWithdrawalThreshold();

        // accepts a new incoming newWithdrawalThreshold
        uint256 ss = vm.snapshot();
        vm.prank(owner);
        rewardReceiver.proposeNewWithdrawalThreshold(
            TEST_WITHDRAWAL_THRESHOLD * 2
        );
        vm.prank(client);
        rewardReceiver.acceptNewWithdrawalThreshold();
        require(
            rewardReceiver.withdrawalThreshold() ==
                TEST_WITHDRAWAL_THRESHOLD * 2,
            "withdrawalThreshold not updated correctly"
        );

        // allows provider to also propose new newWithdrawalThreshold
        vm.revertTo(ss);
        vm.prank(provider);
        rewardReceiver.proposeNewWithdrawalThreshold(
            TEST_WITHDRAWAL_THRESHOLD * 2
        );
        vm.prank(client);
        rewardReceiver.acceptNewWithdrawalThreshold();
        require(
            rewardReceiver.withdrawalThreshold() ==
                TEST_WITHDRAWAL_THRESHOLD * 2,
            "withdrawalThreshold not updated correctly"
        );
    }

    function testWithdrawReentrancy() public {
        RewardReceiver newRewardReceiver = new RewardReceiver();
        SampleAttackContract sampleAttackContract = new SampleAttackContract();
        vm.deal(address(newRewardReceiver), 10 ether);
        vm.prank(owner);
        newRewardReceiver.initialize(
            address(sampleAttackContract),
            provider,
            commission,
            testStakePad
        );
        vm.prank(owner);
        newRewardReceiver.withdraw();
        vm.prank(address(sampleAttackContract));
        vm.expectRevert("RewardReceiver: transfer failed");
        newRewardReceiver.claimClient();
    }

    function testWithdrawPercentage() public {
        vm.deal(address(rewardReceiver), 100 wei);
        vm.expectRevert("RewardReceiver: invalid percentage");
        vm.prank(owner);
        rewardReceiver.percentageWithdraw(10001);

        vm.expectRevert("RewardReceiver: invalid percentage");
        vm.prank(owner);
        rewardReceiver.percentageWithdraw(0);

        vm.expectRevert("RewardReceiver: amount too low");
        vm.prank(owner);
        rewardReceiver.percentageWithdraw(1);

        vm.deal(address(rewardReceiver), 16 ether);
        uint256 sp = vm.snapshot();
        uint256 balanceBefore = address(rewardReceiver).balance;
        vm.prank(owner);
        rewardReceiver.percentageWithdraw(1000);
        uint256 balanceAfter = address(rewardReceiver).balance;
        require(
            balanceBefore - balanceAfter == 16 ether / 10,
            "Incorrect amount of ETH retrieved"
        );

        vm.revertTo(sp);
        vm.prank(owner);
        rewardReceiver.percentageWithdraw(10000);
        require(
            address(rewardReceiver).balance == 0,
            "rewardReceiver not empty"
        );
        require(
            rewardReceiver.totalClaimedProvider() == 16 ether,
            "percentage withdraw did not record provider claim"
        );
        require(
            rewardReceiver.feeAccountedRewards() == 16 ether,
            "percentage withdraw did not account rewards"
        );
        require(
            rewardReceiver.lifetimeReceived() == 16 ether,
            "percentage withdraw changed lifetime received"
        );
    }

    function testWithdraw() public {
        // fails to withdraw when not the owner or provider or client
        vm.prank(account1);
        vm.expectRevert(
            "RewardReceiver: caller is not the owner, client or provider"
        );
        rewardReceiver.withdraw();

        // fails to withdraw when balance is too low
        vm.prank(owner);
        vm.expectRevert("RewardReceiver: no funds to allocate");
        rewardReceiver.withdraw();

        // allocation succeeds even when the client cannot receive ETH
        RewardReceiver testRewardReceiver = new RewardReceiver();
        ContractWithdrawerNoReceive sampleContractWithdrawer = new ContractWithdrawerNoReceive();
        vm.prank(owner);
        testRewardReceiver.initialize(
            address(sampleContractWithdrawer),
            provider,
            commission,
            testStakePad
        );
        vm.deal(address(testRewardReceiver), TEST_WITHDRAWAL_THRESHOLD * 2);
        vm.prank(owner);
        testRewardReceiver.withdraw();
        require(testRewardReceiver.claimableClient() > 0, "client claimable not allocated");
        require(testRewardReceiver.claimableProvider() > 0, "provider claimable not allocated");

        vm.prank(provider);
        testRewardReceiver.claimProvider();
        vm.prank(address(sampleContractWithdrawer));
        vm.expectRevert("RewardReceiver: transfer failed");
        testRewardReceiver.claimClient();

        // succeeds to withdraw if the transfer function succeeds
        testRewardReceiver = new RewardReceiver();
        ContractWithdrawerReceive sampleContractWithdrawerReceive = new ContractWithdrawerReceive();
        vm.prank(owner);
        testRewardReceiver.initialize(
            address(sampleContractWithdrawerReceive),
            provider,
            commission,
            testStakePad
        );
        vm.deal(address(testRewardReceiver), TEST_WITHDRAWAL_THRESHOLD * 2);
        vm.prank(owner);
        testRewardReceiver.withdraw();
        vm.prank(provider);
        testRewardReceiver.claimProvider();
        vm.prank(address(sampleContractWithdrawerReceive));
        testRewardReceiver.claimClient();

        // CHECK AMOUNTS transferred
        vm.deal(address(rewardReceiver), 16 ether - 1);

        // ----DATA BEFORE----
        uint256 rewardReceiverBalanceBefore = address(rewardReceiver).balance;
        uint256 providerBalanceBefore = address(provider).balance;
        uint256 clientBalanceBefore = address(client).balance;

        // ----PERFORM CALL---
        vm.prank(owner);
        rewardReceiver.withdraw();
        vm.prank(provider);
        rewardReceiver.claimProvider();
        vm.prank(client);
        rewardReceiver.claimClient();

        // ----DATA AFTER----
        uint256 rewardReceiverBalanceAfter = address(rewardReceiver).balance;
        uint256 providerBalanceAfter = address(provider).balance;
        uint256 clientBalanceAfter = address(client).balance;

        // ----PERFORM CHECKS----
        require(
            providerBalanceBefore +
                (rewardReceiverBalanceBefore * rewardReceiver.commission()) /
                BASIS_PTS ==
                providerBalanceAfter,
            "withdrawn amount not correct"
        );
        require(rewardReceiverBalanceAfter == 0, "rewardReceiver not empty");
        require(
            clientBalanceBefore +
                rewardReceiverBalanceBefore -
                (rewardReceiverBalanceBefore * rewardReceiver.commission()) /
                BASIS_PTS ==
                clientBalanceAfter,
            "withdrawn amount not correct"
        );

        // CHECK AMOUNTS transferred
        vm.deal(address(rewardReceiver), 1);

        // ----DATA BEFORE----
        rewardReceiverBalanceBefore = address(rewardReceiver).balance;
        providerBalanceBefore = address(provider).balance;
        clientBalanceBefore = address(client).balance;

        // ----PERFORM CALL--- succeeds and assigns dust to the client
        vm.prank(owner);
        rewardReceiver.withdraw();
        require(rewardReceiver.claimableClient() == 1, "dust not allocated to client");
        require(rewardReceiver.claimableProvider() == 0, "dust allocated to provider");
        vm.prank(client);
        rewardReceiver.claimClient();
        require(address(rewardReceiver).balance == 0, "rewardReceiver not empty");
        require(clientBalanceBefore + 1 == address(client).balance, "dust not claimed");

        RewardReceiver thresholdReceiver = new RewardReceiver();
        vm.prank(owner);
        thresholdReceiver.initialize(client, provider, commission, testStakePad);

        // CHECK AMOUNTS transferred
        vm.deal(address(thresholdReceiver), 20 ether);

        // ----DATA BEFORE----
        rewardReceiverBalanceBefore = address(thresholdReceiver).balance;
        providerBalanceBefore = address(provider).balance;
        clientBalanceBefore = address(client).balance;

        // ----UPDATE WITHDRAWAL THRESHOLD----

        vm.prank(owner);
        thresholdReceiver.proposeNewWithdrawalThreshold(TEST_WITHDRAWAL_THRESHOLD);
        vm.prank(client);
        thresholdReceiver.acceptNewWithdrawalThreshold();

        // ----PERFORM CALL---
        vm.prank(owner);
        thresholdReceiver.withdraw();
        vm.prank(provider);
        thresholdReceiver.claimProvider();
        vm.prank(client);
        thresholdReceiver.claimClient();

        // ----DATA AFTER----
        rewardReceiverBalanceAfter = address(thresholdReceiver).balance;
        providerBalanceAfter = address(provider).balance;
        clientBalanceAfter = address(client).balance;

        // ----PERFORM CHECKS----
        require(
            providerBalanceBefore +
                ((rewardReceiverBalanceBefore - TEST_WITHDRAWAL_THRESHOLD) *
                    thresholdReceiver.commission()) /
                BASIS_PTS ==
                providerBalanceAfter,
            "withdrawn amount not correct"
        );
        require(rewardReceiverBalanceAfter == 0, "rewardReceiver not empty");
        require(
            clientBalanceBefore +
                (rewardReceiverBalanceBefore) -
                ((rewardReceiverBalanceBefore - TEST_WITHDRAWAL_THRESHOLD) *
                    thresholdReceiver.commission()) /
                BASIS_PTS ==
                clientBalanceAfter,
            "withdrawn amount not correct"
        );
    }

    function testReceiveAndWithdrawEmitStructuredEvents() public {
        vm.recordLogs();
        vm.prank(owner);
        (bool success,) = address(rewardReceiver).call{value: 1 ether}("");
        require(success, "funding failed");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        require(entries.length == 1, "receive event not emitted");

        vm.recordLogs();
        vm.prank(owner);
        rewardReceiver.withdraw();
        entries = vm.getRecordedLogs();
        require(entries.length == 1, "allocation event not emitted");
    }

    function testCannotWithdrawWhenPending() public {
        vm.deal(address(rewardReceiver), 16 ether);
        vm.prank(owner);
        rewardReceiver.proposeNewCommission(commission * 2);
        vm.prank(client);
        vm.expectRevert("RewardReceiver: pending state");
        rewardReceiver.withdraw();

        vm.prank(owner);
        rewardReceiver.proposeNewWithdrawalThreshold(
            TEST_WITHDRAWAL_THRESHOLD / 2
        );
        vm.prank(client);
        vm.expectRevert("RewardReceiver: pending state");
        rewardReceiver.withdraw();
    }

    function testCancelPendingCommissionAndWithdrawalThreshold() public {
        require(rewardReceiver.pendingCommission() == 0);
        vm.prank(owner);
        rewardReceiver.proposeNewCommission(commission * 2);
        require(rewardReceiver.pendingCommission() == commission * 2);
        vm.prank(provider);
        rewardReceiver.cancelNewCommission();
        require(rewardReceiver.pendingCommission() == 0);

        require(rewardReceiver.pendingWithdrawalThreshold() == 0);
        vm.prank(owner);
        rewardReceiver.proposeNewWithdrawalThreshold(TEST_WITHDRAWAL_THRESHOLD);
        require(
            rewardReceiver.pendingWithdrawalThreshold() ==
                TEST_WITHDRAWAL_THRESHOLD
        );

        vm.prank(provider);
        rewardReceiver.cancelNewWithdrawalThreshold();
        require(rewardReceiver.pendingWithdrawalThreshold() == 0);
    }

    function testFuzzWithdrawal(uint256 balanceOfContract) public {
        vm.assume(balanceOfContract < 1_000_000 ether);
        // CHECK AMOUNTS transferred
        vm.deal(address(rewardReceiver), balanceOfContract);

        // ----UPDATE WITHDRAWAL THRESHOLD----

        vm.prank(owner);
        rewardReceiver.proposeNewWithdrawalThreshold(TEST_WITHDRAWAL_THRESHOLD);
        vm.prank(client);
        rewardReceiver.acceptNewWithdrawalThreshold();

        // ----DATA BEFORE----
        uint256 rewardReceiverBalanceBefore = address(rewardReceiver).balance;
        uint256 providerBalanceBefore = address(provider).balance;
        uint256 clientBalanceBefore = address(client).balance;

        // CALCUATE EXPECTED AMOUNTS
        uint256 commission;

        if (balanceOfContract > TEST_WITHDRAWAL_THRESHOLD) {
            commission =
                ((balanceOfContract - TEST_WITHDRAWAL_THRESHOLD) *
                    rewardReceiver.commission()) /
                BASIS_PTS;
        }

        // ----PERFORM CALL WITH CONDITIONAL REVERT---
        vm.prank(owner);
        if (balanceOfContract == 0) {
            vm.expectRevert("RewardReceiver: no funds to allocate");
            rewardReceiver.withdraw();
        } else {
            rewardReceiver.withdraw();
            if (commission > 0) {
                vm.prank(provider);
                rewardReceiver.claimProvider();
            }
            vm.prank(client);
            rewardReceiver.claimClient();
            // ----DATA AFTER----
            uint256 rewardReceiverBalanceAfter = address(rewardReceiver)
                .balance;
            uint256 providerBalanceAfter = address(provider).balance;
            uint256 clientBalanceAfter = address(client).balance;

            // ----PERFORM CHECKS----
            require(
                providerBalanceBefore + commission == providerBalanceAfter,
                "withdrawn amount not correct"
            );
            require(
                rewardReceiverBalanceAfter == 0,
                "rewardReceiver not empty"
            );
            require(
                clientBalanceBefore + balanceOfContract - commission ==
                    clientBalanceAfter,
                "withdrawn amount not correct"
            );
        }
    }

    function testUnauthorizedCallerCannotClaimClientOrProvider() public {
        vm.deal(address(rewardReceiver), 10 ether);
        vm.prank(owner);
        rewardReceiver.withdraw();

        vm.prank(account1);
        vm.expectRevert("RewardReceiver: caller is not the client");
        rewardReceiver.claimClient();

        vm.prank(account1);
        vm.expectRevert("RewardReceiver: caller is not the client");
        rewardReceiver.claimClient(payable(account1));

        vm.prank(account1);
        vm.expectRevert("RewardReceiver: caller is not the provider");
        rewardReceiver.claimProvider();

        vm.prank(account1);
        vm.expectRevert("RewardReceiver: caller is not the provider");
        rewardReceiver.claimProvider(payable(account1));
    }

    function testClientAndProviderCanClaimToAlternateRecipients() public {
        uint256 balanceOfContract = 10 ether;
        uint256 expectedProviderAmount = (balanceOfContract * rewardReceiver.commission()) / BASIS_PTS;
        uint256 expectedClientAmount = balanceOfContract - expectedProviderAmount;

        vm.deal(address(rewardReceiver), balanceOfContract);
        vm.prank(owner);
        rewardReceiver.withdraw();

        uint256 clientBalanceBefore = address(client).balance;
        uint256 providerBalanceBefore = address(provider).balance;
        uint256 clientRecipientBalanceBefore = address(account1).balance;
        uint256 providerRecipientBalanceBefore = address(account2).balance;

        vm.prank(client);
        rewardReceiver.claimClient(payable(account1));

        vm.prank(provider);
        rewardReceiver.claimProvider(payable(account2));

        require(address(account1).balance == clientRecipientBalanceBefore + expectedClientAmount, "client recipient incorrect");
        require(address(account2).balance == providerRecipientBalanceBefore + expectedProviderAmount, "provider recipient incorrect");
        require(address(client).balance == clientBalanceBefore, "client should not receive redirected claim");
        require(address(provider).balance == providerBalanceBefore, "provider should not receive redirected claim");
        require(rewardReceiver.claimableClient() == 0, "client claimable not cleared");
        require(rewardReceiver.claimableProvider() == 0, "provider claimable not cleared");
        require(rewardReceiver.totalClaimedClient() == expectedClientAmount, "total claimed client incorrect");
        require(rewardReceiver.totalClaimedProvider() == expectedProviderAmount, "total claimed provider incorrect");
    }

    function testClaimFailureDoesNotClearClaimableBalances() public {
        ContractWithdrawerNoReceive failingRecipient = new ContractWithdrawerNoReceive();
        uint256 balanceOfContract = 10 ether;

        vm.deal(address(rewardReceiver), balanceOfContract);
        vm.prank(owner);
        rewardReceiver.withdraw();

        uint256 claimableClientBefore = rewardReceiver.claimableClient();
        uint256 claimableProviderBefore = rewardReceiver.claimableProvider();

        vm.prank(client);
        vm.expectRevert("RewardReceiver: transfer failed");
        rewardReceiver.claimClient(payable(address(failingRecipient)));

        require(rewardReceiver.claimableClient() == claimableClientBefore, "failed client claim cleared balance");
        require(rewardReceiver.totalClaimedClient() == 0, "failed client claim updated total");

        vm.prank(provider);
        vm.expectRevert("RewardReceiver: transfer failed");
        rewardReceiver.claimProvider(payable(address(failingRecipient)));

        require(rewardReceiver.claimableProvider() == claimableProviderBefore, "failed provider claim cleared balance");
        require(rewardReceiver.totalClaimedProvider() == 0, "failed provider claim updated total");
    }

    function testMultipleWithdrawsBeforeClaimsDoNotDoubleCountCommission() public {
        uint256 firstBalance = 10 ether;
        uint256 secondBalance = 5 ether;
        uint256 firstCommission = (firstBalance * rewardReceiver.commission()) / BASIS_PTS;
        uint256 secondCommission = (secondBalance * rewardReceiver.commission()) / BASIS_PTS;

        vm.deal(address(rewardReceiver), firstBalance);
        vm.prank(owner);
        rewardReceiver.withdraw();

        vm.deal(address(rewardReceiver), firstBalance + secondBalance);
        vm.prank(owner);
        rewardReceiver.withdraw();

        require(
            rewardReceiver.claimableProvider() == firstCommission + secondCommission,
            "provider commission double-counted"
        );
        require(
            rewardReceiver.claimableClient() == firstBalance + secondBalance - firstCommission - secondCommission,
            "client claimable incorrect"
        );
        require(rewardReceiver.feeAccountedRewards() == firstBalance + secondBalance, "fee accounted rewards incorrect");

        vm.prank(provider);
        rewardReceiver.claimProvider();
        vm.prank(client);
        rewardReceiver.claimClient();

        require(address(rewardReceiver).balance == 0, "rewardReceiver not empty");
    }

    function testMultipleReceiveWithdrawClaimCyclesKeepAccountingCorrect() public {
        uint256 withdrawalThreshold = 16 ether;
        uint256 firstReceived = 17 ether;
        uint256 secondReceived = 2 ether;
        uint256 firstCommission = ((firstReceived - withdrawalThreshold) * rewardReceiver.commission()) / BASIS_PTS;
        uint256 secondCommission = (secondReceived * rewardReceiver.commission()) / BASIS_PTS;

        vm.prank(owner);
        rewardReceiver.proposeNewWithdrawalThreshold(withdrawalThreshold);
        vm.prank(client);
        rewardReceiver.acceptNewWithdrawalThreshold();

        uint256 providerBalanceBefore = address(provider).balance;
        uint256 clientBalanceBefore = address(client).balance;

        vm.prank(owner);
        (bool success,) = address(rewardReceiver).call{value: firstReceived}("");
        require(success, "first receive failed");

        vm.prank(owner);
        rewardReceiver.withdraw();
        vm.prank(provider);
        rewardReceiver.claimProvider();
        vm.prank(client);
        rewardReceiver.claimClient();

        require(address(provider).balance == providerBalanceBefore + firstCommission, "first provider claim incorrect");
        require(address(client).balance == clientBalanceBefore + firstReceived - firstCommission, "first client claim incorrect");
        require(rewardReceiver.feeAccountedRewards() == firstReceived - withdrawalThreshold, "first rewards incorrect");

        vm.prank(owner);
        (success,) = address(rewardReceiver).call{value: secondReceived}("");
        require(success, "second receive failed");

        vm.prank(owner);
        rewardReceiver.withdraw();
        vm.prank(provider);
        rewardReceiver.claimProvider();
        vm.prank(client);
        rewardReceiver.claimClient();

        require(
            address(provider).balance == providerBalanceBefore + firstCommission + secondCommission,
            "second provider claim incorrect"
        );
        require(
            address(client).balance == clientBalanceBefore + firstReceived + secondReceived - firstCommission - secondCommission,
            "second client claim incorrect"
        );
        require(rewardReceiver.totalClaimedProvider() == firstCommission + secondCommission, "provider total incorrect");
        require(
            rewardReceiver.totalClaimedClient() == firstReceived + secondReceived - firstCommission - secondCommission,
            "client total incorrect"
        );
        require(address(rewardReceiver).balance == 0, "rewardReceiver not empty");
    }

    function testAddValidators() public {
        vm.prank(account3);
        vm.expectRevert(
            "RewardReceiver: caller is not stakePad or provider or owner"
        );
        rewardReceiver.addValidator("0x1234");

        vm.prank(testStakePad);
        rewardReceiver.addValidator("0x12345");

        require(
            rewardReceiver.getValidators().length == 1,
            "validators not added correctly"
        );
        require(
            keccak256(rewardReceiver.getValidators()[0]) ==
                keccak256("0x12345"),
            "validators not added correctly"
        );

        vm.prank(testStakePad);
        rewardReceiver.addValidator("0x123456", 32 ether);
        require(
            rewardReceiver.withdrawalThreshold() == 32 ether,
            "protected principal not updated"
        );

        vm.prank(testStakePad);
        rewardReceiver.removeValidator(1);
        require(
            rewardReceiver.withdrawalThreshold() == 0,
            "protected principal not released on remove"
        );
        require(
            rewardReceiver.getValidators().length == 1,
            "validator not removed"
        );
    }

    function testRemoveValidators() public {
        vm.prank(testStakePad);
        rewardReceiver.addValidator("0x12345");

        vm.prank(testStakePad);
        rewardReceiver.addValidator("0x123456");

        vm.prank(testStakePad);
        rewardReceiver.addValidator("0x1234567");
        require(
            rewardReceiver.getValidators().length == 3,
            "validators not added correctly"
        );

        vm.prank(testStakePad);
        vm.expectRevert("RewardReceiver : invalid index");
        rewardReceiver.removeValidator(3);

        vm.prank(account3);
        vm.expectRevert(
            "RewardReceiver: caller is not stakePad or provider or owner"
        );
        rewardReceiver.removeValidator(0);

        vm.prank(testStakePad);
        rewardReceiver.removeValidator(0);

        require(
            rewardReceiver.getValidators().length == 2,
            "validators not removed correctly"
        );

        bytes memory validator1 = rewardReceiver.getValidators()[0];
        bytes memory validator2 = rewardReceiver.getValidators()[1];

        require(
            keccak256(validator2) == keccak256("0x123456"),
            "validators not removed correctly"
        );
        require(
            keccak256(validator1) == keccak256("0x1234567"),
            "validators not removed correctly"
        );

        vm.prank(testStakePad);
        rewardReceiver.removeValidator(1);

        require(
            rewardReceiver.getValidators().length == 1,
            "validators not removed correctly"
        );
        bytes memory validator3 = rewardReceiver.getValidators()[0];
        require(
            keccak256(validator3) == keccak256("0x1234567"),
            "validators not removed correctly"
        );
    }

    function testRemoveValidatorDoesNotDropAccountedPrincipal() public {
        vm.prank(testStakePad);
        rewardReceiver.addValidator("0xabc", 32 ether);

        vm.deal(address(rewardReceiver), 32.2 ether);
        vm.prank(owner);
        rewardReceiver.withdraw();
        vm.prank(provider);
        rewardReceiver.claimProvider();
        vm.prank(client);
        rewardReceiver.claimClient();

        uint256 thresholdAfterExit = rewardReceiver.withdrawalThreshold();
        require(thresholdAfterExit == 32 ether, "threshold should still protect returned principal");

        vm.prank(testStakePad);
        rewardReceiver.removeValidator(0);
        require(
            rewardReceiver.withdrawalThreshold() == 32 ether,
            "remove after unstake must not unprotect already-received principal"
        );
    }

    function testChangeStakePad() public {
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(0x118cdaa7, client));
        rewardReceiver.changeStakePad(testStakePad);

        vm.prank(owner);
        rewardReceiver.changeStakePad(account3);

        require(
            rewardReceiver.stakePad() == account3,
            "stakePad not updated correctly"
        );
    }

    function testFuzzMigrateCommissionOrThreshold(
        uint96 newInputCommission,
        uint96 newInputThreshold
    ) public {
        if (newInputCommission > BASIS_PTS || newInputCommission == 0) {
            vm.prank(owner);
            vm.expectRevert("RewardReceiver: invalid percentage");
            rewardReceiver.proposeNewCommission(newInputCommission);
        } else {
            if (newInputThreshold == 0) {
                vm.prank(owner);
                vm.expectRevert("RewardReceiver: invalid withdrawal threshold");
                rewardReceiver.proposeNewWithdrawalThreshold(newInputThreshold);
            } else {
                vm.prank(owner);
                rewardReceiver.proposeNewCommission(newInputCommission);
                vm.prank(owner);
                rewardReceiver.proposeNewWithdrawalThreshold(newInputThreshold);
                vm.prank(client);
                rewardReceiver.acceptNewWithdrawalThreshold();
                vm.prank(client);
                rewardReceiver.acceptNewCommission();

                require(
                    rewardReceiver.commission() == newInputCommission,
                    "commission not updated correctly"
                );
                require(
                    rewardReceiver.withdrawalThreshold() == newInputThreshold,
                    "withdrawalThreshold not updated correctly"
                );
                require(
                    rewardReceiver.pendingCommission() == 0,
                    "pendingCommission not updated correctly"
                );
                require(
                    rewardReceiver.pendingWithdrawalThreshold() == 0,
                    "pendingWithdrawalThreshold not updated correctly"
                );
            }
        }
    }
}
