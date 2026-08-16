#!/usr/bin/env node
// Fails on tombstone comments -- comments that narrate code that no longer
// exists ("this used to...", "removed because...", "no X here anymore"). The
// justification for a removal belongs in the commit message; a comment must
// describe code that is present. See CLAUDE.md, "No Tombstone Comments".
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";

const EXTENSIONS = [".swift", ".ts", ".mjs", ".js"];

// Each pattern is matched case-insensitively against comment text only, so a
// string literal saying "no longer" cannot trip it.
const PATTERNS = [
  [/\bno longer\b/i, "no longer"],
  [/\bused to\b/i, "used to"],
  [/\banymore\b/i, "anymore"],
  [/\bpreviously\b/i, "previously"],
  [/\bformerly\b/i, "formerly"],
  [/\bwas removed\b/i, "was removed"],
  [/\bremoved because\b/i, "removed because"],
  [/\bthis was\b/i, "this was"],
  [/\bhas been (removed|deleted|dropped)\b/i, "has been removed"],
];

const files = execSync("git ls-files", { encoding: "utf8" })
  .split("\n")
  .filter((f) => EXTENSIONS.some((ext) => f.endsWith(ext)))
  .filter((f) => !f.startsWith("scripts/lint-comments"));

// A parser would be correct; this is a heuristic that only looks at text after
// a comment marker on each line. Block-comment interiors are caught because
// their lines conventionally start with * or are inside /* ... */ on one line.
function commentText(line) {
  const doubleSlash = line.indexOf("//");
  if (doubleSlash !== -1) {
    // Skip URLs: the // in https:// is not a comment marker.
    const before = line.slice(0, doubleSlash);
    if (!/https?:$/.test(before.trimEnd())) return line.slice(doubleSlash + 2);
  }
  const trimmed = line.trimStart();
  if (trimmed.startsWith("*") || trimmed.startsWith("/*")) return trimmed;
  return null;
}

let failures = 0;
for (const file of files) {
  const lines = readFileSync(file, "utf8").split("\n");
  lines.forEach((line, i) => {
    const comment = commentText(line);
    if (comment === null) return;
    for (const [pattern, label] of PATTERNS) {
      if (pattern.test(comment)) {
        console.error(`${file}:${i + 1}: tombstone comment ("${label}"): ${line.trim()}`);
        failures++;
      }
    }
  });
}

if (failures > 0) {
  console.error(
    `\n${failures} tombstone comment(s). Comments describe code that is present; put the history in the commit message.`,
  );
  process.exit(1);
}
