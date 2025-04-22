// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import "../src/StakePadUpgradeableProxy.sol";
import "../src/RewardReceiver.sol";
import "../src/test/TestStakePadV1.sol";
import "../src/mocks/MockDepositContract.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPk);
        RewardReceiver rewardReceiverImpl = new RewardReceiver();
        MockDepositContract mockDepositContract = new MockDepositContract();
        TestStakePadV1 stakePad = new TestStakePadV1(address(mockDepositContract));
        StakePadUpgradeableProxy stakePadProxy = new StakePadUpgradeableProxy(
            address(stakePad), abi.encodeWithSignature("initialize(address)", address(rewardReceiverImpl))
        );
        if (vm.envAddress("STAKE_PAD_ADMIN_WALLET") != vm.addr(deployerPk)) {
            TestStakePadV1(payable(stakePadProxy)).transferOwnership(vm.envAddress("STAKE_PAD_ADMIN_WALLET"));
        }
        vm.stopBroadcast();
    }

    // to avoid in coverage
    function test() public {}
}
