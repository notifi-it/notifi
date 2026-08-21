-- Devices report the OS version they are running at registration, alongside
-- platform and app_version. Nullable: rows registered before this column
-- existed have no value until that device registers again.

-- AlterTable
ALTER TABLE "devices" ADD COLUMN "os_version" TEXT;
