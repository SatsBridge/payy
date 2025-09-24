# Ethereum Smart Contracts

Rollup smart contracts to verify the rollup state on Ethereum.

## Testing

The project uses Hardhat with Mocha/Chai testing framework and blockchain-specific matchers for comprehensive smart contract testing.

### Run Tests

```bash
yarn test
```

### Test Features

- **Blockchain-specific matchers**: Clean, readable assertions for smart contract testing
- **Balance assertions**: `expect(await contract.balanceOf(owner.address)).to.equal(1000)`
- **Event testing**: `expect(transaction).to.emit(contract, "Transfer")`
- **Revert testing**: `expect(contract.connect(addr1).withdraw()).to.be.revertedWith("Not owner")`
- **Balance change testing**: `expect(tx).to.changeEtherBalance(addr1, ethers.parseEther("1"))`

### Continuous Integration

Tests run automatically on:
- Pull requests modifying files in `eth/`
- Pushes to `main` and `next` branches
- Manual workflow dispatch

All tests must pass with 100% success rate before merge.

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
SECRET_KEY=... ROLLUP_CONTRACT_ADDR=0x9b5df9a65c958d2d37ee1a11c1a691a2124b98d1 ROLLUP_PROXY_ADMIN_ADDR=0x55a99a706d707d033c94ffe95838e332a9e5c220  POLYGON_URL=https://polygon-mainnet.g.alchemy.com/v2/UrFsshbLOrSG1_cPayD3OHHi0s066Shx yarn upgrade-rollup -- --network polygon
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
AGGREGATE_VERIFIER_ADDR=0x79efebbdb0dc14d3d6a359ad82aa772bb6f7fd2f
ROLLUP_V1_IMPL_ADDR=0xb72119747056a8d0b732fe1c8b45b2d028d90c8b
ROLLUP_CONTRACT_ADDR=0x9b5df9a65c958d2d37ee1a11c1a691a2124b98d1
ROLLUP_PROXY_ADMIN_ADDR=0x2b931b2c9ea3eb2ce5afd393a7dbb5aadd92fad0
```


### Mainnet

```bash
OWNER=0x230Dfb03F078B0d5E705F4624fCC915f3126B40f PROVER_ADDRESS=0x5343B904Bf837Befb2f5A256B0CD5fbF30503D38 VALIDATORS=0x41582701CB3117680687Df80bD5a2ca971bDA964 POLYGON_URL=https://polygon-mainnet.g.alchemy.com/v2/UrFsshbLOrSG1_cPayD3OHHi0s066Shx SECRET_KEY=<secret_key> yarn deploy -- --network polygon
```


#### Addresses

```
{
  proverAddress: '0x5343B904Bf837Befb2f5A256B0CD5fbF30503D38',
  validators: [ '0x41582701CB3117680687Df80bD5a2ca971bDA964' ],
  ownerAddress: '0x230Dfb03F078B0d5E705F4624fCC915f3126B40f',
  deployerIsProxyAdmin: false
}
AGGREGATE_VERIFIER_ADDR=0x4eb939ae2d1df8a1e31bbedd9283571852415834
ROLLUP_V1_IMPL_ADDR=0xfee72fcc4de2ad2972da8fa6cc388a1117147b28
ROLLUP_CONTRACT_ADDR=0xcd92281548df923141fd9b690c7c8522e12e76e6
ROLLUP_PROXY_ADMIN_ADDR=0x2db9ce1c38d18c3356d10afe367213007e2ce2d4
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

## Security Improvements

### Block Height Validation (ENG-4064)

The `verifyRollup` function in `contracts/rollup2/RollupV1.sol` now includes validation to ensure new block heights are strictly greater than the current block height. This prevents:

- **Rollback Attacks**: Malicious actors cannot submit blocks with decreasing heights
- **Replay Attacks**: Same block height cannot be reused
- **Sequencing Integrity**: Maintains proper rollup block ordering
- **State Inconsistency**: Prevents breaking dependent systems expecting monotonic height increases

The validation is implemented as:
```solidity
require(height > blockHeight, "RollupV1: New block height must be greater than current");
```

### Testing

Run the security tests with:
```bash
yarn test test/SimpleBlockHeightTest.test.ts
```

## Regenerating EVM aggregate proof verifier

To re-generate EVM proof verifier, see [pkg/contracts](/pkg/prover).
