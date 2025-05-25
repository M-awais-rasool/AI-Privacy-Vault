package controllers

import (
	"database/sql"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"

	"AIPrivacyVaultServer/models"
)

type AuthController struct {
	db        *sql.DB
	jwtSecret string
}

func NewAuthController(db *sql.DB, jwtSecret string) *AuthController {
	return &AuthController{
		db:        db,
		jwtSecret: jwtSecret,
	}
}

func (ac *AuthController) Register(c *gin.Context) {
	var req models.AuthRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	var exists bool
	err := ac.db.QueryRow("SELECT 1 FROM users WHERE username = ?", req.Username).Scan(&exists)
	if err != sql.ErrNoRows {
		c.JSON(http.StatusConflict, gin.H{"error": "Username already exists"})
		return
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	now := time.Now()
	result, err := ac.db.Exec(
		"INSERT INTO users (username, password_hash, device_id, created_at, last_sync_at) VALUES (?, ?, ?, ?, ?)",
		req.Username, passwordHash, req.DeviceID, now, now,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	userID, _ := result.LastInsertId()

	token, expiresAt, err := ac.generateToken(userID, req.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusCreated, models.AuthResponse{
		Token:     token,
		ExpiresAt: expiresAt,
		UserID:    userID,
	})
}

func (ac *AuthController) Login(c *gin.Context) {
	var req models.AuthRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	var user models.User
	err := ac.db.QueryRow(
		"SELECT id, username, password_hash FROM users WHERE username = ?",
		req.Username,
	).Scan(&user.ID, &user.Username, &user.PasswordHash)

	if err == sql.ErrNoRows {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	_, err = ac.db.Exec("UPDATE users SET device_id = ? WHERE id = ?", req.DeviceID, user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update device ID"})
		return
	}

	token, expiresAt, err := ac.generateToken(user.ID, user.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, models.AuthResponse{
		Token:     token,
		ExpiresAt: expiresAt,
		UserID:    user.ID,
	})
}

func (ac *AuthController) AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}
		bearerToken := strings.Split(authHeader, " ")
		if len(bearerToken) != 2 || bearerToken[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization format"})
			c.Abort()
			return
		}

		tokenString := bearerToken[1]

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(ac.jwtSecret), nil
		})

		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
			c.Set("userID", int64(claims["user_id"].(float64)))
			c.Set("username", claims["username"].(string))
			c.Next()
		} else {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
			c.Abort()
			return
		}
	}
}

func (ac *AuthController) generateToken(userID int64, username string) (string, int64, error) {
	expirationTime := time.Now().Add(24 * time.Hour)
	expiresAt := expirationTime.Unix()

	claims := jwt.MapClaims{
		"user_id":  userID,
		"username": username,
		"exp":      expiresAt,
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	tokenString, err := token.SignedString([]byte(ac.jwtSecret))
	if err != nil {
		return "", 0, err
	}

	return tokenString, expiresAt, nil
}
