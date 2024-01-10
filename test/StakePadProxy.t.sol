pragma solidity 0.8.18;

import "../src/StakePadV1.sol";
import "../src/StakePadUpgradeableProxy.sol";
import "../src/mocks/MockDepositContract.sol";
import "./Utils.t.sol";
import "../src/RewardReceiver.sol";

contract StakePadTest is TestUtils {
    StakePadV1 public stakePad;
    StakePadUpgradeableProxy public stakePadProxy;
    RewardReceiver public rewardReceiverImpl;

    // mock beacon contract
    MockDepositContract public mockDepositContract;

    function setUp() public {
        rewardReceiverImpl = new RewardReceiver();
        mockDepositContract = new MockDepositContract();
        stakePad = new StakePadV1(address(mockDepositContract));
        stakePadProxy = new StakePadUpgradeableProxy(
            address(stakePad), abi.encodeWithSignature("initialize(address)", address(rewardReceiverImpl))
        );
    }

    function testInitializedCorrectly() public {
        require(StakePadV1(address(stakePadProxy)).owner() == address(this));
        require(address(StakePadV1(address(stakePadProxy)).beaconDeposit()) == address(mockDepositContract));
        require(StakePadV1(address(stakePadProxy)).rewardReceiverImpl() == address(rewardReceiverImpl));
    }

    function testCannotInitializeAgain() public {
        vm.expectRevert("Initializable: contract is already initialized");
        StakePadV1(address(stakePadProxy)).initialize(address(0x1));
    }

    function testUpgradeability() public {
        StakePadV1 newStakePad = new StakePadV1(address(mockDepositContract));
        StakePadV1(address(stakePadProxy)).upgradeTo(address(newStakePad));
        require(stakePadProxy.implementation() == address(newStakePad), "StakePadV1: upgradeTo not working");
        require(StakePadV1(address(stakePadProxy)).owner() == address(this));
        require(address(StakePadV1(address(stakePadProxy)).beaconDeposit()) == address(mockDepositContract));
        require(StakePadV1(address(stakePadProxy)).rewardReceiverImpl() == address(rewardReceiverImpl));

        MockDepositContract newMockDepositContract = new MockDepositContract();
        newStakePad = new StakePadV1(address(newMockDepositContract));
        RewardReceiver newRewardReceiverImpl = new RewardReceiver();
        vm.expectRevert("Initializable: contract is already initialized");
        StakePadV1(address(stakePadProxy)).upgradeToAndCall(
            address(newStakePad), abi.encodeWithSignature("initialize(address)", address(newRewardReceiverImpl))
        );
        StakePadV1(address(stakePadProxy)).upgradeTo(address(newStakePad));
        require(address(StakePadV1(address(stakePadProxy)).beaconDeposit()) == address(newMockDepositContract));
        require(StakePadV1(address(stakePadProxy)).rewardReceiverImpl() == address(rewardReceiverImpl));
    }
}
