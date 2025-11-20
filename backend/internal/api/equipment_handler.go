package api

import (
	"github.com/NWhite12/EquipChain/internal/model"
	"github.com/NWhite12/EquipChain/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"net/http"
	"time"
)

type EquipmentHandler struct {
	equipmentService *service.EquipmentService
}

func NewEquipmentHandler(equipmentService *service.EquipmentService) *EquipmentHandler {
	return &EquipmentHandler{equipmentService: equipmentService}
}

type CreateEquipmentRequest struct {
	SerialNumber    string  `json:"serial_number" binding:"required"`
	Make            string  `json:"make" binding:"required"`
	Model           string  `json:"model" binding:"required"`
	Location        *string `json:"location"`
	StatusID        *int16  `json:"status_id"`
	OwnerID         *string `json:"owner_id"`
	Notes           *string `json:"notes"`
	PurchasedDate   *string `json:"purchased_date"`
	WarrantyExpires *string `json:"warranty_expires"`
}

type UpdateEquipmentRequest struct {
	SerialNumber    *string `json:"serial_number"`
	Make            *string `json:"make"`
	Model           *string `json:"model"`
	Location        *string `json:"location"`
	StatusID        *int16  `json:"status_id"`
	OwnerID         *string `json:"owner_id"`
	Notes           *string `json:"notes"`
	PurchasedDate   *string `json:"purchased_date"`
	WarrantyExpires *string `json:"warranty_expires"`
}

type EquipmentResponse struct {
	ID              uuid.UUID  `json:"id"`
	SerialNumber    string     `json:"serial_number"`
	Make            string     `json:"make"`
	Model           string     `json:"model"`
	Location        *string    `json:"location,omitempty"`
	StatusID        int16      `json:"status_id"`
	OwnerID         *uuid.UUID `json:"owner_id,omitempty"`
	Notes           *string    `json:"notes,omitempty"`
	PurchasedDate   *string    `json:"purchased_date,omitempty"`
	WarrantyExpires *string    `json:"warranty_expires,omitempty"`
	CreatedAt       string     `json:"created_at"`
	UpdatedAt       string     `json:"updated_at"`
}

func (h *EquipmentHandler) List(c *gin.Context) {
	orgIDInterface, exists := c.Get("organization_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "organization_id not in token"})
		return
	}

	parsedOrganizationID, ok := orgIDInterface.(uuid.UUID)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid organization_id type"})
		return
	}

	filters := map[string]interface{}{
		"status":   c.Query("status"),
		"location": c.Query("location"),
		"search":   c.Query("search"),
	}

	equipment, err := h.equipmentService.ListEquipment(c.Request.Context(), parsedOrganizationID, filters)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	responses := make([]EquipmentResponse, len(equipment))
	for i, e := range equipment {
		responses[i] = h.mapToResponse(e)
	}

	c.JSON(http.StatusOK, gin.H{
		"equipment": responses,
		"total":     len(responses),
	})
}

func (h *EquipmentHandler) Get(c *gin.Context) {
	equipmentID := c.Param("id")
	parsedEquipmentID, err := uuid.Parse(equipmentID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid equipment id"})
		return
	}

	orgIDInterface, exists := c.Get("organization_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "organization_id not in token"})
		return
	}

	parsedOrganizationID, ok := orgIDInterface.(uuid.UUID)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid organization_id type"})
		return
	}
	equipment, err := h.equipmentService.GetEquipmentByID(c.Request.Context(), parsedOrganizationID, parsedEquipmentID)

	if err != nil {
		switch err {
		case service.ErrEquipmentNotFound:
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		case service.ErrUnauthorized:
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		}
		return
	}

	c.JSON(http.StatusOK, h.mapToResponse(equipment))
}

func (h *EquipmentHandler) Create(c *gin.Context) {
	var req CreateEquipmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	orgIDInterface, exists := c.Get("organization_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "organization_id not in token"})
		return
	}

	parsedOrganizationID, ok := orgIDInterface.(uuid.UUID)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid organization_id type"})
		return
	}

	// Get user_id from context
	userIDInterface, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user_id not in token"})
		return
	}

	parsedUserID, ok := userIDInterface.(uuid.UUID)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user_id type"})
		return
	}

	equipment := &model.Equipment{
		SerialNumber: req.SerialNumber,
		Make:         req.Make,
		Model:        req.Model,
		Location:     req.Location,
		Notes:        req.Notes,
	}

	if req.StatusID != nil {
		equipment.StatusID = *req.StatusID
	}

	if req.OwnerID != nil {
		if ownerID, err := uuid.Parse(*req.OwnerID); err == nil {
			equipment.OwnerID = &ownerID
		}
	}

	if req.PurchasedDate != nil {
		parsedDate, err := time.Parse("2006-01-02", *req.PurchasedDate)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid purchased_date format, use YYYY-MM-DD"})
			return
		}
		equipment.PurchasedDate = &parsedDate
	}

	if req.WarrantyExpires != nil {
		parsedDate, err := time.Parse("2006-01-02", *req.WarrantyExpires)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid warranty_expires format, use YYYY-MM-DD"})
			return
		}
		equipment.WarrantyExpires = &parsedDate
	}

	created, err := h.equipmentService.CreateEquipment(c.Request.Context(), parsedOrganizationID, parsedUserID, equipment)

	if err != nil {
		switch err {
		case service.ErrSerialNumberRequired, service.ErrMakeRequired, service.ErrModelRequired, service.ErrStatusIDRequired, service.ErrSerialNumberExists,
			service.ErrSerialNumberRequired, service.ErrLocationNotEmpty, service.ErrWarrantyBeforePurchase, service.ErrInvalidWarrantyDate, service.ErrInvalidStatusID:
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		}
		return
	}

	c.JSON(http.StatusCreated, h.mapToResponse(created))
}

func (h *EquipmentHandler) Update(c *gin.Context) {
	equipmentID := c.Param("id")
	parsedEquipmentID, err := uuid.Parse(equipmentID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid equipment id"})
		return
	}

	orgIDInterface, exists := c.Get("organization_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "organization_id not in token"})
		return
	}

	parsedOrganizationID, ok := orgIDInterface.(uuid.UUID)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid organization_id type"})
		return
	}

	// Get user_id from context
	userIDInterface, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user_id not in token"})
		return
	}

	parsedUserID, ok := userIDInterface.(uuid.UUID)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user_id type"})
		return
	}

	var req UpdateEquipmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updates := make(map[string]interface{})

	if req.Make != nil {
		updates["make"] = *req.Make
	}
	if req.Model != nil {
		updates["model"] = *req.Model
	}
	if req.Location != nil {
		updates["location"] = *req.Location
	}
	if req.StatusID != nil {
		updates["status_id"] = *req.StatusID
	}
	if req.Notes != nil {
		updates["notes"] = *req.Notes
	}
	if req.OwnerID != nil {
		if ownerID, err := uuid.Parse(*req.OwnerID); err == nil {
			updates["owner_id"] = ownerID
		}
	}
	if req.PurchasedDate != nil {
		parsedDate, err := time.Parse("2006-01-02", *req.PurchasedDate)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid purchased_date format, use YYYY-MM-DD"})
			return
		}
		updates["purchased_date"] = &parsedDate
	}
	if req.WarrantyExpires != nil {
		parsedDate, err := time.Parse("2006-01-02", *req.WarrantyExpires)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid warranty_expires format, use YYYY-MM-DD"})
			return
		}
		updates["warranty_expires"] = &parsedDate
	}

	updated, err := h.equipmentService.UpdateEquipment(c.Request.Context(), parsedOrganizationID, parsedEquipmentID, updates, parsedUserID)

	if err != nil {
		switch err {
		case service.ErrEquipmentNotFound:
			c.JSON(http.StatusNotFound, gin.H{"error": "equipment not found"})
		case service.ErrSerialNumberRequired, service.ErrMakeRequired, service.ErrModelRequired,
			service.ErrLocationNotEmpty, service.ErrSerialNumberExists, service.ErrStatusIDRequired,
			service.ErrInvalidStatusID, service.ErrInvalidWarrantyDate:
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		}
		return
	}

	c.JSON(http.StatusOK, h.mapToResponse(updated))
}

func (h *EquipmentHandler) Delete(c *gin.Context) {
	equipmentID := c.Param("id")
	parsedEquipmentID, err := uuid.Parse(equipmentID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid equipment id"})
		return
	}

	orgIDInterface, exists := c.Get("organization_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "organization_id not in token"})
		return
	}

	parsedOrganizationID, ok := orgIDInterface.(uuid.UUID)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid organization_id type"})
		return
	}

	err = h.equipmentService.DeleteEquipment(c.Request.Context(), parsedOrganizationID, parsedEquipmentID)

	if err != nil {
		switch err {
		case service.ErrEquipmentNotFound:
			c.JSON(http.StatusNotFound, gin.H{"error": "equipment not found"})
		case service.ErrUnauthorized:
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		}
		return
	}

	c.JSON(http.StatusNoContent, nil)
}

func (h *EquipmentHandler) mapToResponse(e *model.Equipment) EquipmentResponse {
	resp := EquipmentResponse{
		ID:           e.ID,
		SerialNumber: e.SerialNumber,
		Make:         e.Make,
		Model:        e.Model,
		Location:     e.Location,
		StatusID:     e.StatusID,
		OwnerID:      e.OwnerID,
		Notes:        e.Notes,
		CreatedAt:    e.CreatedAt.Format("2006-01-02T15:04:05Z"),
		UpdatedAt:    e.UpdatedAt.Format("2006-01-02T15:04:05Z"),
	}

	if e.PurchasedDate != nil {
		dateStr := e.PurchasedDate.Format("2006-01-02")
		resp.PurchasedDate = &dateStr
	}
	if e.WarrantyExpires != nil {
		dateStr := e.WarrantyExpires.Format("2006-01-02")
		resp.WarrantyExpires = &dateStr
	}
	return resp
}
