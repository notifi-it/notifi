-- Pausing a key. NULL is a live key; a timestamp is the moment it was paused,
-- and /send answers key_paused until it is cleared. Revoking stays separate and
-- permanent: revoked_at is set once and never unset.

-- AlterTable
ALTER TABLE "keys" ADD COLUMN "paused_at" INTEGER;
