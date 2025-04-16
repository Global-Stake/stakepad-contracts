// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import "../src/StakePadUpgradeableProxy.sol";
import "../src/RewardReceiver.sol";
import "../src/StakePadV1.sol";

contract DeployScript is Script {
    address constant DEPOSIT_CONTRACT = 0x00000000219ab540356cBB839Cbe05303d7705Fa; // real address in hoodi

    function setUp() public {}

    function run() public {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPk);
        RewardReceiver rewardReceiverImpl = new RewardReceiver();
        StakePadV1 stakePad = new StakePadV1(DEPOSIT_CONTRACT);
        StakePadUpgradeableProxy stakePadProxy = new StakePadUpgradeableProxy(
            address(stakePad), abi.encodeWithSignature("initialize(address)", address(rewardReceiverImpl))
        );
        if (vm.envAddress("STAKE_PAD_ADMIN_WALLET") != vm.addr(deployerPk)) {
            StakePadV1(address(stakePadProxy)).transferOwnership(vm.envAddress("STAKE_PAD_ADMIN_WALLET"));
        }
        vm.stopBroadcast();
    }

    // to avoid in coverage
    function test() public {}
}
