pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/interfaces/IStakePad.sol";
import "../src/utils/StakePadUtils.sol";

contract TestFailTxScript is Script {
    IStakePad stakepad = IStakePad(0x5F35Be9209015CC38A13babdF79C258E64b71666);

    function run() public {
        uint256 pk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(pk);
        console.logString("----------TEST SCRIPT--------");
        StakePadUtils.BeaconDepositParams[] memory beaconDepositParams =
            abi.decode(vm.envBytes("TX_INPUT_DATA"), (StakePadUtils.BeaconDepositParams[]));

        stakepad.fundValidators{value: 100 wei}(beaconDepositParams);
        vm.stopBroadcast();
    }

    // avoid on test
    function test() public {}
}
