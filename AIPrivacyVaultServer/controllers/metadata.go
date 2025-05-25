package controllers

import (
	"database/sql"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"AIPrivacyVaultServer/models"
	"AIPrivacyVaultServer/utils"
)

// MetadataController handles file metadata operations
type MetadataController struct {
	db *sql.DB
}

// NewMetadataController creates a new metadata controller
func NewMetadataController(db *sql.DB) *MetadataController {
	return &MetadataController{
		db: db,
	}
}

func (mc *MetadataController) GetAllMetadata(c *gin.Context) {
	userID := c.GetInt64("userID")

	rows, err := mc.db.Query(
		"SELECT id, encrypted_data, version, last_modified_at, is_deleted FROM file_metadata WHERE user_id = ?",
		userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	defer rows.Close()

	var items []models.FileMetadata
	for rows.Next() {
		var item models.FileMetadata
		if err := rows.Scan(&item.ID, &item.EncryptedData, &item.Version, &item.LastModifiedAt, &item.IsDeleted); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error scanning rows"})
			return
		}
		item.UserID = userID
		items = append(items, item)
	}

	c.JSON(http.StatusOK, items)
}

func (mc *MetadataController) GetMetadata(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetInt64("userID")

	var item models.FileMetadata
	err := mc.db.QueryRow(
		"SELECT id, encrypted_data, version, last_modified_at, is_deleted FROM file_metadata WHERE id = ? AND user_id = ?",
		id, userID,
	).Scan(&item.ID, &item.EncryptedData, &item.Version, &item.LastModifiedAt, &item.IsDeleted)

	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "Metadata not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	item.UserID = userID
	c.JSON(http.StatusOK, item)
}

func (mc *MetadataController) AddMetadata(c *gin.Context) {
	var item models.FileMetadata
	if err := c.ShouldBindJSON(&item); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	userID := c.GetInt64("userID")
	item.UserID = userID
	item.ID = uuid.New().String()
	item.Version = 1
	item.LastModifiedAt = time.Now()
	item.IsDeleted = false

	_, err := mc.db.Exec(
		"INSERT INTO file_metadata (id, encrypted_data, user_id, version, last_modified_at, is_deleted) VALUES (?, ?, ?, ?, ?, ?)",
		item.ID, item.EncryptedData, item.UserID, item.Version, item.LastModifiedAt, item.IsDeleted,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add metadata"})
		return
	}

	c.JSON(http.StatusCreated, item)
}

func (mc *MetadataController) UpdateMetadata(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetInt64("userID")

	var item models.FileMetadata
	if err := c.ShouldBindJSON(&item); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	var currentVersion int
	err := mc.db.QueryRow("SELECT version FROM file_metadata WHERE id = ? AND user_id = ?", id, userID).Scan(&currentVersion)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "Metadata not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	item.Version = currentVersion + 1
	item.LastModifiedAt = time.Now()
	item.UserID = userID

	_, err = mc.db.Exec(
		"UPDATE file_metadata SET encrypted_data = ?, version = ?, last_modified_at = ?, is_deleted = ? WHERE id = ? AND user_id = ?",
		item.EncryptedData, item.Version, item.LastModifiedAt, item.IsDeleted, id, userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update metadata"})
		return
	}

	c.JSON(http.StatusOK, item)
}

func (mc *MetadataController) DeleteMetadata(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetInt64("userID")

	var currentVersion int
	err := mc.db.QueryRow("SELECT version FROM file_metadata WHERE id = ? AND user_id = ?", id, userID).Scan(&currentVersion)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "Metadata not found"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	_, err = mc.db.Exec(
		"UPDATE file_metadata SET version = ?, last_modified_at = ?, is_deleted = ? WHERE id = ? AND user_id = ?",
		currentVersion+1, time.Now(), true, id, userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete metadata"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Metadata deleted"})
}

func (mc *MetadataController) SyncMetadata(c *gin.Context) {
	userID := c.GetInt64("userID")

	var syncReq models.SyncRequest
	if err := c.ShouldBindJSON(&syncReq); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	tx, err := mc.db.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to begin transaction"})
		return
	}
	defer tx.Rollback()

	var updatedItems []models.FileMetadata
	var deletedIDs []string

	for _, clientItem := range syncReq.Items {
		var serverItem models.FileMetadata
		err := tx.QueryRow(
			"SELECT id, encrypted_data, version, last_modified_at, is_deleted FROM file_metadata WHERE id = ? AND user_id = ?",
			clientItem.ID, userID,
		).Scan(&serverItem.ID, &serverItem.EncryptedData, &serverItem.Version, &serverItem.LastModifiedAt, &serverItem.IsDeleted)
		fmt.Printf("Processing client item: %v\n", clientItem)
		if err == sql.ErrNoRows {
			_, err = tx.Exec(
				"INSERT INTO file_metadata (id, encrypted_data, user_id, version, last_modified_at, is_deleted) VALUES (?, ?, ?, ?, ?, ?)",
				clientItem.ID, clientItem.EncryptedData, userID, clientItem.Version, clientItem.LastModifiedAt, clientItem.IsDeleted,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to insert client item"})
				return
			}
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error checking item"})
			return
		} else {
			if clientItem.Version > serverItem.Version {
				_, err = tx.Exec(
					"UPDATE file_metadata SET encrypted_data = ?, version = ?, last_modified_at = ?, is_deleted = ? WHERE id = ? AND user_id = ?",
					clientItem.EncryptedData, clientItem.Version, clientItem.LastModifiedAt, clientItem.IsDeleted, clientItem.ID, userID,
				)
				if err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update server item"})
					return
				}
			}
		}
	}

	rows, err := tx.Query(
		"SELECT id, encrypted_data, version, last_modified_at, is_deleted FROM file_metadata WHERE user_id = ?",
		userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to query server items"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var item models.FileMetadata
		if err := rows.Scan(&item.ID, &item.EncryptedData, &item.Version, &item.LastModifiedAt, &item.IsDeleted); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error scanning rows"})
			return
		}
		item.UserID = userID

		if item.IsDeleted {
			deletedIDs = append(deletedIDs, item.ID)
		} else {
			updatedItems = append(updatedItems, item)
		}
	}

	now := time.Now()
	_, err = tx.Exec("UPDATE users SET last_sync_at = ? WHERE id = ?", now, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update sync timestamp"})
		return
	}

	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	syncToken := utils.GenerateSyncToken(userID, now)

	c.JSON(http.StatusOK, models.SyncResponse{
		UpdatedItems: updatedItems,
		DeletedIDs:   deletedIDs,
		SyncToken:    syncToken,
		Timestamp:    now,
	})
}

func (mc *MetadataController) SyncStatus(c *gin.Context) {
	userID := c.GetInt64("userID")

	var lastSyncAt time.Time
	var deviceID string

	err := mc.db.QueryRow("SELECT last_sync_at, device_id FROM users WHERE id = ?", userID).Scan(&lastSyncAt, &deviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get sync status"})
		return
	}

	var itemCount int
	err = mc.db.QueryRow("SELECT COUNT(*) FROM file_metadata WHERE user_id = ? AND is_deleted = 0", userID).Scan(&itemCount)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count items"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"last_sync_at": lastSyncAt,
		"device_id":    deviceID,
		"item_count":   itemCount,
		"sync_token":   utils.GenerateSyncToken(userID, lastSyncAt),
	})
}
