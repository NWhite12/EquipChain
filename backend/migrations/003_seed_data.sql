-- ================================================================================
-- Migration 003: Seed Data for Development
-- Description: Populates lookup tables and demo data for development/testing.
-- This migration is optional and runs only when --seed flag is used.
-- WARNING: Dev data only. Do not use in production.
-- ================================================================================
SET search_path TO equipchain, public;

-- ================================================================================
-- Seed role_lookup Table
-- Description: Define user roles for development environment
-- ================================================================================

INSERT INTO role_lookup (id, code, label, description, permissions, permission_precedence, status)
VALUES
  (1, 'admin', 'Administrator', 'Full system access, can manage all resources', '["*"]'::jsonb, 1, 'active'),
  (2, 'supervisor', 'Supervisor', 'Can manage technicians, approve maintenance records, view reports', '["view:equipment",
"approve:maintenance", "manage:users", "view:reports"]'::jsonb, 10, 'active'),
  (3, 'technician', 'Technician', 'Can create and submit maintenance records, view equipment', '["create:maintenance",
"view:equipment", "view:reports"]'::jsonb, 50, 'active'),
  (4, 'viewer', 'Viewer', 'Read-only access to reports and equipment data', '["view:reports", "view:equipment"]'::jsonb,
100, 'active')
ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE role_lookup IS
'Development seed data: User roles for RBAC system';


-- ================================================================================
-- Seed maintenance_status_lookup Table
-- Description: Define maintenance record workflow states
-- ================================================================================

INSERT INTO maintenance_status_lookup (id, code, label, description, workflow_sequence, requires_photos,
requires_blockchain_signature, requires_supervisor_approval, allows_editing, is_final_status, status)
VALUES
  (1, 'draft', 'Draft', 'Record in progress, not yet submitted', 1, false, false, false, true, false, 'active'),
  (2, 'submitted', 'Submitted', 'Technician submitted for supervisor review', 2, true, false, true, false, false, 'active'),
  (3, 'approved', 'Approved', 'Supervisor approved, ready to record on blockchain', 3, true, true, false, false, false,
'active'),
  (4, 'confirmed', 'Confirmed', 'Successfully recorded on Solana blockchain, permanent', 4, true, true, false, false, true,
'active'),
  (5, 'rejected', 'Rejected', 'Supervisor rejected the submission, technician can resubmit', 5, false, false, false, true,
true, 'active')
ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE maintenance_status_lookup IS
'Development seed data: Maintenance record workflow states';


-- ================================================================================
-- Seed maintenance_type_lookup Table
-- Description: Categorize types of maintenance work
-- ================================================================================

INSERT INTO maintenance_type_lookup (id, code, label, description, requires_multiple_photos, estimated_duration_hours,
status)
VALUES
  (1, 'preventive', 'Preventive Maintenance', 'Scheduled maintenance to prevent equipment failures, standard inspections',
false, 2.00, 'active'),
  (2, 'corrective', 'Corrective Maintenance', 'Unplanned repair of failed equipment, parts replacement', false, 4.00,
'active'),
  (3, 'emergency', 'Emergency Repair', 'Critical failure requiring immediate action and detailed documentation', true, 1.00,
'active'),
  (4, 'inspection', 'Inspection', 'Equipment health check, safety verification, and condition assessment', false, 1.00,
'active')
ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE maintenance_type_lookup IS
'Development seed data: Categories of maintenance work';


-- ================================================================================
-- Seed equipment_status_lookup Table
-- Description: Define equipment lifecycle states
-- ================================================================================

INSERT INTO equipment_status_lookup (id, code, label, description, allows_maintenance, status)
VALUES
  (1, 'active', 'Active', 'Equipment in normal operation', true, 'active'),
  (2, 'inactive', 'Inactive', 'Equipment temporarily out of service', false, 'active'),
  (3, 'damaged', 'Damaged', 'Equipment damaged and removed from service', false, 'active'),
  (4, 'in_repair', 'In Repair', 'Equipment currently under repair', false, 'active'),
  (5, 'decommissioned', 'Decommissioned', 'Equipment permanently removed from inventory', false, 'active')
ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE equipment_status_lookup IS
'Development seed data: Equipment lifecycle states';


-- ================================================================================
-- Seed organizations Table
-- Description: Create demo organizations for testing multi-tenant isolation
-- ================================================================================

INSERT INTO organizations (id, code, name, description, status)
VALUES
  ('550e8400-e29b-41d4-a716-446655440000'::uuid, 'demo_corp', 'Demo Corporation', 'Development demo organization for
testing', 'active'),
  ('550e8400-e29b-41d4-a716-446655440001'::uuid, 'test_builder', 'Test Builder Inc', 'QA testing organization for
integration tests', 'active')
ON CONFLICT (code) DO NOTHING;

COMMENT ON TABLE organizations IS
'Development seed data: Demo organizations for multi-tenant testing';


-- ================================================================================
-- Seed users Table
-- Description: Create demo users with different roles
-- NOTE: All passwords hashed with bcrypt (password: demo123)
-- Hash generation: Use Go: crypto/bcrypt or online tool with cost=12
-- This is development data ONLY - never commit real passwords
-- ================================================================================

-- Demo password hash for "demo123" with bcrypt cost 12:
-- $2a$12$OIYjJHrnZBNfvKfGVBYBr.c7z2LHREG.0lhq6i0gTVGRQFCXXBCzC

INSERT INTO users (id, organization_id, email, password_hash, role_id, email_verified, email_verified_at, status)
VALUES
  -- Demo Corp: Admin user
  ('550e8400-e29b-41d4-a716-446655440010'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'admin@demo.local',
'$2a$12$OIYjJHrnZBNfvKfGVBYBr.c7z2LHREG.0lhq6i0gTVGRQFCXXBCzC', 1, true, CURRENT_TIMESTAMP, 'active'),
  -- Demo Corp: Supervisor user
  ('550e8400-e29b-41d4-a716-446655440011'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'supervisor@demo.local',
'$2a$12$OIYjJHrnZBNfvKfGVBYBr.c7z2LHREG.0lhq6i0gTVGRQFCXXBCzC', 2, true, CURRENT_TIMESTAMP, 'active'),
  -- Demo Corp: Technician user
  ('550e8400-e29b-41d4-a716-446655440012'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'technician@demo.local',
'$2a$12$OIYjJHrnZBNfvKfGVBYBr.c7z2LHREG.0lhq6i0gTVGRQFCXXBCzC', 3, true, CURRENT_TIMESTAMP, 'active'),
  -- Demo Corp: Viewer user
  ('550e8400-e29b-41d4-a716-446655440013'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'viewer@demo.local',
'$2a$12$OIYjJHrnZBNfvKfGVBYBr.c7z2LHREG.0lhq6i0gTVGRQFCXXBCzC', 4, true, CURRENT_TIMESTAMP, 'active'),

  -- Test Builder: Admin user
  ('550e8400-e29b-41d4-a716-446655440020'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'admin@testbuilder.local',
'$2a$12$OIYjJHrnZBNfvKfGVBYBr.c7z2LHREG.0lhq6i0gTVGRQFCXXBCzC', 1, true, CURRENT_TIMESTAMP, 'active'),
  -- Test Builder: Supervisor user
  ('550e8400-e29b-41d4-a716-446655440021'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'supervisor@testbuilder.local', 
    '$2a$12$OIYjJHrnZBNfvKfGVBYBr.c7z2LHREG.0lhq6i0gTVGRQFCXXBCzC', 2, true, CURRENT_TIMESTAMP, 'active'),
  -- Test Builder: Technician user
  ('550e8400-e29b-41d4-a716-446655440022'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'technician@testbuilder.local', 
    '$2a$12$OIYjJHrnZBNfvKfGVBYBr.c7z2LHREG.0lhq6i0gTVGRQFCXXBCzC', 3, true, CURRENT_TIMESTAMP, 'active'),
  -- Test Builder: Viewer user
  ('550e8400-e29b-41d4-a716-446655440023'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'viewer@testbuilder.local',
'$2a$12$OIYjJHrnZBNfvKfGVBYBr.c7z2LHREG.0lhq6i0gTVGRQFCXXBCzC', 4, true, CURRENT_TIMESTAMP, 'active')
ON CONFLICT (organization_id, email) DO NOTHING;


COMMENT ON TABLE users IS
'Development seed data: Demo users for all roles and organizations';

-- ================================================================================
-- Seed equipment Table
-- Description: Demo equipment for Demo Corp and Test Builder organizations
-- ================================================================================

INSERT INTO equipment (id, organization_id, serial_number, make, model, location, status_id, owner_id, created_at, created_by)
VALUES
  -- Demo Corp equipment
  ('650e8400-e29b-41d4-a716-446655440100'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'CAT-320-ABC123', 'Caterpillar', '320 Excavator', 'Construction Site #7', 1, '550e8400-e29b-41d4-a716-446655440010'::uuid, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440010'::uuid),
  ('650e8400-e29b-41d4-a716-446655440101'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'KOM-PC200-XYZ789', 'Komatsu', 'PC200 Excavator', 'Job Site #3', 1, '550e8400-e29b-41d4-a716-446655440010'::uuid, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440010'::uuid),
  ('650e8400-e29b-41d4-a716-446655440102'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'VOL-A40G-QWE456', 'Volvo', 'A40G Articulated Truck', 'Quarry #2', 1, '550e8400-e29b-41d4-a716-446655440011'::uuid, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440010'::uuid),
  
  -- Test Builder equipment
  ('650e8400-e29b-41d4-a716-446655440110'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'JCB-3CX-DEF123', 'JCB', '3CX Excavator', 'North Site', 1, '550e8400-e29b-41d4-a716-446655440020'::uuid, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440020'::uuid),
  ('650e8400-e29b-41d4-a716-446655440111'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'LIO-V638-GHI789', 'Liebherr', 'V638 Wheel Loader', 'South Site', 1, '550e8400-e29b-41d4-a716-446655440020'::uuid, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440020'::uuid)
ON CONFLICT (organization_id, serial_number) DO NOTHING;

COMMENT ON TABLE organizations IS
'Development seed data: Demo equipment for multi-tenant testing';
