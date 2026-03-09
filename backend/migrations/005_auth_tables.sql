-- Auth tables for Telegram login flow
-- Run in Supabase SQL Editor

-- Users table (Telegram-authenticated users)
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    telegram_id BIGINT UNIQUE NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT,
    username TEXT,
    photo_url TEXT,
    role TEXT,  -- 'master' or 'client', NULL until selected
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users (telegram_id);

-- Temporary auth tokens (iOS ↔ Telegram bot handshake)
CREATE TABLE IF NOT EXISTS auth_tokens (
    id BIGSERIAL PRIMARY KEY,
    auth_token TEXT UNIQUE NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    jwt TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_tokens_token ON auth_tokens (auth_token);

-- Auto-cleanup expired tokens (optional: run periodically)
-- DELETE FROM auth_tokens WHERE expires_at < now();
