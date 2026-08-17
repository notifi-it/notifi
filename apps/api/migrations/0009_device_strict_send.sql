-- A device is the account, so the "don't fix my sends quietly" switch lives
-- here rather than on keys: it is the owner's decision, not the sender script's.
-- Defaults off, because the existing behaviour for every device already on the
-- table is to deliver a degraded message rather than refuse it.
ALTER TABLE devices ADD COLUMN strict_send INTEGER NOT NULL DEFAULT 0;
