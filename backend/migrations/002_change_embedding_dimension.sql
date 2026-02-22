-- Change embedding dimension from 1536 to 384
-- (for sentence-transformers all-MiniLM-L6-v2)
-- Run this in Supabase SQL Editor

ALTER TABLE services
    ALTER COLUMN embedding TYPE VECTOR(384);
