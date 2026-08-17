#!/usr/bin/env node
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";

function findComments(src, lang) {
  const hits = [];
  let i = 0;
  let line = 1;
  const n = src.length;
  let state = "code";
  let blockDepth = 0;
  let rawHashes = 0;
  let prevCode = "";
  const templateStack = [];
  const bump = (c) => {
    if (c === "\n") line++;
  };
  while (i < n) {
    const c = src[i];
    const c2 = src.slice(i, i + 2);
    if (state === "code") {
      if (c2 === "//") {
        hits.push(line);
        while (i < n && src[i] !== "\n") i++;
        continue;
      }
      if (c2 === "/*") {
        hits.push(line);
        state = "block";
        blockDepth = 1;
        i += 2;
        continue;
      }
      if (lang === "ts" && c === "/" && /[(,=:[!&|?{;+\-*%~^<>]$/.test(prevCode)) {
        state = "regex";
        i++;
        continue;
      }
      if (lang === "swift" && c === "#") {
        const m = src.slice(i).match(/^#+"/);
        if (m) {
          rawHashes = m[0].length - 1;
          if (src.slice(i + m[0].length - 1, i + m[0].length + 2) === '"""') {
            state = "swiftRawMulti";
            i += rawHashes + 3;
            continue;
          }
          state = "swiftRaw";
          i += m[0].length;
          continue;
        }
      }
      if (lang === "swift" && src.slice(i, i + 3) === '"""') {
        state = "swiftMulti";
        i += 3;
        continue;
      }
      if (c === '"') state = "dq";
      else if (c === "'" && lang === "ts") state = "sq";
      else if (c === "`" && lang === "ts") state = "template";
      else if (c === "}" && templateStack.length && templateStack[templateStack.length - 1] === 0) {
        templateStack.pop();
        state = "template";
      } else {
        if (c === "{" && templateStack.length) templateStack[templateStack.length - 1]++;
        if (c === "}" && templateStack.length) templateStack[templateStack.length - 1]--;
      }
      if (!/\s/.test(c)) prevCode = c;
      bump(c);
      i++;
      continue;
    }
    if (state === "block") {
      if (c2 === "/*" && lang === "swift") {
        blockDepth++;
        i += 2;
        continue;
      }
      if (c2 === "*/") {
        blockDepth--;
        i += 2;
        if (blockDepth === 0) state = "code";
        continue;
      }
      bump(c);
      i++;
      continue;
    }
    if (state === "regex") {
      if (c === "\\") {
        i += 2;
        continue;
      }
      if (c === "[") {
        while (i < n && src[i] !== "]") {
          if (src[i] === "\\") i++;
          i++;
        }
      } else if (c === "/" || c === "\n") {
        state = "code";
        prevCode = "/";
        bump(c);
      } else bump(c);
      i++;
      continue;
    }
    if (state === "dq" || state === "sq") {
      if (c === "\\") {
        i += 2;
        continue;
      }
      if ((state === "dq" && c === '"') || (state === "sq" && c === "'")) state = "code";
      bump(c);
      i++;
      continue;
    }
    if (state === "template") {
      if (c === "\\") {
        i += 2;
        continue;
      }
      if (c2 === "${") {
        templateStack.push(0);
        state = "code";
        i += 2;
        continue;
      }
      if (c === "`") state = "code";
      bump(c);
      i++;
      continue;
    }
    if (state === "swiftMulti") {
      if (c === "\\") {
        i += 2;
        continue;
      }
      if (src.slice(i, i + 3) === '"""') {
        state = "code";
        i += 3;
        continue;
      }
      bump(c);
      i++;
      continue;
    }
    if (state === "swiftRaw" || state === "swiftRawMulti") {
      const close = (state === "swiftRaw" ? '"' : '"""') + "#".repeat(rawHashes);
      if (src.slice(i, i + close.length) === close) {
        state = "code";
        i += close.length;
        continue;
      }
      bump(c);
      i++;
      continue;
    }
  }
  return hits;
}

const files = execSync("git ls-files '*.swift' '*.ts'", { encoding: "utf8" })
  .trim()
  .split("\n");

let failures = 0;
for (const file of files) {
  const lang = file.endsWith(".swift") ? "swift" : "ts";
  const src = readFileSync(file, "utf8");
  for (const line of findComments(src, lang)) {
    console.error(`${file}:${line}: comment`);
    failures++;
  }
}

if (failures > 0) {
  console.error(`\n${failures} comment(s). This codebase carries no comments in Swift or TypeScript; see CLAUDE.md.`);
  process.exit(1);
}
