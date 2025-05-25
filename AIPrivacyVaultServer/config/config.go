package config

import (
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	ServiceName  string
	ServicePort  string
	DatabasePath string
	JWTSecret    string
	EncryptKey   string
}

func LoadConfig() *Config {
	envStart := time.Now()
	log.Println("Loading environment variables...")
	err := godotenv.Load()
	if err == nil {
		log.Printf("Loaded .env file in %v", time.Since(envStart))
	} else {
		log.Printf("No .env file found, using defaults and environment variables")
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		log.Fatalf("Failed to get user home directory: %v", err)
	}

	defaultDBPath := filepath.Join(homeDir, ".aiprivacyvault", "metadata.db")

	log.Printf("Creating directory structure...")
	err = os.MkdirAll(filepath.Dir(defaultDBPath), 0700)
	if err != nil {
		log.Printf("Warning: Failed to create directory: %v", err)
	}

	jwtSecret := getEnvOrDefault("JWT_SECRET", "")
	encryptKey := getEnvOrDefault("ENCRYPT_KEY", "")

	if jwtSecret == "" {
		log.Printf("Generating JWT secret key...")
		jwtSecret = generateRandomKey(32)
	}

	if encryptKey == "" {
		log.Printf("Generating encryption key...")
		encryptKey = generateRandomKey(32)
	}

	config := &Config{
		ServiceName:  getEnvOrDefault("SERVICE_NAME", "AI Privacy Vault Sync"),
		ServicePort:  getEnvOrDefault("SERVICE_PORT", "8080"),
		DatabasePath: getEnvOrDefault("DATABASE_PATH", defaultDBPath),
		JWTSecret:    jwtSecret,
		EncryptKey:   encryptKey,
	}

	log.Printf("Configuration loaded: service=%s, port=%s", config.ServiceName, config.ServicePort)
	return config
}

func getEnvOrDefault(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func generateRandomKey(length int) string {
	keyStart := time.Now()
	const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	result := make([]byte, length)

	randomBytes, err := os.ReadFile("/dev/urandom")
	if err != nil {
		log.Printf("Using fallback key generation method")
		for i := range result {
			result[i] = chars[i%len(chars)]
		}
		return string(result)
	}

	for i := range result {
		result[i] = chars[randomBytes[i%len(randomBytes)]%byte(len(chars))]
	}

	log.Printf("Key generated in %v", time.Since(keyStart))
	return string(result)
}
