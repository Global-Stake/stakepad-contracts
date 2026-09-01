// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

interface IRewardReceiver {
    event RewardSent(address indexed, uint256);
    event CommissionSent(address indexed, uint256);
    event FundsReceived(address indexed sender, uint256 amount, uint256 balanceAfter);
    event WithdrawalAllocated(
        address indexed client,
        address indexed provider,
        uint256 principalAmount,
        uint256 grossRewardAmount,
        uint256 commissionAmount,
        uint256 clientAmount,
        uint256 providerAmount
    );
    event ClientClaimed(address indexed client, address indexed recipient, uint256 amount);
    event ProviderClaimed(address indexed provider, address indexed recipient, uint256 amount);
    event CommissionProposed(address indexed proposer, uint96 commission);
    event CommissionAccepted(address indexed client, uint96 previousCommission, uint96 newCommission);
    event CommissionCancelled(address indexed canceller, uint96 commission);
    event WithdrawalThresholdProposed(address indexed proposer, uint256 withdrawalThreshold);
    event WithdrawalThresholdAccepted(
        address indexed client, uint256 previousWithdrawalThreshold, uint256 newWithdrawalThreshold
    );
    event WithdrawalThresholdCancelled(address indexed canceller, uint256 withdrawalThreshold);
    event ValidatorAdded(bytes pubkey, uint256 protectedPrincipal, uint256 protectedPrincipalAfter);
    event ValidatorRemoved(
        uint256 indexed index, bytes pubkey, uint256 protectedPrincipal, uint256 protectedPrincipalAfter
    );
    event StakePadChanged(address indexed previousStakePad, address indexed newStakePad);
    event PercentageWithdrawn(address indexed caller, address indexed provider, uint96 percentage, uint256 amount);

    function initialize(address, address, uint96, address) external;

    function transferOwnership(address) external;

    function addValidator(bytes memory) external;

    function addValidator(bytes memory, uint256) external;

    function getValidators() external returns (bytes[] memory);

    function withdraw() external;

    function claimClient() external;

    function claimClient(address payable) external;

    function claimProvider() external;

    function claimProvider(address payable) external;

    function proposeNewCommission(uint96) external;

    function proposeNewWithdrawalThreshold(uint256) external;

    function cancelNewCommission() external;

    function cancelNewWithdrawalThreshold() external;

    function acceptNewCommission() external;

    function acceptNewWithdrawalThreshold() external;
}
