#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tag=nightly-2026.10.12-d119a47
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) platform=macos-aarch64; digest=d5293d0f7676b88e562de613ff8144ee84394d01391825db58d02b2222f974c1 ;;
  Linux-x86_64) platform=linux-x86_64; digest=eb91c3053e31dfe822f8481fc9c22f965ae254e025d879ee06c5d8c050647d75 ;;
  Linux-aarch64) platform=linux-aarch64; digest=31d7212e4dcd8c60ef49ea71f6ced4f4fdda56274100d7affa267d2786413f40 ;;
  *) echo 'Use Linux x86_64/aarch64 or Apple Silicon, or install Aeneas manually.' >&2; exit 1 ;;
esac
mkdir -p .tools/aeneas
curl --fail --location --retry 3 -o .tools/aeneas-bin.tar.gz \
  "https://github.com/AeneasVerif/aeneas/releases/download/$tag/aeneas-$platform.tar.gz"
python3 - "$digest" <<'PY'
import hashlib, pathlib, sys
assert hashlib.sha256(pathlib.Path('.tools/aeneas-bin.tar.gz').read_bytes()).hexdigest() == sys.argv[1], 'Aeneas checksum mismatch'
PY
tar -xzf .tools/aeneas-bin.tar.gz -C .tools/aeneas
# Charon needs this exact compiler, including rustc-dev for its compiler driver.
rustup toolchain install nightly-2026-09-17 --profile minimal --component rustc-dev
cd proofs
lake update
lake exe cache get
lake build
