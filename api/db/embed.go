// Package db exposes the SQL schema used to initialise the SQLite database.
package db

import _ "embed"

// Schema is the DDL from schema.sql, applied on every boot (statements are idempotent).
//
//go:embed schema.sql
var Schema string
