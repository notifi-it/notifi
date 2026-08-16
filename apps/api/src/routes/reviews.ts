import { Hono } from 'hono';
import type { AppEnv } from '../types.js';

export const reviews = new Hono<AppEnv>();

const MAX_REVIEWS = 24;
const CACHE_SECONDS = 3600;

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

reviews.get('/reviews.json', async (c) => {
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
