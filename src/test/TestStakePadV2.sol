// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../utils/StakePadUtils.sol";
import "../interfaces/IRewardReceiver.sol";
import "../interfaces/IDepositContract.sol";
import "../interfaces/IStakePad.sol";

/**
 * @title TestStakePadV2
 * @author Quantum3 Labs
 * @notice V2 of StakePad contracts - ONLY FOR TESTING PURPOSES - DO NOT USE IN PRODUCTION
 * @notice test upgradeability -  a new function setNewVariableAdded, see test/ForkTest.sol for more details
 */
contract TestStakePadV2 is IStakePad, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    IDepositContract public immutable beaconDeposit;
    address internal _rewardReceiverImpl;
    EnumerableSet.AddressSet internal _rewardReceivers;

    // VARIABLES ADDED FOR UPGRADEABILITY
    uint256 public newVariable;

    constructor(address _beaconDeposit) {
        // no checks on zero address
        beaconDeposit = IDepositContract(_beaconDeposit);
    }

    /**
     * @notice initilizes the owner and the implementation of the rewardReceiverContract
     * @param newRewardReceiverImpl the implementation of the rewardReceiverContract
     */
    function initialize(address newRewardReceiverImpl) external initializer {
        _updateRewardReceiverImpl(newRewardReceiverImpl);
        __Ownable_init();
    }

    /**
     * @notice creates a contract that will receive the rewards
     * @param client Beneficiary of the rewards
     * @param provider Account on behalf of this contract
     * @param comission percentage of the rewards that will be sent to the provider
     */
    function deployNewRewardReceiver(address client, address provider, uint96 comission) external override onlyOwner {
        address newRewardReceiver = Clones.clone(rewardReceiverImpl());
        IRewardReceiver(newRewardReceiver).initialize(client, provider, comission, address(this));
        IRewardReceiver(newRewardReceiver).transferOwnership(owner());
        _rewardReceivers.add(newRewardReceiver);
        emit NewRewardReceiver(_rewardReceivers.length(), newRewardReceiver, client, provider, comission);
    }

    function setNewVariable(uint256 variable) external onlyOwner {
        newVariable = variable;
    }

    /**
     * @notice funds a set of validators with 32 ETH each
     * @param DepositDataArray Array of DepositData. See StakePadUtils.sol
     */
    function fundValidators(StakePadUtils.BeaconDepositParams[] calldata DepositDataArray) external payable override {
        require(msg.value == 32 ether * DepositDataArray.length, "StakePadV1: incorrect amount of ETH");
        for (uint256 i = 0; i < DepositDataArray.length; ++i) {
            StakePadUtils.BeaconDepositParams calldata DepositData = DepositDataArray[i];
            _validateWithdrawalCredentials(DepositData.withdrawal_credentials);
            _addValidatorPubKey(DepositData.pubkey, DepositData.withdrawal_credentials);
            beaconDeposit.deposit{value: 32 ether}(
                DepositData.pubkey,
                DepositData.withdrawal_credentials,
                DepositData.signature,
                DepositData.deposit_data_root
            );
        }
    }

    /**
     * @dev Updates the implementation of the Reward Receiver Contract
     * @param newRewardReceiverImpl the implementation of the Reward Receiver Contract
     */
    function updateRewardReceiverImpl(address newRewardReceiverImpl) external onlyOwner {
        _updateRewardReceiverImpl(newRewardReceiverImpl);
    }

    function owner() public view override(OwnableUpgradeable, IStakePad) returns (address) {
        return super.owner();
    }

    /**
     * @param rewardReceiver withdrawal address
     * @dev helper function users can call to check anytime before calling fundValidators()
     */
    function isRegisteredRewardReceiver(address rewardReceiver) external view returns (bool) {
        return _isRegisteredRewardReceiver(rewardReceiver);
    }

    function transferOwnership(address newOwner) public override(OwnableUpgradeable, IStakePad) onlyOwner {
        super.transferOwnership(newOwner);
    }

    function updateDepositContract() external onlyOwner {}

    /**
     * @dev Renouncing ownership is not allowed
     */
    function renounceOwnership() public view override onlyOwner {
        revert("StakePadV1: cannot renounce ownership");
    }

    /**
     * @dev Returns the implementation of the Reward Receiver Contract.
     */
    function rewardReceiverImpl() public view returns (address) {
        return _rewardReceiverImpl;
    }

    function _validateWithdrawalCredentials(bytes calldata withdrawalCredentials) internal view {
        require(withdrawalCredentials.length == 32, "StakePadV1: invalid withdrawal_credentials length");

        address withdrawalCredentialsAddress = address(bytes20(withdrawalCredentials[12:]));

        require(
            _isRegisteredRewardReceiver(withdrawalCredentialsAddress) && uint8(bytes1(withdrawalCredentials[:1])) == 1,
            "StakePadV1: invalid withdrawal_credentials"
        );
    }

    function _isRegisteredRewardReceiver(address rewardReceiver) internal view returns (bool) {
        return _rewardReceivers.contains(rewardReceiver);
    }

    /**
     * @dev perform some address checks
     */
    function _updateRewardReceiverImpl(address newRewardReceiverImpl) internal {
        require(newRewardReceiverImpl != address(0), "StakePadV1: new implementation is the zero address");
        _rewardReceiverImpl = newRewardReceiverImpl;
    }

    function _addValidatorPubKey(bytes calldata pubkey, bytes calldata withdrawal_credentials) internal {
        require(pubkey.length == 48, "StakePadV1: invalid pubkey length");
        IRewardReceiver(address(bytes20(withdrawal_credentials[12:]))).addValidator(pubkey);
    }

    /**
     * @dev Upgrade the implementation of the proxy
     * @param newImplementation address of the new implementation
     * @notice only the ADMIN ( owner ) can upgrade this contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
