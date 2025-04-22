// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IRewardReceiver.sol";

/**
 * @title RewardReceiver Implementation
 * @author GlobalStake
 * @notice Contract will be used with Clones library
 */
contract RewardReceiver is IRewardReceiver, Initializable, OwnableUpgradeable {
    uint96 public constant BASIS_PTS = 10000;
    uint256 public constant INIT_WITHDRAWAL_THRESHOLD =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff; // max(type(uint256))

    uint96 public pendingCommission;
    uint256 public pendingWithdrawalThreshold;
    bytes[] public validators;

    address internal _client;
    address internal _provider; // managed by stakepad NO MALICIOUS PROVIDER
    address internal _stakePad; // managed by stakepad NO MALICIOUS PROVIDER
    uint96 internal _commission;
    uint256 internal _withdrawalThreshold;

    modifier onlyOwnerClientOrProvider() {
        require(
            owner() == _msgSender() || client() == _msgSender() || provider() == _msgSender(),
            "RewardReceiver: caller is not the owner, client or provider"
        );
        _;
    }

    modifier onlyOwnerOrProvider() {
        require(
            owner() == _msgSender() || provider() == _msgSender(), "RewardReceiver: caller is not the owner or provider"
        );
        _;
    }

    modifier onlyClient() {
        require(client() == _msgSender(), "RewardReceiver: caller is not the client");
        _;
    }

    modifier onlyStakePadOrProviderOrAdmin() {
        require(
            stakePad() == _msgSender() || owner() == _msgSender() || provider() == _msgSender(),
            "RewardReceiver: caller is not stakePad or provider or owner"
        );
        _;
    }

    modifier notPendingState() {
        require(pendingCommission == 0 && pendingWithdrawalThreshold == 0, "RewardReceiver: pending state");
        _;
    }

    /**
     * @notice Allows the contract to receive ETH
     * @dev execution layer rewards may be sent as plain ETH transfers
     * @dev withdrawals from consensus layer to be sent through balance increments
     */
    receive() external payable {}

    function initialize(address newClient, address newProvider, uint96 newCommission, address newStakePad)
        external
        initializer
    {
        __Client_init(newClient);
        __Provider_init(newProvider);
        __Ownable_init(0xD60CA38884509c7b296da19A44C71C61D9e78EFf);
        __stakePad_init(newStakePad);
        __initializeRewardReceiver(newCommission);
    }

    /**
     * @notice Withdraws the rewards to the client and the commission to the provider
     */
    function withdraw() external onlyOwnerClientOrProvider notPendingState {
        uint256 balance = address(this).balance;
        uint256 weightedCommission;
        uint256 rewards;
        if (balance > _withdrawalThreshold) {
            weightedCommission = ((balance - _withdrawalThreshold) * _commission) / BASIS_PTS;
        } else {
            weightedCommission = (balance * _commission) / BASIS_PTS;
        }
        require(weightedCommission > 0, "RewardReceiver: commission too low");
        rewards = balance - weightedCommission;

        // transfer to provider first for safety
        (bool success1,) = address(_provider).call{value: weightedCommission}("");
        (bool success0,) = address(_client).call{value: rewards}("");

        emit RewardSent(_client, rewards);
        emit CommissionSent(_provider, weightedCommission);

        require(success0 && success1, "RewardReceiver: transfer failed");
    }

    function proposeNewCommission(uint96 newCommission) external onlyOwnerOrProvider {
        _checkValidPercentange(newCommission);
        pendingCommission = newCommission;
    }

    function proposeNewWithdrawalThreshold(uint256 newWithdrawalThreshold) external onlyOwnerOrProvider {
        _checkValidWithdrawalThreshold(newWithdrawalThreshold);
        pendingWithdrawalThreshold = newWithdrawalThreshold;
    }

    function acceptNewCommission() external onlyClient {
        _checkValidPercentange(pendingCommission);
        _commission = pendingCommission;
        pendingCommission = 0;
    }

    function acceptNewWithdrawalThreshold() external onlyClient {
        _checkValidWithdrawalThreshold(pendingWithdrawalThreshold);
        _withdrawalThreshold = pendingWithdrawalThreshold;
        pendingWithdrawalThreshold = 0;
    }

    function cancelNewCommission() external onlyOwnerOrProvider {
        _checkValidPercentange(pendingCommission);
        pendingCommission = 0;
    }

    function cancelNewWithdrawalThreshold() external onlyOwnerOrProvider {
        _checkValidWithdrawalThreshold(pendingWithdrawalThreshold);
        pendingWithdrawalThreshold = 0;
    }

    function commission() external view returns (uint96) {
        return _commission;
    }

    function withdrawalThreshold() external view returns (uint256) {
        return _withdrawalThreshold;
    }

    function addValidator(bytes memory pubkey) external onlyStakePadOrProviderOrAdmin {
        validators.push(pubkey);
    }

    function removeValidator(uint256 index) external onlyStakePadOrProviderOrAdmin {
        uint256 len = validators.length;
        require(index < len, "RewardReceiver : invalid index");
        if (index != len - 1) {
            validators[index] = validators[len - 1];
        }
        validators.pop();
    }

    function changeStakePad(address newStakePad) external onlyOwner {
        _stakePad = newStakePad;
    }

    function percentageWithdraw(uint96 percentage) external onlyOwner {
        _checkValidPercentange(percentage);
        uint256 balance = address(this).balance;
        uint256 amounToWithdraw = (balance * percentage) / BASIS_PTS;
        require(amounToWithdraw > 0, "RewardReceiver: amount too low");
        (bool success,) = address(_provider).call{value: amounToWithdraw}("");
        require(success, "RewardReceiver: transfer failed");
    }

    function getValidators() external view returns (bytes[] memory) {
        return validators;
    }

    function renounceOwnership() public pure override {
        revert("RewardReceiver: renounceOwnership is disabled");
    }

    function client() public view returns (address) {
        return _client;
    }

    function provider() public view returns (address) {
        return _provider;
    }

    function stakePad() public view returns (address) {
        return _stakePad;
    }

    function transferOwnership(address newOwner) public override(IRewardReceiver, OwnableUpgradeable) {
        super.transferOwnership(newOwner);
    }

    function __Client_init(address newClient) internal {
        require(newClient != address(0), "RewardReceiver: client is the zero address");
        _client = newClient;
    }

    function __Provider_init(address newProvider) internal {
        require(newProvider != address(0), "RewardReceiver: provider is the zero address");
        _provider = newProvider;
    }

    function __stakePad_init(address newStakePad) internal {
        require(newStakePad != address(0), "RewardReceiver: stakePad is the zero address");
        _stakePad = newStakePad;
    }

    function __initializeRewardReceiver(uint96 newCommission) internal {
        _checkValidPercentange(newCommission);
        _commission = newCommission;
        _withdrawalThreshold = INIT_WITHDRAWAL_THRESHOLD;
    }

    function _checkValidPercentange(uint96 newPercentage) internal pure {
        require(newPercentage > 0 && newPercentage <= BASIS_PTS, "RewardReceiver: invalid percentage");
    }

    function _checkValidWithdrawalThreshold(uint256 newWithdrawalThreshold) internal pure {
        require(newWithdrawalThreshold > 0, "RewardReceiver: invalid withdrawal threshold");
    }
}
