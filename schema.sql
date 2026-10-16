PRAGMA journal_mode = WAL;
CREATE TABLE IF NOT EXISTS quotas (
    tenant_id TEXT PRIMARY KEY,
    used INTEGER NOT NULL CHECK (used BETWEEN 0 AND 4294967295),
    quota_limit INTEGER NOT NULL CHECK (quota_limit BETWEEN 0 AND 4294967295),
    CHECK (used <= quota_limit)
);
CREATE TABLE IF NOT EXISTS requests (
    tenant_id TEXT NOT NULL,
    request_key TEXT NOT NULL,
    amount INTEGER NOT NULL,
    accepted INTEGER NOT NULL,
    used INTEGER NOT NULL,
    quota_limit INTEGER NOT NULL,
    PRIMARY KEY (tenant_id, request_key)
);
