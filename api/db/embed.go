// Package db exposes the SQL used to initialise and reset the SQLite database.
package db

import _ "embed"

// Schema is the DDL from schema.sql, applied on every boot (statements are idempotent).
//
//go:embed schema.sql
var Schema string

// Seed is the demo dataset used by POST /dev/reset when DEV=1. It clears all
// mutable tables before inserting users, stock and one open request.
//
//go:embed seed.sql
var Seed string
