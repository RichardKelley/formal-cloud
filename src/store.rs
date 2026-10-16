use rusqlite::{params, Connection, OptionalExtension, TransactionBehavior};
use serde::Serialize;
use std::{
    path::{Path, PathBuf},
    time::Duration,
};

#[derive(Clone)]
pub struct Store {
    path: PathBuf,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Snapshot {
    pub used: u32,
    pub limit: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Reservation {
    pub accepted: bool,
    pub used: u32,
    pub limit: u32,
    pub replayed: bool,
}

#[derive(Debug)]
pub enum Error {
    Db(rusqlite::Error),
    NotFound,
    KeyConflict,
}
impl From<rusqlite::Error> for Error {
    fn from(e: rusqlite::Error) -> Self {
        Self::Db(e)
    }
}

impl Store {
    /// Each operation opens its own connection: synchronization belongs to SQLite.
    pub fn open(path: impl AsRef<Path>) -> Result<Self, Error> {
        let store = Self {
            path: path.as_ref().to_owned(),
        };
        let conn = store.connect()?;
        conn.execute_batch(include_str!("../schema.sql"))?;
        conn.execute("INSERT OR IGNORE INTO quotas VALUES ('alice', 70, 100)", [])?;
        Ok(store)
    }

    fn connect(&self) -> Result<Connection, Error> {
        let conn = Connection::open(&self.path)?;
        conn.busy_timeout(Duration::from_secs(5))?;
        Ok(conn)
    }

    pub fn snapshot(&self, tenant: &str) -> Result<Snapshot, Error> {
        self.connect()?
            .query_row(
                "SELECT used, quota_limit FROM quotas WHERE tenant_id = ?1",
                [tenant],
                |r| {
                    Ok(Snapshot {
                        used: r.get(0)?,
                        limit: r.get(1)?,
                    })
                },
            )
            .optional()?
            .ok_or(Error::NotFound)
    }

    pub fn reserve(
        &self,
        tenant: &str,
        amount: u32,
        key: Option<&str>,
    ) -> Result<Reservation, Error> {
        let mut conn = self.connect()?;
        // Acquire the SQLite writer reservation before checking the deduplication table.
        let tx = conn.transaction_with_behavior(TransactionBehavior::Immediate)?;
        if let Some(key) = key {
            let previous = tx.query_row(
                "SELECT amount, accepted, used, quota_limit FROM requests WHERE tenant_id=?1 AND request_key=?2",
                params![tenant, key], |r| Ok((r.get::<_, u32>(0)?, Reservation {
                    accepted: r.get(1)?, used: r.get(2)?, limit: r.get(3)?, replayed: true,
                }))
            ).optional()?;
            if let Some((original_amount, response)) = previous {
                if amount != original_amount {
                    return Err(Error::KeyConflict);
                }
                return Ok(response);
            }
        }
        let accepted = tx.execute(
            "UPDATE quotas SET used = used + ?1 WHERE tenant_id = ?2 AND ?1 <= quota_limit AND used <= quota_limit - ?1",
            params![amount, tenant],
        )? == 1;
        let snapshot = tx
            .query_row(
                "SELECT used, quota_limit FROM quotas WHERE tenant_id=?1",
                [tenant],
                |r| {
                    Ok(Snapshot {
                        used: r.get(0)?,
                        limit: r.get(1)?,
                    })
                },
            )
            .optional()?
            .ok_or(Error::NotFound)?;
        if let Some(key) = key {
            tx.execute(
                "INSERT INTO requests VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                params![tenant, key, amount, accepted, snapshot.used, snapshot.limit],
            )?;
        }
        // The allocation and the cached response become durable together.
        tx.commit()?;
        Ok(Reservation {
            accepted,
            used: snapshot.used,
            limit: snapshot.limit,
            replayed: false,
        })
    }
}
