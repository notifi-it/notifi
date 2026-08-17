-- Apple's review RSS is per storefront, and it answers 403 to a burst of
-- requests from Cloudflare's shared edge addresses: fourteen parallel fetches
-- returned one feed and thirteen refusals. Reviews therefore live here, topped
-- up a storefront at a time, and the endpoint reads the table rather than the
-- feed. A refused storefront costs nothing — the rows from the last successful
-- pass are still the answer.
CREATE TABLE app_reviews (
  id TEXT PRIMARY KEY,
  rating INTEGER NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  author TEXT NOT NULL,
  country TEXT NOT NULL,
  version TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  fetched_at INTEGER NOT NULL
);

CREATE INDEX idx_app_reviews_updated_at ON app_reviews(updated_at DESC);
