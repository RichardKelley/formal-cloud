import Lake
open Lake DSL
package formalCloudProofs
require aeneas from "../.tools/aeneas/backends/lean"
@[default_target] lean_lib QuotaCore
@[default_target] lean_lib QuotaProof
