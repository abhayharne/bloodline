PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  role        TEXT NOT NULL CHECK (role IN ('requester','donor','bank')),
  blood_group TEXT CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  lat         REAL NOT NULL DEFAULT 0,
  lng         REAL NOT NULL DEFAULT 0,
  push_token  TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (name, role)
);

CREATE TABLE IF NOT EXISTS bank_stock (
  bank_id     TEXT NOT NULL REFERENCES users(id),
  blood_group TEXT NOT NULL CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  units       INTEGER NOT NULL DEFAULT 0 CHECK (units >= 0),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (bank_id, blood_group)
);

CREATE TABLE IF NOT EXISTS requests (
  id           TEXT PRIMARY KEY,
  requester_id TEXT NOT NULL REFERENCES users(id),
  blood_group  TEXT NOT NULL CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  units        INTEGER NOT NULL CHECK (units > 0),
  hospital     TEXT NOT NULL,
  urgency      TEXT NOT NULL CHECK (urgency IN ('critical','urgent','planned')),
  lat          REAL NOT NULL,
  lng          REAL NOT NULL,
  status       TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','fulfilled','cancelled')),
  channel_id   TEXT,
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  fulfilled_at TEXT
);

CREATE TABLE IF NOT EXISTS request_members (
  request_id TEXT NOT NULL REFERENCES requests(id),
  user_id    TEXT NOT NULL REFERENCES users(id),
  role       TEXT NOT NULL,
  joined_at  TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (request_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_users_role_group ON users(role, blood_group);
