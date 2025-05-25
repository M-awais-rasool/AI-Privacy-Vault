package utils

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"io"
)

type CryptoService struct {
	key []byte
}

func NewCryptoService(key string) *CryptoService {
	return &CryptoService{
		key: []byte(key),
	}
}

func (cs *CryptoService) Encrypt(plaintext []byte) (string, error) {
	block, err := aes.NewCipher(cs.key)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, 12)
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	aesgcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	ciphertext := aesgcm.Seal(nil, nonce, plaintext, nil)

	encrypted := make([]byte, len(nonce)+len(ciphertext))
	copy(encrypted, nonce)
	copy(encrypted[len(nonce):], ciphertext)

	return base64.StdEncoding.EncodeToString(encrypted), nil
}

func (cs *CryptoService) Decrypt(encryptedStr string) ([]byte, error) {
	encrypted, err := base64.StdEncoding.DecodeString(encryptedStr)
	if err != nil {
		return nil, err
	}

	if len(encrypted) < 12 {
		return nil, errors.New("ciphertext too short")
	}

	nonce := encrypted[:12]
	ciphertext := encrypted[12:]

	block, err := aes.NewCipher(cs.key)
	if err != nil {
		return nil, err
	}

	aesgcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	plaintext, err := aesgcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return nil, err
	}

	return plaintext, nil
}
