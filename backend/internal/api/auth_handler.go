package api

import (
	"github.com/NWhite12/EquipChain/internal/service"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"net/http"
)

type AuthHandler struct {
	authService service.AuthService
}

func NewAuthHandler(authService *service.AuthService) *AuthHandler {
	return &AuthHandler{authService: *authService}
}

type RegisterRequest struct {
	Email          string `json:"email" binding:"required,email"`
	Password       string `json:"password" binding:"required, min=12"`
	OrganizationID string `json:"organization_id" binding:"required"`
}

type LoginRequest struct {
	Email          string `json:"email" binding:"required"`
	Password       string `json:"password" binding:"required"`
	OrganizationID string `json:"organization_id" binding:"required"`
}

type AuthResponse struct {
	Token string `json:"token"`
	Email string `json:"email"`
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	organizationID, err := uuid.Parse(req.OrganizationID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid organization_id"})
		return
	}

	user, token, err := h.authService.RegisterUserAndGenerateToken(c.Request.Context(), organizationID, req.Email, req.Password)
	if err != nil {
		// Check error type to determine status code
		switch err {
		case service.ErrEmailExists, service.ErrWeakPassword, service.ErrInvalidCredentials:
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		}
		return
	}

	c.JSON(http.StatusCreated, AuthResponse{
		Token: token,
		Email: user.Email,
	})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindBodyWithJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	organizationID, err := uuid.Parse(req.OrganizationID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid org_id"})
		return
	}

	token, err := h.authService.LoginUser(c.Request.Context(), organizationID, req.Email, req.Password)
	if err != nil {
		// Don't leak which org exists
		switch err {
		case service.ErrAccountLocked:
			c.JSON(http.StatusUnauthorized, gin.H{"error": "account temporarily locked"})
		default:
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		}
		return
	}

	c.JSON(http.StatusOK, AuthResponse{
		Token: token,
		Email: req.Email,
	})
}
