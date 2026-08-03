-- Per-device message numbering.
--
-- `messages.id` is a global AUTOINCREMENT, and /history handed it to the device
-- as the message id. Any device could therefore read the relay's total traffic
-- off its own ids, and by sending itself two messages an hour apart, count how
-- many other people's messages passed through in between. The device needs an
-- id that orders its own messages and says nothing about anyone else's.
--
-- `device_seq` is that id: 1, 2, 3 within each device. It is what /history
-- returns, what the push payload carries, and what `acked_id` now points at.
-- `id` stays as the primary key, insertion order and expiry basis, and is never
-- exposed.
--
-- The counter lives on the device row rather than being derived from
-- MAX(device_seq), because collected messages are deleted — deriving it would
-- reuse numbers the device had already acknowledged and the messages would
-- never be served.

-- Acknowledged messages are already destined for deletion by the nightly cron.
-- Clearing them here means every row that survives this migration is one the
-- device has never seen, so the renumbering below cannot make the device
-- re-collect something it already holds.
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

-- Every surviving message is unacknowledged, so the counter is exactly the
-- number of them and the acknowledgement pointer goes back to zero. Clients
-- reset their own bookmark to match (see SyncEngine).
UPDATE devices SET
  seq_counter = (SELECT COUNT(*) FROM messages m WHERE m.device_id = devices.id),
  acked_id    = 0;

CREATE UNIQUE INDEX idx_messages_device_seq ON messages(device_id, device_seq);

-- Superseded by the index above: nothing reads (device_id, id) any more.
DROP INDEX idx_messages_device;
