#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
shasum -a 256 -c proofs/source.sha256
# Check the committed extraction and proof; translation is a separate target.
cd proofs
lake build
lake env lean -DwarningAsError=true QuotaProof.lean
