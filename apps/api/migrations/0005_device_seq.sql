DELETE FROM messages WHERE id IN (
  SELECT m.id FROM messages m JOIN devices d ON d.id = m.device_id
  WHERE m.id <= d.acked_id
);

ALTER TABLE messages ADD COLUMN device_seq INTEGER NOT NULL DEFAULT 0;

UPDATE messages SET device_seq = (
  SELECT COUNT(*) FROM messages m2
  WHERE m2.device_id = messages.device_id AND m2.id <= messages.id
);

ALTER TABLE devices ADD COLUMN seq_counter INTEGER NOT NULL DEFAULT 0;

UPDATE devices SET
  seq_counter = (SELECT COUNT(*) FROM messages m WHERE m.device_id = devices.id),
  acked_id    = 0;

CREATE UNIQUE INDEX idx_messages_device_seq ON messages(device_id, device_seq);

DROP INDEX idx_messages_device;
