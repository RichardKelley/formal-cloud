//! Sequential logic only: no storage, HTTP, concurrency, or side effects.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Quota {
    pub used: u32,
    pub limit: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QuotaError {
    InvalidState,
    Exceeded,
}

/// Reject invalid states first, then subtract before adding to avoid overflow.
pub fn reserve(quota: Quota, amount: u32) -> Result<Quota, QuotaError> {
    if quota.used > quota.limit {
        return Err(QuotaError::InvalidState);
    }
    if amount > quota.limit - quota.used {
        return Err(QuotaError::Exceeded);
    }
    Ok(Quota {
        used: quota.used + amount,
        limit: quota.limit,
    })
}
