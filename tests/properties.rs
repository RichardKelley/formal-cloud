use proptest::prelude::*;
use quota_core::{reserve, Quota, QuotaError};

fn valid_quota() -> impl Strategy<Value = Quota> {
    any::<u32>().prop_flat_map(|limit| (0..=limit).prop_map(move |used| Quota { used, limit }))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(512))]
    // For a valid quota, accept exactly when used + amount <= limit. Success
    // adds exactly amount and preserves the limit; otherwise return Exceeded.
    // Compute the expected sum in u64 so the test's arithmetic cannot overflow.
    #[test]
    fn agrees_with_wide_integer_spec(q in valid_quota(), amount in any::<u32>()) {
        let expected = u64::from(q.used) + u64::from(amount);
        match reserve(q, amount) {
            Ok(next) => {
                prop_assert!(next.used <= next.limit);
                prop_assert_eq!(u64::from(next.used), expected);
                prop_assert_eq!(next.limit, q.limit);
            }
            Err(e) => {
                prop_assert_eq!(e, QuotaError::Exceeded);
                prop_assert!(expected > u64::from(q.limit));
            }
        }
        prop_assert_eq!(reserve(q, amount).is_ok(), expected <= u64::from(q.limit));
    }

    // After each request, usage stays within the quota and equals initial usage
    // plus all accepted amounts. The caller keeps its old state on rejection;
    // a request is rejected only when it would exceed the quota.
    #[test]
    fn sequences_preserve_invariant(q in valid_quota(), amounts in prop::collection::vec(any::<u32>(), 0..100)) {
        let mut actual = q;
        let mut model_used = u64::from(q.used);
        for amount in amounts {
            let before = actual;
            let expected = model_used + u64::from(amount);
            match reserve(actual, amount) {
                Ok(next) => { prop_assert!(expected <= u64::from(q.limit)); actual = next; model_used = expected; }
                Err(_) => { prop_assert!(expected > u64::from(q.limit)); prop_assert_eq!(actual, before); }
            }
            prop_assert!(actual.used <= actual.limit);
            prop_assert_eq!(u64::from(actual.used), model_used);
        }
    }

    // If usage already exceeds the limit, reject every requested amount with
    // InvalidState rather than treating the quota as a valid starting state.
    #[test]
    fn invalid_states_are_rejected(limit in 0..u32::MAX, amount in any::<u32>()) {
        prop_assert_eq!(reserve(Quota { used: limit + 1, limit }, amount), Err(QuotaError::InvalidState));
    }

    // Even at the u32 boundary, accept exactly when the mathematical sum fits
    // within the limit, without panicking or accepting a wrapped-around sum.
    // Expected failure, isolated from normal CI. Works in debug and release:
    // debug panics; release wraps and disagrees with the u64 specification.
    #[test]
    #[ignore = "intentional overflow bug; run make overflow"]
    fn overflow_demo(used in 1u32..=u32::MAX, amount in 1u32..=u32::MAX) {
        let q = Quota { used, limit: u32::MAX };
        let expected = u64::from(used) + u64::from(amount) <= u64::from(q.limit);
        prop_assert_eq!(formal_cloud::reserve_buggy(q, amount).is_ok(), expected);
    }
}

// Boundary examples: reserving zero preserves a full quota (including 0/0),
// adding one to a full quota is rejected, and filling an empty quota is allowed.
#[test]
fn boundaries() {
    let full = Quota {
        used: u32::MAX,
        limit: u32::MAX,
    };
    assert_eq!(reserve(full, 0), Ok(full));
    assert_eq!(reserve(full, 1), Err(QuotaError::Exceeded));
    assert_eq!(
        reserve(Quota { used: 0, limit: 0 }, 0),
        Ok(Quota { used: 0, limit: 0 })
    );
    assert_eq!(
        reserve(
            Quota {
                used: 0,
                limit: u32::MAX
            },
            u32::MAX
        ),
        Ok(full)
    );
}
