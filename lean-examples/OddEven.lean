import Std

-- An odd integer has a witness k such that n = 2k + 1.
def Odd (n : Int) : Prop :=
  ∃ k : Int, n = 2 * k + 1

-- An even integer has a witness k such that n = 2k.
def Even (n : Int) : Prop :=
  ∃ k : Int, n = 2 * k

/-- If two integers are odd, their sum is even. -/
theorem odd_add_odd (a b : Int) (ha : Odd a) (hb : Odd b) :
    Even (a + b) := by
  -- Extract a witness m and its equation hm from ha.
  cases ha with
  | intro m hm =>
    -- Extract a witness n and its equation hn from hb.
    cases hb with
    | intro n hn =>
      -- Supply the witness that makes a + b even.
      refine ⟨m + n + 1, ?_⟩
      -- The remaining goal is a + b = 2 * (m + n + 1).
      omega

/-- The same argument using `obtain` to name the existential witnesses. -/
theorem odd_add_odd_1 (a b : Int) (ha : Odd a) (hb : Odd b) :
    Even (a + b) := by
  unfold Odd at ha hb
  obtain ⟨m, hm⟩ := ha
  obtain ⟨n, hn⟩ := hb
  unfold Even
  refine ⟨m + n + 1, ?_⟩
  grind
