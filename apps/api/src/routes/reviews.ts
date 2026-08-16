import { Hono } from 'hono';
import type { AppEnv } from '../types.js';

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
  const res = await fetch(url, {
    cf: { cacheTtl: CACHE_SECONDS, cacheEverything: true },
  });
  if (!res.ok) return [];
  const feed = (await res.json()) as Feed;
  return entries(feed)
    .map((entry) => toReview(entry, country))
    .filter((review): review is Review => review !== null);
}

reviews.get('/reviews.json', async (c) => {
  const settled = await Promise.allSettled(STOREFRONTS.map(fetchStorefront));

  const seen = new Set<string>();
  const all: Review[] = [];
  for (const result of settled) {
    if (result.status !== 'fulfilled') continue;
    for (const review of result.value) {
      if (seen.has(review.id)) continue;
      seen.add(review.id);
      all.push(review);
    }
  }

  all.sort((a, b) => b.date.localeCompare(a.date));
  const list = all.slice(0, MAX_REVIEWS);
  const average =
    all.length > 0
      ? Math.round((all.reduce((sum, r) => sum + r.rating, 0) / all.length) * 10) / 10
      : 0;

  return c.json(
    { count: all.length, average, reviews: list },
    200,
    { 'cache-control': `public, max-age=300, s-maxage=${CACHE_SECONDS}` },
  );
});
