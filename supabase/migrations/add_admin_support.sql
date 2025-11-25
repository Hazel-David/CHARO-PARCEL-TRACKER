-- Phase 1: Add Admin Support to Users Table
-- Run this SQL in your Supabase SQL Editor

-- Add is_admin column to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Set your admin account (REPLACE 'your-email@example.com' with your actual email)
-- You can run this after adding the column
UPDATE users 
SET is_admin = TRUE 
WHERE email = 'your-email@example.com';

-- Verify the update
SELECT id, email, full_name, is_admin 
FROM users 
WHERE is_admin = TRUE;

