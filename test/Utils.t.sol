pragma solidity 0.8.18;

import "forge-std/test.sol";
import "../src/utils/StakePadUtils.sol";

contract TestUtils is Test {
    uint96 public constant BASIS_PTS = 10000;
    uint256 public constant INIT_WITHDRAWAL_THRESHOLD =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 public constant TEST_WITHDRAWAL_THRESHOLD = 16 ether;
    uint256 MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public constant BEACON_DEPOSIT_CONTRACT_ADDRESS = 0x00000000219ab540356cBB839Cbe05303d7705Fa;

    address public owner = vm.addr(1);
    address public client = vm.addr(2);
    address public provider = vm.addr(3);
    address public account1 = vm.addr(4);
    address public account2 = vm.addr(5);
    address public account3 = vm.addr(6);
    address public testStakePad = vm.addr(7);

    uint96 comission = 1000; // 10% comission

    function _getRandomDepositParams(uint256 amount)
        internal
        pure
        returns (StakePadUtils.BeaconDepositParams[] memory depositDataArray, uint256 size)
    {
        depositDataArray = new StakePadUtils.BeaconDepositParams[](amount);
        for (uint256 i = 0; i < amount; i++) {
            StakePadUtils.BeaconDepositParams memory depositData;
            depositData.pubkey = new bytes(48);
            depositData.withdrawal_credentials = new bytes(32);
            depositData.signature = new bytes(96);
            depositData.deposit_data_root = bytes32(keccak256("RANDOM_DEPOSIT_DATA_ROOT"));
            depositData.depositValue = 32 ether;
            depositDataArray[i] = depositData;
        }
        size = depositDataArray.length;
    }

    /**
     * @dev fund all accounts with ether
     */
    function _fundEther() internal {
        vm.deal(owner, 1000 ether);
        vm.deal(account1, 1000 ether);
        vm.deal(account2, 1000 ether);
        vm.deal(account3, 1000 ether);
    }

    function _toBigEndian64(uint64 value) internal pure returns (bytes memory ret) {
        ret = new bytes(8);
        bytes8 bytesValue = bytes8(value);
        ret[0] = bytesValue[7];
        ret[1] = bytesValue[6];
        ret[2] = bytesValue[5];
        ret[3] = bytesValue[4];
        ret[4] = bytesValue[3];
        ret[5] = bytesValue[2];
        ret[6] = bytesValue[1];
        ret[7] = bytesValue[0];
    }

    // returns 32 bytes of padded account with 0x02 at the top
    function _withdrawalCredentialsFromAddress(address addr) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes1(0x02), bytes11(0x0), bytes20(addr));
    }

    function testOk() public {}
}
