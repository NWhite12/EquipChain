package service

import (
	"fmt"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"log"
	"os"
	"time"
)

type JWTService struct {
	secret string
}

type Claims struct {
	UserID         uuid.UUID `json:"user_id"`
	OrganizationID uuid.UUID `json:"organization_id"`
	Email          string    `json:"email"`
	RoleID         int16     `json:"role_id"`
	jwt.RegisteredClaims
}

func NewJWTService() *JWTService {
	secret := os.Getenv("JWT_SECRET")
	env := os.Getenv("APP_ENV")

	// Production requires JWT_SECRET
	if secret == "" {
		if env == "production" || env == "prod" {
			log.Fatal("JWT_SECRET environment variable is required in production")
		}

		log.Println("WARNING: JWT_SECRET not set, using insecure default. DO NOT USE IN PRODUCTION!")
		secret = "dev-secret-key-change-in-production"
	}

	// Validate strength in production
	if (env == "production" || env == "prod") && len(secret) < 32 {
		log.Fatalf("JWT_SECRET must be at least 32 characters in production (currently %d chars)", len(secret))
	}

	return &JWTService{secret: secret}
}

func (s *JWTService) GenerateToken(userID, orgID uuid.UUID, email string, roleID int16) (string, error) {
	claims := Claims{
		UserID:         userID,
		OrganizationID: orgID,
		Email:          email,
		RoleID:         roleID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "equipchain",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.secret))
}

func (s *JWTService) ValidateToken(tokenString string) (*Claims, error) {
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(s.secret), nil
	})

	if err != nil {
		return nil, err
	}

	if !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}

	return claims, nil
}
