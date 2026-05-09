-- ============================================
-- SoloStyle Backend: Chat / Messenger Tables
-- Run this script in Supabase SQL Editor
-- ============================================
--
-- Identity model:
--   external_id = JWT.sub
--     - Telegram users: str(telegram_id)
--     - Apple users:    apple_user_id
--   We store external_id as TEXT so both auth providers fit
--   without joining the users table on every chat operation.
--

-- Conversation = pair (master_external_id, client_external_id).
-- One row per pair, reused for the entire history.
CREATE TABLE IF NOT EXISTS conversations (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    master_external_id   TEXT NOT NULL,
    client_external_id   TEXT NOT NULL,
    last_message_preview TEXT,
    last_message_at      TIMESTAMPTZ,
    unread_master        INT NOT NULL DEFAULT 0,
    unread_client        INT NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(master_external_id, client_external_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_master
    ON conversations(master_external_id, last_message_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_conv_client
    ON conversations(client_external_id, last_message_at DESC NULLS LAST);

-- Messages.  seq is a monotonic counter used by clients
-- as the canonical sort key (instead of created_at, which can drift).
CREATE TABLE IF NOT EXISTS chat_messages (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id    UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_role        TEXT NOT NULL CHECK (sender_role IN ('master','client','system')),
    sender_external_id TEXT NOT NULL,
    content_type       TEXT NOT NULL CHECK (content_type IN ('text','photo','voice','system')) DEFAULT 'text',
    body               TEXT,
    attachment_url     TEXT,
    attachment_meta    JSONB,
    client_message_id  UUID,         -- idempotency key from sender
    seq                BIGSERIAL,
    delivered_at       TIMESTAMPTZ,
    read_at            TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_msg_conv_seq
    ON chat_messages(conversation_id, seq);

-- Unique partial index → idempotent inserts: same (conv_id, client_msg_id)
-- pair will silently no-op if the network retries.
CREATE UNIQUE INDEX IF NOT EXISTS uq_msg_idem
    ON chat_messages(conversation_id, client_message_id)
    WHERE client_message_id IS NOT NULL;
