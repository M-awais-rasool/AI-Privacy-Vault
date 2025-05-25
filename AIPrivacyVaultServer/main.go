package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"AIPrivacyVaultServer/config"
	"AIPrivacyVaultServer/controllers"
	"AIPrivacyVaultServer/utils"
)

func main() {
	cfg := config.LoadConfig()

	db, err := utils.InitDatabase(cfg.DatabasePath)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()

	router := gin.Default()
	router.Use(gin.Logger())
	router.Use(gin.Recovery())

	authController := controllers.NewAuthController(db, cfg.JWTSecret)
	metadataController := controllers.NewMetadataController(db)

	router.POST("/api/auth/register", authController.Register)
	router.POST("/api/auth/login", authController.Login)
	router.GET("/api/status", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "online"})
	})

	authorized := router.Group("/api")
	authorized.Use(authController.AuthMiddleware())
	{
		authorized.GET("/metadata", metadataController.GetAllMetadata)
		authorized.GET("/metadata/:id", metadataController.GetMetadata)
		authorized.POST("/metadata", metadataController.AddMetadata)
		authorized.PUT("/metadata/:id", metadataController.UpdateMetadata)
		authorized.DELETE("/metadata/:id", metadataController.DeleteMetadata)

		authorized.POST("/sync", metadataController.SyncMetadata)
		authorized.GET("/sync/status", metadataController.SyncStatus)
	}

	serverCh := make(chan error, 1)
	go func() {
		serverStartTime := time.Now()
		serverErr := router.Run(":" + cfg.ServicePort)
		log.Printf("Server stopped after running for %v", time.Since(serverStartTime))
		serverCh <- serverErr
	}()

	var discovery *utils.DiscoveryService
	go func() {
		time.Sleep(500 * time.Millisecond)

		discoveryStartTime := time.Now()
		log.Printf("Starting discovery service at %v...", discoveryStartTime.Format(time.RFC3339))
		discovery = utils.NewDiscoveryService(cfg.ServiceName, cfg.ServicePort)

		if err := discovery.Advertise(); err != nil {
			log.Printf("Warning: Failed to start discovery service: %v", err)
		} else {
			log.Printf("Discovery service started successfully in %v", time.Since(discoveryStartTime))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	log.Printf("Server ready and waiting for connections")

	select {
	case err := <-serverCh:
		log.Fatalf("Server error: %v", err)
	case <-quit:
		log.Println("Shutting down server...")
	}

	if discovery != nil {
		discoveryStopStart := time.Now()
		discovery.Stop()
		log.Printf("Discovery service stopped in %v", time.Since(discoveryStopStart))
	}

	log.Printf("Server shutdown completed")
}
