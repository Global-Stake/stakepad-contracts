// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import "../src/StakePadUpgradeableProxy.sol";
import "../src/RewardReceiver.sol";
import "../src/interfaces/IStakePad.sol";
import "../src/mocks/MockDepositContract.sol";

contract DeployScript is Script {
    IStakePad public stakePad = IStakePad(0x4265b719f9f92508440dBC144a237e31Bb115EF0);
    address public client = 0x2918f73136Cf6bD284D51B847e680c28319eD3c3; // dev account 1
    address public provider = 0xDeA40BE986dE36CDb271e34ae04036AAE9fA5639; // dev account 2
    uint96 public commission = 1000;

    function setUp() public {}

    function run() public {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPk);
        stakePad.deployNewRewardReceiver(client, provider, commission);
        vm.stopBroadcast();
    }

    // to avoid in coverage
    function test() public {}
}
