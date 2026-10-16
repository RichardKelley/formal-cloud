pub mod api;
pub mod store;

/// Deliberate bug for the opt-in overflow demonstration.
pub fn reserve_buggy(
    q: quota_core::Quota,
    amount: u32,
) -> Result<quota_core::Quota, quota_core::QuotaError> {
    if q.used + amount <= q.limit {
        Ok(quota_core::Quota {
            used: q.used + amount,
            ..q
        })
    } else {
        Err(quota_core::QuotaError::Exceeded)
    }
}
