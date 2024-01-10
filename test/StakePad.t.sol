pragma solidity 0.8.18;

import "forge-std/test.sol";
import "../src/RewardReceiver.sol";
import "../src/StakePadV1.sol";
import "../src/mocks/MockDepositContract.sol";

import "./Utils.t.sol";

contract StakePadTest is TestUtils {
    RewardReceiver public rewardReceiverImpl;
    StakePadV1 public stakePad;

    // mock beacon contract
    MockDepositContract public mockDepositContract;

    function setUp() public {
        _fundEther();
        mockDepositContract = new MockDepositContract();
        rewardReceiverImpl = new RewardReceiver();
        stakePad = new StakePadV1(address(mockDepositContract));
        vm.prank(owner);
        stakePad.initialize(address(rewardReceiverImpl));
    }

    function testCorrectInitialization() public {
        // implementation was set correctly
        require(
            stakePad.rewardReceiverImpl() == address(rewardReceiverImpl), "RewardReceiver address is not set correctly"
        );

        // beaconDeposit contract address was set correctly
        require(
            address(stakePad.beaconDeposit()) == address(mockDepositContract),
            "BeaconDepositContract address is not set correctly"
        );
        // owner was set correctly
        require(stakePad.owner() == owner, "Owner address is not set correctly");

        // cant initialized anymore
        vm.prank(owner);
        vm.expectRevert("Initializable: contract is already initialized");
        stakePad.initialize(address(rewardReceiverImpl));

        // cant initialize with zero address
        StakePadV1 newStakePad = new StakePadV1(BEACON_DEPOSIT_CONTRACT_ADDRESS);
        vm.prank(owner);
        vm.expectRevert("StakePadV1: new implementation is the zero address");
        newStakePad.initialize(address(0));
    }

    function testRetrieveEth() public {
        vm.deal(address(stakePad), 10 ether);
        uint256 balanceBefore = address(owner).balance;
        vm.prank(owner);
        stakePad.retrieveETH();
        uint256 balanceAfter = address(owner).balance;
        require(balanceAfter - balanceBefore == 10 ether, "Incorrect amount of ETH retrieved");
    }

    function testChangeOwnerShip() public {
        vm.prank(owner);
        stakePad.transferOwnership(account1);
        require(stakePad.owner() == account1, "Owner address is not set correctly");

        vm.prank(account1);
        vm.expectRevert("Ownable: new owner is the zero address");
        stakePad.transferOwnership(address(0));
    }

    function testMigrateImplementation() public {
        vm.prank(owner);
        RewardReceiver newRewardReceiverImpl = new RewardReceiver();
        vm.prank(owner);
        stakePad.updateRewardReceiverImpl(address(newRewardReceiverImpl));
        require(
            stakePad.rewardReceiverImpl() == address(newRewardReceiverImpl),
            "RewardReceiver address is not set correctly"
        );

        // cannot update to zero address
        vm.prank(owner);
        vm.expectRevert("StakePadV1: new implementation is the zero address");
        stakePad.updateRewardReceiverImpl(address(0));
    }

    function testDeployRewardReceivers() public {
        address client = account1;
        address provider = account2;
        uint96 comission = 1000;
        vm.prank(owner);
        vm.recordLogs();
        stakePad.deployNewRewardReceiver(client, provider, comission);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        (address newRewardReceiver,,,) =
            abi.decode(entries[entries.length - 1].data, (address, address, address, uint96));

        require(stakePad.isRegisteredRewardReceiver(newRewardReceiver), "RewardReceiver was not registered");

        // check initialization of rewards contract
        require(RewardReceiver(payable(newRewardReceiver)).client() == client, "Client address is not set correctly");
        require(
            RewardReceiver(payable(newRewardReceiver)).provider() == provider, "Provider address is not set correctly"
        );
        require(RewardReceiver(payable(newRewardReceiver)).comission() == comission, "Comission is not set correctly");
        require(RewardReceiver(payable(newRewardReceiver)).owner() == owner, "Owner address is not set correctly");
    }

    function testCannotRenounceOwnership() public {
        vm.prank(owner);
        vm.expectRevert("StakePadV1: cannot renounce ownership");
        stakePad.renounceOwnership();
    }

    function testUpgradeTo() public {
        StakePadV1 newStakePad = new StakePadV1(BEACON_DEPOSIT_CONTRACT_ADDRESS);
        vm.expectRevert("Function must be called through delegatecall");
        stakePad.upgradeTo(address(newStakePad));
    }

    function testFundValidators() public {
        //deposit single
        (StakePadUtils.BeaconDepositParams[] memory depositDataArray,) = _getRandomDepositParams(1);

        vm.prank(account1);
        vm.expectRevert("StakePadV1: incorrect amount of ETH");
        stakePad.fundValidators{value: 31 ether}(depositDataArray);

        address client = account1;
        address provider = account2;
        uint96 comission = 1000;
        vm.prank(owner);
        vm.recordLogs();
        stakePad.deployNewRewardReceiver(client, provider, comission);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        (address newRewardReceiver,,,) =
            abi.decode(entries[entries.length - 1].data, (address, address, address, uint96));

        bytes memory withdrawalCredentials = _withdrawalCredentialsFromAddress(newRewardReceiver);

        //invalid withdrawal credentials address
        vm.prank(account1);
        vm.expectRevert("StakePadV1: invalid withdrawal_credentials");
        stakePad.fundValidators{value: 32 ether}(depositDataArray);

        //invalid length of withdrawal credentials
        depositDataArray[0].withdrawal_credentials = new bytes(1);

        vm.prank(account1);
        vm.expectRevert("StakePadV1: invalid withdrawal_credentials length");
        stakePad.fundValidators{value: 32 ether}(depositDataArray);

        depositDataArray[0].withdrawal_credentials = withdrawalCredentials;

        // withdrawal credentials are correct, invalid pub key now
        bytes memory tempPubKey = depositDataArray[0].pubkey;
        depositDataArray[0].pubkey = new bytes(1);
        vm.prank(account1);
        vm.expectRevert("StakePadV1: invalid pubkey length");
        stakePad.fundValidators{value: 32 ether}(depositDataArray);

        vm.recordLogs();
        depositDataArray[0].pubkey = tempPubKey;
        vm.prank(account1);
        stakePad.fundValidators{value: 32 ether}(depositDataArray);
        entries = vm.getRecordedLogs();

        // check logs
        require(entries.length == 1, "Incorrect number of events");
        (,,,, bytes memory index) = abi.decode(entries[0].data, (bytes, bytes, bytes, bytes, bytes));
        require(uint64(bytes8(_toBigEndian64(uint64(bytes8(index))))) == 0);
    }

    function testOthers() public {
        vm.prank(account1);
        vm.expectRevert("Function must be called through delegatecall");
        stakePad.upgradeToAndCall(address(0), new bytes(0));

        vm.prank(account1);
        require(stakePad.proxiableUUID() == _IMPLEMENTATION_SLOT, "Incorrect implementation slot");
    }
}
