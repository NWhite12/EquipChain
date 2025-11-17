package model

import (
	"github.com/google/uuid"
	"time"
)

type Equipment struct {
	ID             uuid.UUID `gorm:"primaryKey"`
	OrganizationID uuid.UUID

	SerialNumber string
	Make         string
	Model        string
	Location     *string

	StatusID int16
	OwnerID  *uuid.UUID

	QRCode          *string
	Notes           *string
	PurchasedDate   *time.Time
	WarrantyExpires *time.Time

	CreatedAt time.Time
	UpdatedAt time.Time
	DeletedAt *time.Time
	CreatedBy *uuid.UUID
	UpdatedBy *uuid.UUID
}

func (Equipment) TableName() string {
	return "equipchain.equipment"
}

type EquipmentStatusLookup struct {
	ID                int16 `gorm:"primaryKey"`
	Code              string
	Label             string
	Description       string
	AllowsMaintenance bool
	Status            string
	CreatedAt         time.Time
	UpdatedAt         time.Time
	CreatedBy         *uuid.UUID
	UpdatedBy         *uuid.UUID
}

func (EquipmentStatusLookup) TableName() string {
	return "equipchain.equipment_status_lookup"
}
