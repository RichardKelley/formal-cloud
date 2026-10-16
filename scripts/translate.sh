#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
charon="${CHARON:-$PWD/.tools/aeneas/charon}"
aeneas="${AENEAS:-$PWD/.tools/aeneas/aeneas}"
[[ -x "$charon" && -x "$aeneas" ]] || { echo 'Run make setup-proof first.' >&2; exit 1; }
mkdir -p .tools proofs
# Optional workspace-local compiler (used when global rustup installs are unavailable).
local_rust="${QUOTA_RUST_SYSROOT:-$PWD/.tools/rustc-nightly-aarch64-apple-darwin/rustc}"
if [[ -x "$local_rust/bin/rustc" ]]; then
  export PATH="$local_rust/bin:$PATH"
  export DYLD_LIBRARY_PATH="$local_rust/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
  export CHARON_TOOLCHAIN_IS_IN_PATH=1
fi
# A single-file extraction selects the actual function used by the Rust demos.
# Derive implementations and the unverified HTTP/storage crate are excluded.
"$charon" rustc --preset=aeneas --sysroot default --start-from quota_core::reserve \
  --dest-file .tools/quota_core.llbc -- \
  --crate-type=lib --crate-name quota_core crates/quota-core/src/lib.rs
"$aeneas" -backend lean .tools/quota_core.llbc -dest proofs -namespace quota_core
shasum -a 256 crates/quota-core/src/lib.rs > proofs/source.sha256
