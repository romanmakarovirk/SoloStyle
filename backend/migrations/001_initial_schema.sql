-- ============================================
-- SoloStyle Backend: Initial Database Schema
-- Run this script in Supabase SQL Editor
-- ============================================

-- Step 1: Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS vector;

-- Step 2: Create masters table
CREATE TABLE IF NOT EXISTS masters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    experience INTEGER DEFAULT 0,
    rating NUMERIC(2,1) DEFAULT 0.0,
    location GEOGRAPHY(POINT, 4326),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Step 3: Create services table
CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    master_id UUID NOT NULL REFERENCES masters(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL,
    embedding VECTOR(1536),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Step 4: Create indexes
CREATE INDEX IF NOT EXISTS idx_masters_location ON masters USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_services_master_id ON services (master_id);

-- Step 5: Auto-update updated_at on row changes
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER masters_updated_at
    BEFORE UPDATE ON masters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER services_updated_at
    BEFORE UPDATE ON services
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
