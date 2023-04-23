// eslint-disable-next-line filenames/match-regex
import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  sendAndConfirmTransaction
} from '@solana/web3.js'
import Squads from '@sqds/sdk'
import {createIdlUpgradeInstruction} from './createIdlUpgradeInstruction'
import {createProgramUpgradeInstruction} from './createProgramUpgradeInstruction'
import NodeWallet from '@project-serum/anchor/dist/cjs/nodewallet'
import {getTxPDA} from './pda'
import {BN} from '@project-serum/anchor'

export const createProgramUpgrade = async ({
  multisig,
  programId,
  buffer,
  spill,
  authority,
  wallet,
  networkUrl,
  idlBuffer
}: {
  multisig: PublicKey
  programId: PublicKey
  buffer: PublicKey
  spill: PublicKey
  authority: PublicKey
  idlBuffer: PublicKey
  wallet: Keypair
  networkUrl: string
}) => {
  const connection = new Connection(networkUrl)
  const squads = Squads.endpoint(
    connection.rpcEndpoint,
    new NodeWallet(wallet),
    {
      commitmentOrConfig: 'finalized'
    }
  )

  const instructions = [
    await createIdlUpgradeInstruction(programId, idlBuffer, authority),
    await createProgramUpgradeInstruction(programId, buffer, authority, spill)
  ]

  const nextTransactionIndex = await squads.getNextTransactionIndex(multisig)
  const [transactionPDA] = getTxPDA(
    multisig,
    new BN(nextTransactionIndex, 10),
    squads.multisigProgramId
  )

  const realIxns = [
    await squads.buildCreateTransaction(multisig, 1, nextTransactionIndex),
    ...(await Promise.all(
      instructions.map((ix, idx) =>
        squads.buildAddInstruction(multisig, transactionPDA, ix, idx)
      )
    )),
    await squads.buildActivateTransaction(multisig, transactionPDA)
  ]

  const tx = new Transaction()
  tx.feePayer = wallet.publicKey
  tx.recentBlockhash = (await connection.getRecentBlockhash()).blockhash
  tx.add(...realIxns)
  const txid = await sendAndConfirmTransaction(connection, tx, [wallet])

  console.log(
    `Successfully created program upgrade for MS_PDA ${multisig.toString()} https://explorer.solana.com/tx/${txid}`
  )
  return txid
}
