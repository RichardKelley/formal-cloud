#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p var
set +e
bash scripts/p-model.sh NonAtomic > var/non-atomic.log 2>&1
status=$?
set -e
cat var/non-atomic.log
if [[ $status != 2 ]] || ! grep -q 'Property violated:.*QuotaInvariant: used=110 limit=100' var/non-atomic.log || ! grep -q 'Result: found cex' var/non-atomic.log; then
  echo 'Expected the specific quota counterexample (P exit 2).' >&2
  exit 1
fi
bash scripts/p-model.sh Atomic | tee var/atomic.log
if ! grep -q 'Found 0 bugs\.' var/atomic.log || ! grep -q 'Result: correct for any depth' var/atomic.log; then
  echo 'Expected exhaustive completion of the finite atomic P model.' >&2
  exit 1
fi
