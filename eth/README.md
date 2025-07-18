# Ethereum Smart Contracts

Rollup smart contracts to verify the rollup state on Ethereum.

## Run locally

Run the local Ethereum hardhat node (resets on each restart):

```bash
yarn eth-node
```

Deploy the contract:

```bash
yarn deploy:local
```

Run server:

```bash
cargo run --release --bin node
```

### Mock aggregate proof

You can deploy a mock aggregate proof verifier using the `DEV_USE_NOOP_VERIFIER=1` environment variable.

You can then run a node with `--mode mock-prover` to skip generating aggregate proofs.

## Deploy to live network

Deploy to a live network. `SECRET_KEY` must have native token on the account. Select network by providing
the network URL

* MAINNET_URL
* SEPOLIA_URL
* MUMBAI_URL
etc

For example:

```bash
SEPOLIA_URL=<alchemy_url> SECRET_KEY=<secret key with eth on network> yarn deploy -- --network sepolia
```

Run server:

```bash
export ETHEREUM_RPC='<same as SEPOLIA_URL>' # maybe I should have just used the same env var names for hardhat deploy
export PROVER_SECRET_KEY=<same as SEPOLIA_SECRET_KEY>
export ROLLUP_CONTRACT_ADDR=...

cargo run --release server
```


### Prenet

#### Deploy

```bash
OWNER=0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323 PROVER_ADDRESS=0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323 VALIDATORS=0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323 AMOY_URL=https://polygon-amoy.g.alchemy.com/v2/9e_9NcJQ4rvg9RCsW2l7dqdbHw0VHBCf SECRET_KEY=<SECRET_KEY> GAS_PRICE_GWEI=2 yarn deploy -- --network amoy
```

#### Upgrade

```bash
ROLLUP_PROXY_ADMIN_ADDR=0x3a7122f0711822e63aa6218f4db3a6e40f97bdcf ROLLUP_CONTRACT_ADDR=0x1e44fa332fc0060164061cfedf4d3a1346a9dc38 AMOY_URL=https://polygon-amoy.g.alchemy.com/v2/9e_9NcJQ4rvg9RCsW2l7dqdbHw0VHBCf SECRET_KEY=<SECRET_KEY> yarn upgrade-rollup -- --network amoy
```

Add `UPGRADE_DEPLOY=true` to deploy the contract (not just print the calldata).

### Testnet

#### Deploy

```bash
OWNER=0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323 PROVER_ADDRESS=0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323 VALIDATORS=0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323 POLYGON_URL=https://polygon-mainnet.g.alchemy.com/v2/UrFsshbLOrSG1_cPayD3OHHi0s066Shx SECRET_KEY=<SECRET_KEY> yarn deploy -- --network polygon
```

#### Upgrade

```bash
SECRET_KEY=... ROLLUP_CONTRACT_ADDR=0x55d1cf90392c7b7a4dc131cab6916dba5799e77c ROLLUP_PROXY_ADMIN_ADDR=0x55a99a706d707d033c94ffe95838e332a9e5c220  POLYGON_URL=https://polygon-mainnet.g.alchemy.com/v2/UrFsshbLOrSG1_cPayD3OHHi0s066Shx yarn upgrade-rollup -- --network polygon
```

#### Addresses

```
// remove after migration
OLD_ROLLUP_CONTRACT_ADDR=0x24baf24128af44f03d61a3e657b1cec298ef6cdc
```

```
{
  proverAddress: '0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323',
  validators: [ '0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323' ],
  ownerAddress: '0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323',
  deployerIsProxyAdmin: true
}
AGGREGATE_VERIFIER_ADDR=0x11078b70ed4fcbc9625d9e90c017ac67e2c30dd5
MINT_VERIFIER_ADDR=0x9fe035bc7cdfb1f604cf14de74897f0301167df2
ROLLUP_V1_IMPL_ADDR=0x364e153ec91878dc9e52c370ab1f471ff4ba09f5
ROLLUP_CONTRACT_ADDR=0x55d1cf90392c7b7a4dc131cab6916dba5799e77c
ROLLUP_PROXY_ADMIN_ADDR=0x43aac3c779b26a210b8723bac2d70bd38a571506
```


### Mainnet

```bash
OWNER=0x230Dfb03F078B0d5E705F4624fCC915f3126B40f PROVER_ADDRESS=0x5343b904bf837befb2f5a256b0cd5fbf30503d38 VALIDATORS=0x41582701cb3117680687df80bd5a2ca971bda964,0x75eadc4a85ee07e3b60610dc383eab1b27b1c4c1,0x53b385c35d7238d44dfd591eee94fee83f6711de,0x05dc3d71e2a163e6926956bc0769c5cb8a6b9d1a,0x581c5d92e35e51191a982ebd803f92742e3c9fe3,0xbb82aef611b513965371b3d33c4d3b6c8b926f24,0xeacb0b7e37709bafb4204c0c31a2919212049975,0xf9d65db5f8952bee5ea990df79a0032eda0752b7,0x662b7930b201fbe11bcef3cdef6e8f2c8ed4983a,0x68a78d978497b0a87ff8dbeaffae8e68ad4c39dc POLYGON_URL=https://polygon-mainnet.g.alchemy.com/v2/UrFsshbLOrSG1_cPayD3OHHi0s066Shx SECRET_KEY=<SECRET_KEY> yarn deploy -- --network polygon
```

#### Temp Deploy

```bash
OWNER=0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323 PROVER_ADDRESS=0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323 VALIDATORS=0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323 POLYGON_URL=https://polygon-mainnet.g.alchemy.com/v2/UrFsshbLOrSG1_cPayD3OHHi0s066Shx SECRET_KEY=<SECRET_KEY> yarn deploy -- --network polygon
```

(using testnet key for now, we will redeploy with mainnet keys before external release)

{
  proverAddress: '0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323',
  validators: [ '0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323' ],
  ownerAddress: '0x6B96F1A8D65eDe8AD688716078B3DD79f9BD7323',
  deployerIsProxyAdmin: true
}
AGGREGATE_VERIFIER_ADDR=0xf6941ea04d29eed53de63021acddabdf02270735
MINT_VERIFIER_ADDR=0xe572f601ab078940bd4bfe004754ad54538c79e1
ROLLUP_V1_IMPL_ADDR=0x383881a7597eec5d0044e49d709539fc6952a983
ROLLUP_CONTRACT_ADDR=0xda9afe961b09290dcff632347866a6ce97d36df1
ROLLUP_PROXY_ADMIN_ADDR=0xbbf8258e8405770a4e739cf03d9aeae4d674ef14


#### Addresses

```
USDC_CONTRACT_ADDR=0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
AGGREGATE_BIN_ADDR=0x31063c00ad62f9090abb9308f4549a1dee4a6362
AGGREGATE_VERIFIER_ADDR=0x9d9fe636a329a07d26b5c5e8411b278462f5f325
MINT_BIN_ADDR=0xe025bb7ce28a4565a890a8d708faf9dd48ea1678
MINT_VERIFIER_ADDR=0xe938b6c17a39e80c7630040df0d2dbe794d42534
BURN_BIN_ADDR=0x4449d93873f7523d1b6cdfaa5a792e0867ca3a17
BURN_VERIFIER_ADDR=0x36e4a9f800e07a4aa6647c83e97f7e47b8028895
ROLLUP_V1_CONTRACT_ADDR=0x470e6986d9a54b498f4fa39ee118d25d52cc0a19
ROLLUP_CONTRACT_ADDR=0x4cbb5041df8d815d752239960fba5e155ba2687e
ROLLUP_PROXY_ADMIN_ADDR=0xe022130f28c4e6ddf1da5be853a185fbeb84d795
BURN_TO_ADDRESS_ROUTER_CONTRACT_ADDR=0x8e93495fb707785af8c1345858e4898c2d005f7b
BURN_V2_BIN_ADDR=0x2c103552a8f311cd6e35c2ca69e2f42e812c12d0
BURN_VERIFIER_V2_ADDR=0x51c77c8b99aab9d6c83a4deb1247c528325e5c0b
ROLLUP_V5_CONTRACT_ADDR=0x451a98322400d2a9018303cc66a68b3d903a3329
ROLLUP_V6_CONTRACT_ADDR=0x3a58033501778babcd785cd89c054f16fa9b1f2b
ACROSS_WITH_AUTHORIZATION_CONTRACT_ADDR=0xf5bf1a6a83029503157bb3761488bb75d64002e7
```

#### Upgrade

```bash
SECRET_KEY=... ROLLUP_CONTRACT_ADDR=0x4cbb5041df8d815d752239960fba5e155ba2687e ROLLUP_PROXY_ADMIN_ADDR=0xe022130f28c4e6ddf1da5be853a185fbeb84d795  POLYGON_URL=https://polygon-mainnet.g.alchemy.com/v2/UrFsshbLOrSG1_cPayD3OHHi0s066Shx yarn upgrade-rollup -- --network polygon
```

### Upgrade Rollup contract

Using `yarn upgrade-rollup`, you can upgrade a previously deployed rollup contract to a new version.

Example without a specified network:

```bash
SECRET_KEY=... ROLLUP_CONTRACT_ADDR=<proxy_contract_addr> ROLLUP_PROXY_ADMIN_ADDR=<proxy_admin_contract_addr> yarn upgrade-rollup
```

## Regenerating EVM aggregate proof verifier

To re-generate EVM proof verifier, see [pkg/contracts](/pkg/prover).
