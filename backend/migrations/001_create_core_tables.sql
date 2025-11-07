-- ================================================================================
-- Migration 001: Create Core Tables (Phase 1: Table Definitions)
-- Description: Creates all foundational tables without foreign key constraints.
-- Foreign keys are added in migration 002 to resolve circular dependencies.
-- ================================================================================
SET search_path TO equipchain, public;

-- ================================================================================
-- Create organizations Table
-- Description: Multi-tenant support - each company/organization is isolated
-- ================================================================================

CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  code VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  
  status VARCHAR(50) NOT NULL DEFAULT 'active',
  CONSTRAINT organization_status_valid CHECK (
    status IN ('active', 'suspended', 'deleted')
  ),
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  created_by UUID,
  updated_by UUID,
  
  CONSTRAINT organization_code_not_empty CHECK (TRIM(code) != ''),
  CONSTRAINT organization_name_not_empty CHECK (TRIM(name) != '')
);

COMMENT ON TABLE organizations IS
'Multi-tenant container for companies/organizations. Each organization has isolated equipment, users, and maintenance records.';

COMMENT ON COLUMN organizations.id IS 
'Primary key - UUID auto-generated for security and distributed systems.';

COMMENT ON COLUMN organizations.code IS 
'Unique code identifier for organization.
Example: "acme_corp", "builder_inc"
Used in API requests, reports, and audit logs. Immutable after creation.';

COMMENT ON COLUMN organizations.name IS
'Human-readable organization name for UI and reports.';

COMMENT ON COLUMN organizations.status IS
'Organization lifecycle: active (operating), suspended (no new activity), deleted (soft delete).';

COMMENT ON COLUMN organizations.created_by IS
'System admin who created this organization. May be NULL for system-created orgs.';

COMMENT ON COLUMN organizations.updated_by IS
'System admin who last modified organization. Auto-updated by trigger.';


-- ================================================================================
-- Create users Table
-- Description: User accounts with OWASP-compliant authentication and lockout
-- Note: Foreign keys to organizations and users added in migration 002
-- ================================================================================

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  organization_id UUID NOT NULL,
  
  email VARCHAR(255) NOT NULL,
  CONSTRAINT users_email_not_empty CHECK (TRIM(email) != ''),
  CONSTRAINT users_email_valid CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
  
  password_hash VARCHAR(255) NOT NULL,
  CONSTRAINT password_hash_not_empty CHECK (TRIM(password_hash) != ''),
  
  role_id SMALLINT NOT NULL,
  
  email_verified BOOLEAN NOT NULL DEFAULT false,
  email_verified_at TIMESTAMP WITH TIME ZONE,
  email_verification_token VARCHAR(255) UNIQUE,
  email_verification_token_expires_at TIMESTAMP WITH TIME ZONE,
  
  failed_login_attempts SMALLINT NOT NULL DEFAULT 0,
  CONSTRAINT failed_login_attempts_positive CHECK (failed_login_attempts >= 0),
  
  last_failed_login_at TIMESTAMP WITH TIME ZONE,
  
  locked_until TIMESTAMP WITH TIME ZONE,
  CONSTRAINT locked_until_logic CHECK (
    locked_until IS NULL OR locked_until > CURRENT_TIMESTAMP
  ),
  
  last_login_at TIMESTAMP WITH TIME ZONE,
  last_login_ip INET,
  
  password_changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  status VARCHAR(50) NOT NULL DEFAULT 'active',
  CONSTRAINT user_status_valid CHECK (
    status IN ('active', 'inactive', 'locked', 'deleted')
  ),
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  created_by UUID,
  updated_by UUID,
  
  CONSTRAINT self_reference_prevention CHECK (
    created_by IS NULL OR created_by != id
  )
);

COMMENT ON TABLE users IS
'User accounts with role-based access control, email verification, and OWASP-compliant account lockout.
Supports multi-tenant isolation via organization_id.';

COMMENT ON COLUMN users.id IS
'Primary key - UUID for security and distributed systems. Never exposed in URLs.';

COMMENT ON COLUMN users.organization_id IS
'Foreign key to organizations (added in migration 002). Enforces multi-tenant isolation - users only see their organization''s data.';

COMMENT ON COLUMN users.email IS
'Unique per organization. Used for login and password recovery. Must be verified before account is active.';

COMMENT ON COLUMN users.password_hash IS
'Argon2id hash of password (or bcrypt/scrypt). NEVER store plaintext passwords.
Hash includes embedded salt. Compare using constant-time comparison function.';

COMMENT ON COLUMN users.role_id IS
'Foreign key to role_lookup (added in migration 002). Determines permissions (admin, manager, technician, supervisor, viewer).';

COMMENT ON COLUMN users.email_verified IS
'true=user clicked verification link, false=awaiting email verification.
Unverified accounts cannot create maintenance records or access equipment.';

COMMENT ON COLUMN users.email_verified_at IS
'Timestamp when user completed email verification. NULL until verified.';

COMMENT ON COLUMN users.email_verification_token IS
'One-time token sent to email. User clicks link with token to verify address.
Token is hashed in database, never sent in plaintext in URLs (use token in POST body or querystring with HTTPS).';

COMMENT ON COLUMN users.email_verification_token_expires_at IS
'Verification token expires after 24 hours. Expired tokens cannot be used for verification.';

COMMENT ON COLUMN users.failed_login_attempts IS
'Counter of consecutive failed login attempts. Reset to 0 on successful login.
When >= 5, account is locked until lockout duration expires.';

COMMENT ON COLUMN users.last_failed_login_at IS
'Timestamp of most recent failed login attempt. Used for failed login observation window.';

COMMENT ON COLUMN users.locked_until IS
'Timestamp when account lockout expires and login attempts are allowed again.
NULL = account not locked. Used for exponential backoff: 1s → 2s → 4s → 8s...';

COMMENT ON COLUMN users.last_login_at IS
'Timestamp of most recent successful login. Used for user activity monitoring and anomaly detection.';

COMMENT ON COLUMN users.last_login_ip IS
'IP address of last successful login. Used for anomaly detection (suspicious IP changes).
Can be NULL for early logins before this field existed.';

COMMENT ON COLUMN users.password_changed_at IS
'Timestamp when password was last changed. Used to enforce password rotation policies.
Updated whenever user changes password via change password flow or admin reset.';

COMMENT ON COLUMN users.status IS
'Account lifecycle status:
- active: User can login and use system
- inactive: User cannot login (admin-deactivated)
- locked: Account locked due to failed login attempts (temporary)
- deleted: Soft delete - record kept for audit, user cannot login';

COMMENT ON COLUMN users.created_by IS
'User ID of who created this account (foreign key added in migration 002). May be NULL for self-registered accounts.';

COMMENT ON COLUMN users.updated_by IS
'User ID of who last modified this account (foreign key added in migration 002). Auto-updated by trigger.';


-- ================================================================================
-- Create user_password_history Table
-- Description: Prevent password reuse
-- Note: Foreign key to users added in migration 002
-- ================================================================================

CREATE TABLE user_password_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  set_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT password_history_user_unique UNIQUE(user_id, password_hash)
);

COMMENT ON TABLE user_password_history IS
'Prevents users from reusing old passwords. Keep last 5 password hashes.
Prevents security vulnerabilities from cycling through old passwords.';

COMMENT ON COLUMN user_password_history.user_id IS
'Foreign key to users (added in migration 002). Cascade delete when user is deleted.';

COMMENT ON COLUMN user_password_history.password_hash IS
'Hash of previous password. Used to check if new password was used before.';

COMMENT ON COLUMN user_password_history.set_at IS
'When this password was in effect.';


-- ================================================================================
-- Create role_lookup Table
-- Description: Defines all user roles in the system
-- Note: Foreign keys to users added in migration 002
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
  
  created_by UUID,
  updated_by UUID,
  
  CONSTRAINT role_code_not_empty CHECK (TRIM(code) != ''),
  CONSTRAINT role_label_not_empty CHECK (TRIM(label) != '')
);

COMMENT ON TABLE role_lookup IS
'User roles for role-based access control (RBAC)';

COMMENT ON COLUMN role_lookup.id IS
'Primary key - explicitly set to ensure consistency across environments.';

COMMENT ON COLUMN role_lookup.code IS
'Code identifier for roles. 
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
'User ID of admin who defined this role (for audit trail, foreign key added in migration 002).
Nullable: System-created roles can have null creator.';

COMMENT ON COLUMN role_lookup.updated_by IS
'User ID of admin who last modified this role (for audit trail, foreign key added in migration 002).
Updated automatically by trigger_role_lookup_update_at.';


-- ================================================================================
-- Create maintenance_status_lookup Table
-- Description: Defines maintenance record workflow states
-- Note: Foreign keys to users added in migration 002
-- ================================================================================

CREATE TABLE maintenance_status_lookup (
  id SMALLINT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  label VARCHAR(100) NOT NULL,
  description TEXT,
  
  workflow_sequence SMALLINT NOT NULL,
  CONSTRAINT status_sequence_positive CHECK (workflow_sequence > 0),
  requires_photos BOOLEAN NOT NULL DEFAULT false,
  
  requires_blockchain_signature BOOLEAN NOT NULL DEFAULT false,
  requires_supervisor_approval BOOLEAN NOT NULL DEFAULT false,
  allows_editing BOOLEAN NOT NULL DEFAULT true,
  is_final_status BOOLEAN NOT NULL DEFAULT false,
  
  status VARCHAR(50) NOT NULL DEFAULT 'active',
  CONSTRAINT maintenance_status_valid CHECK (
    status IN ('active', 'deprecated', 'deleted')
  ),
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  created_by UUID,
  updated_by UUID,
  
  CONSTRAINT status_code_not_empty CHECK (TRIM(code) != ''),
  CONSTRAINT status_label_not_empty CHECK (TRIM(label) != '')
);

COMMENT ON COLUMN maintenance_status_lookup.id IS
'Primary key - explicitly set to ensure consistency across environments.';

COMMENT ON COLUMN maintenance_status_lookup.code IS
'Code identifier for maintenance status. 
Example: draft, submitted, pending_approval, approved, confirmed, rejected.';

COMMENT ON COLUMN maintenance_status_lookup.label IS
'Human-readable display name for UI and reports.';

COMMENT ON COLUMN maintenance_status_lookup.description IS
'Explanation of what this status means and when it occurs.';

COMMENT ON COLUMN maintenance_status_lookup.workflow_sequence IS
'Position in workflow 
Example: 1=draft, 2=submitted, 3=pending_approval, 4=approved, 5=confirmed, 6=rejected.
Enforces forward-only progression: new_sequence must be >= old_sequence.';

COMMENT ON COLUMN maintenance_status_lookup.requires_photos IS
'true=photos must be uploaded before reaching this status.';

COMMENT ON COLUMN maintenance_status_lookup.requires_blockchain_signature IS
'true=record must be written to Solana blockchain.';

COMMENT ON COLUMN maintenance_status_lookup.requires_supervisor_approval IS
'true=supervisor/manager signature required before proceeding (multi-sig workflow).';

COMMENT ON COLUMN maintenance_status_lookup.allows_editing IS
'true=record can be edited; false=record is locked.';

COMMENT ON COLUMN maintenance_status_lookup.is_final_status IS
'true=terminal status (confirmed or rejected, no further transitions).';

COMMENT ON COLUMN maintenance_status_lookup.status IS
'Record lifecycle: active, deprecated, deleted.';

COMMENT ON COLUMN maintenance_status_lookup.created_by IS
'User ID of admin who created this status (foreign key added in migration 002). Nullable for system-created statuses.';

COMMENT ON COLUMN maintenance_status_lookup.updated_by IS
'User ID of admin who last modified this status (foreign key added in migration 002). Auto-updated by trigger.';


-- ================================================================================
-- Create maintenance_type_lookup Table
-- Description: Categorize Types of maintenance work
-- Note: Foreign keys to users added in migration 002 (and typo fix: created_at -> created_by)
-- ================================================================================

CREATE TABLE maintenance_type_lookup (
  id SMALLINT PRIMARY KEY,
  code VARCHAR(50) NOT NULL,
  label VARCHAR(100) NOT NULL,
  description TEXT,
  
  requires_multiple_photos BOOLEAN NOT NULL DEFAULT false,
  estimated_duration_hours DECIMAL(5,2),
  
  status VARCHAR(50) NOT NULL DEFAULT 'active',
  CONSTRAINT maintenance_type_status_valid CHECK (
    status IN ('active', 'deprecated', 'deleted')
  ),
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  created_by UUID,
  updated_by UUID,
  
  CONSTRAINT maintenance_type_code_not_empty CHECK (TRIM(code) != ''),
  CONSTRAINT maintenance_type_label_not_empty CHECK (TRIM(label) != ''),
  CONSTRAINT maintenance_type_duration_positive CHECK (
    estimated_duration_hours IS NULL OR estimated_duration_hours > 0
  )
);

COMMENT ON TABLE maintenance_type_lookup IS
'Categorizes types of maintenance work (preventive, corrective, emergency, inspection).
Allows system to enforce different requirements (photos, approvals) based on work type.';

COMMENT ON COLUMN maintenance_type_lookup.id IS
'Primary key - explicitly set to ensure consistency across environments.';

COMMENT ON COLUMN maintenance_type_lookup.code IS
'Code identifier for maintenance types.
Example: preventive, corrective, emergency, inspection.
Must be lowercase alphanumeric + underscore.';

COMMENT ON COLUMN maintenance_type_lookup.label IS
'Human-readable display name for reports, dashboards, and UI.';

COMMENT ON COLUMN maintenance_type_lookup.requires_multiple_photos IS
'true=type requires 3+ photos for evidence (emergency repairs).
false=type requires minimum 1 photo (routine checks).';

COMMENT ON COLUMN maintenance_type_lookup.estimated_duration_hours IS
'Expected time to complete this type of maintenance.
Used for scheduling, planning, and SLA tracking.
NULL = duration not applicable for this type.';

COMMENT ON COLUMN maintenance_type_lookup.status IS
'Record lifecycle status: active, deprecated, deleted.
active=currently in use, deprecated=no longer used (kept for history), deleted=soft delete.';

COMMENT ON COLUMN maintenance_type_lookup.created_by IS
'User ID of admin who defined this maintenance type (foreign key added in migration 002).
Nullable: System-created types can have null creator.';

COMMENT ON COLUMN maintenance_type_lookup.updated_by IS
'User ID of admin who last modified this type (foreign key added in migration 002).
Updated automatically by trigger_maintenance_type_lookup_update_at.';


-- ================================================================================
-- Create equipment_status_lookup Table
-- Description: Defines equipment lifecycle status
-- Note: Foreign keys to users added in migration 002
-- ================================================================================

CREATE TABLE equipment_status_lookup (
  id SMALLINT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  label VARCHAR(100) NOT NULL,
  description TEXT,
  
  allows_maintenance BOOLEAN NOT NULL DEFAULT true,
  
  status VARCHAR(50) NOT NULL DEFAULT 'active',
  CONSTRAINT equipment_status_valid CHECK (
    status IN ('active', 'deprecated', 'deleted')
  ),
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  created_by UUID,
  updated_by UUID,
  
  CONSTRAINT equipment_status_code_not_empty CHECK (TRIM(code) != ''),
  CONSTRAINT equipment_status_label_not_empty CHECK (TRIM(label) != '')
);

COMMENT ON TABLE equipment_status_lookup IS
'Equipment lifecycle states: active, inactive, damaged, decommissioned, in_repair.
Controls whether equipment can have maintenance records created.';

COMMENT ON COLUMN equipment_status_lookup.id IS
'Primary key - explicitly set to ensure consistency across environments.';

COMMENT ON COLUMN equipment_status_lookup.code IS
'Code identifier: active, inactive, damaged, decommissioned, in_repair.
Must be lowercase alphanumeric + underscore.';

COMMENT ON COLUMN equipment_status_lookup.label IS
'Human-readable display name for UI, reports, and equipment registries.';

COMMENT ON COLUMN equipment_status_lookup.allows_maintenance IS
'true=maintenance records can be created for equipment in this status.
false=equipment in this status cannot have new maintenance records (e.g., decommissioned).
Used to enforce business rules: can''t maintain inactive equipment.';

COMMENT ON COLUMN equipment_status_lookup.status IS
'Record lifecycle status: active, deprecated, deleted.
active=currently in use, deprecated=no longer used (kept for history), deleted=soft delete.';

COMMENT ON COLUMN equipment_status_lookup.created_by IS
'User ID of admin who defined this status (foreign key added in migration 002).
Nullable: System-created statuses can have null creator.';

COMMENT ON COLUMN equipment_status_lookup.updated_by IS
'User ID of admin who last modified this status (foreign key added in migration 002).
Updated automatically by trigger_equipment_status_lookup_update_at.';


-- ================================================================================
-- Create Indexes on All Tables
-- ================================================================================

CREATE INDEX idx_users_email_org ON users(organization_id, email);
COMMENT ON INDEX idx_users_email_org IS
'Fast lookup during login: find user by email within their organization.';

CREATE INDEX idx_users_organization_id ON users(organization_id);
COMMENT ON INDEX idx_users_organization_id IS
'List all users in an organization for admin management.';

CREATE INDEX idx_users_status ON users(status);
COMMENT ON INDEX idx_users_status IS
'Filter active users for reporting and user lists (exclude deleted).';

CREATE INDEX idx_users_role_id ON users(role_id);
COMMENT ON INDEX idx_users_role_id IS
'Find all users with specific role (e.g., all technicians for supervisor).';

CREATE INDEX idx_users_locked_until ON users(locked_until);
COMMENT ON INDEX idx_users_locked_until IS
'Find locked accounts that can be unlocked (locked_until <= now). Used for periodic unlock checks.';

CREATE INDEX idx_users_last_login_at ON users(last_login_at);
COMMENT ON INDEX idx_users_last_login_at IS
'Identify inactive users (last_login_at < 90 days ago) for compliance and cleanup.';

CREATE INDEX idx_organizations_code ON organizations(code);
COMMENT ON INDEX idx_organizations_code IS
'Fast lookup of organization by code identifier.';

CREATE INDEX idx_organizations_status ON organizations(status);
COMMENT ON INDEX idx_organizations_status IS
'Filter active organizations (exclude deleted/suspended).';

CREATE INDEX idx_user_password_history_user_id ON user_password_history(user_id);
COMMENT ON INDEX idx_user_password_history_user_id IS
'Retrieve password history for a specific user during password change.';

CREATE INDEX idx_role_lookup_code ON role_lookup(code);
COMMENT ON INDEX idx_role_lookup_code IS 
'Fast lookups by role code in application authorization logic';

CREATE INDEX idx_role_lookup_status ON role_lookup(status);
COMMENT ON INDEX idx_role_lookup_status IS
'Filter active/deprecated roles for dashboard and user management';

CREATE INDEX idx_maintenance_status_lookup_code ON maintenance_status_lookup(code);
COMMENT ON INDEX idx_maintenance_status_lookup_code IS
'Fast status code lookups when updating maintenance record workflow.';

CREATE INDEX idx_maintenance_status_lookup_workflow ON maintenance_status_lookup(workflow_sequence);
COMMENT ON INDEX idx_maintenance_status_lookup_workflow IS 
'Query valid next workflow transitions (statuses where sequence > current).';

CREATE INDEX idx_maintenance_type_lookup_code ON maintenance_type_lookup(code);
COMMENT ON INDEX idx_maintenance_type_lookup_code IS 
'Fast lookups by maintenance type code during record creation';

CREATE INDEX idx_maintenance_type_lookup_status ON maintenance_type_lookup(status);
COMMENT ON INDEX idx_maintenance_type_lookup_status IS 
'Filter active maintenance types for UI dropdowns and validation.';

CREATE INDEX idx_equipment_status_lookup_code ON equipment_status_lookup(code);
COMMENT ON INDEX idx_equipment_status_lookup_code IS 
'Fast lookups by equipment status code during equipment lifecycle transitions.';

CREATE INDEX idx_equipment_status_lookup_allow_maintenance ON equipment_status_lookup(allows_maintenance);
COMMENT ON INDEX idx_equipment_status_lookup_allow_maintenance IS 
'Query which statuses allow maintenance record creation (business rule enforcement).';


-- ================================================================================
-- Create Trigger Function for Updated_At Timestamp (Users/Organizations)
-- Description: Automatically update updated_at on any modification
-- ================================================================================

CREATE OR REPLACE FUNCTION update_user_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_user_timestamp() IS
'Trigger function for users and organizations tables.
Automatically sets updated_at to CURRENT_TIMESTAMP on UPDATE.';


-- ================================================================================
-- Create Trigger Function for Lookup Table Updated_At Timestamp
-- Description: Automatically update updated_at on any lookup table modification
-- ================================================================================

CREATE OR REPLACE FUNCTION update_lookup_table_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_lookup_table_timestamp() IS
'Trigger function that automatically sets updated_at to current timestamp.
Applied to all lookup tables to maintain audit trail without manual updates';


-- ================================================================================
-- Create Triggers for Users and Organizations
-- Description: Apply timestamp update function to users and organizations
-- ================================================================================

CREATE TRIGGER trigger_users_update_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_user_timestamp();

COMMENT ON TRIGGER trigger_users_update_at ON users IS
'Automatically updates users.updated_at timestamp on row modification.';

CREATE TRIGGER trigger_organizations_update_at
  BEFORE UPDATE ON organizations
  FOR EACH ROW
  EXECUTE FUNCTION update_user_timestamp();

COMMENT ON TRIGGER trigger_organizations_update_at ON organizations IS
'Automatically updates organizations.updated_at timestamp on row modification.';


-- ================================================================================
-- Create Triggers for All Lookup Tables
-- Description: Apply timestamp update function to all lookup tables
-- ================================================================================

CREATE TRIGGER trigger_role_lookup_update_at
  BEFORE UPDATE ON role_lookup
  FOR EACH ROW
  EXECUTE FUNCTION update_lookup_table_timestamp();

COMMENT ON TRIGGER trigger_role_lookup_update_at ON role_lookup IS 
'Automatically updates role_lookup.updated_at when row is modified.';


CREATE TRIGGER trigger_maintenance_status_lookup_update_at
  BEFORE UPDATE ON maintenance_status_lookup
  FOR EACH ROW
  EXECUTE FUNCTION update_lookup_table_timestamp();

COMMENT ON TRIGGER trigger_maintenance_status_lookup_update_at ON maintenance_status_lookup IS 
'Automatically updates maintenance_status_lookup.updated_at when row is modified.';

CREATE TRIGGER trigger_maintenance_type_lookup_update_at
  BEFORE UPDATE ON maintenance_type_lookup
  FOR EACH ROW
  EXECUTE FUNCTION update_lookup_table_timestamp();

COMMENT ON TRIGGER trigger_maintenance_type_lookup_update_at ON maintenance_type_lookup IS 
'Automatically updates maintenance_type_lookup.updated_at when row is modified.';

CREATE TRIGGER trigger_equipment_status_lookup_update_at
  BEFORE UPDATE ON equipment_status_lookup
  FOR EACH ROW
  EXECUTE FUNCTION update_lookup_table_timestamp();

COMMENT ON TRIGGER trigger_equipment_status_lookup_update_at ON equipment_status_lookup IS
'Automatically updates equipment_status_lookup.updated_at when row is modified.';


-- ================================================================================
-- Create Function check_and_update_lockout
-- Description: Helper function to check/update account lockout status
-- ================================================================================

CREATE OR REPLACE FUNCTION check_and_update_lockout(
  p_user_id UUID,
  p_lockout_duration_seconds INT DEFAULT 300
)
RETURNS TABLE(
  is_locked BOOLEAN,
  remaining_lockout_seconds INT
) AS $$
DECLARE
  v_locked_until TIMESTAMP WITH TIME ZONE;
  v_attempts INT;
  v_is_locked BOOLEAN;
  v_remaining_seconds INT;
BEGIN
  SELECT locked_until, failed_login_attempts INTO v_locked_until, v_attempts FROM users WHERE id = p_user_id;

  -- Check if still in lockout period
  IF v_locked_until IS NOT NULL AND v_locked_until > CURRENT_TIMESTAMP THEN
    v_is_locked := true;
    v_remaining_seconds := EXTRACT(EPOCH FROM (v_locked_until - CURRENT_TIMESTAMP))::INT;
  ELSE
    v_attempts := COALESCE(v_attempts, 0) + 1;

    IF v_attempts >= 5 THEN
      v_locked_until := NOW() + (p_lockout_duration_seconds || ' seconds')::INTERVAL;
      v_is_locked := TRUE;
      v_remaining_seconds := p_lockout_duration_seconds;
    ELSE
      v_locked_until := NULL;
    END IF;

    UPDATE users SET
    failed_login_attempts = v_attempts,
    locked_until = v_locked_until,
    last_failed_login_at = CURRENT_TIMESTAMP
    WHERE id = p_user_id;
  END IF;

  RETURN QUERY SELECT v_is_locked, v_remaining_seconds;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_and_update_lockout(UUID, INT) IS
'Secure lockout function for failed login attempts.

- Increments failed_login_attempts on each call
- Locks account for p_lockout_duration_seconds (default 300) when attempts >= 5
- Returns:
    • is_locked: TRUE if account is currently locked
    • remaining_lockout_seconds: Seconds until unlock (0 if not locked)
- Resets lockout timer only on expiration
- Call after every failed login; reset attempts manually on success
- Thread-safe with row-level locking (add FOR UPDATE if high concurrency)

Usage:
  SELECT * FROM check_and_update_lockout(user_id);

On success:
  UPDATE users SET failed_login_attempts = 0, locked_until = NULL WHERE id = user_id;';
