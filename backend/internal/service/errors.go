package service

import "errors"

var (
	ErrUserNotFound           = errors.New("user not found")
	ErrInvalidCredentials     = errors.New("invalid credentials")
	ErrEmailExists            = errors.New("email already registered in organization")
	ErrAccountLocked          = errors.New("account temporarily locked")
	ErrWeakPassword           = errors.New("password does not meet requirements")
	ErrSerialNumberRequired   = errors.New("serial_number is required")
	ErrMakeRequired           = errors.New("make is required")
	ErrModelRequired          = errors.New("model is required")
	ErrLocationNotEmpty       = errors.New("location cannot be empty string")
	ErrSerialNumberExists     = errors.New("serial_number already exists in organization")
	ErrInvalidWarrantyDate    = errors.New("warranty_expires must be in the future")
	ErrWarrantyBeforePurchase = errors.New("warranty_expires must be after purchased_date")
	ErrEquipmentNotFound      = errors.New("equipment not found")
	ErrStatusIDRequired       = errors.New("status_id is required")
	ErrInvalidStatusID        = errors.New("status_id is invalid")
	ErrUnauthorized           = errors.New("unauthorized")
)
