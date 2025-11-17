package model

import (
	"github.com/google/uuid"
	"net"
	"time"
)

type User struct {
	ID                              uuid.UUID `gorm:"primaryKey"`
	OrganizationID                  uuid.UUID
	Email                           string
	PasswordHash                    string
	RoleID                          int16
	EmailVerified                   bool
	EmailVerifiedAt                 *time.Time
	EmailVerificationToken          string
	EmailVerificationTokenExpiresAt *time.Time
	FailedLoginAttempts             int16
	LastFailedLoginAt               *time.Time
	LockedUntil                     *time.Time
	LastLoginAt                     *time.Time
	LastLoginIP                     *net.IP
	PasswordChangedAt               time.Time
	Status                          string
	CreatedAt                       time.Time
	UpdatedAt                       time.Time
	CreatedBy                       *uuid.UUID
	UpdatedBy                       *uuid.UUID
}

func (User) TableName() string {
	return "equipchain.users"
}
