## StakePad Contracts (ON MAINNET)

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
