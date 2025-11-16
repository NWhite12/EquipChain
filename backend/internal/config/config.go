package config

import (
	"context"
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spf13/viper"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"time"
)

type Config struct {
	DatabaseURL string
	JWTSecret   string
	Port        string
	Environment string
	LogLevel    string
}

func LoadConfig() (*Config, error) {
	// Set config file path
	viper.SetConfigName(".env")
	viper.SetConfigType("env")
	viper.AddConfigPath(".") // Current directory

	// Read env file (won't fail if .env doesn't exist)
	_ = viper.ReadInConfig()

	// Environment variables override .env file values
	viper.AutomaticEnv()

	// Set defaults
	viper.SetDefault("DATABASE_URL", "postgresql://equipchain_dev@localhost:5432/equipchain?sslmode=disable")
	viper.SetDefault("PORT", "8080")
	viper.SetDefault("ENVIRONMENT", "development")
	viper.SetDefault("LOG_LEVEL", "debug")
	viper.SetDefault("JWT_SECRET", "dev-secret-key")

	// Bind environment variables to Viper keys
	viper.BindEnv("DATABASE_URL")
	viper.BindEnv("JWT_SECRET")
	viper.BindEnv("PORT")
	viper.BindEnv("ENVIRONMENT")
	viper.BindEnv("LOG_LEVEL")

	// Create config struct
	cfg := &Config{
		DatabaseURL: viper.GetString("DATABASE_URL"),
		JWTSecret:   viper.GetString("JWT_SECRET"),
		Port:        viper.GetString("PORT"),
		Environment: viper.GetString("ENVIRONMENT"),
		LogLevel:    viper.GetString("LOG_LEVEL"),
	}

	// Validate required config
	if cfg.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}

	return cfg, nil
}

func InitDB(ctx context.Context, cfg *Config) (*gorm.DB, error) {
	databaseURL := cfg.DatabaseURL

	// Parse pgx config
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse DATABASE_URL: %w", err)
	}

	// Apply pool settings
	config.MaxConns = 25
	config.MinConns = 5
	config.MaxConnLifetime = 5 * time.Minute
	config.MaxConnIdleTime = 2 * time.Minute
	config.ConnConfig.ConnectTimeout = 30 * time.Second

	gormDB, err := gorm.Open(postgres.New(postgres.Config{
		DriverName: "pgx",
		DSN:        config.ConnString(),
	}), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	sqlDB, err := gormDB.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to get underlying DB: %w", err)
	}
	if err := sqlDB.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	return gormDB, nil
}
