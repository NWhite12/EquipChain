package repository

import (
	"context"
	"errors"
	"github.com/NWhite12/EquipChain/internal/model"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Struct with only safe-to-update fields
type UserUpdates struct {
	Email     *string    `gorm:"column:email"`
	RoleID    *int16     `gorm:"column:role_id"`
	Status    *string    `gorm:"column:status"`
	UpdatedBy *uuid.UUID `gorm:"column:updated_by"`
}

type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) FindByEmail(ctx context.Context, orgID uuid.UUID, email string) (*model.User, error) {
	var user model.User
	if err := r.db.WithContext(ctx).Where("organization_id = ? AND email ?", orgID, email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}

		return nil, err
	}

	return &user, nil
}

func (r *UserRepository) FindByID(ctx context.Context, userID uuid.UUID) (*model.User, error) {
	var user model.User
	if err := r.db.WithContext(ctx).First(&user, userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}

		return nil, err
	}

	return &user, nil
}

func (r *UserRepository) Create(ctx context.Context, user *model.User) error {
	return r.db.WithContext(ctx).Create(user).Error
}

func (r *UserRepository) UpdateEmail(ctx context.Context, userID uuid.UUID, email string, updatedBy uuid.UUID) error {
	return r.db.WithContext(ctx).
		Model(&model.User{}).
		Where("id = ?", userID).
		Updates(map[string]interface{}{
			"email":      email,
			"updated_by": updatedBy,
		}).Error
}

func (r *UserRepository) UpdateRole(ctx context.Context, userID uuid.UUID, roleID int16, updatedBy uuid.UUID) error {
	return r.db.WithContext(ctx).
		Model(&model.User{}).
		Where("id = ?", userID).
		Updates(map[string]interface{}{
			"role_id":    roleID,
			"updated_by": updatedBy,
		}).Error
}

func (r *UserRepository) UpdateStatus(ctx context.Context, userID uuid.UUID, status string, updatedBy uuid.UUID) error {
	return r.db.WithContext(ctx).
		Model(&model.User{}).
		Where("id = ?", userID).
		Updates(map[string]interface{}{
			"status":     status,
			"updated_by": updatedBy,
		}).Error
}

func (r *UserRepository) UpdateProfile(ctx context.Context, userID uuid.UUID, email string, roleID int16, updatedBy uuid.UUID) error {
	return r.db.WithContext(ctx).
		Model(&model.User{}).
		Where("id = ?", userID).
		Updates(map[string]interface{}{
			"email":      email,
			"role_id":    roleID,
			"updated_by": updatedBy,
		}).Error
}

func (r *UserRepository) CheckAndUpdateLockout(ctx context.Context, userID uuid.UUID) (isLocked bool, remainingSeconds int, err error) {
	var locked bool
	var remaining int
	err = r.db.WithContext(ctx).Raw("SELECT is_locked, remaining_lockout_seconds FROM check_and_update_lockout(?)", userID).Row().Scan(locked, remaining)
	return locked, remaining, err
}

func (r *UserRepository) ResetFailedAttempts(ctx context.Context, userID uuid.UUID) error {
	updates := model.User{
		FailedLoginAttempts: 0,
		LockedUntil:         nil,
		Status:              "active",
	}

	return r.db.WithContext(ctx).
		Model(&model.User{}).
		Where("id = ?", userID).
		Updates(updates).Error
}
