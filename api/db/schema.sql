PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  role          TEXT NOT NULL CHECK (role IN ('requester','donor','bank')),
  blood_group   TEXT CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  lat           REAL NOT NULL DEFAULT 0,
  lng           REAL NOT NULL DEFAULT 0,
  push_token    TEXT,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  -- Phone auth + donor profile (D11). Old name+role signups may leave these NULL.
  phone         TEXT UNIQUE,
  sex           TEXT CHECK (sex IS NULL OR sex IN ('male','female','other')),
  age           INTEGER CHECK (age IS NULL OR (age >= 0 AND age <= 120)),
  weight_kg     REAL CHECK (weight_kg IS NULL OR weight_kg >= 0),
  height_cm     REAL CHECK (height_cm IS NULL OR height_cm >= 0),
  donated_before INTEGER NOT NULL DEFAULT 0,
  last_donated_at TEXT,
  available     INTEGER NOT NULL DEFAULT 1 CHECK (available IN (0,1)),
  consent_at    TEXT,
  UNIQUE (name, role)
);

CREATE TABLE IF NOT EXISTS bank_stock (
  bank_id     TEXT NOT NULL REFERENCES users(id),
  blood_group TEXT NOT NULL CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  units       INTEGER NOT NULL DEFAULT 0 CHECK (units >= 0),
  updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  PRIMARY KEY (bank_id, blood_group)
);

CREATE TABLE IF NOT EXISTS requests (
  id           TEXT PRIMARY KEY,
  requester_id TEXT NOT NULL REFERENCES users(id),
  blood_group  TEXT NOT NULL CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  units        INTEGER NOT NULL CHECK (units > 0),
  hospital     TEXT NOT NULL,
  urgency      TEXT NOT NULL CHECK (urgency IN ('low','medium','high','critical')),
  lat          REAL NOT NULL,
  lng          REAL NOT NULL,
  status       TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','fulfilled','cancelled')),
  channel_id   TEXT,
  created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  fulfilled_at TEXT
);

CREATE TABLE IF NOT EXISTS request_members (
  request_id TEXT NOT NULL REFERENCES requests(id),
  user_id    TEXT NOT NULL REFERENCES users(id),
  role       TEXT NOT NULL,
  joined_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  PRIMARY KEY (request_id, user_id)
);

-- One pledged donation per donor per request (written on donor accept).
CREATE TABLE IF NOT EXISTS donations (
  id         TEXT PRIMARY KEY,
  request_id TEXT NOT NULL REFERENCES requests(id),
  donor_id   TEXT NOT NULL REFERENCES users(id),
  units      INTEGER NOT NULL CHECK (units > 0),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  UNIQUE (request_id, donor_id)
);

-- In-app notification feed written by the Notifier from request events.
-- Notification rows keep plain ids (no FK) so a notification survives a
-- rolled-back or deleted request; the feed is best-effort by design.
CREATE TABLE IF NOT EXISTS notifications (
  id         TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  type       TEXT NOT NULL,
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  request_id TEXT,
  read_at    TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_users_role_group ON users(role, blood_group);
-- The phone index is created by store.Open's migration: fresh tables already
-- have an inline UNIQUE constraint, legacy tables get index + column there.
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_donations_request ON donations(request_id);
