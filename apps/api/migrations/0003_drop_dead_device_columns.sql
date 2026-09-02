-- Hand-written: Prisma's SQLite diff expresses a column drop as a table
-- rebuild, which D1 cannot roll back. Nothing reads or writes these columns
-- any more: both send limits are counted from messages.
ALTER TABLE "devices" DROP COLUMN "acked_id";
ALTER TABLE "devices" DROP COLUMN "seq_counter";
ALTER TABLE "devices" DROP COLUMN "rl_window_start";
ALTER TABLE "devices" DROP COLUMN "rl_window_count";
ALTER TABLE "messages" DROP COLUMN "device_seq";
ALTER TABLE "keys" DROP COLUMN "rl_window_start";
ALTER TABLE "keys" DROP COLUMN "rl_window_count";
