## StakePad Contracts (ON MAINNET)

## Contract Documentation

### StakePadV1

**Purpose:**

The StakePadV1 contract is designed to manage the staking process in Ethereum 2.0. It facilitates the creation of contracts to receive rewards, funds validators with Ethereum, and manages the implementation of reward receiver contracts.

**Behavior and Interactions:**

1. Initialization: The contract initializes with the address of the deposit contract (beaconDeposit).

2. Deployment of Reward Receivers:

The contract allows the owner to deploy new reward receiver contracts, specifying the beneficiary, provider, and commission percentage.
Each deployed reward receiver contract is registered and managed by the StakePadV1 contract.

3. Funding Validators:

StakePadV1 enables funding validators with 32 ETH each.
Validators are funded based on provided deposit data, ensuring the correct amount of ETH is sent for each validator.

4. Updating Reward Receiver Implementation:

The contract owner can update the implementation of the reward receiver contract.

5. Retrieving Mistakenly Sent Funds:

The owner can retrieve any mistakenly sent Ether to the contract.

6. Ownership Transfer:

Ownership of the contract can be transferred to a new address by the current owner.

7. Validation Functions:

Functions like _validateWithdrawalCredentials and _isRegisteredRewardReceiver are internal helper functions to validate withdrawal credentials and check if a reward receiver is registered.

**Main Design Choices:**

- Upgradeability: The contract utilizes OpenZeppelin's upgradeable contracts (UUPSUpgradeable), allowing for future upgrades without losing contract state or requiring users to update their interactions.

- Modularity: StakePadV1 separates concerns by using different contracts for specific functionalities like reward receivers (IRewardReceiver) and deposit contracts (IDepositContract).

- Security: Various checks are implemented to ensure the validity of data and protect against potential vulnerabilities, such as validating withdrawal credentials and checking for zero addresses during upgrades.

- Efficiency: The contract efficiently manages validators' funds, ensuring the correct amount of Ether is sent for each validator.

### Reward Receiver

Purpose:
The RewardReceiver contract is designed to manage the distribution of rewards earned from staking activities. It allows for the withdrawal of rewards to the client and commission to the provider while ensuring secure and auditable operations.

**Behavior and Interactions:**

1. Initialization:

The contract initializes with the client, provider, and commission percentage.
It sets the withdrawal threshold to the maximum value initially.

2. Withdrawal of Rewards:

The contract allows the owner, client, or provider to withdraw rewards.
The withdrawal process calculates commissions based on the provided commission percentage and transfers the remaining rewards to the client.
3. Proposing and Accepting Changes:

The owner or provider can propose changes to the commission or withdrawal threshold.
The client can accept or cancel proposed changes.

4. Adding and Removing Validators:

Validators can be added or removed by the stakePad, provider, or owner.

5. Changing StakePad:

The owner can change the stakePad address if needed.

6. Percentage Withdrawal:

The owner can withdraw a certain percentage of the contract's balance as a commission.

**Main Design Choices:**

Permission Modifiers: The contract uses various modifiers to restrict access to specific functions, ensuring that only authorized parties can perform certain actions.

Security Measures: The contract implements checks for valid percentages and withdrawal thresholds to prevent invalid operations.

Flexibility: The contract allows for the dynamic adjustment of commission percentages and withdrawal thresholds, providing flexibility in reward distribution.

Ownership Renouncement: Renouncing ownership is disabled in the contract to maintain control over critical functions.


### StakePadUpgradeableProxy

**Purpose:**
The StakePadUpgradeableProxy contract acts as an upgradeable proxy for the StakePad contract. It serves as the entry point for all functions inside the StakePad contract, enabling seamless upgrades of the contract logic while maintaining the same proxy address.

**Behavior and Interactions:**
1. Initialization:

The contract initializes with the address of the logic contract and initialization data.
It inherits from ERC1967Proxy, facilitating transparent proxy functionality.

2. Current Implementation:

The contract provides a function to query the current implementation address of the proxy.

**Main Design Choices:**
Proxy Pattern: The contract follows the transparent proxy pattern, separating logic from the proxy, enabling upgrades without changing the proxy address.

Inheritance: StakePadUpgradeableProxy inherits from ERC1967Proxy, leveraging its functionalities for upgradeability.

Simplicity: The contract's design prioritizes simplicity, serving as a straightforward entry point to the underlying logic contract.

## SECURITY ASSUMPTIONS

- Owner and provider (in `RewardReceiver.sol` & `StakePadV1`) are not malicious. These wallets are meant to be controlled by GlobalStake
- Block productions are transfers
- Block attestations are increments of balance on the contract

## Coverage

Run coverage

```
./coverage.sh
```

See coverage

```
cd coverage && open index.html
```

## Deployments

- [Proxy](https://etherscan.io/address/0x9ad446797ad259bd1a6d6b690a6ad142cc36722d)

- [StakePad Implementation](https://etherscan.io/address/0xe0de630e8e0ec122913e1e9f68146f25f0505272)

- [RewardReceiver Implementation](https://etherscan.io/address/0x7bc46ef89a09c9054784584a044c1a91ce89d6aa)
