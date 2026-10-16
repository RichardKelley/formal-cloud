import QuotaCore

open Aeneas Aeneas.Std
open quota_core

/-- Allocation is within the tenant's fixed quota. U32 supplies nonnegativity. -/
def Valid (q : Quota) : Prop := q.used.val ≤ q.limit.val

/-- For every quota `q` and request amount `a`, assume that current usage is
    within the limit (`h : Valid q`). Then the translated Rust function finishes
    without a panic or arithmetic failure, and its returned value satisfies:

    * If the reservation is accepted, the new usage is still within the limit,
      is exactly the old usage plus the requested amount, and the limit is unchanged.
    * If the reservation is rejected, the error is `Exceeded` and the requested
      total really is greater than the limit. Valid input cannot produce an
      `InvalidState` error.

    The notation `reserve q a ⦃ result => ... ⦄` asserts that the computation
    succeeds and its result has the stated properties. Here `.Ok` and `.Err`
    are the Rust function's acceptance/rejection outcomes; a rejection is a
    normal return, not a panic. `.val` reads a U32's mathematical integer value,
    so the sums in the specification describe exact arithmetic, not wraparound. -/
@[step]
theorem reserve_spec (q : Quota) (a : U32) (h : Valid q) :
    reserve q a ⦃ result =>
      match result with
      | .Ok next => Valid next ∧ next.used.val = q.used.val + a.val ∧ next.limit = q.limit
      | .Err error => error = .Exceeded ∧ q.limit.val < q.used.val + a.val ⦄ := by
  unfold reserve
  unfold Valid at *
  split
  · scalar_tac
  · step as ⟨remaining⟩
    split
    · simp
      scalar_tac
    · step as ⟨total⟩
      scalar_tac

/-- A sequential caller retains the old state on domain-level rejection. -/
def applyRequest (q : Quota) (a : U32) : Result Quota := do
  let r ← reserve q a
  match r with
  | .Ok next => .ok next
  | .Err _ => .ok q

/-- Starting from a valid quota, handling one request leaves a valid quota and
    does not panic. This includes both outcomes: acceptance returns the valid
    updated quota guaranteed by `reserve_spec`; rejection keeps the original
    quota, which is valid by assumption `h`.

    This theorem states preservation of the quota bound. The more detailed
    accounting and error guarantees are in `reserve_spec`. -/
@[step]
theorem applyRequest_spec (q : Quota) (a : U32) (h : Valid q) :
    applyRequest q a ⦃ next => Valid next ⦄ := by
  unfold applyRequest
  step as ⟨r, hr⟩
  cases r with
  | Ok next => simpa using hr.1
  | Err error => simpa using h

/-- This driver is a Lean specification of sequential calls, not extracted Rust. -/
def reserveMany (q : Quota) (amounts : List U32) : Result Quota := do
  match amounts with
  | [] => .ok q
  | a :: rest =>
    let next ← applyRequest q a
    reserveMany next rest

/-- For any finite list of request amounts, start with a valid quota and process
    the requests one at a time, passing each resulting quota to the next call.
    The whole computation finishes without a panic and its final quota is valid.
    Rejected requests leave usage unchanged, as specified by `applyRequest`.

    The proof is by induction on the list: no requests leave the starting quota
    unchanged; for a nonempty list, `applyRequest_spec` preserves validity for
    the first request, and the induction hypothesis handles the remaining requests.

    This is a theorem about the Lean sequential driver `reserveMany`. It does
    not establish safety for concurrent callers using stale snapshots, nor does
    it verify the HTTP server or database implementation. -/
theorem reserveMany_spec (amounts : List U32) (q : Quota) (h : Valid q) :
    reserveMany q amounts ⦃ next => Valid next ⦄ := by
  induction amounts generalizing q with
  | nil => simpa [reserveMany] using h
  | cons a rest ih =>
    unfold reserveMany
    step as ⟨next, hn⟩
    exact ih next hn

#print axioms reserve_spec
#print axioms reserveMany_spec
