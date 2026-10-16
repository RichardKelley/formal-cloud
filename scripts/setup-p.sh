#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for tool in curl python3 java javac jar; do
  command -v "$tool" >/dev/null || { echo "Install $tool (Java requires JDK 17+)." >&2; exit 1; }
done
mkdir -p .tools

# Keep downloads local, verify before extracting, and reuse verified archives.
fetch() {
  local url="$1" path="$2" algorithm="$3" digest="$4"
  if ! verify "$path" "$algorithm" "$digest"; then
    curl --fail --location --retry 3 -o "$path" "$url"
    verify "$path" "$algorithm" "$digest" || { echo "Checksum mismatch: $path" >&2; exit 1; }
  fi
}
verify() {
  python3 - "$@" <<'PY'
import hashlib, pathlib, sys
p = pathlib.Path(sys.argv[1])
sys.exit(0 if p.is_file() and hashlib.new(sys.argv[2], p.read_bytes()).hexdigest() == sys.argv[3] else 1)
PY
}

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) platform=osx-arm64; digest=d42156be70b489236479a415536013a89a9fd6eaca57d5716a7017612fcc65bdb459068973d7cffd6fe710f2799af8bee95b2046ba032762d47df176f5c4a7d6 ;;
  Linux-x86_64) platform=linux-x64; digest=934b8060a7190e5909ad1fd0785db542f487b3bbf6cdd14826b02095fdd0d0394298b1634085eff302928fccc33f7c1a7253e9b87df555fc36fce819bcd2e798 ;;
  Linux-aarch64) platform=linux-arm64; digest=84a4d017d74d7aa842e981679d1b044e6be1f35b9b2b214021e30bc40871d016d29611cca373d8502ad5c890e3ad360ee698f9cf2d7a4d5a9fba102d88ba310f ;;
  *) echo 'P bootstrap supports Apple Silicon and Linux x86_64/aarch64.' >&2; exit 1 ;;
esac
fetch "https://builds.dotnet.microsoft.com/dotnet/Sdk/8.0.425/dotnet-sdk-8.0.425-$platform.tar.gz" \
  .tools/dotnet-sdk.tar.gz sha512 "$digest"
fetch https://api.nuget.org/v3-flatcontainer/p/3.1.0/p.3.1.0.nupkg \
  .tools/p.nupkg sha256 b2a212e3b1af1bf2fdc9b80899da2901d6625d1a2e478d478e30028872a4bdc1
fetch https://repo.maven.apache.org/maven2/io/github/p-org/pex/0.4.1/pex-0.4.1-jar-with-dependencies.jar \
  .tools/pex.jar sha256 4eee5f00d50ed7b90af90808640ec13ffaf0d1b75682a723f5846a44286c1aeb
fetch https://repo.maven.apache.org/maven2/org/projectlombok/lombok/1.18.24/lombok-1.18.24.jar \
  .tools/lombok.jar sha256 d3584bc2db03f059f984fb0a9c119aac1fa0da578a448e69fc3f68b36584c749

mkdir -p .tools/dotnet .tools/p-package
tar -xzf .tools/dotnet-sdk.tar.gz -C .tools/dotnet
python3 - <<'PY'
import zipfile
with zipfile.ZipFile('.tools/p.nupkg') as z:
    z.extractall('.tools/p-package')
PY
chmod +x scripts/p-build/mvn
source scripts/p-env.sh
dotnet "$P_DLL" compile --mode pex --pproj models/Quota.pproj
echo 'P toolchain ready. Run make models.'
