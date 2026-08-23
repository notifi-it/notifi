#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { execSync } from "node:child_process";

const SOURCES = [
  "README.md",
  "packages/site/pages/*.md",
  "packages/site/src/*.ts",
  "packages/copy/src/strings.ts",
  "packages/copy/src/translations/*.ts",
  "packages/apidoc/src/*.ts",
  "apps/api/public/llms.txt",
  "apps/api/public/index.md",
  "apps/api/public/index.html",
  "apps/app/fastlane/metadata/**/*.txt",
  "sketches/gif/gen.py",
];

const files = execSync(`git ls-files -- ${SOURCES.map((s) => `'${s}'`).join(" ")}`, {
  encoding: "utf8",
})
  .split("\n")
  .filter(Boolean);

let total = 0;
const perFile = new Map();

function blankComments(src) {
  return src.replace(/<!--[\s\S]*?-->|\/\*[\s\S]*?\*\/|(^|\s)\/\/[^\n]*/g, (m) =>
    m.replace(/[^\n]/g, " "),
  );
}

for (const file of files) {
  let src = readFileSync(file, "utf8");
  if (file.endsWith(".html")) src = blankComments(src);
  const lines = src.split("\n");
  lines.forEach((text, i) => {
    const count = (text.match(/—/g) || []).length;
    if (!count) return;
    total += count;
    perFile.set(file, (perFile.get(file) || 0) + count);
    const shown = text.trim().length > 120 ? text.trim().slice(0, 117) + "..." : text.trim();
    console.log(`${file}:${i + 1}: ${shown}`);
  });
}

if (total === 0) {
  console.log("no em dashes found");
} else {
  console.log("");
  for (const [file, count] of [...perFile.entries()].sort((a, b) => b[1] - a[1])) {
    console.log(`${String(count).padStart(4)}  ${file}`);
  }
  console.log(`${String(total).padStart(4)}  total`);
}

if (process.argv.includes("--fail") && total > 0) process.exit(1);
