#!/usr/bin/env node
import { createHash } from "node:crypto";
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

function usage() {
  console.error(
    "usage: node tools/extract_gpuweb_cts_invalid_static_wgsl.mjs CTS_ROOT OUT_DIR MANIFEST",
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

function sourceLooksLikeTranslationUnit(wgsl) {
  return /(^|\n)\s*(enable|requires|diagnostic|alias|struct|const|override|var\b|var<|@|fn)\b/.test(
    wgsl,
  );
}

function findObjectStart(source, index) {
  for (let i = index; i >= 0; i -= 1) {
    const ch = source[i];
    if (ch === "{") {
      return i;
    }
    if (ch === ";" || ch === "\n" && index - i > 800) {
      break;
    }
  }
  return -1;
}

function findObjectEnd(source, index) {
  let depth = 0;
  let quote = "";
  for (let i = index; i < source.length; i += 1) {
    const ch = source[i];
    if (quote !== "") {
      if (ch === "\\" && i + 1 < source.length) {
        i += 1;
      } else if (ch === quote) {
        quote = "";
      }
      continue;
    }
    if (ch === "`" || ch === "'" || ch === "\"") {
      quote = ch;
    } else if (ch === "{") {
      depth += 1;
    } else if (ch === "}") {
      depth -= 1;
      if (depth === 0) {
        return i + 1;
      }
    }
  }
  return -1;
}

const validationRoot = path.join(ctsRoot, "src/webgpu/shader/validation");
const literalPattern =
  "(`(?:\\\\[\\s\\S]|[^`])*`|'(?:\\\\.|[^'])*'|\"(?:\\\\.|[^\"])*\")";
const constPattern = new RegExp(
  `const\\s+([A-Za-z_$][\\w$]*)\\s*=\\s*${literalPattern}\\s*;`,
  "g",
);
const expectPattern = new RegExp(
  `expectCompileResult\\(\\s*false\\s*,\\s*([A-Za-z_$][\\w$]*|${literalPattern})`,
  "g",
);
const codePropertyPattern = new RegExp(
  `\\bcode\\s*:\\s*${literalPattern}`,
  "g",
);

mkdirSync(outDir, { recursive: true });
const seen = new Set();
const manifest = [
  "# id\tcts_path\tline\tsha256\tbytes",
];

function addCase(rel, line, localIndex, wgsl) {
  wgsl = wgsl.trim();
  if (wgsl === "" || !sourceLooksLikeTranslationUnit(wgsl)) {
    return localIndex;
  }
  if (!/(^|\n)\s*(@[^\n]*\n\s*)*fn\b/.test(wgsl) && /(^|\n)\s*let\b/.test(wgsl)) {
    return localIndex;
  }
  const dedupeKey = `${rel}\0${wgsl}`;
  if (seen.has(dedupeKey)) {
    return localIndex;
  }
  seen.add(dedupeKey);
  localIndex += 1;
  const hash = createHash("sha256").update(wgsl).digest("hex");
  const id = `${sanitizeIdPart(rel)}_${String(localIndex).padStart(3, "0")}_${hash.slice(0, 12)}`;
  writeFileSync(path.join(outDir, `${id}.wgsl`), `${wgsl}\n`);
  manifest.push(
    `${id}\t${rel}\t${line}\t${hash}\t${Buffer.byteLength(wgsl, "utf8")}`,
  );
  return localIndex;
}

function standaloneWgslFromObject(code, objectText) {
  let wgsl = code;
  if (/\bf16\s*:\s*true\b/.test(objectText) && !/\benable\s+f16\s*;/.test(wgsl)) {
    wgsl = `enable f16;\n${wgsl}`;
  }
  if (
    /@blend_src\s*\(/.test(wgsl) &&
    !/\benable\s+dual_source_blending\s*;/.test(wgsl)
  ) {
    wgsl = `enable dual_source_blending;\n${wgsl}`;
  }
  return wgsl;
}

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
    if (/^[`'"]/.test(argument) && !argument.includes("${")) {
      wgsl = literalText(argument);
    }
    if (wgsl === undefined) {
      continue;
    }
    localIndex = addCase(rel, lineForIndex(source, match.index), localIndex, wgsl);
  }

  codePropertyPattern.lastIndex = 0;
  while ((match = codePropertyPattern.exec(source)) !== null) {
    const literal = match[1];
    if (literal.includes("${")) {
      continue;
    }
    const objectStart = findObjectStart(source, match.index);
    if (objectStart < 0) {
      continue;
    }
    const objectEnd = findObjectEnd(source, objectStart);
    if (objectEnd < 0) {
      continue;
    }
    const objectText = source.slice(objectStart, objectEnd);
    if (!/\b(valid|pass|expect)\s*:\s*false\b/.test(objectText)) {
      continue;
    }
    localIndex = addCase(
      rel,
      lineForIndex(source, match.index),
      localIndex,
      standaloneWgslFromObject(literalText(literal), objectText),
    );
  }
}

writeFileSync(manifestPath, `${manifest.join("\n")}\n`);
