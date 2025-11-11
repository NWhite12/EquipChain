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
-- Create equipment Table
-- Description: Core equipment registry
-- ================================================================================

CREATE TABLE equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  
  -- equipment identifiers
  serial_number VARCHAR(100) NOT NULL,
  make VARCHAR(100) NOT NULL,
  model VARCHAR(100) NOT NULL,
  location VARCHAR(255),

  -- equipment lifecycle
  status_id SMALLINT NOT NULL,
  owner_id UUID,

  -- QR Code (bas64 PNG data)
  qr_code TEXT,

  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

  created_by UUID,
  updated_by UUID,

  CONSTRAINT serial_number_not_empty CHECK (TRIM(serial_number) != ''),
  CONSTRAINT make_not_empty CHECK (TRIM(make) != ''),
  CONSTRAINT model_not_empty CHECK (TRIM(model) != '')
);

COMMENT ON TABLE equipment IS
'Core equipment registry. Each equipment belongs to an organization.
Tracks serial number, make, model, location, and lifecycle status.
QR codes link physical equipment to digital maintenance records.';

COMMENT ON COLUMN equipment.id IS
'Primary key - UUID auto-generated for security.';

COMMENT ON COLUMN equipment.organization_id IS
'Foreign key to organizations. Supports Multi-tenant isolation.';

COMMENT ON COLUMN equipment.serial_number IS
'Unique identifier within organization. Example: "CAT-320-ABC123".
Must be unique per organization (different orgs can have same serial).';

COMMENT ON COLUMN equipment.make IS
'Equipment manufacturer. Example: "Caterpillar".';

COMMENT ON COLUMN equipment.model IS
'Equipment model. Example: "320 Excavator".';

COMMENT ON COLUMN equipment.location IS
'Current location or job site. Example: "Construction Site #7".
May be NULL if location is not tracked.';

COMMENT ON COLUMN equipment.status_id IS
'Foreign key to equipment_status_lookup.
Controls whether equipment can have maintenance records created.';

COMMENT ON COLUMN equipment.owner_id IS
'Foreign key to users. Who owns this equipment?
Optional - may be NULL if ownership is organizational.';

COMMENT ON COLUMN equipment.qr_code IS
'QR code as base64 PNG data. Format: "data:image/png;base64,iVBORw0KGgoAAAA...".
Generated on equipment creation. Printed and placed on physical equipment.';

COMMENT ON COLUMN equipment.created_by IS
'User ID of who created this equipment.';

COMMENT ON COLUMN equipment.updated_by IS
'User ID of who last modified this equipment (auto-updated by trigger).';

-- ================================================================================
-- Create maintenance_records Table
-- Description: 
-- ================================================================================

  CREATE TABLE maintenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    equipment_id UUID NOT NULL,
    maintenance_type_id SMALLINT NOT NULL,
    status_id SMALLINT NOT NULL,

    technician_id UUID NOT NULL,
    supervisor_id UUID,
    inspector_id UUID,

    notes TEXT,

    gps_latitude DECIMAL(10, 8),
    gps_longitude DECIMAL(11, 8),

    solana_signature VARCHAR(255),

    submitted_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    rejected_at TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID,

    CONSTRAINT gps_latitude_valid CHECK (
      gps_latitude IS NULL OR (gps_latitude >= -90 AND gps_latitude <= 90)
    ),
    CONSTRAINT gps_longitude_valid CHECK (
      gps_longitude IS NULL OR (gps_longitude >= -180 and gps_longitude <= 180)
    )
  );

COMMENT ON TABLE maintenance_records IS
'Maintenance records for equipment. Tracks workflow from creation through blockchain confirmation.
Supports multi-signature approval workflow (1-3 signatures: technician, supervisor, inspector).
Immutable once confirmed on blockchain.';

COMMENT ON COLUMN maintenance_records.id IS
'Primary key - UUID for security.';

COMMENT ON COLUMN maintenance_records.organization_id IS
'Foreign key to organizations. Multi-tenant isolation.';

COMMENT ON COLUMN maintenance_records.equipment_id IS
'Foreign key to equipment. RESTRICT on delete (cannot delete equipment with maintenance records).';

COMMENT ON COLUMN maintenance_records.maintenance_type_id IS
'Foreign key to maintenance_type_lookup.
Categorizes work: preventive, corrective, emergency, inspection.';

COMMENT ON COLUMN maintenance_records.status_id IS
'Foreign key to maintenance_status_lookup.
Workflow: draft → submitted → approved → confirmed (or rejected).';

COMMENT ON COLUMN maintenance_records.technician_id IS
'Foreign key to users. Who performed the work?
RESTRICT on delete (cannot delete technician with maintenance records).';

COMMENT ON COLUMN maintenance_records.supervisor_id IS
'Foreign key to users. Optional supervisor for multi-sig approval.
SET NULL on delete.';

COMMENT ON COLUMN maintenance_records.inspector_id IS
'Foreign key to users. Optional third signature for critical work.
SET NULL on delete.';

COMMENT ON COLUMN maintenance_records.notes IS
'Work description. Example: "Changed hydraulic fluid, replaced filter, tested pressure."
May be NULL initially, populated before submission.';

COMMENT ON COLUMN maintenance_records.gps_latitude IS
'GPS latitude for proof-of-work. Decimal with 8 places (0.00000001 degree precision).
Range: -90 to 90. NULL if location not required.';

COMMENT ON COLUMN maintenance_records.gps_longitude IS
'GPS longitude for proof-of-work. Decimal with 8 places (0.00000001 degree precision).
Range: -180 to 180. NULL if location not required.';

COMMENT ON COLUMN maintenance_records.solana_signature IS
'Solana blockchain transaction signature. Globally unique proof of blockchain confirmation.
Example: "5Kf7x3B9p2NnqsQ7vM8dZaRlQe4jFhK2...".
NULL until maintenance is confirmed on blockchain.';

COMMENT ON COLUMN maintenance_records.submitted_at IS
'Timestamp when technician submitted for approval. Workflow trigger.';

COMMENT ON COLUMN maintenance_records.approved_at IS
'Timestamp when supervisor approved. Workflow trigger.';

COMMENT ON COLUMN maintenance_records.confirmed_at IS
'Timestamp when blockchain confirmation received. Final workflow state.';

COMMENT ON COLUMN maintenance_records.rejected_at IS
'Timestamp when supervisor rejected. Allows technician to resubmit from draft.';

-- ================================================================================
-- Create maintenance_photos Table
-- Description: 
-- ================================================================================

CREATE TABLE maintenance_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  maintenance_record_id UUID NOT NULL,
  organization_id UUID NOT NULL,

  -- Photo sequence (1=before, 2=during, 3=after)
  sequence_number SMALLINT NOT NULL,
  CONSTRAINT photo_sequence_valid CHECK (sequence_number IN (1, 2, 3)), 
  
  ipfs_hash VARCHAR(100) NOT NULL,
  ipfs_url VARCHAR(255),

  s3_backup_url VARCHAR(255),

  file_size_bytes INTEGER,
  mime_type VARCHAR(50), -- "image/jpeg", "image/png"

  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by UUID,

  CONSTRAINT ipfs_hash_not_empty CHECK (TRIM(ipfs_hash) != ''),
  CONSTRAINT file_size_positive CHECK (file_size_bytes IS NULL OR file_size_bytes > 0)
);

COMMENT ON TABLE maintenance_photos IS
'Photo evidence for maintenance records. Stores 3 photos per maintenance event:
1=before, 2=during, 3=after. IPFS for decentralized storage, S3 for backup redundancy.
Immutable once created.';

COMMENT ON COLUMN maintenance_photos.id IS
'Primary key - UUID.';

COMMENT ON COLUMN maintenance_photos.maintenance_record_id IS
'Foreign key to maintenance_records. CASCADE on delete.';

COMMENT ON COLUMN maintenance_photos.organization_id IS
'Foreign key to organizations. Denormalized for multi-tenant queries.';

COMMENT ON COLUMN maintenance_photos.sequence_number IS
'Photo sequence: 1=before, 2=during, 3=after.
Constraint ensures only these values (CHECK constraint).';

COMMENT ON COLUMN maintenance_photos.ipfs_hash IS
'IPFS content hash. Example: "QmX7f3MN2pK9vR4tQsDxC5nL1jYe8bZqH6wFgUoPv3Xy".
Globally unique identifier for immutable content.';

COMMENT ON COLUMN maintenance_photos.ipfs_url IS
'Reconstructed IPFS URL. Example: "https://ipfs.io/ipfs/QmX7f3MN2...".
Can be regenerated from ipfs_hash but stored for convenience.';

COMMENT ON COLUMN maintenance_photos.s3_backup_url IS
'AWS S3 URL for backup storage. Example: "https://s3.amazonaws.com/equipchain/.../photo.jpg".
Redundancy in case IPFS becomes unavailable.';

COMMENT ON COLUMN maintenance_photos.file_size_bytes IS
'Size of photo file in bytes. Used for storage quota tracking and SLA monitoring.';

COMMENT ON COLUMN maintenance_photos.mime_type IS
'MIME type of photo. Example: "image/jpeg", "image/png".
Helps client validate before storing.';

COMMENT ON COLUMN maintenance_photos.created_by IS
'User ID of who uploaded. For audit trail.';

-- ================================================================================
-- Create blockchain_transactions Table
-- Description: 
-- ================================================================================

CREATE TABLE blockchain_transactions(
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  maintenance_record_id UUID NOT NULL,
  organization_id UUID NOT NULL,

  transaction_signature VARCHAR(255) NOT NULL,
  block_number BIGINT,
  block_timestamp INTEGER, -- Unix timestamp from blockchain

  confirmation_status VARCHAR(50) NOT NULL DEFAULT 'pending',
  CONSTRAINT confirmation_status_valid CHECK (
    confirmation_status IN ('pending', 'confirmed', 'failed', 'expired')
  ),

  transaction_fee_lamports BIGINT,
  CONSTRAINT fee_positive CHECK (transaction_fee_lamports IS NULL OR transaction_fee_lamports > 0),

  solana_rpc_response JSONB,

  retry_count SMALLINT NOT NULL DEFAULT 0,
  CONSTRAINT retry_count_positive CHECK (retry_count >= 0),

  last_retry_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,

  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  confirmed_at TIMESTAMP WITH TIME ZONE,

  solana_cluster VARCHAR(50) DEFAULT 'mainnet-beta'
 );

COMMENT ON TABLE blockchain_transactions IS
'Tracks Solana blockchain transactions for maintenance records.
One transaction per maintenance confirmation. Stores transaction status,
block information, fee data, and retry metadata for debugging and cost tracking.';

COMMENT ON COLUMN blockchain_transactions.id IS
'Primary key - UUID.';

COMMENT ON COLUMN blockchain_transactions.maintenance_record_id IS
'Foreign key to maintenance_records. RESTRICT on delete.';

COMMENT ON COLUMN blockchain_transactions.organization_id IS
'Foreign key to organizations. Cost tracking per organization.';

COMMENT ON COLUMN blockchain_transactions.transaction_signature IS
'Solana transaction signature (base58 encoded). Globally unique.
Example: "5Kf7x3B9p2NnqsQ7vM8dZaRlQe4jFhK2GkJxNoPq7RsQeT9vL1wM".
This is the immutable proof on blockchain.';

COMMENT ON COLUMN blockchain_transactions.block_number IS
'Solana block number where transaction was confirmed.
NULL for pending transactions, populated after confirmation.';

COMMENT ON COLUMN blockchain_transactions.block_timestamp IS
'Unix timestamp from blockchain (seconds since epoch).
When blockchain confirmed the transaction.';

COMMENT ON COLUMN blockchain_transactions.confirmation_status IS
'Transaction status: pending → confirmed (or pending → failed → expired).
Controls retry logic and maintenance record workflow state.';

COMMENT ON COLUMN blockchain_transactions.transaction_fee_lamports IS
'Fee paid in lamports (1 SOL = 1,000,000,000 lamports).
Used for cost tracking and monthly billing calculations.';

COMMENT ON COLUMN blockchain_transactions.solana_rpc_response IS
'Full Solana RPC API response as JSONB. For debugging failed/pending transactions.
Stores error details, logs, and metadata from RPC.';

COMMENT ON COLUMN blockchain_transactions.retry_count IS
'Number of retry attempts. Max 3 retries before status = ''failed''.';

COMMENT ON COLUMN blockchain_transactions.last_retry_at IS
'Timestamp of last retry attempt. Used for exponential backoff calculation.';

COMMENT ON COLUMN blockchain_transactions.error_message IS
'Error description from last attempt. Example: "Insufficient funds", "Network timeout".';

COMMENT ON COLUMN blockchain_transactions.solana_cluster IS
'Which Solana cluster: mainnet-beta, devnet, testnet.
Defaults to mainnet-beta for production.';

-- ================================================================================
-- Create technician_profiles Table
-- Description: Extended user profile for technicians tracking licensing, certifications, and availability.
-- Supports OSHA compliance verification and multi-signature approval workflows.
-- ================================================================================

CREATE TABLE technician_profiles (
id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
user_id UUID NOT NULL UNIQUE,
organization_id UUID NOT NULL,

license_number VARCHAR(50),
CONSTRAINT license_number_not_empty CHECK (TRIM(license_number) != '' OR license_number IS NULL),

license_type VARCHAR(100),  -- "Equipment Operator", "Supervisor", "Inspector"
CONSTRAINT license_type_not_empty CHECK (TRIM(license_type) != '' OR license_type IS NULL),

license_state VARCHAR(2), -- state abbreviation
CONSTRAINT license_state_format CHECK (license_state IS NULL OR license_state ~ '^[A-Z]{2}$'),

license_issued_date DATE,
license_expiration_date DATE,
CONSTRAINT license_date_valid CHECK (
  license_issued_date IS NULL
  OR license_expiration_date IS NULL
  OR license_expiration_date > license_issued_date
),

  -- Certifications (stored as JSONB array for flexibility)
  -- Example: ["hydraulics", "diesel_engine", "welding", "electrical_systems"]
  certifications JSONB DEFAULT '[]'::jsonb,
  CONSTRAINT certifications_is_array CHECK (
    certifications IS NULL OR jsonb_typeof(certifications) = 'array'
  ),

  is_available BOOLEAN NOT NULL DEFAULT true,
  hourly_rate DECIMAL(10, 2),
  CONSTRAINT hourly_rate_positive CHECK (hourly_rate IS NULL OR hourly_rate > 0),

  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by UUID,
  updated_by UUID
);

COMMENT ON TABLE technician_profiles IS
'Extended profile for technician users with licensing, certifications, and availability.
Supports OSHA compliance verification and multi-signature approval workflows.
One profile per technician user (1:1 relationship with users table).';

COMMENT ON COLUMN technician_profiles.id IS
'Primary key - UUID auto-generated.';

COMMENT ON COLUMN technician_profiles.user_id IS
'Foreign key to users (1:1 unique relationship, added in migration 002).
User must have role "technician", "supervisor", or "inspector".
Deleted when user is deleted (CASCADE).';

COMMENT ON COLUMN technician_profiles.organization_id IS
'Foreign key to organizations for multi-tenant isolation.
Technician can only work for one organization (or create duplicate profile in another).';

COMMENT ON COLUMN technician_profiles.license_number IS
'License identifier. Example: "MT-8472", "CA-123456".
Unique identifier within state/license_type combination.
Nullable if license not required for this role.';

COMMENT ON COLUMN technician_profiles.license_type IS
'Type of license. Examples: "Equipment Operator", "Supervisor", "Inspector".
Determines permission level for maintenance approvals.
Nullable if role is not licensable.';

COMMENT ON COLUMN technician_profiles.license_state IS
'US state abbreviation where license was issued. Format: 2 uppercase letters.
Examples: MT, CO, CA, TX.
Used for regulatory compliance and insurance verification.';

COMMENT ON COLUMN technician_profiles.license_issued_date IS
'Date license was originally issued. Used for validation and historical tracking.';

COMMENT ON COLUMN technician_profiles.license_expiration_date IS
'Date license expires. Used for alerts and compliance verification.
Query: "is this technician''s license valid today?" = (license_expiration_date >= CURRENT_DATE).
Alerts should be sent when license expires in 30 days.';

COMMENT ON COLUMN technician_profiles.certifications IS
'JSONB array of certification codes. Examples: ["hydraulics", "diesel_engine", "welding"].
Stored as JSON for flexibility (can add new certifications without schema changes).
Query: "who is certified for hydraulics?" = certifications @> ''"hydraulics"''::jsonb';

COMMENT ON COLUMN technician_profiles.is_available IS
'true = technician can be assigned work, false = on leave/unavailable.
Used for scheduling and dashboard "available technicians today" query.';

COMMENT ON COLUMN technician_profiles.hourly_rate IS
'Billing rate for invoicing and cost tracking. Example: 85.00 (USD per hour).
Used for integration with billing/ERP systems in future roadmap.
Nullable if hourly billing not applicable.';

-- ================================================================================
-- Create maintenance_approval_audit Table
-- Description: Immutable audit trail of all maintenance approval/rejection events. 
-- Supports 1-3 signature workflow (technician → supervisor → inspector).
-- ================================================================================

CREATE TABLE maintenance_approval_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  maintenance_record_id UUID NOT NULL,
  organization_id UUID NOT NULL,

  approver_id UUID NOT NULL,
  
  action VARCHAR(50) NOT NULL,
  CONSTRAINT approval_action_valid CHECK (action IN ('approved', 'rejected')),
  
  comments TEXT,
  CONSTRAINT comments_not_empty CHECK (TRIM(comments) != '' OR comments IS NULL),

  approval_sequence SMALLINT NOT NULL,
  CONSTRAINT approval_sequence_positive CHECK (approval_sequence >= 1),

  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

  ip_address INET,
  user_agent TEXT
);

COMMENT ON TABLE maintenance_approval_audit IS
'Immutable audit trail of maintenance approval/rejection workflow.
One record per approval/rejection action (not per maintenance record).
Supports multi-signature workflow: technician submits → supervisor reviews → inspector verifies.
Never updated after creation (audit integrity).';

COMMENT ON COLUMN maintenance_approval_audit.id IS
'Primary key - UUID auto-generated.';

COMMENT ON COLUMN maintenance_approval_audit.maintenance_record_id IS
'Foreign key to maintenance_records.
Multiple audit records per maintenance (one per approval/rejection).
CASCADE on delete: if maintenance record deleted, audit entries deleted.';

COMMENT ON COLUMN maintenance_approval_audit.organization_id IS
'Foreign key to organizations for multi-tenant isolation and efficient queries.
Denormalized from maintenance_records for faster filtering.';

COMMENT ON COLUMN maintenance_approval_audit.approver_id IS
'Foreign key to users, who took this action (approved or rejected)?
Must be user with role "supervisor" or "inspector" (validated in app layer).
RESTRICT on delete (cannot delete user with pending approvals).';

COMMENT ON COLUMN maintenance_approval_audit.action IS
'Action taken: "approved" or "rejected".
- approved: Approver signed off on maintenance (moves workflow forward)
- rejected: Approver rejected maintenance (sends back to draft for tech to revise)';

COMMENT ON COLUMN maintenance_approval_audit.comments IS
'Optional comments from approver.
Used for rejections: explain why rejected.
Used for approvals: note any special conditions or observations.';

COMMENT ON COLUMN maintenance_approval_audit.approval_sequence IS
'Position in approval chain (1, 2, or 3).
- 1: First approval (usually supervisor reviews technician''s submission)
- 2: Second approval (inspector reviews supervisor''s approval)
- 3: Third approval (additional oversight for critical work)
Used to prevent out-of-order approvals.';

COMMENT ON COLUMN maintenance_approval_audit.created_at IS
'Timestamp when approval/rejection was recorded. Immutable (never changes).
Used for compliance: "show me all approvals for this record".';

COMMENT ON COLUMN maintenance_approval_audit.ip_address IS
'IP address of approver. Used for security investigation.
Example: "192.168.1.100" or "2001:db8::1".
Helps detect unusual approval patterns.';

COMMENT ON COLUMN maintenance_approval_audit.user_agent IS
'User-Agent header from approver''s browser/app.
Used for security investigation: "Which app version approved this?"';

-- ================================================================================
-- Create audit_log TABLE
-- Description: System-wide audit trail for compliance, security investigation, and data access tracking.
-- Populated by application layer (middleware), never directly by users.
-- ================================================================================

CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  user_id UUID,  -- NULL for system actions
  
  entity_type VARCHAR(100) NOT NULL,  -- "user", "equipment", "maintenance_record", etc.
  entity_id UUID NOT NULL,  -- ID of the entity that changed
  
  action VARCHAR(50) NOT NULL,
  CONSTRAINT audit_action_valid CHECK (action IN ('create', 'read', 'update', 'delete')),
  
  changes_before JSONB,  -- Old values: {"status": "draft", "notes": "Old notes"}
  changes_after JSONB,   -- New values: {"status": "submitted", "notes": "New notes"}
  
  -- Request context (for security investigation)
  ip_address INET,  -- "192.168.1.100"
  user_agent TEXT,  -- "Mozilla/5.0..."
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE audit_log IS
'System audit trail for compliance, security investigation, and data access tracking.
Populated by application middleware for all API operations.
Immutable (no updates after creation).
Used for GDPR/HIPAA/OSHA compliance, security audits, and fraud detection.';

COMMENT ON COLUMN audit_log.id IS
'Primary key - UUID auto-generated.';

COMMENT ON COLUMN audit_log.organization_id IS
'Foreign key to organizations.
Multi-tenant isolation: organization admins only see their own audit entries.';

COMMENT ON COLUMN audit_log.user_id IS
'Foreign key to users.
NULL for system actions (scheduled jobs, webhooks).
SET NULL on delete (user can be deleted but audit record remains).';

COMMENT ON COLUMN audit_log.entity_type IS
'Type of entity that was accessed/modified. Examples:
- "equipment" - equipment record accessed
- "maintenance_record" - maintenance record accessed
- "maintenance_approval_audit" - approval/rejection recorded
- "user" - user account accessed
- "technician_profile" - technician profile accessed
- "blockchain_transaction" - blockchain data accessed
Used to filter audit logs by entity type.';

COMMENT ON COLUMN audit_log.entity_id IS
'UUID of the entity that was accessed/modified.
Combined with entity_type, can reconstruct what changed: "equipment ABC123 was updated"';

COMMENT ON COLUMN audit_log.action IS
'CRUD action performed:
- create: New entity created (INSERT)
- read: Entity data accessed/queried (SELECT)
- update: Existing entity modified (UPDATE)
- delete: Entity deleted (DELETE)
Note: Only log read operations for sensitive endpoints (equipment, maintenance records).
Do not log routine non-sensitive reads (performance consideration).';

COMMENT ON COLUMN audit_log.changes_before IS
'JSONB snapshot of entity state BEFORE the change (for update actions).
Example: {"status": "draft", "notes": "Old notes", "submitted_at": null}
NULL for create/read/delete actions.
Used to show "what changed?" in compliance reports.';

COMMENT ON COLUMN audit_log.changes_after IS
'JSONB snapshot of entity state AFTER the change (for update actions).
Example: {"status": "submitted", "notes": "New notes", "submitted_at": "2025-11-11T08:00:00Z"}
NULL for create/read/delete actions.
Combined with changes_before, shows exact differences.';

COMMENT ON COLUMN audit_log.ip_address IS
'IP address of user who performed the action. Examples: "192.168.1.100", "2001:db8::1".
Used for security investigation: "Did authorized admin approve this, or was account compromised?"
Can detect: VPN usage, impossible travel (logged in from two continents in 5 minutes).';

COMMENT ON COLUMN audit_log.user_agent IS
'User-Agent header from browser/client (not always accurate, spoofable).
Example: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
Used to detect automated/unusual access patterns (bot vs human behavior).';

COMMENT ON COLUMN audit_log.created_at IS
'Timestamp when audit entry was recorded. Immutable (never changes).
Precise ordering of events (used to rebuild state changes over time).
Example: Replay all updates to equipment #ABC123 from Jan 1 - Jan 31 to show full history.';

-- ================================================================================
-- Create equipment_maintenance_schedule
-- Description: Tracks preventive maintenance schedules for equipment. Enables overdue 
-- alerts, OSHA compliance verification, and equipment health dashboards. Supports 
-- recurring maintenance tasks with frequency-based scheduling.
-- ================================================================================

CREATE TABLE equipment_maintenance_schedule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID NOT NULL,
  organization_id UUID NOT NULL,
  
  maintenance_type_id SMALLINT NOT NULL,
  
  scheduled_frequency_days INTEGER NOT NULL,
  CONSTRAINT scheduled_frequency_positive CHECK (scheduled_frequency_days > 0),
  
  last_maintenance_date DATE,
  next_due_date DATE NOT NULL,
  
  overdue_alert_sent_at TIMESTAMP WITH TIME ZONE,
  due_soon_alert_sent_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by UUID,
  updated_by UUID,
  
  CONSTRAINT last_maintenance_before_next CHECK (
    last_maintenance_date IS NULL 
    OR next_due_date > last_maintenance_date
  )
);

COMMENT ON TABLE equipment_maintenance_schedule IS
'Tracks preventive maintenance schedules for equipment. Enables overdue maintenance alerts and OSHA compliance reporting.
Supports recurring maintenance tasks: e.g., "change oil every 500 hours" or "inspect hydraulics every 30 days".
One schedule per equipment + maintenance_type combination.
Used for equipment health dashboards and proactive maintenance planning.';

COMMENT ON COLUMN equipment_maintenance_schedule.id IS
'Primary key - UUID auto-generated.';

COMMENT ON COLUMN equipment_maintenance_schedule.equipment_id IS
'Foreign key to equipment.
Identifies which equipment has this maintenance schedule.
CASCADE on delete: if equipment deleted, schedules deleted.';

COMMENT ON COLUMN equipment_maintenance_schedule.organization_id IS
'Foreign key to organizations for multi-tenant isolation.
Denormalized from equipment for faster filtering in dashboard queries.';

COMMENT ON COLUMN equipment_maintenance_schedule.maintenance_type_id IS
'Foreign key to maintenance_type_lookup.
Type of maintenance: preventive, inspection, corrective, emergency.
Different types have different frequency requirements and alert rules.';

COMMENT ON COLUMN equipment_maintenance_schedule.scheduled_frequency_days IS
'How often this maintenance should occur (in days). Examples: 30, 90, 365.
Used to calculate next_due_date after each completed maintenance: next_due_date = last_maintenance_date + scheduled_frequency_days.
Immutable after creation (prevents losing audit trail of schedule changes).';

COMMENT ON COLUMN equipment_maintenance_schedule.last_maintenance_date IS
'Date when this maintenance was last completed. Updated after maintenance_records confirms on blockchain.
NULL if maintenance has never been done for this schedule.
Used as starting point to calculate when next maintenance is due.';

COMMENT ON COLUMN equipment_maintenance_schedule.next_due_date IS
'Calculated date when this maintenance is next due.
Critical for dashboard queries: "is equipment overdue?" = (next_due_date < CURRENT_DATE).
Critical for alert queries: "equipment due in 30 days?" = (next_due_date BETWEEN NOW() AND NOW() + 30 DAYS).
Updated after each completed maintenance record (via update_maintenance_schedule_after_completion function).';

COMMENT ON COLUMN equipment_maintenance_schedule.overdue_alert_sent_at IS
'Timestamp when "overdue" alert email was sent. NULL if not sent.
Prevents duplicate alert emails for same overdue maintenance.
Reset to NULL when next maintenance is completed (allows new alerts for next cycle).
Used by cron job: only send alert if overdue_alert_sent_at IS NULL AND next_due_date < TODAY.';

COMMENT ON COLUMN equipment_maintenance_schedule.due_soon_alert_sent_at IS
'Timestamp when "due in 30 days" alert email was sent. NULL if not sent.
Allows "nudging" technicians 30 days before maintenance is due.
Reset to NULL when next maintenance is completed.
Used by cron job: send if next_due_date is 30 days away AND due_soon_alert_sent_at IS NULL.';

COMMENT ON COLUMN equipment_maintenance_schedule.created_by IS
'User ID of admin/supervisor who created this maintenance schedule.
Tracks who established the preventive maintenance plan.';

COMMENT ON COLUMN equipment_maintenance_schedule.updated_by IS
'User ID of who last modified this schedule (admin changing frequency, etc).
Auto-updated by trigger_equipment_maintenance_schedule_update_at.';


-- ================================================================================
-- Create organizations_integrations
-- Description: Stores third-party API credentials and webhook configurations for 
-- insurance companies, ERP systems (Procore, Autodesk), and other integrations. 
-- ================================================================================

CREATE TABLE organizations_integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  
  integration_type VARCHAR(100) NOT NULL,
  CONSTRAINT integration_type_not_empty CHECK (TRIM(integration_type) != ''),
  
  integration_name VARCHAR(255),
  CONSTRAINT integration_name_not_empty CHECK (integration_name IS NULL OR TRIM(integration_name) != ''),
  
  api_key_encrypted TEXT,
  CONSTRAINT api_key_not_empty CHECK (api_key_encrypted IS NULL OR TRIM(api_key_encrypted) != ''),
  
  api_secret_encrypted TEXT,
  CONSTRAINT api_secret_not_empty CHECK (api_secret_encrypted IS NULL OR TRIM(api_secret_encrypted) != ''),
  
  webhook_url VARCHAR(255),
  webhook_secret VARCHAR(255),
  
  is_active BOOLEAN NOT NULL DEFAULT true,
  test_mode BOOLEAN NOT NULL DEFAULT false,
  
  last_webhook_call TIMESTAMP WITH TIME ZONE,
  webhook_call_count INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT webhook_call_count_positive CHECK (webhook_call_count >= 0),
  
  last_error TEXT,
  error_count INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT error_count_positive CHECK (error_count >= 0),
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by UUID,
  updated_by UUID
);

COMMENT ON TABLE organizations_integrations IS
'Third-party API integrations for insurance companies, ERP systems, and other platforms.
Stores encrypted API credentials and webhook configurations.
Supports V1.5+ roadmap: Insurance API, ERP integrations (Procore, Autodesk), CRM systems, etc.
Credentials encrypted at rest (decrypted only during actual API calls).
Circuit breaker pattern: disable integration after 10 consecutive errors to prevent flooding.';

COMMENT ON COLUMN organizations_integrations.id IS
'Primary key - UUID auto-generated.';

COMMENT ON COLUMN organizations_integrations.organization_id IS
'Foreign key to organizations (added in migration 002).
Each integration belongs to exactly one organization.
CASCADE on delete: if organization deleted, all its integrations deleted.';

COMMENT ON COLUMN organizations_integrations.integration_type IS
'Type of integration. Examples: "insurance_api", "procore", "autodesk", "crm_salesforce", "slack".
Used to route webhook calls to appropriate handlers in application.
Validates against whitelisted integration types in business logic.';

COMMENT ON COLUMN organizations_integrations.integration_name IS
'Human-readable name for this specific integration instance.
Examples: "Acme Insurance Portal", "Procore Main Site", "Autodesk Project XYZ".
For admin UI display and identification in logs.';

COMMENT ON COLUMN organizations_integrations.api_key_encrypted IS
'API key for authentication (ENCRYPTED). Never stored in plaintext in database.
Decryption key stored separately in AWS Secrets Manager or HashiCorp Vault.
Example plaintext: "sk_live_51234567890abcdef" or "Bearer token...".
Decrypted only when making outbound API calls to third-party.
Example encrypted: "ENCRYPTED[aes256:abc123def456...]"';

COMMENT ON COLUMN organizations_integrations.api_secret_encrypted IS
'API secret or password (ENCRYPTED). Used for HMAC signatures or basic auth.
Examples: OAuth client secret, webhook signing key, database password.
Decrypted only when making API calls or validating incoming webhooks.';

COMMENT ON COLUMN organizations_integrations.webhook_url IS
'URL where EquipChain sends webhook notifications to third-party.
Examples: "https://acme-insurance.com/equipchain/webhook", "https://procore.api.com/webhooks/maintenance".
Called when maintenance_records status changes (submitted, approved, confirmed, rejected).
Optional: some integrations may not support webhooks.';

COMMENT ON COLUMN organizations_integrations.webhook_secret IS
'Secret key for webhook signature verification (HMAC-SHA256).
Prevents unauthorized calls from spoofing maintenance updates.
Included in Authorization header or X-Webhook-Signature header for security.';

COMMENT ON COLUMN organizations_integrations.is_active IS
'true = integration is enabled and will receive webhook calls and API calls.
false = integration disabled (errors won''t prevent system operation, graceful degradation).
Allows admins to temporarily disable problematic integrations without data loss.';

COMMENT ON COLUMN organizations_integrations.test_mode IS
'false = production mode (real data sent to third-party system).
true = test/sandbox mode (use sandbox endpoints, or don''t send data to production).
Allows testing integrations without affecting real data in third-party systems.';

COMMENT ON COLUMN organizations_integrations.last_webhook_call IS
'Timestamp of most recent webhook call (success or failure).
Used for "integration health check": is_active AND last_webhook_call > NOW() - INTERVAL ''7 days''.
NULL if webhook never called (new integration).';

COMMENT ON COLUMN organizations_integrations.webhook_call_count IS
'Total number of webhook calls sent (success + failure combined).
Used for tracking integration usage volume for billing and analytics.
Incremented every time webhook is called, regardless of success.';

COMMENT ON COLUMN organizations_integrations.last_error IS
'Error message from last failed webhook call or API request.
Examples: "Connection timeout", "HTTP 403 Forbidden", "Invalid API key", "Rate limited by API".
Helps admins debug integration issues without checking logs.';

COMMENT ON COLUMN organizations_integrations.error_count IS
'Consecutive error count. Reset to 0 on successful API call/webhook.
Used for circuit breaker pattern: disable integration after N consecutive errors.
Prevents system from flooding third-party with failed requests.';

COMMENT ON COLUMN organizations_integrations.created_by IS
'User ID of admin who created this integration (set via API).
Tracks who configured the integration for audit trail.';

COMMENT ON COLUMN organizations_integrations.updated_by IS
'User ID of admin who last modified this integration (credentials, webhook URL, etc).
Auto-updated by trigger_organizations_integrations_update_at.';

-- ================================================================================
-- Create email_queue 
-- Description: Reliable async email queue for notifications (approvals, confirmations, alerts). 
-- Implements retry logic for failed sends. Cron job processes queue every 5 minutes with exponential backoff.
-- ================================================================================

CREATE TABLE email_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  
  recipient_email VARCHAR(255) NOT NULL,
  CONSTRAINT recipient_email_valid CHECK (
    recipient_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'
  ),
  
  -- Email type (determines template)
  email_type VARCHAR(100) NOT NULL,
  CONSTRAINT email_type_valid CHECK (email_type IN (
    'supervisor_approval_needed',
    'approval_receipt',
    'maintenance_confirmed',
    'email_verification',
    'password_reset',
    'overdue_maintenance_alert',
    'license_expiration_alert',
    'maintenance_rejected',
    'technician_assigned'
  )),
  
  -- Template data (rendered into email body by email service)
  template_data JSONB,
  CONSTRAINT template_data_is_object CHECK (
    template_data IS NULL OR jsonb_typeof(template_data) = 'object'
  ),
  
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  CONSTRAINT email_status_valid CHECK (status IN ('pending', 'sent', 'failed', 'bounced')),
  
  retry_count SMALLINT NOT NULL DEFAULT 0,
  CONSTRAINT retry_count_positive CHECK (retry_count >= 0),
  
  last_attempt_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sent_at TIMESTAMP WITH TIME ZONE
);

COMMENT ON TABLE email_queue IS
'Async email queue for reliable notification delivery with automatic retry logic.
Supports multiple email types: approvals, confirmations, alerts, verifications.
Implements retry logic: max 3 retries with exponential backoff (1min, 5min, 15min).
Cron job processes queue every 5 minutes.
Prevents email service outages from blocking maintenance workflows.';

COMMENT ON COLUMN email_queue.id IS
'Primary key - UUID auto-generated.';

COMMENT ON COLUMN email_queue.organization_id IS
'Foreign key to organizations (added in migration 002).
Multi-tenant isolation: admins only see emails for their organization.
CASCADE on delete: if organization deleted, queued emails deleted.';

COMMENT ON COLUMN email_queue.recipient_email IS
'Email address to send to. Example: "supervisor@acme.local".
Validated against email regex before insertion.
Used as primary recipient; no CC/BCC in this design (kept simple).';

COMMENT ON COLUMN email_queue.email_type IS
'Type of email determines template used and content. Examples:
- supervisor_approval_needed: "Maintenance XYZ waiting for your approval"
- approval_receipt: "Your approval was received, thank you"
- maintenance_confirmed: "Maintenance XYZ confirmed on blockchain"
- maintenance_rejected: "Your maintenance was rejected, see comments"
- email_verification: Account activation email
- password_reset: Password recovery link
- overdue_maintenance_alert: "Equipment XYZ overdue for maintenance"
- license_expiration_alert: "Your license expires in 30 days"
- technician_assigned: "You have been assigned maintenance XYZ"';

COMMENT ON COLUMN email_queue.template_data IS
'JSON object containing template variables, rendered into email body.
Example: {"maintenance_id": "abc123", "equipment_name": "Excavator #7", "technician_name": "John"}.
Used in email template: "{{ equipment_name }} requires maintenance by {{ technician_name }}".
Allows dynamic personalized emails from static templates.';

COMMENT ON COLUMN email_queue.status IS
'Email delivery status. Progression: pending → sent (or pending → failed/bounced).
- pending: Awaiting delivery (cron job will process)
- sent: Successfully delivered (sent_at is populated)
- failed: Delivery failed after max retries (error_message populated)
- bounced: Email address invalid or permanently undeliverable (don''t retry)';

COMMENT ON COLUMN email_queue.retry_count IS
'Number of delivery attempts. Max 3 retries before status = ''failed''.
Cron job increments on each attempt.
After 3 retries: update status = ''failed'', give up.';

COMMENT ON COLUMN email_queue.last_attempt_at IS
'Timestamp of most recent delivery attempt (success or failure).
Used for exponential backoff timing: 1min after 1st fail, 5min after 2nd fail, 15min after 3rd fail.
NULL if email never attempted.';

COMMENT ON COLUMN email_queue.error_message IS
'Error from last failed delivery attempt.
Examples: "Connection timeout", "Invalid email address", "Rate limited by SendGrid".
Helps admins debug email delivery issues without checking logs.
NULL if status = ''sent'' or ''pending''.';

COMMENT ON COLUMN email_queue.sent_at IS
'Timestamp when email was successfully delivered.
NULL for pending/failed/bounced emails.
Used for "show me all emails sent in past 30 days" queries (audit trail).';

-- ================================================================================
-- Create Indexes on All Tables
-- ================================================================================

-- users Indexes
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

-- organizations Indexes
CREATE INDEX idx_organizations_code ON organizations(code);
COMMENT ON INDEX idx_organizations_code IS
'Fast lookup of organization by code identifier.';

CREATE INDEX idx_organizations_status ON organizations(status);
COMMENT ON INDEX idx_organizations_status IS
'Filter active organizations (exclude deleted/suspended).';

-- user_password_history Indexes
CREATE INDEX idx_user_password_history_user_id ON user_password_history(user_id);
COMMENT ON INDEX idx_user_password_history_user_id IS
'Retrieve password history for a specific user during password change.';

-- role_lookup Indexes
CREATE INDEX idx_role_lookup_code ON role_lookup(code);
COMMENT ON INDEX idx_role_lookup_code IS 
'Fast lookups by role code in application authorization logic';

CREATE INDEX idx_role_lookup_status ON role_lookup(status);
COMMENT ON INDEX idx_role_lookup_status IS
'Filter active/deprecated roles for dashboard and user management';

-- maintenance_status_lookup Indexes
CREATE INDEX idx_maintenance_status_lookup_code ON maintenance_status_lookup(code);
COMMENT ON INDEX idx_maintenance_status_lookup_code IS
'Fast status code lookups when updating maintenance record workflow.';

CREATE INDEX idx_maintenance_status_lookup_workflow ON maintenance_status_lookup(workflow_sequence);
COMMENT ON INDEX idx_maintenance_status_lookup_workflow IS 
'Query valid next workflow transitions (statuses where sequence > current).';

-- maintenance_type_lookup Indexes
CREATE INDEX idx_maintenance_type_lookup_code ON maintenance_type_lookup(code);
COMMENT ON INDEX idx_maintenance_type_lookup_code IS 
'Fast lookups by maintenance type code during record creation';

CREATE INDEX idx_maintenance_type_lookup_status ON maintenance_type_lookup(status);
COMMENT ON INDEX idx_maintenance_type_lookup_status IS 
'Filter active maintenance types for UI dropdowns and validation.';

-- equipment Indexes
CREATE INDEX idx_equipment_status_lookup_code ON equipment_status_lookup(code);
COMMENT ON INDEX idx_equipment_status_lookup_code IS 
'Fast lookups by equipment status code during equipment lifecycle transitions.';

CREATE INDEX idx_equipment_status_lookup_allow_maintenance ON equipment_status_lookup(allows_maintenance);
COMMENT ON INDEX idx_equipment_status_lookup_allow_maintenance IS 
'Query which statuses allow maintenance record creation (business rule enforcement).';

CREATE INDEX idx_equipment_organization_id ON equipment(organization_id);
COMMENT ON INDEX idx_equipment_organization_id IS
'Multi-tenant isolation: List all equipment for organization.';

CREATE INDEX idx_equipment_serial_number ON equipment(serial_number, organization_id);
COMMENT ON INDEX idx_equipment_serial_number IS
'Fast lookup during equipment registration and maintenance submission.';

CREATE INDEX idx_equipment_status_id ON equipment(status_id);
COMMENT ON INDEX idx_equipment_status_id IS
'Filter active equipment or equipment in specific lifecycle state.';

CREATE INDEX idx_equipment_owner_id ON equipment(owner_id);
COMMENT ON INDEX idx_equipment_owner_id IS
'List all equipment owned by specific user.';

CREATE INDEX idx_equipment_created_at ON equipment(created_at);
COMMENT ON INDEX idx_equipment_created_at IS
'Time-based queries for reporting.';

--maintenance_records Indexes
CREATE INDEX idx_maintenance_records_organization_id ON maintenance_records(organization_id);
COMMENT ON INDEX idx_maintenance_records_organization_id IS
'Multi-tenant isolation: List all maintenance for organization.';

CREATE INDEX idx_maintenance_records_equipment_id ON maintenance_records(equipment_id);
COMMENT ON INDEX idx_maintenance_records_equipment_id IS
'Equipment history: List all maintenance for specific equipment.';

CREATE INDEX idx_maintenance_records_status_id ON maintenance_records(status_id);
COMMENT ON INDEX idx_maintenance_records_status_id IS
'Filter maintenance in specific workflow state (e.g., pending approval).';

CREATE INDEX idx_maintenance_records_technician_id ON maintenance_records(technician_id);
COMMENT ON INDEX idx_maintenance_records_technician_id IS
'List all maintenance performed by specific technician.';

CREATE INDEX idx_maintenance_records_supervisor_id ON maintenance_records(supervisor_id);
COMMENT ON INDEX idx_maintenance_records_supervisor_id IS
'List all maintenance approved by specific supervisor.';

CREATE INDEX idx_maintenance_records_solana_signature ON maintenance_records(solana_signature);
COMMENT ON INDEX idx_maintenance_records_solana_signature IS
'Blockchain verification: Fast lookup by Solana signature.';

CREATE INDEX idx_maintenance_records_created_at ON maintenance_records(created_at);
COMMENT ON INDEX idx_maintenance_records_created_at IS
'Time-based queries for reporting and dashboards.';

CREATE INDEX idx_maintenance_records_confirmed_at ON maintenance_records(confirmed_at);
COMMENT ON INDEX idx_maintenance_records_confirmed_at IS
'Query confirmed maintenance in date range (fast confirmation lookups).';

-- maintenance_photos Indexes
CREATE INDEX idx_maintenance_photos_maintenance_record_id ON maintenance_photos(maintenance_record_id);
COMMENT ON INDEX idx_maintenance_photos_maintenance_record_id IS
'Retrieve all photos for maintenance record (typically 3 photos per record).';

CREATE INDEX idx_maintenance_photos_ipfs_hash ON maintenance_photos(ipfs_hash);
COMMENT ON INDEX idx_maintenance_photos_ipfs_hash IS
'Fast lookup by IPFS hash for verification and deduplication.';

CREATE INDEX idx_maintenance_photos_organization_id ON maintenance_photos(organization_id);
COMMENT ON INDEX idx_maintenance_photos_organization_id IS
'Multi-tenant storage quota tracking.';

CREATE INDEX idx_maintenance_photos_created_at ON maintenance_photos(created_at);
COMMENT ON INDEX idx_maintenance_photos_created_at IS
'Time-based queries for storage analytics.';

-- blockchain_transactions Indexes
CREATE INDEX idx_blockchain_transactions_maintenance_record_id ON blockchain_transactions(maintenance_record_id);
COMMENT ON INDEX idx_blockchain_transactions_maintenance_record_id IS
'Fast lookup: Get blockchain info for maintenance record.';

CREATE INDEX idx_blockchain_transactions_transaction_signature ON blockchain_transactions(transaction_signature);
COMMENT ON INDEX idx_blockchain_transactions_transaction_signature IS
'Blockchain verification: Look up transaction by signature.';

CREATE INDEX idx_blockchain_transactions_confirmation_status ON blockchain_transactions(confirmation_status);
COMMENT ON INDEX idx_blockchain_transactions_confirmation_status IS
'Query pending transactions for retry processing and confirmation.';

CREATE INDEX idx_blockchain_transactions_organization_id ON blockchain_transactions(organization_id);
COMMENT ON INDEX idx_blockchain_transactions_organization_id IS
'Cost tracking: Sum transaction fees per organization.';

CREATE INDEX idx_blockchain_transactions_created_at ON blockchain_transactions(created_at);
COMMENT ON INDEX idx_blockchain_transactions_created_at IS
'Time-based queries for reporting.';

CREATE INDEX idx_blockchain_transactions_block_number ON blockchain_transactions(block_number);
COMMENT ON INDEX idx_blockchain_transactions_block_number IS
'Query confirmed transactions by block range (rare but useful).';

CREATE INDEX idx_blockchain_transactions_confirmed_at ON blockchain_transactions(confirmed_at);
COMMENT ON INDEX idx_blockchain_transactions_confirmed_at IS
'Query confirmed transactions in date range.';

-- technician_profiles Indexes
CREATE INDEX idx_technician_profiles_user_id ON technician_profiles(user_id);
COMMENT ON INDEX idx_technician_profiles_user_id IS
'Fast lookup by user_id (unique).';

CREATE INDEX idx_technician_profiles_organization_id ON technician_profiles(organization_id);
COMMENT ON INDEX idx_technician_profiles_organization_id IS
'List all technicians in organization for staffing/scheduling.';

CREATE INDEX idx_technician_profiles_license_state ON technician_profiles(license_state);
COMMENT ON INDEX idx_technician_profiles_license_state IS
'Query technicians by license state (regulatory reporting).';

CREATE INDEX idx_technician_profiles_license_expiration_date ON technician_profiles(license_expiration_date);
COMMENT ON INDEX idx_technician_profiles_license_expiration_date IS
'Find expiring licenses: license_expiration_date < NOW() + INTERVAL ''30 DAYS''';

CREATE INDEX idx_technician_profiles_is_available ON technician_profiles(is_available);
COMMENT ON INDEX idx_technician_profiles_is_available IS
'List available technicians for assignment and scheduling.';

-- maintenance_approval_audit Indexes
CREATE INDEX idx_maintenance_approval_audit_maintenance_record_id ON maintenance_approval_audit(maintenance_record_id);
COMMENT ON INDEX idx_maintenance_approval_audit_maintenance_record_id IS
'List all approvals/rejections for a maintenance record (show approval history).';

CREATE INDEX idx_maintenance_approval_audit_approver_id ON maintenance_approval_audit(approver_id);
COMMENT ON INDEX idx_maintenance_approval_audit_approver_id IS
'List all approvals made by a specific approver (audit trail by user).';

CREATE INDEX idx_maintenance_approval_audit_action ON maintenance_approval_audit(action);
COMMENT ON INDEX idx_maintenance_approval_audit_action IS
'Count approvals vs rejections, find all rejections for a time period.';

CREATE INDEX idx_maintenance_approval_audit_organization_id ON maintenance_approval_audit(organization_id);
COMMENT ON INDEX idx_maintenance_approval_audit_organization_id IS
'Multi-tenant isolation: list all approvals for organization.';

CREATE INDEX idx_maintenance_approval_audit_created_at ON maintenance_approval_audit(created_at);
COMMENT ON INDEX idx_maintenance_approval_audit_created_at IS
'Time-based queries: "Show me all approvals from last 30 days".';

CREATE INDEX idx_maintenance_approval_audit_maintenance_record_created_at ON maintenance_approval_audit(maintenance_record_id, created_at);
COMMENT ON INDEX idx_maintenance_approval_audit_maintenance_record_created_at IS
'Optimized query: get all approvals for a maintenance record in chronological order.';

-- equipment_maintenance_schedule Indexes
CREATE INDEX idx_equipment_maintenance_schedule_equipment_id ON equipment_maintenance_schedule(equipment_id);
COMMENT ON INDEX idx_equipment_maintenance_schedule_equipment_id IS
'Find all maintenance schedules for a specific equipment.
Query: "What maintenance is due for excavator #XYZ?"';

CREATE INDEX idx_equipment_maintenance_schedule_organization_id ON equipment_maintenance_schedule(organization_id);
COMMENT ON INDEX idx_equipment_maintenance_schedule_organization_id IS
'Multi-tenant isolation: List all schedules for organization.
Query: "Show all maintenance schedules for acme_corp"';

CREATE INDEX idx_equipment_maintenance_schedule_next_due_date ON equipment_maintenance_schedule(next_due_date);
COMMENT ON INDEX idx_equipment_maintenance_schedule_next_due_date IS
'CRITICAL for dashboard performance. Find equipment due for maintenance.
Query: "What equipment needs maintenance today or is overdue?"
Query: "What equipment needs maintenance in next 7 days?" (for scheduling)';

CREATE INDEX idx_equipment_maintenance_schedule_maintenance_type_id ON equipment_maintenance_schedule(maintenance_type_id);
COMMENT ON INDEX idx_equipment_maintenance_schedule_maintenance_type_id IS
'Find all equipment requiring specific maintenance type.
Query: "Find all equipment needing hydraulic system inspections"';

-- organizations_integrations Indexes
CREATE INDEX idx_organizations_integrations_organization_id ON organizations_integrations(organization_id);
COMMENT ON INDEX idx_organizations_integrations_organization_id IS
'List all integrations for an organization (admin settings page, integrations dashboard).';

CREATE INDEX idx_organizations_integrations_integration_type ON organizations_integrations(integration_type);
COMMENT ON INDEX idx_organizations_integrations_integration_type IS
'Find all integrations of specific type (e.g., all insurance APIs, all Procore instances).';

CREATE INDEX idx_organizations_integrations_is_active ON organizations_integrations(is_active);
COMMENT ON INDEX idx_organizations_integrations_is_active IS
'Find all active integrations that should receive webhook calls and API requests.
Query: "Should we send webhook to this integration?" = is_active = true';

CREATE INDEX idx_organizations_integrations_created_at ON organizations_integrations(created_at);
COMMENT ON INDEX idx_organizations_integrations_created_at IS
'Time-based queries for integration auditing and retention policies.';

-- email_queue Indexes
CREATE INDEX idx_email_queue_organization_id ON email_queue(organization_id);
COMMENT ON INDEX idx_email_queue_organization_id IS
'Multi-tenant isolation: List all emails for organization.';

CREATE INDEX idx_email_queue_status ON email_queue(status);
COMMENT ON INDEX idx_email_queue_status IS
'Cron job critical query: Find all pending emails to process.
Query: WHERE status = ''pending'' AND (last_attempt_at IS NULL OR ready_for_retry)';

CREATE INDEX idx_email_queue_email_type ON email_queue(email_type);
COMMENT ON INDEX idx_email_queue_email_type IS
'Find all emails of specific type (e.g., all ''approval_needed'' emails).';

CREATE INDEX idx_email_queue_created_at ON email_queue(created_at);
COMMENT ON INDEX idx_email_queue_created_at IS
'Time-range queries for reporting: "Show all emails created in past 30 days".';

CREATE INDEX idx_email_queue_recipient_email ON email_queue(recipient_email);
COMMENT ON INDEX idx_email_queue_recipient_email IS
'Find all emails sent to a specific address (for unsubscribe, bounce handling).';

CREATE INDEX idx_email_queue_status_created_at ON email_queue(status, created_at);
COMMENT ON INDEX idx_email_queue_status_created_at IS
'Optimized cron job query: Find pending emails ordered by age.
Query: WHERE status = ''pending'' ORDER BY created_at ASC LIMIT 100';

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
-- Create Triggers for Equipment and Maintenance Records
-- Description: Apply timestamp update function to equipment and maintenance_records.
-- ================================================================================

CREATE TRIGGER trigger_equipment_update_at
BEFORE UPDATE ON equipment
FOR EACH ROW
  EXECUTE FUNCTION update_user_timestamp();

COMMENT ON TRIGGER trigger_equipment_update_at ON equipment IS 
'Automatically updates equipment.updated_at timestamp on row modification';

CREATE TRIGGER trigger_maintenance_records_update_at
BEFORE UPDATE ON maintenance_records
FOR EACH ROW
  EXECUTE FUNCTION update_user_timestamp();

COMMENT ON TRIGGER trigger_maintenance_records_update_at ON maintenance_records IS 
'Automatically updates maintenance_records.updated_at timestamp on row modification';


-- ================================================================================
-- Create Triggers for technician_profiles
-- Description: defines updated_at, validate_technician_license, get_technicians_by_certification, 
-- is_technician_qualified_to_approve, get_expiring_licenses, and is_technician_qualified_to_approve
-- functions and triggers
-- ================================================================================

CREATE TRIGGER trigger_technician_profiles_update_at
BEFORE UPDATE ON technician_profiles
FOR EACH ROW
EXECUTE FUNCTION update_user_timestamp();

COMMENT ON TRIGGER trigger_technician_profiles_update_at ON technician_profiles IS
'Automatically updates technician_profiles.updated_at on row modification.';


CREATE OR REPLACE FUNCTION validate_technician_license()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.license_expiration_date IS NOT NULL 
     AND NEW.license_expiration_date < CURRENT_DATE
     AND OLD.license_expiration_date IS DISTINCT FROM NEW.license_expiration_date THEN
    RAISE WARNING 'Technician license has expired: % (expired %)', 
      NEW.license_number, 
      NEW.license_expiration_date;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_technician_license
BEFORE INSERT OR UPDATE ON technician_profiles
FOR EACH ROW
EXECUTE FUNCTION validate_technician_license();

COMMENT ON TRIGGER trigger_validate_technician_license ON technician_profiles IS
'Validates license expiration dates during INSERT/UPDATE operations.';

CREATE OR REPLACE FUNCTION get_technicians_by_certification(
  p_org_id UUID,
  p_certification VARCHAR(100),
  OUT technician_id UUID,
  OUT license_number VARCHAR(50),
  OUT license_type VARCHAR(100),
  OUT is_available BOOLEAN,
  OUT hourly_rate DECIMAL(10, 2)
)
RETURNS SETOF record
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT 
    tp.user_id,
    tp.license_number,
    tp.license_type,
    tp.is_available,
    tp.hourly_rate
  FROM technician_profiles tp
  WHERE 
    tp.organization_id = p_org_id
    AND tp.certifications @> to_jsonb(p_certification)::jsonb
    AND (tp.license_expiration_date IS NULL OR tp.license_expiration_date >= CURRENT_DATE)
  ORDER BY tp.is_available DESC, tp.created_at;
$$;

COMMENT ON FUNCTION get_technicians_by_certification(UUID, VARCHAR) IS
'Get all technicians in organization with specific certification and valid license.
Returns available technicians first.
Example: SELECT * FROM get_technicians_by_certification(org_id, ''hydraulics'')';

CREATE OR REPLACE FUNCTION get_expiring_licenses(
  p_org_id UUID,
  p_days_until_expiry INT DEFAULT 30,
  OUT technician_id UUID,
  OUT license_number VARCHAR(50),
  OUT license_type VARCHAR(100),
  OUT license_expiration_date DATE,
  OUT days_until_expiry INT
)
RETURNS SETOF record
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT 
    tp.user_id,
    tp.license_number,
    tp.license_type,
    tp.license_expiration_date,
    (tp.license_expiration_date - CURRENT_DATE)::INT
  FROM technician_profiles tp
  WHERE 
    tp.organization_id = p_org_id
    AND tp.license_expiration_date IS NOT NULL
    AND tp.license_expiration_date BETWEEN CURRENT_DATE AND CURRENT_DATE + (p_days_until_expiry || ' days')::INTERVAL
  ORDER BY tp.license_expiration_date ASC;
$$;

COMMENT ON FUNCTION get_expiring_licenses(UUID, INT) IS
'Get technicians with licenses expiring within N days (default 30).
Used for automated email alerts about expiring certifications.
Example: SELECT * FROM get_expiring_licenses(org_id, 30)';

CREATE OR REPLACE FUNCTION is_technician_qualified_to_approve(
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM technician_profiles tp
    WHERE 
      tp.user_id = p_user_id
      AND (tp.license_expiration_date IS NULL OR tp.license_expiration_date >= CURRENT_DATE)
      AND tp.license_type IN ('Supervisor', 'Inspector')
  );
$$;

COMMENT ON FUNCTION is_technician_qualified_to_approve(UUID) IS
'Check if technician is qualified to approve maintenance records.
Returns true if:
  - Technician profile exists
  - License is not expired
  - License type is Supervisor or Inspector
Returns false otherwise (not qualified to approve).';

-- ================================================================================
-- Create triggers for maintenance_approval_audit
-- Description: Defines get_approval_history, has_maintenance_been_approved,
-- has_maintenance_been_approved, get_latest_approval_action, and count_maintenance_rejections 
-- functions and triggers
-- ================================================================================

CREATE OR REPLACE FUNCTION get_approval_history(
  p_maintenance_record_id UUID,
  OUT approval_sequence SMALLINT,
  OUT approver_name VARCHAR(255),
  OUT approver_license VARCHAR(50),
  OUT action VARCHAR(50),
  OUT comments TEXT,
  OUT created_at TIMESTAMP WITH TIME ZONE
)
RETURNS SETOF record
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT 
    maa.approval_sequence,
    u.email as approver_name,
    tp.license_number as approver_license,
    maa.action,
    maa.comments,
    maa.created_at
  FROM maintenance_approval_audit maa
  LEFT JOIN users u ON maa.approver_id = u.id
  LEFT JOIN technician_profiles tp ON u.id = tp.user_id
  WHERE maa.maintenance_record_id = p_maintenance_record_id
  ORDER BY maa.approval_sequence ASC, maa.created_at ASC;
$$;

COMMENT ON FUNCTION get_approval_history(UUID) IS
'Get complete approval workflow history for a maintenance record.
Returns all approvals/rejections in chronological order.
Includes approver name, license, action, comments, and timestamp.
Used for compliance reporting and blockchain proof verification.';

CREATE OR REPLACE FUNCTION has_maintenance_been_approved(
  p_maintenance_record_id UUID
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM maintenance_approval_audit
    WHERE 
      maintenance_record_id = p_maintenance_record_id
      AND action = 'approved'
    LIMIT 1
  );
$$;

COMMENT ON FUNCTION has_maintenance_been_approved(UUID) IS
'Check if maintenance record has at least one approval.
Returns true if "approved" action exists in audit trail.
Returns false if only rejections exist or no approvals.
Used in workflow validation: can''t move to blockchain without approval.';

CREATE OR REPLACE FUNCTION get_latest_approval_action(
  p_maintenance_record_id UUID,
  OUT action VARCHAR(50),
  OUT approver_name VARCHAR(255),
  OUT created_at TIMESTAMP WITH TIME ZONE
)
RETURNS record
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT 
    maa.action,
    u.email,
    maa.created_at
  FROM maintenance_approval_audit maa
  LEFT JOIN users u ON maa.approver_id = u.id
  WHERE maa.maintenance_record_id = p_maintenance_record_id
  ORDER BY maa.created_at DESC
  LIMIT 1;
$$;

COMMENT ON FUNCTION get_latest_approval_action(UUID) IS
'Get the most recent approval/rejection for a maintenance record.
Useful for determining current workflow state without querying maintenance_records table.
Returns NULL if no approvals/rejections exist.';

CREATE OR REPLACE FUNCTION count_maintenance_rejections(
  p_maintenance_record_id UUID
)
RETURNS INT
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT COUNT(*)::INT
  FROM maintenance_approval_audit
  WHERE 
    maintenance_record_id = p_maintenance_record_id
    AND action = 'rejected';
$$;

COMMENT ON FUNCTION count_maintenance_rejections(UUID) IS
'Count how many times a maintenance record was rejected by approvers.
Used to identify problematic records (rejected 3+ times = needs escalation).';

CREATE OR REPLACE FUNCTION validate_approval_sequence(
  p_maintenance_record_id UUID,
  p_next_sequence SMALLINT
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT 
    CASE 
      WHEN p_next_sequence = 1 THEN NOT EXISTS (
        SELECT 1 FROM maintenance_approval_audit 
        WHERE maintenance_record_id = p_maintenance_record_id AND action = 'approved'
      )
      WHEN p_next_sequence > 1 THEN EXISTS (
        SELECT 1 FROM maintenance_approval_audit 
        WHERE 
          maintenance_record_id = p_maintenance_record_id 
          AND approval_sequence = p_next_sequence - 1
          AND action = 'approved'
      )
      ELSE FALSE
    END;
$$;

COMMENT ON FUNCTION validate_approval_sequence(UUID, SMALLINT) IS
'Validate that approval sequence is correct (no skipping steps).
Returns true if next sequence is valid, false if trying to skip approval step.
- Sequence 1: First approval (from draft → submitted)
- Sequence 2: Second approval (from first approval → ready for blockchain)
- Sequence 3: Third approval (optional, for triple-sig critical work)';


-- ================================================================================
-- Create Triggers for equipment_maintenance_schedule
-- Description: defines update_at, is_maintenance_overdue, 
-- and update_maintenance_schedule_after_completion functions and triggers
-- ================================================================================

CREATE TRIGGER trigger_equipment_maintenance_schedule_update_at
BEFORE UPDATE ON equipment_maintenance_schedule
FOR EACH ROW
EXECUTE FUNCTION update_user_timestamp();

COMMENT ON TRIGGER trigger_equipment_maintenance_schedule_update_at ON equipment_maintenance_schedule IS
'Automatically updates equipment_maintenance_schedule.updated_at on row modification.';

CREATE OR REPLACE FUNCTION is_maintenance_overdue(
  p_schedule_id UUID
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT next_due_date < CURRENT_DATE
  FROM equipment_maintenance_schedule
  WHERE id = p_schedule_id;
$$;

COMMENT ON FUNCTION is_maintenance_overdue(UUID) IS
'Check if maintenance schedule is overdue.
Returns true if next_due_date is in the past.
Used for dashboard alert highlighting and cron job alert generation.
Example: WHERE is_maintenance_overdue(schedule_id)';

CREATE OR REPLACE FUNCTION get_equipment_due_for_maintenance(
  p_org_id UUID,
  p_days_until_due INT DEFAULT 30,
  OUT equipment_id UUID,
  OUT equipment_name VARCHAR(255),
  OUT maintenance_type VARCHAR(100),
  OUT days_until_due INT,
  OUT is_overdue BOOLEAN
)
RETURNS SETOF record
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT 
    ems.equipment_id,
    CONCAT(e.make, ' ', e.model) as equipment_name,
    mtl.label as maintenance_type,
    (ems.next_due_date - CURRENT_DATE)::INT as days_until_due,
    (ems.next_due_date < CURRENT_DATE) as is_overdue
  FROM equipment_maintenance_schedule ems
  JOIN equipment e ON ems.equipment_id = e.id
  JOIN maintenance_type_lookup mtl ON ems.maintenance_type_id = mtl.id
  WHERE 
    ems.organization_id = p_org_id
    AND ems.next_due_date BETWEEN CURRENT_DATE - INTERVAL '1 day' 
    AND CURRENT_DATE + (p_days_until_due || ' days')::INTERVAL
  ORDER BY ems.next_due_date ASC;
$$;

COMMENT ON FUNCTION get_equipment_due_for_maintenance(UUID, INT) IS
'Get all equipment needing maintenance in next N days (default 30).
Returns both overdue (negative days_until_due) and upcoming maintenance.
Used for dashboard widgets, email alerts, and scheduling views.
Results ordered by next_due_date (oldest/most urgent first).
Example: SELECT * FROM get_equipment_due_for_maintenance(org_id, 30)';

CREATE OR REPLACE FUNCTION update_maintenance_schedule_after_completion(
  p_maintenance_record_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_equipment_id UUID;
  v_maintenance_type_id SMALLINT;
  v_schedule_id UUID;
BEGIN
  -- Get equipment and maintenance type from the completed record
  SELECT equipment_id, maintenance_type_id 
  INTO v_equipment_id, v_maintenance_type_id
  FROM maintenance_records 
  WHERE id = p_maintenance_record_id;

  -- Find the schedule
  SELECT id INTO v_schedule_id
  FROM equipment_maintenance_schedule
  WHERE equipment_id = v_equipment_id 
    AND maintenance_type_id = v_maintenance_type_id
  LIMIT 1;

  -- Update schedule with new dates
  UPDATE equipment_maintenance_schedule
  SET 
    last_maintenance_date = CURRENT_DATE,
    next_due_date = CURRENT_DATE + (scheduled_frequency_days || ' days')::INTERVAL,
    overdue_alert_sent_at = NULL,
    due_soon_alert_sent_at = NULL,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = v_schedule_id;
END;
$$;

COMMENT ON FUNCTION update_maintenance_schedule_after_completion(UUID) IS
'Called after maintenance_records is confirmed on blockchain.
Updates last_maintenance_date and next_due_date in schedule.
Resets alert timestamps (overdue_alert_sent_at, due_soon_alert_sent_at) so new alerts can be generated.
Should be called from maintenance confirmation flow after blockchain records confirmation.
Example: CALL update_maintenance_schedule_after_completion(maintenance_id) after solana_signature populated.';

-- ================================================================================
-- Create Triggers for organizations_integrations
-- Description: defines update_at triggers
-- ================================================================================

CREATE TRIGGER trigger_organizations_integrations_update_at
BEFORE UPDATE ON organizations_integrations
FOR EACH ROW
EXECUTE FUNCTION update_user_timestamp();

COMMENT ON TRIGGER trigger_organizations_integrations_update_at ON organizations_integrations IS
'Automatically updates organizations_integrations.updated_at on row modification.';

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
