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
-- $2a$12$p1ucRTMjNrMMBjSECc3SfOkuaNDdDe9wcqZZQSsJa0R4r9WDne3EG

INSERT INTO users (id, organization_id, email, password_hash, role_id, email_verified, email_verified_at, status)
VALUES
  -- Demo Corp: Admin user
  ('550e8400-e29b-41d4-a716-446655440010'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'admin@demo.local',
'$2a$12$p1ucRTMjNrMMBjSECc3SfOkuaNDdDe9wcqZZQSsJa0R4r9WDne3EG', 1, true, CURRENT_TIMESTAMP, 'active'),
  -- Demo Corp: Supervisor user
  ('550e8400-e29b-41d4-a716-446655440011'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'supervisor@demo.local',
'$2a$12$p1ucRTMjNrMMBjSECc3SfOkuaNDdDe9wcqZZQSsJa0R4r9WDne3EG', 2, true, CURRENT_TIMESTAMP, 'active'),
  -- Demo Corp: Technician user
  ('550e8400-e29b-41d4-a716-446655440012'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'technician@demo.local',
'$2a$12$p1ucRTMjNrMMBjSECc3SfOkuaNDdDe9wcqZZQSsJa0R4r9WDne3EG', 3, true, CURRENT_TIMESTAMP, 'active'),
  -- Demo Corp: Viewer user
  ('550e8400-e29b-41d4-a716-446655440013'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'viewer@demo.local',
'$2a$12$p1ucRTMjNrMMBjSECc3SfOkuaNDdDe9wcqZZQSsJa0R4r9WDne3EG', 4, true, CURRENT_TIMESTAMP, 'active'),

  -- Test Builder: Admin user
  ('550e8400-e29b-41d4-a716-446655440020'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'admin@testbuilder.local',
'$2a$12$p1ucRTMjNrMMBjSECc3SfOkuaNDdDe9wcqZZQSsJa0R4r9WDne3EG', 1, true, CURRENT_TIMESTAMP, 'active'),
  -- Test Builder: Supervisor user
  ('550e8400-e29b-41d4-a716-446655440021'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'supervisor@testbuilder.local', 
    '$2a$12$p1ucRTMjNrMMBjSECc3SfOkuaNDdDe9wcqZZQSsJa0R4r9WDne3EG', 2, true, CURRENT_TIMESTAMP, 'active'),
  -- Test Builder: Technician user
  ('550e8400-e29b-41d4-a716-446655440022'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'technician@testbuilder.local', 
    '$2a$12$p1ucRTMjNrMMBjSECc3SfOkuaNDdDe9wcqZZQSsJa0R4r9WDne3EG', 3, true, CURRENT_TIMESTAMP, 'active'),
  -- Test Builder: Viewer user
  ('550e8400-e29b-41d4-a716-446655440023'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'viewer@testbuilder.local',
'$2a$12$p1ucRTMjNrMMBjSECc3SfOkuaNDdDe9wcqZZQSsJa0R4r9WDne3EG', 4, true, CURRENT_TIMESTAMP, 'active')
ON CONFLICT (organization_id, email) DO NOTHING;


COMMENT ON TABLE users IS
'Development seed data: Demo users for all roles and organizations';

-- ================================================================================
-- Seed equipment Table
-- Description: Demo equipment for Demo Corp and Test Builder organizations
-- ================================================================================

INSERT INTO equipment (id, organization_id, serial_number, make, model, location, status_id, owner_id, notes, purchased_date, warranty_expires, created_at, created_by)
VALUES
  -- Demo Corp equipment
  ('650e8400-e29b-41d4-a716-446655440100'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'CAT-320-ABC123', 'Caterpillar', '320 Excavator', 'Construction Site #7', 1, '550e8400-e29b-41d4-a716-446655440010'::uuid, 'Primary excavator for site prep work',
'2022-06-15'::DATE, '2026-06-15'::DATE, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440010'::uuid),
  ('650e8400-e29b-41d4-a716-446655440101'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'KOM-PC200-XYZ789', 'Komatsu', 'PC200 Excavator', 'Job Site #3', 1, '550e8400-e29b-41d4-a716-446655440010'::uuid, 'Secondary excavator, older model',
'2019-03-22'::DATE, NULL, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440010'::uuid),
  ('650e8400-e29b-41d4-a716-446655440102'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'VOL-A40G-QWE456', 'Volvo', 'A40G Articulated Truck', 'Quarry #2', 1, '550e8400-e29b-41d4-a716-446655440011'::uuid, 'Heavy hauler, high capacity', '2023-11-08'::DATE,
'2028-11-08'::DATE, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440010'::uuid),

  -- Test Builder equipment
  ('650e8400-e29b-41d4-a716-446655440110'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'JCB-3CX-DEF123', 'JCB', '3CX Excavator', 'North Site', 1, '550e8400-e29b-41d4-a716-446655440020'::uuid, 'Multi-purpose backhoe loader', '2021-01-10'::DATE,
'2025-01-10'::DATE, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440020'::uuid),
  ('650e8400-e29b-41d4-a716-446655440111'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'LIO-V638-GHI789', 'Liebherr', 'V638 Wheel Loader', 'South Site', 1, '550e8400-e29b-41d4-a716-446655440020'::uuid, NULL, '2020-05-30'::DATE, NULL, CURRENT_TIMESTAMP,
'550e8400-e29b-41d4-a716-446655440020'::uuid)
ON CONFLICT (organization_id, serial_number) DO NOTHING;

COMMENT ON TABLE equipment IS
'Development seed data: Demo equipment for multi-tenant testing';

-- ================================================================================
-- Seed maintenance_records Table
-- Description: Demo maintenance_records for Demo Corp and Test Builder organizations
-- ================================================================================

INSERT INTO maintenance_records (id, organization_id, equipment_id, maintenance_type_id, status_id, technician_id, supervisor_id, notes, gps_latitude, gps_longitude, created_at, created_by)
VALUES
  -- Demo Corp maintenance
  ('750e8400-e29b-41d4-a716-446655440100'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, '650e8400-e29b-41d4-a716-446655440100'::uuid, 1, 1, '550e8400-e29b-41d4-a716-446655440012'::uuid, '550e8400-e29b-41d4-a716-446655440011'::uuid, 'Scheduled preventive maintenance. Oil change and filter replacement.', 40.71280000, -74.00600000, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440012'::uuid),
  ('750e8400-e29b-41d4-a716-446655440101'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, '650e8400-e29b-41d4-a716-446655440101'::uuid, 1, 1, '550e8400-e29b-41d4-a716-446655440012'::uuid, '550e8400-e29b-41d4-a716-446655440011'::uuid, 'Additional Demo Corp maintenance.', 40.71280000, -74.00600000, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440012'::uuid),
  -- Test Builder maintenance
  ('750e8400-e29b-41d4-a716-446655440110'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, '650e8400-e29b-41d4-a716-446655440110'::uuid, 2, 1, '550e8400-e29b-41d4-a716-446655440022'::uuid, '550e8400-e29b-41d4-a716-446655440021'::uuid, 'Emergency repair: hydraulic hose replacement, tested under load.', 39.73915000, -104.99028000, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440022'::uuid),
  ('750e8400-e29b-41d4-a716-446655440111'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, '650e8400-e29b-41d4-a716-446655440111'::uuid, 2, 1, '550e8400-e29b-41d4-a716-446655440022'::uuid, '550e8400-e29b-41d4-a716-446655440021'::uuid, 'Additional Test
Builder maintenance.', 39.73915000, -104.99028000, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440022'::uuid)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE maintenance_records IS
'Development seed data: Demo maintenance_records for multi-tenant testing';

-- ================================================================================
-- Seed maintenance_photos Table
-- Description: Demo maintenance_photos for Demo Corp and Test Builder organizations
-- ================================================================================

INSERT INTO maintenance_photos (id, maintenance_record_id, organization_id, sequence_number, ipfs_hash, ipfs_url, file_size_bytes, mime_type, created_at, created_by)
VALUES
  -- Photos for first Demo Corp maintenance record
  ('850e8400-e29b-41d4-a716-446655440100'::uuid, '750e8400-e29b-41d4-a716-446655440100'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 1, 'QmX7f3MN2pK9vR4tQsDxC5nL1jYe8bZqH6wFgUoPvDemoBeforePhoto001', 'https://ipfs.io/ipfs/QmX7f3MN2pK9vR4tQsDxC5nL1jYe8bZqH6wFgUoPvDemoBeforePhoto001', 2048576, 'image/jpeg', CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440012'::uuid),
  ('850e8400-e29b-41d4-a716-446655440101'::uuid, '750e8400-e29b-41d4-a716-446655440100'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 2, 'QmY8g4NO3qL0wS5uRdYePmM2kZf9cAiRj7xVhPqWDemoDuringPhoto001', 'https://ipfs.io/ipfs/QmY8g4NO3qL0wS5uRdYePmM2kZf9cAiRj7xVhPqWDemoDuringPhoto001', 2150512, 'image/jpeg', CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440012'::uuid),
  ('850e8400-e29b-41d4-a716-446655440102'::uuid, '750e8400-e29b-41d4-a716-446655440100'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 3, 'QmZ9h5OP4rM1xT6vSeFnFqN3laG0dBjSk8yWiQrXDemoAfterPhoto001', 'https://ipfs.io/ipfs/QmZ9h5OP4rM1xT6vSeFnFqN3laG0dBjSk8yWiQrXDemoAfterPhoto001', 1978304, 'image/jpeg', CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440012'::uuid),
  
  -- Photos for Test Builder maintenance record
  ('850e8400-e29b-41d4-a716-446655440110'::uuid, '750e8400-e29b-41d4-a716-446655440110'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 1, 'QmTestBuilderBefore001TestEquipmentPhoto0001TESTPREPFixturePNG', 'https://ipfs.io/ipfs/QmTestBuilderBefore001TestEquipmentPhoto0001TESTPREPFixturePNG', 2321408, 'image/png', CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440022'::uuid),
  ('850e8400-e29b-41d4-a716-446655440111'::uuid, '750e8400-e29b-41d4-a716-446655440110'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 2, 'QmTestBuilderDuring001TestEquipmentPhoto0002TESTREPAIRFixturePNG', 'https://ipfs.io/ipfs/QmTestBuilderDuring001TestEquipmentPhoto0002TESTREPAIRFixturePNG', 2458624, 'image/png', CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440022'::uuid),
  ('850e8400-e29b-41d4-a716-446655440112'::uuid, '750e8400-e29b-41d4-a716-446655440110'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 3, 'QmTestBuilderAfter001TestEquipmentPhoto0003TESTVERIFYFixturePNG', 'https://ipfs.io/ipfs/QmTestBuilderAfter001TestEquipmentPhoto0003TESTVERIFYFixturePNG', 2187264, 'image/png', CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440022'::uuid)
ON CONFLICT (ipfs_hash) DO NOTHING;

COMMENT ON TABLE maintenance_photos IS
'Development seed data: Demo maintenance_photos for multi-tenant testing';

-- ===============================================================================
-- Seed blockchain_transactions Table
-- Description: Demo blockchain transactions for Demo Corp and Test Builder organizations
-- ===============================================================================

INSERT INTO blockchain_transactions (
  id,
  maintenance_record_id,
  organization_id,
  transaction_signature,
  block_number,
  block_timestamp,
  confirmation_status,
  transaction_fee_lamports,
  solana_rpc_response,
  retry_count,
  last_retry_at,
  error_message,
  created_at,
  confirmed_at,
  solana_cluster
)
VALUES
  -- Demo Corp: First maintenance record - CONFIRMED
  (
    '950e8400-e29b-41d4-a716-446655440100'::uuid,
    '750e8400-e29b-41d4-a716-446655440100'::uuid,
    '550e8400-e29b-41d4-a716-446655440000'::uuid,
    '4pUQSfJYzQ7Rk2mN5wB8xC1dE3fG6hI9jK0lL2mN4oP5qR6sT7uV8wX9yZ0aB1cD2eF3gH4iJ5kL6mN'::varchar,
    274915162,
    1699627543,
    'confirmed',
    5000,
    '{"jsonrpc":"2.0","result":{"context":{"slot":274915162},"value":{"err":null,"logs":["Program TokenkegQfeZyiNwAJsyFbPYrGqQ7LrhSuno6gSvEF invoke [1]","Program TokenkegQfeZyiNwAJsyFbPYrGqQ7LrhSuno6gSvEF consumed 3616 of 1400000 compute units","Program TokenkegQfeZyiNwAJsyFbPYrGqQ7LrhSuno6gSvEF success"],"signature":"4pUQSfJYzQ7Rk2mN5wB8xC1dE3fG6hI9jK0lL2mN4oP5qR6sT7uV8wX9yZ0aB1cD2eF3gH4iJ5kL6mN"}},"id":1}'::jsonb,
    0,
    NULL,
    NULL,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    'mainnet-beta'
  ),

  -- Test Builder: First maintenance record - CONFIRMED with retries
  (
    '950e8400-e29b-41d4-a716-446655440110'::uuid,
    '750e8400-e29b-41d4-a716-446655440110'::uuid,
    '550e8400-e29b-41d4-a716-446655440001'::uuid,
    '5zM9nO8pQ7rS6tU5vW4xX3yY2zA1bB0cC1dD2eE3fF4gG5hH6iI7jJ8kK9lL0mM1nN2oO3pP4qQ5rR'::varchar,
    274915175,
    1699627588,
    'confirmed',
    5500,
    '{"jsonrpc":"2.0","result":{"context":{"slot":274915175},"value":{"err":null,"logs":["Program invoke [1]","Program consumed 2847 of 1400000 compute units","Program success"],
"signature":"5zM9nO8pQ7rS6tU5vW4xX3yY2zA1bB0cC1dD2eE3fF4gG5hH6iI7jJ8kK9lL0mM1nN2oO3pP4qQ5rR"}},"id":1}'::jsonb,
    2,
    CURRENT_TIMESTAMP - INTERVAL '30 seconds',
    'Transient error during first submission attempt',
    CURRENT_TIMESTAMP - INTERVAL '1 minute',
    CURRENT_TIMESTAMP - INTERVAL '30 seconds',
    'mainnet-beta'
  ),

  -- Demo Corp: Additional pending transaction (in-flight)
  (
    '950e8400-e29b-41d4-a716-446655440200'::uuid,
    '750e8400-e29b-41d4-a716-446655440101'::uuid,
    '550e8400-e29b-41d4-a716-446655440000'::uuid,
    '2aB3cD4eE5fF6gG7hH8iI9jJ0kK1lL2mM3nN4oO5pP6qQ7rR8sS9tT0uU1vV2wW3xX4yY5zZ6aA7bB'::varchar,
    NULL,
    NULL,
    'pending',
    NULL,
    '{"jsonrpc":"2.0","id":1,"method":"sendTransaction"}'::jsonb,
    1,
    CURRENT_TIMESTAMP - INTERVAL '45 seconds',
    'Awaiting blockchain confirmation',
    CURRENT_TIMESTAMP - INTERVAL '2 minutes',
    NULL,
    'mainnet-beta'
  ),

  -- Test Builder: Additional failed transaction
  (
    '950e8400-e29b-41d4-a716-446655440210'::uuid,
    '750e8400-e29b-41d4-a716-446655440111'::uuid,
    '550e8400-e29b-41d4-a716-446655440001'::uuid,
    '6cD7eE8fF9gG0hH1iI2jJ3kK4lL5mM6nN7oO8pP9qQ0rR1sS2tT3uU4vV5wW6xX7yY8zZ9aA0bB1cC'::varchar,
    NULL,
    NULL,
    'failed',
    NULL,
    '{"jsonrpc":"2.0","error":{"code":-32003,"message":"Insufficient lamports"}}'::jsonb,
    3,
    CURRENT_TIMESTAMP - INTERVAL '1 second',
    'Insufficient lamports for transaction',
    CURRENT_TIMESTAMP - INTERVAL '5 minutes',
    NULL,
    'mainnet-beta'
  )
ON CONFLICT DO NOTHING;

COMMENT ON TABLE blockchain_transactions IS
'Development seed data: Demo blockchain transactions showing various states (confirmed, pending, failed)';

-- ================================================================================
-- Seed technician_profiles Table
-- Description: Demo technician_profiles for Demo Corp and Test Builder organizations
-- ================================================================================

INSERT INTO technician_profiles (id, user_id, organization_id, license_number, license_type, license_state, license_issued_date, license_expiration_date, certifications, is_available, hourly_rate, created_at, created_by)
VALUES
  -- Demo Corp: Technician with hydraulics certification
  ('950e8400-e29b-41d4-a716-446655440010'::uuid, '550e8400-e29b-41d4-a716-446655440012'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'MT-8472', 'Equipment Operator', 'MT', '2022-03-15'::date, '2026-03-14'::date, '["hydraulics", "diesel_engine"]'::jsonb, true, 85.00, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440010'::uuid),
  
  -- Demo Corp: Supervisor with approval authority
  ('950e8400-e29b-41d4-a716-446655440011'::uuid, '550e8400-e29b-41d4-a716-446655440011'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'SV-3021', 'Supervisor', 'MT', '2020-06-01'::date, '2027-05-31'::date, '["hydraulics", "diesel_engine", "welding", "electrical_systems"]'::jsonb, true, 125.00, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440010'::uuid),
  
  -- Test Builder: Technician with welding certification
  ('950e8400-e29b-41d4-a716-446655440012'::uuid, '550e8400-e29b-41d4-a716-446655440022'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'CO-5847', 'Equipment Operator', 'CO', '2021-09-20'::date, '2025-09-19'::date, '["welding", "electrical_systems"]'::jsonb, true, 90.00, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440020'::uuid),
  
  -- Test Builder: Supervisor with approval authority
  ('950e8400-e29b-41d4-a716-446655440013'::uuid, '550e8400-e29b-41d4-a716-446655440021'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'IN-7293', 'Inspector', 'CO', '2019-02-14'::date, '2027-02-13'::date, '["hydraulics", "diesel_engine", "welding", "electrical_systems"]'::jsonb, true, 140.00, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440020'::uuid)
ON CONFLICT (user_id) DO NOTHING;

COMMENT ON TABLE technician_profiles IS
'Development seed data: Demo technician profiles with licensing, certification, and availability constraints.';

INSERT INTO maintenance_approval_audit (id, maintenance_record_id, organization_id, approver_id, action, comments, approval_sequence, created_at, ip_address, user_agent)
VALUES
  -- Demo Corp: Supervisor approved first maintenance record
  ('b50e8400-e29b-41d4-a716-446655440010'::uuid, '750e8400-e29b-41d4-a716-446655440100'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, '550e8400-e29b-41d4-a716-446655440011'::uuid, 'approved', 'Approved - all documentation complete and photos clear', 1, CURRENT_TIMESTAMP - INTERVAL '2 hours', '192.168.1.100'::inet, 'Mozilla/5.0'),
  
  -- Test Builder: Inspector approved first maintenance record
  ('b50e8400-e29b-41d4-a716-446655440011'::uuid, '750e8400-e29b-41d4-a716-446655440110'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, '550e8400-e29b-41d4-a716-446655440021'::uuid, 'approved', 'Inspection complete - ready for blockchain confirmation', 1, CURRENT_TIMESTAMP - INTERVAL '1 hour', '192.168.1.101'::inet, 'Mozilla/5.0')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE maintenance_approval_audit IS
'Development seed data: Demo approval workflow history';

-- ================================================================================
-- Seed equipment_maintenance_schedule Table
-- Description: Demo equipment_maintenance_schedule for Demo Corp and Test Builder organizations
-- ================================================================================

INSERT INTO equipment_maintenance_schedule (id, equipment_id, organization_id, maintenance_type_id, scheduled_frequency_days, last_maintenance_date, next_due_date, created_at, created_by)
VALUES
  -- Demo Corp: Preventive maintenance every 30 days for CAT excavator
  ('a60e8400-e29b-41d4-a716-446655440100'::uuid, '650e8400-e29b-41d4-a716-446655440100'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 1, 30, (CURRENT_DATE - INTERVAL '10 days')::date, (CURRENT_DATE + INTERVAL '20 days')::date, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440010'::uuid),
  
  -- Test Builder: Inspection every 60 days for JCB excavator (OVERDUE example)
  ('a60e8400-e29b-41d4-a716-446655440110'::uuid, '650e8400-e29b-41d4-a716-446655440110'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 4, 60, (CURRENT_DATE - INTERVAL '100 days')::date, (CURRENT_DATE - INTERVAL '40 days')::date, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440020'::uuid)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE equipment_maintenance_schedule IS
'Development seed data: Demo maintenance schedules including one overdue example for testing alerts.';


-- ================================================================================
-- Seed organizations_integrations Table
-- Description: Demo organizations_integrations for Demo Corp and Test Builder organizations
-- ================================================================================

INSERT INTO organizations_integrations (id, organization_id, integration_type, integration_name, webhook_url, is_active, test_mode, created_at, created_by)
VALUES
  -- Demo Corp: Staging webhook (test mode - no real data sent)
  ('c70e8400-e29b-41d4-a716-446655440100'::uuid, '550e8400-e29b-41d4-a716-446655440000'::uuid, 'insurance_api', 'Acme Insurance Staging', 'https://staging.acme-insurance.com/equipchain/webhook', true, true, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440010'::uuid),
  
  -- Test Builder: Production integration (currently disabled for testing)
  ('c70e8400-e29b-41d4-a716-446655440110'::uuid, '550e8400-e29b-41d4-a716-446655440001'::uuid, 'procore', 'Procore Main Site', 'https://procore.api.com/webhooks/equipchain', false, false, CURRENT_TIMESTAMP, '550e8400-e29b-41d4-a716-446655440020'::uuid)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE organizations_integrations IS
'Development seed data: Demo integration configurations for testing webhook flows.';
