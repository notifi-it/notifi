import { Hono } from 'hono';
import { now } from '../lib/time.js';
import type { AppEnv, Env } from '../types.js';

export const reviews = new Hono<AppEnv>();

const APP_ID = '1563961135';

const STOREFRONTS = [
  'us',
  'gb',
  'ca',
  'au',
  'de',
  'fr',
  'es',
  'it',
  'nl',
  'se',
  'br',
  'mx',
  'jp',
  'in',
] as const;

const MAX_REVIEWS = 24;
const CACHE_SECONDS = 3600;

interface Label {
  label?: string;
}

interface FeedEntry {
  author?: { name?: Label };
  updated?: Label;
  'im:rating'?: Label;
  'im:version'?: Label;
  id?: Label;
  title?: Label;
  content?: Label;
}

interface Feed {
  feed?: { entry?: FeedEntry | FeedEntry[] };
}

export interface Review {
  id: string;
  rating: number;
  title: string;
  body: string;
  author: string;
  country: string;
  version: string;
  date: string;
}

function entries(feed: Feed): FeedEntry[] {
  const entry = feed.feed?.entry;
  if (!entry) return [];
  return Array.isArray(entry) ? entry : [entry];
}

function toReview(entry: FeedEntry, country: string): Review | null {
  const rating = Number(entry['im:rating']?.label);
  const id = entry.id?.label;
  const title = entry.title?.label;
  const body = entry.content?.label;
  const date = entry.updated?.label;
  if (!id || !title || !body || !date) return null;
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) return null;
  return {
    id,
    rating,
    title,
    body,
    author: entry.author?.name?.label ?? '',
    country,
    version: entry['im:version']?.label ?? '',
    date,
  };
}

async function fetchStorefront(country: string): Promise<Review[]> {
  const url = `https://itunes.apple.com/${country}/rss/customerreviews/id=${APP_ID}/sortby=mostrecent/json`;
  const res = await fetch(url);
  if (!res.ok) {
    console.error('reviews.fetch', { country, status: res.status });
    return [];
  }
  const feed = (await res.json()) as Feed;
  return entries(feed)
    .map((entry) => toReview(entry, country))
    .filter((review): review is Review => review !== null);
}

export async function refreshReviews(env: Env): Promise<number> {
  const nowS = now();
  let stored = 0;

  for (const country of STOREFRONTS) {
    let list: Review[];
    try {
      list = await fetchStorefront(country);
    } catch (err) {
      console.error('reviews.refresh', country, err);
      continue;
    }
    if (list.length === 0) continue;

    await env.DB.batch(
      list.map((r) =>
        env.DB.prepare(
          `INSERT INTO app_reviews
             (id, rating, title, body, author, country, version, updated_at, fetched_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET
             rating = excluded.rating, title = excluded.title, body = excluded.body,
             version = excluded.version, updated_at = excluded.updated_at,
             fetched_at = excluded.fetched_at`,
        ).bind(r.id, r.rating, r.title, r.body, r.author, r.country, r.version, r.date, nowS),
      ),
    );
    stored += list.length;
  }

  return stored;
}

reviews.get('/reviews.json', async (c) => {
  const totals = await c.env.DB.prepare(
    'SELECT COUNT(*) AS count, AVG(rating) AS average FROM app_reviews',
  ).first<{ count: number; average: number | null }>();

  if (!totals || totals.count === 0) {
    await refreshReviews(c.env);
  }

  const [counted, rows] = await Promise.all([
    c.env.DB.prepare('SELECT COUNT(*) AS count, AVG(rating) AS average FROM app_reviews').first<{
      count: number;
      average: number | null;
    }>(),
    c.env.DB.prepare(
      `SELECT id, rating, title, body, author, country, version, updated_at AS date
       FROM app_reviews ORDER BY updated_at DESC LIMIT ?`,
    )
      .bind(MAX_REVIEWS)
      .all<Review>(),
  ]);

  const count = counted?.count ?? 0;
  const average = counted?.average ? Math.round(counted.average * 10) / 10 : 0;

  return c.json({ count, average, reviews: rows.results }, 200, {
    'cache-control': `public, max-age=300, s-maxage=${CACHE_SECONDS}`,
  });
});
