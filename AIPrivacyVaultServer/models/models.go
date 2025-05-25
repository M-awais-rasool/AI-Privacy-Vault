package models

import "time"

type User struct {
	ID           int64     `json:"id" db:"id"`
	Username     string    `json:"username" db:"username"`
	PasswordHash string    `json:"-" db:"password_hash"`
	DeviceID     string    `json:"device_id" db:"device_id"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	LastSyncAt   time.Time `json:"last_sync_at" db:"last_sync_at"`
}

type FileMetadata struct {
	ID             string    `json:"id" db:"id"`
	EncryptedData  string    `json:"encrypted_data" db:"encrypted_data"`
	UserID         int64     `json:"user_id" db:"user_id"`
	Version        int       `json:"version" db:"version"`
	LastModifiedAt time.Time `json:"last_modified_at" db:"last_modified_at"`
	IsDeleted      bool      `json:"is_deleted" db:"is_deleted"`
}

type PlainMetadata struct {
	FileName       string    `json:"filename"`
	Classification string    `json:"classification"`
	RiskScore      int       `json:"risk_score"`
	FileSize       int64     `json:"file_size"`
	DateAdded      time.Time `json:"date_added"`
	Keywords       []string  `json:"keywords"`
	Category       string    `json:"category"`
}

type SyncRequest struct {
	DeviceID  string         `json:"device_id"`
	Items     []FileMetadata `json:"items"`
	SyncToken string         `json:"sync_token"`
}

type SyncResponse struct {
	UpdatedItems []FileMetadata `json:"updated_items"`
	DeletedIDs   []string       `json:"deleted_ids"`
	SyncToken    string         `json:"sync_token"`
	Timestamp    time.Time      `json:"timestamp"`
}

type AuthRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
	DeviceID string `json:"device_id" binding:"required"`
}
type AuthResponse struct {
	Token     string `json:"token"`
	ExpiresAt int64  `json:"expires_at"`
	UserID    int64  `json:"user_id"`
}
