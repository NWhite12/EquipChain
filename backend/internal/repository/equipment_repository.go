package repository

import (
	"context"
	"errors"

	"github.com/NWhite12/EquipChain/internal/model"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type EquipmentRepository struct {
	db *gorm.DB
}

func NewEquipmentRepository(db *gorm.DB) *EquipmentRepository {
	return &EquipmentRepository{db: db}
}

func (r *EquipmentRepository) FindByOrganizationID(ctx context.Context, organizationID uuid.UUID, filters map[string]interface{}) ([]*model.Equipment, error) {
	var equipment []*model.Equipment
	query := r.db.WithContext(ctx).Where("organization_id = ? AND deleted_at IS NULL", organizationID)

	if statusID, ok := filters["status_id"]; ok && statusID != "" {
		query = query.Where("status_id = ?", statusID)
	}

	if location, ok := filters["location"]; ok && location != "" {
		query = query.Where("location ILIKE ?", "%"+location.(string)+"%")
	}

	if search, ok := filters["search"]; ok && search != "" {
		query = query.Where("serial_number ILIKE ? OR make ILIKE ? OR model ILIKE ?",
			"%"+search.(string)+"%",
			"%"+search.(string)+"%",
			"%"+search.(string)+"%")
	}

	if err := query.Order("created_at DESC").Find(&equipment).Error; err != nil {
		return nil, err
	}

	return equipment, nil
}

func (r *EquipmentRepository) FindByID(ctx context.Context, equipmentID uuid.UUID) (*model.Equipment, error) {
	var equipment model.Equipment

	if err := r.db.WithContext(ctx).Where("id = ? AND deleted_at IS NULL", equipmentID).First(&equipment).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}

	return &equipment, nil
}

func (r *EquipmentRepository) FindBySerialNumber(ctx context.Context, organizationID uuid.UUID, serialNumber string) (*model.Equipment, error) {
	var equipment model.Equipment

	if err := r.db.WithContext(ctx).Where("organization_id = ? AND serial_number = ? AND deleted_at IS NULL", organizationID, serialNumber).First(&equipment).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}

	return &equipment, nil
}

func (r *EquipmentRepository) Create(ctx context.Context, equipment *model.Equipment) error {
	return r.db.WithContext(ctx).Create(equipment).Error
}

func (r *EquipmentRepository) UpdateEquipment(ctx context.Context, equipmentID uuid.UUID, updates map[string]interface{}, updatedBy uuid.UUID) error {
	updates["updated_by"] = updatedBy

	return r.db.WithContext(ctx).
		Model(&model.Equipment{}).
		Where("id = ? AND deleted_at IS NULL", equipmentID).
		Updates(updates).Error
}

func (r *EquipmentRepository) Delete(ctx context.Context, equipmentID uuid.UUID) error {
	return r.db.WithContext(ctx).
		Model(&model.Equipment{}).
		Where("id = ?", equipmentID).
		Update("deleted_at", gorm.Expr("NOW()")).Error
}

func (r *EquipmentRepository) CountByOrganization(ctx context.Context, organizationID uuid.UUID) (int64, error) {
	var count int64
	if err := r.db.WithContext(ctx).
		Model(&model.Equipment{}).
		Where("organization_id = ? AND deleted_at IS NULL", organizationID).
		Count(&count).Error; err != nil {
		return 0, err
	}
	return count, nil
}

func (r *EquipmentRepository) IsValidStatusID(ctx context.Context, statusID int16) (bool, error) {
	var count int64
	if err := r.db.WithContext(ctx).
		Model(&model.EquipmentStatusLookup{}).
		Where("id = ? AND status = ?", statusID, "active").
		Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}
