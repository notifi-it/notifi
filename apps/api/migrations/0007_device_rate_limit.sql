-- The send limit counts per account rather than per key. A device is the
-- account, so the window moves onto `devices`: minting a second key used to buy
-- a second allowance, which made the limit a formality for anyone who noticed.
--
-- `keys.rl_window_start` and `keys.rl_window_count` stay where they are and stop
-- being written. There is no down-migration story here and dropping a column
-- rewrites the table; a pair of frozen counters costs less than that.
ALTER TABLE devices ADD COLUMN rl_window_start INTEGER NOT NULL DEFAULT 0;
ALTER TABLE devices ADD COLUMN rl_window_count INTEGER NOT NULL DEFAULT 0;
