-- Optional client-supplied event time, in unix MILLISECONDS.
--
-- This is display-only. `created_at` (server, seconds) remains the sort key, the
-- `since` bookmark and the expiry basis, because a sender can put anything in
-- here — including times far in the past or future — and letting that drive
-- ordering would break pagination and let one sender pin itself to the top of
-- someone's feed.
ALTER TABLE messages ADD COLUMN occurred_at INTEGER;
