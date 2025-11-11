-- ================================================================================
-- Migration 002: Add Foreign Keys and Constraints (Phase 2)
-- Description: Adds all foreign key constraints to resolve circular dependencies.
-- These must be added AFTER all tables are created in migration 001.
-- ================================================================================
SET search_path TO equipchain, public;

-- ================================================================================
-- Foreign Key Constraints for organizations Table
-- ================================================================================
-- Note: organizations.created_by and updated_by reference users.id
-- These are NOT added as foreign keys to allow system-created orgs with null values

ALTER TABLE organizations
  ADD CONSTRAINT fk_organizations_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE organizations
  ADD CONSTRAINT fk_organizations_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_organizations_created_by ON organizations IS
'Foreign key to users.id - admin who created this organization.
Nullable for system-created organizations.';

COMMENT ON CONSTRAINT fk_organizations_updated_by ON organizations IS
'Foreign key to users.id - admin who last modified this organization.
Automatically updated by trigger_organizations_update_at.';


-- ================================================================================
-- Foreign Key Constraints for users Table
-- ================================================================================

ALTER TABLE users
  ADD CONSTRAINT fk_users_organization_id
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

COMMENT ON CONSTRAINT fk_users_organization_id ON users IS
'Foreign key to organizations.id - enforces multi-tenant isolation.
On delete: CASCADE (if organization is deleted, all its users are deleted).';

ALTER TABLE users
  ADD CONSTRAINT users_email_unique_per_org
    UNIQUE(organization_id, email);

COMMENT ON CONSTRAINT users_email_unique_per_org ON users IS
'Email must be unique within organization, but same email can exist in different orgs.';

ALTER TABLE users
  ADD CONSTRAINT fk_users_role_id
    FOREIGN KEY (role_id) REFERENCES role_lookup(id) ON DELETE RESTRICT;

COMMENT ON CONSTRAINT fk_users_role_id ON users IS
'Foreign key to role_lookup.id - determines user permissions.
On delete: RESTRICT (cannot delete a role if users have it assigned).';

ALTER TABLE users
  ADD CONSTRAINT fk_users_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_users_created_by ON users IS
'Foreign key to users.id (self-reference) - user who created this account.
Nullable for self-registered accounts. On delete: SET NULL.';

ALTER TABLE users
  ADD CONSTRAINT fk_users_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_users_updated_by ON users IS
'Foreign key to users.id (self-reference) - user who last modified this account.
Auto-updated by trigger. On delete: SET NULL.';


-- ================================================================================
-- Foreign Key Constraints for user_password_history Table
-- ================================================================================

ALTER TABLE user_password_history
  ADD CONSTRAINT fk_user_password_history_user_id
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

COMMENT ON CONSTRAINT fk_user_password_history_user_id ON user_password_history IS
'Foreign key to users.id - password history for specific user.
On delete: CASCADE (if user is deleted, password history is deleted).';


-- ================================================================================
-- Foreign Key Constraints for role_lookup Table
-- ================================================================================

ALTER TABLE role_lookup
  ADD CONSTRAINT fk_role_lookup_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_role_lookup_created_by ON role_lookup IS
'Foreign key to users.id - admin who defined this role.
Nullable for system-created roles. On delete: SET NULL.';

ALTER TABLE role_lookup
  ADD CONSTRAINT fk_role_lookup_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_role_lookup_updated_by ON role_lookup IS
'Foreign key to users.id - admin who last modified this role.
Auto-updated by trigger. On delete: SET NULL.';


-- ================================================================================
-- Foreign Key Constraints for maintenance_status_lookup Table
-- ================================================================================

ALTER TABLE maintenance_status_lookup
  ADD CONSTRAINT fk_maintenance_status_lookup_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_maintenance_status_lookup_created_by ON maintenance_status_lookup IS
'Foreign key to users.id - admin who created this status.
Nullable for system-created statuses. On delete: SET NULL.';

ALTER TABLE maintenance_status_lookup
  ADD CONSTRAINT fk_maintenance_status_lookup_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_maintenance_status_lookup_updated_by ON maintenance_status_lookup IS
'Foreign key to users.id - admin who last modified this status.
Auto-updated by trigger. On delete: SET NULL.';


-- ================================================================================
-- Foreign Key Constraints for maintenance_type_lookup Table
-- ================================================================================

ALTER TABLE maintenance_type_lookup
  ADD CONSTRAINT fk_maintenance_type_lookup_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_maintenance_type_lookup_created_by ON maintenance_type_lookup IS
'Foreign key to users.id - admin who defined this maintenance type.
Nullable for system-created types. On delete: SET NULL.';

ALTER TABLE maintenance_type_lookup
  ADD CONSTRAINT fk_maintenance_type_lookup_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_maintenance_type_lookup_updated_by ON maintenance_type_lookup IS
'Foreign key to users.id - admin who last modified this type.
Auto-updated by trigger. On delete: SET NULL.';


-- ================================================================================
-- Foreign Key Constraints for equipment_status_lookup Table
-- ================================================================================

ALTER TABLE equipment_status_lookup
  ADD CONSTRAINT fk_equipment_status_lookup_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_equipment_status_lookup_created_by ON equipment_status_lookup IS
'Foreign key to users.id - admin who defined this status.
Nullable for system-created statuses. On delete: SET NULL.';

ALTER TABLE equipment_status_lookup
  ADD CONSTRAINT fk_equipment_status_lookup_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_equipment_status_lookup_updated_by ON equipment_status_lookup IS
'Foreign key to users.id - admin who last modified this status.
Auto-updated by trigger. On delete: SET NULL.';

-- ================================================================================
-- Constraints for equipment Table
-- ================================================================================

ALTER TABLE equipment
  ADD CONSTRAINT fk_equipment_organization_id
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

ALTER TABLE equipment
  ADD CONSTRAINT fk_equipment_status_id
    FOREIGN KEY (status_id) REFERENCES equipment_status_lookup(id) ON DELETE RESTRICT;

ALTER TABLE equipment
  ADD CONSTRAINT fk_equipment_owner_id
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE equipment
  ADD CONSTRAINT fk_equipment_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE equipment
  ADD CONSTRAINT fk_equipment_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE equipment
  ADD CONSTRAINT equipment_serial_number_unique_per_org
    UNIQUE(organization_id, serial_number);

-- ================================================================================
-- Constraints for maintenance_records
--================================================================================

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maintenance_records_organization_id
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maintenance_records_equipment_id
    FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE RESTRICT;

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maintenance_records_type_id
    FOREIGN KEY (maintenance_type_id) REFERENCES maintenance_type_lookup(id) ON DELETE RESTRICT;

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maintenance_records_status_id
    FOREIGN KEY (status_id) REFERENCES maintenance_status_lookup(id) ON DELETE RESTRICT;

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maintenance_records_technician_id
    FOREIGN KEY (technician_id) REFERENCES users(id) ON DELETE RESTRICT;

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maintenance_records_supervisor_id
    FOREIGN KEY (supervisor_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maintenance_records_inspector_id
    FOREIGN KEY (inspector_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maintenance_records_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maintenance_records_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL;

-- ================================================================================
-- Constraints for maintenance_photos
-- ================================================================================

ALTER TABLE maintenance_photos
  ADD CONSTRAINT unique_sequence_per_maintenance UNIQUE(maintenance_record_id, sequence_number);

ALTER TABLE maintenance_photos
  ADD CONSTRAINT fk_maintenance_photos_maintenance_record_id
    FOREIGN KEY (maintenance_record_id) REFERENCES maintenance_records(id) ON DELETE CASCADE;

ALTER TABLE maintenance_photos
  ADD CONSTRAINT fk_maintenance_photos_organization_id
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

ALTER TABLE maintenance_photos
  ADD CONSTRAINT fk_maintenance_photos_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE maintenance_photos
  ADD CONSTRAINT unique_ipfs_hash
    UNIQUE(ipfs_hash);

-- ================================================================================
-- Constraints for blockchain_transactions
-- ================================================================================

ALTER TABLE blockchain_transactions
  ADD CONSTRAINT fk_blockchain_transactions_maintenance_record_id
    FOREIGN KEY (maintenance_record_id) REFERENCES maintenance_records(id) ON DELETE RESTRICT;

ALTER TABLE blockchain_transactions
  ADD CONSTRAINT fk_blockchain_transactions_organization_id
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

-- ================================================================================
-- Constraints for technician_profiles
-- ================================================================================

ALTER TABLE technician_profiles
  ADD CONSTRAINT fk_technician_profiles_user_id
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE technician_profiles
  ADD CONSTRAINT fk_technician_profiles_organization_id
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

ALTER TABLE technician_profiles
  ADD CONSTRAINT fk_technician_profiles_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE technician_profiles
  ADD CONSTRAINT fk_technician_profiles_updated_by
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL;
  
-- ================================================================================
-- Constraints for maintenance_approval_audit
-- ================================================================================

ALTER TABLE maintenance_approval_audit
  ADD CONSTRAINT fk_maintenance_approval_audit_maintenance_record_id
    FOREIGN KEY (maintenance_record_id) REFERENCES maintenance_records(id) ON DELETE CASCADE;

ALTER TABLE maintenance_approval_audit
  ADD CONSTRAINT fk_maintenance_approval_audit_organization_id
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;

ALTER TABLE maintenance_approval_audit
  ADD CONSTRAINT fk_maintenance_approval_audit_approver_id
    FOREIGN KEY (approver_id) REFERENCES users(id) ON DELETE RESTRICT;

-- ================================================================================
-- Constraints for audit_log
-- ================================================================================

CREATE INDEX idx_audit_log_organization_id ON audit_log(organization_id);
COMMENT ON INDEX idx_audit_log_organization_id IS
'Multi-tenant isolation: List all audit entries for organization.';

CREATE INDEX idx_audit_log_user_id ON audit_log(user_id);
COMMENT ON INDEX idx_audit_log_user_id IS
'Find all actions performed by a specific user (for user behavior analysis).';

CREATE INDEX idx_audit_log_entity_type ON audit_log(entity_type);
COMMENT ON INDEX idx_audit_log_entity_type IS
'Filter audit logs by entity type (e.g., "show me all maintenance_record changes").';

CREATE INDEX idx_audit_log_entity_id ON audit_log(entity_id);
COMMENT ON INDEX idx_audit_log_entity_id IS
'Find all audit entries for a specific entity (e.g., "show me all changes to equipment #XYZ").';

CREATE INDEX idx_audit_log_action ON audit_log(action);
COMMENT ON INDEX idx_audit_log_action IS
'Filter by action type (e.g., "show me all deletes" for compliance).';

CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);
COMMENT ON INDEX idx_audit_log_created_at IS
'Time-range queries: "Show me all audit entries from Jan 1-31".';

CREATE INDEX idx_audit_log_user_id_created_at ON audit_log(user_id, created_at);
COMMENT ON INDEX idx_audit_log_user_id_created_at IS
'Find recent actions by a specific user (performance optimization).
Example: "What did user john@example.com do in the last 24 hours?"';

CREATE INDEX idx_audit_log_organization_id_created_at ON audit_log(organization_id, created_at);
COMMENT ON INDEX idx_audit_log_organization_id_created_at IS
'Find recent audit entries for organization (compliance export).
Example: "Show me all audit entries for acme_corp from last 30 days".';

CREATE INDEX idx_audit_log_entity_type_action ON audit_log(entity_type, action);
COMMENT ON INDEX idx_audit_log_entity_type_action IS
'Find specific actions on specific entities (e.g., "all deletes to maintenance_records").';
