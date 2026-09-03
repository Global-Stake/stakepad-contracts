// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IRewardReceiver.sol";

/**
 * @title RewardReceiver Implementation
 * @author Quantum3 Labs
 * @notice Contract will be used with Clones library
 */
contract RewardReceiver is IRewardReceiver, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint96 public constant BASIS_PTS = 10000;
    uint256 public constant INIT_WITHDRAWAL_THRESHOLD = 0;

    uint96 public pendingCommission;
    uint256 public pendingWithdrawalThreshold;
    bytes[] public validators;

    address internal _client;
    address internal _provider; // managed by stakepad NO MALICIOUS PROVIDER
    address internal _stakePad; // managed by stakepad NO MALICIOUS PROVIDER
    uint96 internal _commission;
    uint256 internal _withdrawalThreshold;
    uint256 public claimableClient;
    uint256 public claimableProvider;
    uint256 public totalClaimedClient;
    uint256 public totalClaimedProvider;
    uint256 internal _feeAccountedRewards;
    uint256[] internal _validatorPrincipals;
    bool internal _hasPendingWithdrawalThreshold;

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

    modifier onlyOwnerOrClient() {
        require(
            owner() == _msgSender() || client() == _msgSender(), "RewardReceiver: caller is not the owner or client"
        );
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
        require(pendingCommission == 0 && !_hasPendingWithdrawalThreshold, "RewardReceiver: pending state");
        _;
    }

    /**
     * @notice Allows the contract to receive ETH
     * @dev execution layer rewards may be sent as plain ETH transfers
     * @dev withdrawals from consensus layer to be sent through balance increments
     */
    receive() external payable {
        emit FundsReceived(_msgSender(), msg.value, address(this).balance);
    }

    function initialize(address newClient, address newProvider, uint96 newCommission, address newStakePad)
        external
        initializer
    {
        __Client_init(newClient);
        __Provider_init(newProvider);
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __stakePad_init(newStakePad);
        __initializeRewardReceiver(newCommission);
    }

    /**
     * @notice Allocates newly received funds to client/provider claimable balances
     */
    function withdraw() external onlyOwnerClientOrProvider notPendingState nonReentrant {
        uint256 availableBalance = _unallocatedBalance();
        require(availableBalance > 0, "RewardReceiver: no funds to allocate");

        uint256 totalReceived = _lifetimeReceived();
        uint256 totalRewards = totalReceived > _withdrawalThreshold ? totalReceived - _withdrawalThreshold : 0;
        uint256 grossRewards = totalRewards > _feeAccountedRewards ? totalRewards - _feeAccountedRewards : 0;

        // Lowering the threshold can reclassify already-paid principal as rewards.
        // That gap is not in the contract; book it without taking commission.
        if (grossRewards > availableBalance) {
            _feeAccountedRewards += grossRewards - availableBalance;
            grossRewards = availableBalance;
        }

        uint256 weightedCommission = (grossRewards * _commission) / BASIS_PTS;
        uint256 clientAmount = availableBalance - weightedCommission;
        uint256 principalAmount = availableBalance > grossRewards ? availableBalance - grossRewards : 0;

        claimableClient += clientAmount;
        claimableProvider += weightedCommission;
        _feeAccountedRewards += grossRewards;

        emit WithdrawalAllocated(
            _client, _provider, principalAmount, grossRewards, weightedCommission, clientAmount, weightedCommission
        );
    }

    function claimClient() external {
        claimClient(payable(_client));
    }

    function claimClient(address payable recipient) public onlyOwnerOrClient nonReentrant {
        require(recipient != address(0), "RewardReceiver: recipient is the zero address");

        uint256 amount = claimableClient;
        require(amount > 0, "RewardReceiver: nothing to claim");

        claimableClient = 0;
        totalClaimedClient += amount;

        (bool success,) = recipient.call{value: amount}("");
        require(success, "RewardReceiver: transfer failed");

        emit ClientClaimed(_client, recipient, amount);
    }

    function claimProvider() external {
        claimProvider(payable(_provider));
    }

    function claimProvider(address payable recipient) public onlyOwnerOrProvider nonReentrant {
        _claimProvider(recipient);
    }

    function proposeNewCommission(uint96 newCommission) external onlyOwnerOrProvider {
        _checkValidPercentange(newCommission);
        pendingCommission = newCommission;
        emit CommissionProposed(_msgSender(), newCommission);
    }

    function proposeNewWithdrawalThreshold(uint256 newWithdrawalThreshold) external onlyOwnerOrProvider {
        pendingWithdrawalThreshold = newWithdrawalThreshold;
        _hasPendingWithdrawalThreshold = true;
        emit WithdrawalThresholdProposed(_msgSender(), newWithdrawalThreshold);
    }

    function acceptNewCommission() external onlyOwnerOrClient {
        _checkValidPercentange(pendingCommission);
        uint96 previousCommission = _commission;
        _commission = pendingCommission;
        pendingCommission = 0;
        emit CommissionAccepted(_msgSender(), previousCommission, _commission);
    }

    function acceptNewWithdrawalThreshold() external onlyOwnerOrClient {
        require(_hasPendingWithdrawalThreshold, "RewardReceiver: no pending withdrawal threshold");
        uint256 previousWithdrawalThreshold = _withdrawalThreshold;
        _withdrawalThreshold = pendingWithdrawalThreshold;
        pendingWithdrawalThreshold = 0;
        _hasPendingWithdrawalThreshold = false;
        emit WithdrawalThresholdAccepted(_msgSender(), previousWithdrawalThreshold, _withdrawalThreshold);
    }

    function cancelNewCommission() external onlyOwnerOrProvider {
        _checkValidPercentange(pendingCommission);
        uint96 cancelledCommission = pendingCommission;
        pendingCommission = 0;
        emit CommissionCancelled(_msgSender(), cancelledCommission);
    }

    function cancelNewWithdrawalThreshold() external onlyOwnerOrProvider {
        require(_hasPendingWithdrawalThreshold, "RewardReceiver: no pending withdrawal threshold");
        uint256 cancelledWithdrawalThreshold = pendingWithdrawalThreshold;
        pendingWithdrawalThreshold = 0;
        _hasPendingWithdrawalThreshold = false;
        emit WithdrawalThresholdCancelled(_msgSender(), cancelledWithdrawalThreshold);
    }

    function commission() external view returns (uint96) {
        return _commission;
    }

    function withdrawalThreshold() external view returns (uint256) {
        return _withdrawalThreshold;
    }

    function addValidator(bytes memory pubkey, uint256 protectedPrincipal) external onlyStakePadOrProviderOrAdmin {
        _addValidator(pubkey, protectedPrincipal);
    }

    function feeAccountedRewards() external view returns (uint256) {
        return _feeAccountedRewards;
    }

    function unallocatedBalance() external view returns (uint256) {
        return _unallocatedBalance();
    }

    function lifetimeReceived() external view returns (uint256) {
        return _lifetimeReceived();
    }

    function _addValidator(bytes memory pubkey, uint256 protectedPrincipal) internal {
        validators.push(pubkey);
        _validatorPrincipals.push(protectedPrincipal);
        _withdrawalThreshold += protectedPrincipal;
        emit ValidatorAdded(pubkey, protectedPrincipal, _withdrawalThreshold);
    }

    function removeValidator(uint256 index) external onlyStakePadOrProviderOrAdmin {
        uint256 len = validators.length;
        require(index < len, "RewardReceiver : invalid index");
        bytes memory removedValidator = validators[index];
        uint256 removedPrincipal = 0;
        uint256 principalLen = _validatorPrincipals.length;
        if (index < principalLen) {
            removedPrincipal = _validatorPrincipals[index];
            if (index != principalLen - 1) {
                _validatorPrincipals[index] = _validatorPrincipals[principalLen - 1];
            }
            _validatorPrincipals.pop();
        }
        if (index != len - 1) {
            validators[index] = validators[len - 1];
        }
        validators.pop();
        // Never lower the threshold: on-chain we cannot tell whether the
        // removed validator's principal has already been received. A mistaken
        // pubkey is corrected via propose/accept withdrawal threshold.
        emit ValidatorRemoved(index, removedValidator, removedPrincipal, _withdrawalThreshold);
    }

    function changeStakePad(address newStakePad) external onlyOwner {
        require(newStakePad != address(0), "RewardReceiver: stakePad is the zero address");
        address previousStakePad = _stakePad;
        _stakePad = newStakePad;
        emit StakePadChanged(previousStakePad, newStakePad);
    }

    function percentageWithdraw(uint96 percentage) external onlyOwner {
        _checkValidPercentange(percentage);
        uint256 unaccountedRewards = _unaccountedRewards();
        uint256 availableBalance = _unallocatedBalance();
        uint256 withdrawable = unaccountedRewards < availableBalance ? unaccountedRewards : availableBalance;
        uint256 amountToWithdraw = (withdrawable * percentage) / BASIS_PTS;
        require(amountToWithdraw > 0, "RewardReceiver: amount too low");
        totalClaimedProvider += amountToWithdraw;
        _feeAccountedRewards += amountToWithdraw;
        (bool success,) = address(_provider).call{value: amountToWithdraw}("");
        require(success, "RewardReceiver: transfer failed");
        emit PercentageWithdrawn(_msgSender(), _provider, percentage, amountToWithdraw);
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

    function _claimProvider(address payable recipient) internal {
        require(recipient != address(0), "RewardReceiver: recipient is the zero address");

        uint256 amount = claimableProvider;
        require(amount > 0, "RewardReceiver: nothing to claim");

        claimableProvider = 0;
        totalClaimedProvider += amount;

        (bool success,) = recipient.call{value: amount}("");
        require(success, "RewardReceiver: transfer failed");

        emit ProviderClaimed(_provider, recipient, amount);
    }

    function _unallocatedBalance() internal view returns (uint256) {
        uint256 allocatedBalance = claimableClient + claimableProvider;
        uint256 balance = address(this).balance;

        require(balance >= allocatedBalance, "RewardReceiver: insufficient balance");

        return balance - allocatedBalance;
    }

    function _lifetimeReceived() internal view returns (uint256) {
        return address(this).balance + totalClaimedClient + totalClaimedProvider;
    }

    function _unaccountedRewards() internal view returns (uint256) {
        uint256 totalReceived = _lifetimeReceived();
        uint256 totalRewards = totalReceived > _withdrawalThreshold ? totalReceived - _withdrawalThreshold : 0;
        return totalRewards > _feeAccountedRewards ? totalRewards - _feeAccountedRewards : 0;
    }

    function _checkValidPercentange(uint96 newPercentage) internal pure {
        require(newPercentage > 0 && newPercentage <= BASIS_PTS, "RewardReceiver: invalid percentage");
    }

}
