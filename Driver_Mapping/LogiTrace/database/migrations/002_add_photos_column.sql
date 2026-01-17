-- Migration 002: Add photos column to vehicle_inspection_records
-- Date: 2026-01-16

-- Add photos column (JSONB array of photo URLs)
ALTER TABLE vehicle_inspection_records
ADD COLUMN IF NOT EXISTS photos JSONB DEFAULT NULL;

-- Comment
COMMENT ON COLUMN vehicle_inspection_records.photos IS 'Array of photo URLs attached to the inspection record';
