#!/usr/bin/env node
import { createHash } from "node:crypto";
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

function usage() {
  console.error(
    "usage: node tools/extract_gpuweb_cts_static_wgsl.mjs CTS_ROOT OUT_DIR MANIFEST",
  );
  process.exit(2);
}

const [, , ctsRoot, outDir, manifestPath] = process.argv;
if (!ctsRoot || !outDir || !manifestPath) {
  usage();
}

function walk(dir, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(file, out);
    } else if (entry.name.endsWith(".spec.ts")) {
      out.push(file);
    }
  }
  return out;
}

function literalText(literal) {
  return Function(`"use strict"; return (${literal});`)();
}

function lineForIndex(text, index) {
  let line = 1;
  for (let i = 0; i < index; i += 1) {
    if (text.charCodeAt(i) === 10) {
      line += 1;
    }
  }
  return line;
}

function sanitizeIdPart(text) {
  return text.replace(/[^A-Za-z0-9_]+/g, "_").replace(/^_+|_+$/g, "");
}

const validationRoot = path.join(ctsRoot, "src/webgpu/shader/validation");
const literalPattern =
  "(`(?:\\\\[\\s\\S]|[^`])*`|'(?:\\\\.|[^'])*'|\"(?:\\\\.|[^\"])*\")";
const constPattern = new RegExp(
  `const\\s+([A-Za-z_$][\\w$]*)\\s*=\\s*${literalPattern}\\s*;`,
  "g",
);
const expectPattern = new RegExp(
  `expectCompileResult\\(\\s*true\\s*,\\s*([A-Za-z_$][\\w$]*|${literalPattern})`,
  "g",
);

mkdirSync(outDir, { recursive: true });
const seen = new Set();
const manifest = [
  "# id\tcts_path\tline\tsha256\tbytes",
];

for (const file of walk(validationRoot).sort()) {
  const source = readFileSync(file, "utf8");
  const rel = path.relative(ctsRoot, file);
  const constants = new Map();
  let match;
  constPattern.lastIndex = 0;
  while ((match = constPattern.exec(source)) !== null) {
    const literal = match[2];
    if (!literal.includes("${")) {
      const entries = constants.get(match[1]) ?? [];
      entries.push({ index: match.index, value: literalText(literal) });
      constants.set(match[1], entries);
    }
  }
  let localIndex = 0;
  expectPattern.lastIndex = 0;
  while ((match = expectPattern.exec(source)) !== null) {
    const argument = match[1];
    let wgsl = undefined;
    if (constants.has(argument)) {
      const entries = constants.get(argument);
      for (const entry of entries) {
        if (entry.index < match.index) {
          wgsl = entry.value;
        } else {
          break;
        }
      }
    } else if (/^[`'"]/.test(argument) && !argument.includes("${")) {
      wgsl = literalText(argument);
    }
    if (wgsl === undefined) {
      continue;
    }
    wgsl = wgsl.trim();
    if (wgsl === "") {
      continue;
    }
    const dedupeKey = `${rel}\0${wgsl}`;
    if (seen.has(dedupeKey)) {
      continue;
    }
    seen.add(dedupeKey);
    localIndex += 1;
    const hash = createHash("sha256").update(wgsl).digest("hex");
    const id = `${sanitizeIdPart(rel)}_${String(localIndex).padStart(3, "0")}_${hash.slice(0, 12)}`;
    writeFileSync(path.join(outDir, `${id}.wgsl`), `${wgsl}\n`);
    manifest.push(
      `${id}\t${rel}\t${lineForIndex(source, match.index)}\t${hash}\t${Buffer.byteLength(wgsl, "utf8")}`,
    );
  }
}

writeFileSync(manifestPath, `${manifest.join("\n")}\n`);
