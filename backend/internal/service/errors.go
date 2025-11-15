package service

import "errors"

var (
	ErrUserNotFound       = errors.New("user not found")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrEmailExists        = errors.New("email already registered in organization")
	ErrAccountLocked      = errors.New("account temporarily locked")
	ErrWeakPassword       = errors.New("password does not meet requirements")
)
