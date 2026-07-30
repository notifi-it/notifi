CREATE TABLE devices (
  id                     INTEGER PRIMARY KEY,
  public_key             TEXT NOT NULL UNIQUE,
  encryption_public_key  TEXT NOT NULL,
  apns_token             TEXT NOT NULL,
  apns_token_hmac        TEXT NOT NULL UNIQUE,
  platform               TEXT NOT NULL,
  app_version            TEXT NOT NULL,
  created_at             INTEGER NOT NULL,
  last_seen_at           INTEGER NOT NULL
);

CREATE TABLE keys (
  id               INTEGER PRIMARY KEY,
  device_id        INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  meta_sealed      TEXT NOT NULL,
  secret_hash      TEXT NOT NULL UNIQUE,
  sent_count       INTEGER NOT NULL DEFAULT 0,
  rl_window_start  INTEGER NOT NULL DEFAULT 0,
  rl_window_count  INTEGER NOT NULL DEFAULT 0,
  created_at       INTEGER NOT NULL,
  last_used_at     INTEGER,
  revoked_at       INTEGER
);

CREATE TABLE messages (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id       INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  key_id          INTEGER REFERENCES keys(id) ON DELETE SET NULL,
  content_sealed  TEXT NOT NULL,
  created_at      INTEGER NOT NULL,
  expires_at      INTEGER NOT NULL
);

CREATE INDEX idx_messages_device ON messages(device_id, id);
CREATE INDEX idx_messages_expiry ON messages(expires_at);
