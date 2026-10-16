#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
model="${1:-Atomic}"
case "$model" in
  NonAtomic) testcase=tcNonAtomic; output=non-atomic ;;
  Atomic) testcase=tcAtomic; output=atomic ;;
  *) echo 'Expected Atomic or NonAtomic' >&2; exit 2 ;;
esac
source scripts/p-env.sh
if [[ ! -x "$DOTNET_ROOT/dotnet" || ! -f "$P_DLL" || ! -f "$QUOTA_PEX_JAR" || ! -f "$QUOTA_LOMBOK_JAR" ]]; then
  echo 'Run make setup-p first.' >&2
  exit 1
fi
# Always compile: stale generated models must never pass a source change.
dotnet "$P_DLL" compile --mode pex --pproj models/Quota.pproj
# Zero schedules means no schedule bound. Depth/time limits are safeguards;
# check-models.sh requires full completion, not merely exit zero / no bugs.
exec dotnet "$P_DLL" check PGenerated/PEx/target/Quota-jar-with-dependencies.jar \
  --mode pex --testcase "$testcase" --sch-pex dfs --seed 0 --schedules 0 \
  --max-steps 100 --fail-on-maxsteps --timeout 30 --outdir "var/p/$output"
