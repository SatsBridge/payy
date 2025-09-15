#![deny(clippy::disallowed_methods)]

mod across;
mod client;
mod constants;
mod error;
mod rollup;
#[cfg(test)]
mod tests;
mod usdc;
pub mod util;
pub mod wallet;

pub use across::AcrossWithAuthorizationContract;
pub use client::Client;
pub use error::{Error, Result};
pub use rollup::RollupContract;
pub use usdc::USDCContract;

pub use web3::{
    signing::SecretKey,
    types::{Address, H256, U256},
};
