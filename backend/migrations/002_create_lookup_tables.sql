-- ================================================================================
-- Migration 002: Create lookup Tables
-- Description: This migration creates the foundational lookup tables taht other tables
-- will reference via foregn keys. These tables will store configuration values
-- that can change over time. 
-- ================================================================================

-- ================================================================================
-- Create role_lookup Table
-- Description: Defines all user roles in the system
-- ================================================================================ 

CREATE TABLE role_lookup (
    id SMALLINT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    label VARCHAR(100) NOT NULL,
    description TEXT,

    permissions JSONB,
    CONSTRAINT permissions_is_object CHECK (
      permissions IS NULL OR jsonb_typeof(permissions) = 'array'
    ),

    permission_precedence SMALLINT NOT NULL DEFAULT 999,
    CONSTRAINT permission_precedence_positive CHECK (
      permission_precedence >= 1 AND permission_precedence <= 999
    ),

    status VARCHAR(50) NOT NULL DEFAULT 'active',
    CONSTRAINT status_valid CHECK (
      status IN ('active', 'deprecated', 'deleted')
    ),

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),

    CONSTRAINT role_code_not_empty CHECK (TRIM(code) != ''),
    CONSTRAINT role_label_not_empty CHECK (TRIM(label) != '')
);

COMMENT ON TABLE role_lookup IS
'User roles for role-based access control (RBAC)'

COMMENT ON COLUMN role_lookup.id IS
'Primary key - explicitly set to ensure consistency across environments.';

COMMENT ON COLUMN role_lookup.code IS
'Code identifier used in application code and queries. 
Must be lowercase alphanumeric + underscore.';

COMMENT ON COLUMN role_lookup.label IS 'Human-readable display name for UI, reports, and logs.';

COMMENT ON COLUMN role_lookup.permissions IS
'JSONB array of permission strings.
Example: ["create:equipment", "approve:maintenance", "view:reports", "create:*"].
Null permissions means no specific permissions (deny all).';

COMMENT ON COLUMN role_lookup.permission_precedence IS
'Numeric authorization hierarchy (1=highest authority, 999=lowest).';

COMMENT ON COLUMN role_lookup.status IS
'Record lifecycle status: active, deprecated, deleted.
active=currently in use, deprecated=no longer used (kept for history), deleted=soft delete.';

COMMENT ON COLUMN role_lookup.created_by IS
'User ID of admin who defined this role (for audit trail).
Nullable: System-created roles can have null creator.';

COMMENT ON COLUMN role_lookup.updated_by IS
'User ID of admin who last modified this role (for audit trail).
Updated automatically by trigger_role_lookup_update_at.';
