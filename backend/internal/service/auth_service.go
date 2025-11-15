package service

import (
	"context"
	"time"

	"github.com/NWhite12/EquipChain/internal/model"
	"github.com/NWhite12/EquipChain/internal/repository"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type AuthService struct {
	userRepo   *repository.UserRepository
	jwtService *JWTService
}

func NewAuthService(userRepo *repository.UserRepository, jwtService *JWTService) *AuthService {
	return &AuthService{
		userRepo:   userRepo,
		jwtService: jwtService,
	}
}

func (s *AuthService) RegisterUser(ctx context.Context, orgID uuid.UUID, email, password string) (*model.User, error) {
	existing, err := s.userRepo.FindByEmail(ctx, orgID, email)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, ErrEmailExists
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		return nil, err
	}

	user := &model.User{

		ID:             uuid.New(),
		OrganizationID: orgID,
		Email:          email,
		PasswordHash:   string(hashedPassword),
		RoleID:         4,
		Status:         "active",
		EmailVerified:  false,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
	}
	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, err
	}
	return user, nil
}

func (s *AuthService) LoginUser(ctx context.Context, orgID uuid.UUID, email, password string) (string, error) {
	user, err := s.userRepo.FindByEmail(ctx, orgID, email)
	if err != nil {
		return "", err
	}
	if user == nil {
		return "", ErrInvalidCredentials
	}

	if user.Status == "locked" && user.LockedUntil != nil {
		if time.Now().Before(*user.LockedUntil) {
			return "", ErrAccountLocked
		}

		s.userRepo.RestFailedAttempts(ctx, user.ID)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		s.userRepo.CheckAndUpdateLockout(ctx, user.ID)
		return "", ErrInvalidCredentials
	}

	s.userRepo.RestFailedAttempts(ctx, user.ID)

	token, err := s.jwtService.GenerateToken(user.ID, user.OrganizationID, user.Email, user.RoleID)
	if err != nil {
		return "", err
	}

	return token, nil

}

func (s *AuthService) RegisterUserAndGenerateToken(ctx context.Context, organizationID uuid.UUID, email, password string) (*model.User, string, error) {
	// Register user
	user, err := s.RegisterUser(ctx, organizationID, email, password)
	if err != nil {
		return nil, "", err
	}

	// Generate token
	token, err := s.jwtService.GenerateToken(user.ID, user.OrganizationID, user.Email, user.RoleID)
	if err != nil {
		return nil, "", err
	}

	return user, token, nil
}
