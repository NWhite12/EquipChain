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
-- Add comment-only documentation:

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
