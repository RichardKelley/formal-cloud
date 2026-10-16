# What has actually been established?

| Layer | Evidence or guarantee | Boundary |
|---|---|---|
| Rust core | Property tests against a wider-integer oracle, including request sequences | Sampled executions; not universal correctness |
| Extracted core | Lean theorem over the actual Aeneas translation | Assumes translation and the semantics of supported Rust; not a proof of the compiler, server, or SQLite |
| Vulnerable protocol | Reproducible runtime schedule and PEx counterexample | Read/check/increment, not snapshot overwrite |
| Atomic protocol | PEx exhaustively completes the finite two-client P model without a violation | One tenant, fixed quota/amount, no retries, failures, or external provisioning |
| HTTP/SQLite implementation | Integration tests with independent connections and transactions | Implementation evidence, not an end-to-end refinement proof |

## Sequential specification

The Rust core uses `u32`. Validity is `used ≤ limit`; nonnegativity follows from
the representation. For valid input the proof establishes that the computation
terminates without arithmetic failure. Acceptance preserves the limit and
returns exactly `old used + amount ≤ limit`. Rejection is `Exceeded` and means
`old used + amount > limit`. Rust explicitly rejects invalid input, which is
also tested; the main theorem assumes validity.

`reserveMany_spec` proves preservation for arbitrary finite sequences in a Lean
driver that keeps the old state after rejection. This driver composes calls to
the extracted function; the driver itself is explicitly handwritten Lean.

The committed extraction was generated with the pinned Aeneas release.
`make proof` checks its source fingerprint, typechecks the proof, and prints its
axiom dependencies. No `sorry` or user-introduced axiom is used in these proofs.
Regenerate with `make translate` after changing the core. A fingerprint detects
staleness; it is not itself evidence that the translation is correct.

## Model correspondence

`NonAtomicStore` handles `eRead` by sending a snapshot to the requesting client.
`NonAtomicClient` checks that snapshot using the capacity predicate, then sends
`eIncrement`. The store adds the amount to its *current* allocation without
rechecking. The message boundaries allow both clients to authorize an increment
from 70 before either increment is processed. `race.rs` implements the same
read/check/increment separation, with a barrier choosing a violating schedule;
the P test uses scheduler exploration instead of a barrier.

`AtomicStore` handles `eReserve` by combining the current-state check and
increment, without receiving another request between them. The SQL
predicate implements the same mathematical condition over nonnegative integers.
Inputs are bounded by `u32`; SQLite's signed 64-bit arithmetic can represent
their sums. The extra `amount ≤ quota_limit` guard makes the SQL bound explicit.
The schema checks ensure every stored quota is valid.

`QuotaInvariant` observes `eUsage`, announced at initialization and after each
update (also after rejection in the atomic protocol). The test drivers fix
two clients, initial usage 70, limit 100, and request amounts 20. P integers
are used with these nonnegative constants; this is not a model of Rust overflow.

PEx explores this finite system with depth-first search and no schedule-count
bound. One-shot clients halt after their results (or local rejection), and the
store becomes idle when no messages remain. The scripts require the exact
quota counterexample for the broken protocol and `correct for any depth` with
zero bugs for the fixed protocol. A timeout, step-bound failure, or partial
search does not pass. "Any depth" refers only to the configured finite system,
not arbitrary client counts or inputs. The model checks safety; it makes no
availability, fairness, or liveness claim and is not an end-to-end refinement
proof of the Rust/SQLite implementation.

## Storage and retry assumptions

- A single SQLite database is authoritative. Independent connections share
  SQLite's transaction and locking semantics. There are no stale replicas.
- Every writer preserves the schema and the atomic conditional-update protocol.
  Quotas are fixed in this model; administrative changes need their own rules.
- A keyed operation acquires an `IMMEDIATE` transaction before lookup. Its quota
  mutation and cached response commit together. Simultaneous retries therefore
  allocate at most once for the same tenant/key and payload.
- Clients reuse a stable key when the outcome is uncertain. Reusing it with a
  different amount is an error. Key expiry is deliberately absent; deleting keys
  would require a defined retry horizon and additional reasoning.
- A replay returns the stored outcome, even if later allocations have changed
  current usage. Rejected results are cached as part of that contract.
- Database errors produce 503; they are not reported as successful allocations.
  Crash recovery and disk durability rely on SQLite/filesystem semantics, which
  the tests and P models do not verify.

Actual VM provisioning is outside the transaction and outside this demo.
Adding it introduces another failure boundary (e.g. an outbox or a compensating
workflow), even when reservation and deduplication are correct.
