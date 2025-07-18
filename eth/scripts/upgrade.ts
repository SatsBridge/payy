import hre from 'hardhat'
// import { Json } from 'ethers'
import { encodeFunctionData } from 'viem'
import { deployBin } from './shared'

async function main(): Promise<void> {
  const rollupProxyAdminAddr = process.env.ROLLUP_PROXY_ADMIN_ADDR as `0x${string}` | undefined
  if (rollupProxyAdminAddr === undefined) throw new Error('ROLLUP_PROXY_ADMIN_ADDR is not set')

  const proxyRollupAddress = process.env.ROLLUP_CONTRACT_ADDR as `0x${string}` | undefined
  if (proxyRollupAddress === undefined) throw new Error('ROLLUP_CONTRACT_ADDR is not set')

  const shouldDeploy = process.env.UPGRADE_DEPLOY === 'true'

  // // This code is based on a test upgrade to a V2 version.
  // // It was working when I tested on a sample V2 contract,
  // // so it will be useful when we want to actually add a new version.
  const [owner] = await hre.viem.getWalletClients()
  const publicClient = await hre.viem.getPublicClient()

  const rollupProxy = await hre.viem.getContractAt('TransparentUpgradeableProxy', proxyRollupAddress)

  const rollupProxyAdmin = await hre.viem.getContractAt('@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol:ProxyAdmin', rollupProxyAdminAddr)

  const maybeUpgradeRollup = async (newImpl: `0x${string}`, calldata: `0x${string}`) => {
    if (shouldDeploy) {
      await rollupProxyAdmin.write.upgradeAndCall([rollupProxy.address, newImpl, calldata])
    }
  }

  const maybeCall = async (to: `0x${string}`, calldata: `0x${string}`) => {
    if (shouldDeploy) {
      const tx = await owner.sendTransaction({
        to,
        data: calldata
      })
      const receipt = await publicClient.waitForTransactionReceipt({
        hash: tx
      })
      if (receipt.status === 'reverted') {
        throw new Error(`Transaction ${tx} reverted. To: ${to}, Calldata: ${calldata}`)
      }
    } else {
      console.log('Please make a call with the following arguments:')
      console.log('\tTo:', to)
      console.log('\tCalldata:', calldata)
    }
  }

  let version = await (await hre.viem.getContractAt('RollupV1', rollupProxy.address)).read.version()

  console.log('Current version:', version)

  if (version === 1) {
    const rollupV2 = await hre.viem.deployContract('RollupV2', [])
    console.log(`ROLLUP_V2_CONTRACT_ADDR=${rollupV2.address}`)

    const initializeV2Data = encodeFunctionData({
      abi: [rollupV2.abi.find(x => x.type === 'function' && x.name === 'initializeV2') as any],
      // @ts-expect-error We know the ABI has this function
      name: 'initializeV2',
      args: []
    })
    console.log(`ROLLUP_V2_INITIALIZE_V2_CALLDATA=${initializeV2Data}`)
    await maybeUpgradeRollup(rollupV2.address, initializeV2Data)
    version = 2
  }

  if (version === 2) {
    const rollupV3 = await hre.viem.deployContract('RollupV3', [])
    console.log(`ROLLUP_V3_CONTRACT_ADDR=${rollupV3.address}`)

    const initializeV3Data = encodeFunctionData({
      abi: [rollupV3.abi.find(x => x.type === 'function' && x.name === 'initializeV3') as any],
      // @ts-expect-error We know the ABI has this function
      name: 'initializeV3',
      args: []
    })
    console.log(`ROLLUP_V3_INITIALIZE_V3_CALLDATA=${initializeV3Data}`)
    await maybeUpgradeRollup(rollupV3.address, initializeV3Data)
    version = 3
  }

  if (version === 3) {
    const rollupV4 = await hre.viem.deployContract('RollupV4', [])
    console.log(`ROLLUP_V4_CONTRACT_ADDR=${rollupV4.address}`)

    const initializeV4Data = encodeFunctionData({
      abi: [rollupV4.abi.find(x => x.type === 'function' && x.name === 'initializeV4') as any],
      // @ts-expect-error We know the ABI has this function
      name: 'initializeV4',
      args: []
    })
    console.log(`ROLLUP_V4_INITIALIZE_V4_CALLDATA=${initializeV4Data}`)
    await maybeUpgradeRollup(rollupV4.address, initializeV4Data)
    version = 4
  }

  if (version === 4) {
    const burnToAddressRouter = await hre.viem.deployContract('BurnToAddressRouter', [])
    console.log(`BURN_TO_ADDRESS_ROUTER_CONTRACT_ADDR=${burnToAddressRouter.address}`)

    const burnV2BinAddr = await deployBin('BurnVerifierV2.bin')
    console.log(`BURN_V2_BIN_ADDR=${burnV2BinAddr}`)

    const burnVerifierV2 = await hre.viem.deployContract('BurnVerifierV2', [burnV2BinAddr], {})
    console.log(`BURN_VERIFIER_V2_ADDR=${burnVerifierV2.address}`)

    const rollupV5 = await hre.viem.deployContract('RollupV5', [])
    console.log(`ROLLUP_V5_CONTRACT_ADDR=${rollupV5.address}`)

    const initializeV5Data = encodeFunctionData({
      abi: [rollupV5.abi.find(x => x.type === 'function' && x.name === 'initializeV5') as any],
      // @ts-expect-error We know the ABI has this function
      name: 'initializeV5',
      args: [burnVerifierV2.address]
    })

    console.log(`ROLLUP_V5_INITIALIZE_V5_CALLDATA=${initializeV5Data}`)
    await maybeUpgradeRollup(rollupV5.address, initializeV5Data)
    await maybeCall(rollupProxy.address, encodeFunctionData({
      abi: [rollupV5.abi.find((x) => x.type === 'function' && x.name === 'addRouter') as any],
      // @ts-expect-error We know the ABI has this function
      name: 'addRouter',
      args: [burnToAddressRouter.address]
    }))
    version = 5
  }

  if (version === 5) {
    const rollupV6 = await hre.viem.deployContract('RollupV6', [])
    console.log(`ROLLUP_V6_CONTRACT_ADDR=${rollupV6.address}`)

    const initializeV6Data = encodeFunctionData({
      abi: [rollupV6.abi.find(x => x.type === 'function' && x.name === 'initializeV6') as any],
      // @ts-expect-error We know the ABI has this function
      name: 'initializeV6',
      args: []
    })
    console.log(`ROLLUP_V6_INITIALIZE_V6_CALLDATA=${initializeV6Data}`)
    await maybeUpgradeRollup(rollupV6.address, initializeV6Data)
    version = 6
  }

  if (version === 6) {
    const rollupV7 = await hre.viem.deployContract('RollupV7', [])
    console.log(`ROLLUP_V7_IMPL_ADDR=${rollupV7.address}`)

    const initializeV7Data = encodeFunctionData({
      abi: [rollupV7.abi.find(x => x.type === 'function' && x.name === 'initializeV7') as any],
      functionName: 'initializeV7',
      args: []
    })
    console.log(`ROLLUP_V7_INITIALIZE_V7_CALLDATA=${initializeV7Data}`)
    await maybeUpgradeRollup(rollupV7.address, initializeV7Data)
    version = 7
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
