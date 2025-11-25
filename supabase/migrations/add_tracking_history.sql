-- Add tracking_history table to store parcel status changes and admin notes
-- Run this SQL in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS tracking_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parcel_id TEXT NOT NULL,
  status TEXT NOT NULL,
  location TEXT,
  notes TEXT,
  updated_by TEXT, -- Admin user ID (optional, can be null for system updates)
  updated_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_tracking_history_parcel_id ON tracking_history(parcel_id);
CREATE INDEX IF NOT EXISTS idx_tracking_history_updated_at ON tracking_history(updated_at DESC);

-- Add comment
COMMENT ON TABLE tracking_history IS 'Stores all status changes and updates for parcels, including admin notes';

