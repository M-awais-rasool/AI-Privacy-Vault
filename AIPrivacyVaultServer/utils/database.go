package utils

import (
	"database/sql"
	"log"
	"os"
	"path/filepath"

	_ "github.com/mattn/go-sqlite3"
	"fmt"
)

func InitDatabase(dbPath string) (*sql.DB, error) {
	err := os.MkdirAll(filepath.Dir(dbPath), 0700)
	if err != nil {
		return nil, err
	}

	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, err
	}

	if err := db.Ping(); err != nil {
		log.Printf("Failed to ping database in %v:", err)
		return nil, err
	}

	if err := createSchema(db); err != nil {
		log.Printf("Failed to create schema in %v:", err)
		return nil, err
	}

	return db, nil
}

func createSchema(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT UNIQUE NOT NULL,
			password_hash TEXT NOT NULL,
			device_id TEXT NOT NULL,
			created_at TIMESTAMP NOT NULL,
			last_sync_at TIMESTAMP NOT NULL
		)
	`)
	if err != nil {
		log.Printf("Failed to create users table in %v:", err)
		return err
	}

	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS file_metadata (
			id TEXT PRIMARY KEY,
			encrypted_data TEXT NOT NULL,
			user_id INTEGER NOT NULL,
			version INTEGER NOT NULL,
			last_modified_at TIMESTAMP NOT NULL,
			is_deleted BOOLEAN NOT NULL DEFAULT 0,
			FOREIGN KEY (user_id) REFERENCES users(id)
		)
	`)
	if err != nil {
		log.Printf("Failed to create file_metadata table in %v:", err)
		return err
	}

	log.Printf("Creating index if not exists...")
	_, err = db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_file_metadata_user_id ON file_metadata (user_id)
	`)
	if err != nil {
		log.Printf("Failed to create index in %v:", err)
		return err
	}

	return nil
}

func GenerateSyncToken(userID int64, timestamp interface{}) string {
	return "sync_token_" + fmt.Sprint(userID)
}
