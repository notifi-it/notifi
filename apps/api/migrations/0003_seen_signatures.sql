CREATE TABLE seen_signatures (
  sig_hash    TEXT PRIMARY KEY,
  expires_at  INTEGER NOT NULL
);

CREATE INDEX idx_seen_signatures_expiry ON seen_signatures(expires_at);
