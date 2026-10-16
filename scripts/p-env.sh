#!/usr/bin/env bash
# Source from scripts after changing to the repository root.
export DOTNET_ROOT="$PWD/.tools/dotnet"
export DOTNET_CLI_HOME="$PWD/.tools/dotnet-home"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export PATH="$PWD/scripts/p-build:$DOTNET_ROOT:$PATH"
export QUOTA_PEX_JAR="$PWD/.tools/pex.jar"
export QUOTA_LOMBOK_JAR="$PWD/.tools/lombok.jar"
P_DLL="$PWD/.tools/p-package/tools/net8.0/any/p.dll"
