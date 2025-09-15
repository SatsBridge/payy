use super::Backend;
use lazy_static::lazy_static;
use std::sync::{Mutex, Once};

pub struct BindingBackend;

lazy_static! {
    static ref INIT: Once = Once::new();
    static ref BB_MUTEX: Mutex<()> = Mutex::new(());
}

const G2: [u8; 128] = [
    126, 35, 31, 236, 147, 136, 131, 176, 159, 89, 68, 7, 59, 50, 7, 139, 188, 137, 181, 179, 152,
    181, 151, 78, 1, 24, 196, 213, 184, 55, 188, 194, 78, 254, 48, 250, 192, 147, 131, 193, 234,
    81, 216, 122, 53, 142, 3, 139, 231, 255, 78, 88, 7, 145, 222, 232, 38, 14, 1, 178, 81, 246,
    241, 199, 133, 74, 135, 212, 218, 204, 94, 85, 17, 230, 221, 63, 150, 230, 206, 162, 86, 71,
    91, 66, 20, 229, 97, 94, 34, 254, 189, 163, 192, 192, 99, 42, 238, 65, 60, 128, 218, 106, 95,
    228, 156, 242, 160, 70, 65, 249, 155, 164, 210, 81, 86, 193, 187, 154, 114, 133, 4, 252, 99,
    105, 247, 17, 15, 227,
];

#[cfg(feature = "bb_utxo")]
lazy_static! {
    static ref G1: &'static [u8] = include_bytes!("../../../../fixtures/params/g1.utxo.dat");
}

#[cfg(not(feature = "bb_utxo"))]
lazy_static! {
    static ref G1: &'static [u8] = include_bytes!("../../../../fixtures/params/g1.max.dat");
}

impl BindingBackend {
    fn load_srs() {
        INIT.call_once(|| unsafe {
            bb_rs::barretenberg_api::srs::init_srs(&G1, (G1.len() / 64) as u32, &G2);
        });
    }
}

impl Backend for BindingBackend {
    fn prove(
        _program: &[u8],
        bytecode: &[u8],
        witness: &[u8],
        recursive: bool,
        oracle_hash_keccak: bool,
    ) -> crate::Result<Vec<u8>> {
        let _guard = BB_MUTEX.lock().unwrap();

        Self::load_srs();

        let mut proof = match oracle_hash_keccak {
            false => unsafe {
                bb_rs::barretenberg_api::acir::acir_prove_ultra_honk(bytecode, witness, recursive)
            },
            true => unsafe {
                bb_rs::barretenberg_api::acir::acir_prove_ultra_keccak_honk(
                    bytecode, witness, recursive,
                )
            },
        };

        proof.drain(..4);

        Ok(proof)
    }

    fn verify(proof: &[u8], key: &[u8], oracle_hash_keccak: bool) -> crate::Result<()> {
        let _guard = BB_MUTEX.lock().unwrap();

        Self::load_srs();

        let verified = match oracle_hash_keccak {
            false => unsafe { bb_rs::barretenberg_api::acir::acir_verify_ultra_honk(proof, key) },
            true => unsafe {
                bb_rs::barretenberg_api::acir::acir_verify_ultra_keccak_honk(proof, key)
            },
        };

        match verified {
            true => Ok(()),
            false => Err("Proof verification failed".to_owned().into()),
        }
    }
}
