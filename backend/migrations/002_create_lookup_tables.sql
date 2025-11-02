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
'User ID of admin who defined this role (for audit trail).
Nullable: System-created roles can have null creator.';

COMMENT ON COLUMN role_lookup.updated_by IS
'User ID of admin who last modified this role (for audit trail).
Updated automatically by trigger_role_lookup_update_at.';


-- ================================================================================
-- Create maintenance_status_lookup
-- Description: Defines maintenance record workflow states
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

  created_by UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id),

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
Eample: 1=draft, 2=submitted, 3=pending_approval, 4=approved, 5=confirmed, 6=rejected.
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
'User ID of admin who created this status. Nullable for system-created statuses.';

COMMENT ON COLUMN maintenance_status_lookup.updated_by IS
'User ID of admin who last modified this status. Auto-updated by trigger.';

-- ================================================================================
-- Create maintenance_type_lookup Table
-- Description: Categorize Types of maintenance work
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

  created_at UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id),

  CONSTRAINT maintenance_type_code_not_empty CHECK (TRIM(code) != ''),
  CONSTRAINT maintenance_type_label_not_empty CHECK (TRIM(label) != ''),
  CONSTRAINT maintenance_typle_duration_positive CHECK (
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
'User ID of admin who defined this maintenance type (for audit trail).
Nullable: System-created types can have null creator.';

COMMENT ON COLUMN maintenance_type_lookup.updated_by IS
'User ID of admin who last modified this type (for audit trail).
Updated automatically by trigger_maintenance_type_lookup_update_at.';

-- ================================================================================ 
-- Create equipment_status_lookup 
-- Description: Defines equipment lifecycle status
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

  created_by UUID REFERENCES users(id),
  updated_by UUID REFERENCES users(id),

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
'User ID of admin who defined this status (for audit trail).
Nullable: System-created statuses can have null creator.';

COMMENT ON COLUMN equipment_status_lookup.updated_by IS
'User ID of admin who last modified this status (for audit trail).
Updated automatically by trigger_equipment_status_lookup_update_at.';


-- ================================================================================
-- Creates Indexes on Lookup TABLES
-- ================================================================================

CREATE INDEX idx_role_lookup_code ON role_lookup(code);
COMMENT ON INDEX idx_role_lookup_code IS 
'Fast lookups by role code in application authorization logic';

CREATE INDEX idx_role_lookup_status ON role_lookup(statux);
COMMENT ON  INDEX idx_role_lookup_status IS
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
-- Create Trigger Function for updated_at Timestams
-- automatically update updated_at timestamp on any lookup table modification
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
-- Create Triggers for All Lookup Tables
-- apply timestamp update function to all lookup tables
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
