-- CreateTable
CREATE TABLE "devices" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "public_key" TEXT NOT NULL,
    "encryption_public_key" TEXT NOT NULL,
    "apns_token" TEXT NOT NULL,
    "apns_token_hmac" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "app_version" TEXT NOT NULL,
    "created_at" INTEGER NOT NULL,
    "last_seen_at" INTEGER NOT NULL,
    "acked_id" INTEGER NOT NULL DEFAULT 0,
    "seq_counter" INTEGER NOT NULL DEFAULT 0,
    "rl_window_start" INTEGER NOT NULL DEFAULT 0,
    "rl_window_count" INTEGER NOT NULL DEFAULT 0,
    "strict_send" INTEGER NOT NULL DEFAULT 0
);

-- CreateTable
CREATE TABLE "keys" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "device_id" INTEGER NOT NULL,
    "meta_sealed" TEXT NOT NULL,
    "secret_hash" TEXT NOT NULL,
    "sent_count" INTEGER NOT NULL DEFAULT 0,
    "rl_window_start" INTEGER NOT NULL DEFAULT 0,
    "rl_window_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" INTEGER NOT NULL,
    "last_used_at" INTEGER,
    "revoked_at" INTEGER,
    "is_critical" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "keys_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "messages" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "device_id" INTEGER NOT NULL,
    "key_id" INTEGER,
    "content_sealed" TEXT NOT NULL,
    "created_at" INTEGER NOT NULL,
    "expires_at" INTEGER NOT NULL,
    "occurred_at" INTEGER,
    "device_seq" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "messages_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "messages_key_id_fkey" FOREIGN KEY ("key_id") REFERENCES "keys" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "seen_signatures" (
    "sig_hash" TEXT NOT NULL PRIMARY KEY,
    "expires_at" INTEGER NOT NULL
);

-- CreateTable
CREATE TABLE "app_reviews" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "rating" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "author" TEXT NOT NULL,
    "country" TEXT NOT NULL,
    "version" TEXT NOT NULL,
    "updated_at" TEXT NOT NULL,
    "fetched_at" INTEGER NOT NULL
);

-- CreateIndex
CREATE UNIQUE INDEX "devices_public_key_key" ON "devices"("public_key");

-- CreateIndex
CREATE UNIQUE INDEX "devices_apns_token_hmac_key" ON "devices"("apns_token_hmac");

-- CreateIndex
CREATE UNIQUE INDEX "keys_secret_hash_key" ON "keys"("secret_hash");

-- CreateIndex
CREATE INDEX "idx_messages_expiry" ON "messages"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "idx_messages_device_seq" ON "messages"("device_id", "device_seq");

-- CreateIndex
CREATE INDEX "idx_seen_signatures_expiry" ON "seen_signatures"("expires_at");

-- CreateIndex
CREATE INDEX "idx_app_reviews_updated_at" ON "app_reviews"("updated_at" DESC);

