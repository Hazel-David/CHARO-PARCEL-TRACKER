-- Phase 3: Add current_location column to parcels table
-- Run this SQL in your Supabase SQL Editor

-- Add current_location column to parcels table
ALTER TABLE parcels 
ADD COLUMN IF NOT EXISTS current_location TEXT;

-- Optional: Add a comment to explain the column
COMMENT ON COLUMN parcels.current_location IS 'Current location (county) where the parcel is located';

