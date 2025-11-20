package main

import (
	"context"
	"fmt"
	"log"

	"github.com/NWhite12/EquipChain/internal/api"
	"github.com/NWhite12/EquipChain/internal/config"
	"github.com/NWhite12/EquipChain/internal/middleware"
	"github.com/NWhite12/EquipChain/internal/repository"
	"github.com/NWhite12/EquipChain/internal/service"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

func main() {
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}
	logger, _ := zap.NewProduction()
	defer logger.Sync()

	ctx := context.Background()
	db, err := config.InitDB(ctx, cfg)
	if err != nil {
		panic(err)
	}

	// Initialize repositories
	userRepo := repository.NewUserRepository(db)
	equipmentRepo := repository.NewEquipmentRepository(db)

	// Initialize services
	jwtService := service.NewJWTService(cfg)
	authService := service.NewAuthService(userRepo, jwtService)
	equipmentService := service.NewEquipmentService(equipmentRepo)

	// Initialize handlers
	authHandler := api.NewAuthHandler(authService)
	equipmentHandler := api.NewEquipmentHandler(equipmentService)

	router := gin.Default()

	// Public routes
	router.POST("/api/auth/register", authHandler.Register)
	router.POST("/api/auth/login", authHandler.Login)

	// Protected routes
	protected := router.Group("/api")
	protected.Use(middleware.AuthMiddleware(jwtService))
	{
		// Equipment endpoints
		protected.GET("/equipment", equipmentHandler.List)
		protected.GET("/equipment/:id", equipmentHandler.Get)
		protected.POST("/equipment", equipmentHandler.Create)
		protected.PUT("/equipment/:id", equipmentHandler.Update)
		protected.DELETE("/equipment/:id", equipmentHandler.Delete)

		// Health check
		protected.GET("/health", func(c *gin.Context) {
			c.JSON(200, gin.H{"status": "authenticated"})
		})
	}

	if err := router.Run(":8080"); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	} else {
		fmt.Println("Server running on :8080")
	}
}
