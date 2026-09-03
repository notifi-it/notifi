-- The row outlives its collection: /history blanks the content and stamps
-- collected_at instead of deleting, so the hourly send limit and the
-- uncollected ceiling are both plain counts over this table.
-- DropIndex
DROP INDEX "idx_messages_device_seq";

-- AlterTable
ALTER TABLE "messages" ADD COLUMN "collected_at" INTEGER;

-- CreateIndex
CREATE INDEX "idx_messages_device" ON "messages"("device_id");

-- The drops below are hand-written: Prisma's SQLite diff expresses a column
-- drop as a table rebuild, which D1 cannot roll back. Nothing reads or writes
-- these columns any more.
ALTER TABLE "devices" DROP COLUMN "acked_id";
ALTER TABLE "devices" DROP COLUMN "seq_counter";
ALTER TABLE "devices" DROP COLUMN "rl_window_start";
ALTER TABLE "devices" DROP COLUMN "rl_window_count";
ALTER TABLE "messages" DROP COLUMN "device_seq";
ALTER TABLE "keys" DROP COLUMN "rl_window_start";
ALTER TABLE "keys" DROP COLUMN "rl_window_count";
