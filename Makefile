.PHONY: test serve race overflow setup-p setup-proof translate proof lean-examples models model-bug model-fixed check fmt fmt-check

# Reuse the workspace-local cache when present; otherwise use Cargo's default.
ifneq ($(wildcard .tools/cargo/registry),)
export CARGO_HOME := $(CURDIR)/.tools/cargo
export CARGO_NET_OFFLINE := true
endif

test:
	cargo test --workspace --locked

serve:
	cargo run --locked --bin server

race:
	cargo run --locked --bin race

# Intentional failure: exits nonzero, so shrinking is visible to students.
overflow:
	cargo test --locked --test properties overflow_demo -- --ignored

setup-p:
	bash scripts/setup-p.sh

setup-proof:
	bash scripts/setup-proof.sh

translate:
	bash scripts/translate.sh

proof:
	bash scripts/check-proof.sh

lean-examples:
	cd lean-examples && lake build && lake env lean -DwarningAsError=true OddEven.lean

models:
	bash scripts/check-models.sh

model-bug:
	bash scripts/p-model.sh NonAtomic

model-fixed:
	bash scripts/p-model.sh Atomic

check: fmt-check test lean-examples proof models

fmt:
	cargo fmt --all

fmt-check:
	cargo fmt --all -- --check
