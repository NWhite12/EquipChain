package service

import (
	"context"
	"github.com/NWhite12/EquipChain/internal/model"
	"github.com/NWhite12/EquipChain/internal/repository"
	"github.com/google/uuid"
	"time"
)

type EquipmentService struct {
	equipmentRepo *repository.EquipmentRepository
}

func NewEquipmentService(equipmentRepo *repository.EquipmentRepository) *EquipmentService {
	return &EquipmentService{
		equipmentRepo: equipmentRepo,
	}
}
func (s *EquipmentService) ValidateEquipment(ctx context.Context, organizationID uuid.UUID, equipment *model.Equipment) error {
	if equipment.SerialNumber == "" {
		return ErrSerialNumberRequired
	}
	if equipment.Make == "" {
		return ErrMakeRequired
	}
	if equipment.Model == "" {
		return ErrModelRequired
	}

	// Only validate if provided
	if equipment.Location != nil && *equipment.Location == "" {
		return ErrLocationNotEmpty
	}

	// Serial number must be unique within organization (except for same equipment on update)
	existing, err := s.equipmentRepo.FindBySerialNumber(ctx, organizationID, equipment.SerialNumber)
	if err != nil {
		return err
	}
	if existing != nil && existing.ID != equipment.ID {
		return ErrSerialNumberExists
	}

	// StatusID validation (if provided)
	if equipment.StatusID != 0 {
		isValid, err := s.equipmentRepo.IsValidStatusID(ctx, equipment.StatusID)
		if err != nil {
			return err
		}
		if !isValid {
			return ErrInvalidStatusID
		}
	}

	// Warranty date validation (if provided)
	if equipment.WarrantyExpires != nil && equipment.WarrantyExpires.Before(time.Now()) {
		return ErrInvalidWarrantyDate
	}

	// Warranty must be after purchase date (if both provided)
	if equipment.PurchasedDate != nil && equipment.WarrantyExpires != nil {
		if equipment.WarrantyExpires.Before(*equipment.PurchasedDate) {
			return ErrWarrantyBeforePurchase
		}
	}

	return nil
}
func (s *EquipmentService) CreateEquipment(ctx context.Context, organizationID uuid.UUID, createdBy uuid.UUID, equipment *model.Equipment) (*model.Equipment, error) {
	if err := s.ValidateEquipment(ctx, organizationID, equipment); err != nil {
		return nil, err
	}

	// Set defaults
	equipment.ID = uuid.New()
	equipment.OrganizationID = organizationID
	equipment.CreatedBy = &createdBy
	equipment.UpdatedBy = &createdBy
	equipment.CreatedAt = time.Now()
	equipment.UpdatedAt = time.Now()
	if equipment.StatusID == 0 {
		equipment.StatusID = 1
	}

	// Insert
	if err := s.equipmentRepo.Create(ctx, equipment); err != nil {
		return nil, err
	}

	return equipment, nil
}

func (s *EquipmentService) UpdateEquipment(ctx context.Context, organizationID uuid.UUID, equipmentID uuid.UUID, updates map[string]interface{}, updatedBy uuid.UUID) (*model.Equipment, error) {
	// Whitelist only editable fields
	allowedFields := map[string]bool{
		"make": true, "model": true, "location": true, "status_id": true,
		"owner_id": true, "notes": true, "purchased_date": true, "warranty_expires": true,
	}

	// Filter updates to only allowed fields
	safeUpdates := make(map[string]interface{})
	for k, v := range updates {
		if allowedFields[k] {
			safeUpdates[k] = v
		}
	}

	// Validate equipment exists and belongs to org
	equipment, err := s.equipmentRepo.FindByID(ctx, equipmentID)
	if err != nil || equipment == nil || equipment.OrganizationID != organizationID {
		return nil, ErrEquipmentNotFound
	}

	// Build a temporary equipment object with updated values for validation
	equipmentToValidate := &model.Equipment{
		ID:              equipment.ID, // Keep same ID for uniqueness check
		OrganizationID:  equipment.OrganizationID,
		SerialNumber:    equipment.SerialNumber,
		Make:            equipment.Make,
		Model:           equipment.Model,
		Location:        equipment.Location,
		StatusID:        equipment.StatusID,
		WarrantyExpires: equipment.WarrantyExpires,
		PurchasedDate:   equipment.PurchasedDate,
	}

	// Apply updates to validation object
	if make, ok := safeUpdates["make"]; ok {
		equipmentToValidate.Make = make.(string)
	}
	if model, ok := safeUpdates["model"]; ok {
		equipmentToValidate.Model = model.(string)
	}
	if location, ok := safeUpdates["location"]; ok {
		if location != nil {
			loc := location.(string)
			equipmentToValidate.Location = &loc
		} else {
			equipmentToValidate.Location = nil
		}
	}
	if statusID, ok := safeUpdates["status_id"]; ok {
		equipmentToValidate.StatusID = statusID.(int16)
	}
	if purchasedDate, ok := safeUpdates["purchased_date"]; ok {
		if purchasedDate != nil {
			equipmentToValidate.PurchasedDate = purchasedDate.(*time.Time)
		} else {
			equipmentToValidate.PurchasedDate = nil
		}
	}
	if warrantyExpires, ok := safeUpdates["warranty_expires"]; ok {
		if warrantyExpires != nil {
			equipmentToValidate.WarrantyExpires = warrantyExpires.(*time.Time)
		} else {
			equipmentToValidate.WarrantyExpires = nil
		}
	}

	if err := s.ValidateEquipment(ctx, organizationID, equipmentToValidate); err != nil {
		return nil, err
	}

	// Update
	if err := s.equipmentRepo.UpdateEquipment(ctx, equipmentID, safeUpdates, updatedBy); err != nil {
		return nil, err
	}

	// Reload and return updated equipment
	return s.equipmentRepo.FindByID(ctx, equipmentID)
}

func (s *EquipmentService) DeleteEquipment(ctx context.Context, organizationID uuid.UUID, equipmentID uuid.UUID) error {
	existing, err := s.equipmentRepo.FindByID(ctx, equipmentID)
	if err != nil {
		return err
	}
	if existing == nil || existing.OrganizationID != organizationID {
		return ErrEquipmentNotFound
	}

	return s.equipmentRepo.Delete(ctx, equipmentID)
}

func (s *EquipmentService) GetEquipmentByID(ctx context.Context, organizationID uuid.UUID, equipmentID uuid.UUID) (*model.Equipment, error) {
	equipment, err := s.equipmentRepo.FindByID(ctx, equipmentID)
	if err != nil {
		return nil, err
	}
	if equipment == nil {
		return nil, ErrEquipmentNotFound
	}
	// Enforce multi-tenant isolation
	if equipment.OrganizationID != organizationID {
		return nil, ErrUnauthorized
	}
	return equipment, nil
}

func (s *EquipmentService) ListEquipment(ctx context.Context, organizationID uuid.UUID, filters map[string]interface{}) ([]*model.Equipment, error) {
	return s.equipmentRepo.FindByOrganizationID(ctx, organizationID, filters)
}
