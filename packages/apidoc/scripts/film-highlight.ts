import { shikify, type Lang } from '../src/shikify.js';

interface Job {
  lang: Lang;
  code: string;
  keys?: string[];
}

const input = await new Promise<string>((resolve) => {
  let data = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => {
    data += chunk;
  });
  process.stdin.on('end', () => resolve(data));
});

const jobs: Job[] = JSON.parse(input);

const out = jobs.map((job) => {
  let html = shikify(job.code, job.lang);
  for (const key of job.keys ?? []) {
    html = html.replaceAll(key, `<span class="k">${key}</span>`);
  }
  return html.split('\n');
});

process.stdout.write(JSON.stringify(out));
