use element::Element;
use primitives::block_height::BlockHeight;
use serde::{Deserialize, Serialize};
use zk_primitives::UtxoProof;

/// Request for submit transaction
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TransactionRequest {
    /// Utxo proof to be verified and applied
    pub proof: UtxoProof,
}

/// Response for submit transaction
#[derive(Debug, Default, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TransactionResponse {
    /// Height of the block the transaction was included in
    pub height: BlockHeight,
    /// Root hash of the merkle tree for the block
    pub root_hash: Element,
    /// Transaction hash of submitted transaction
    pub txn_hash: Element,
}
