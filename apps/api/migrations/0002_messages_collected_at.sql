-- The row outlives its collection: /history blanks the content and stamps
-- collected_at instead of deleting, so the hourly send limit and the
-- uncollected ceiling are both plain counts over this table.
-- DropIndex
DROP INDEX "idx_messages_device_seq";

-- AlterTable
ALTER TABLE "messages" ADD COLUMN "collected_at" INTEGER;

-- CreateIndex
CREATE INDEX "idx_messages_device" ON "messages"("device_id");
