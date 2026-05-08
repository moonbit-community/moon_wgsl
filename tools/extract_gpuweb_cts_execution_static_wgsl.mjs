#!/usr/bin/env node
import { createHash } from "node:crypto";
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

function usage() {
  console.error(
    "usage: node tools/extract_gpuweb_cts_execution_static_wgsl.mjs CTS_ROOT OUT_DIR MANIFEST",
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

function hasEntryPoint(wgsl) {
  return /(^|\n)\s*@[^]*?\bfn\b/.test(wgsl) || /(^|\n)\s*fn\b/.test(wgsl);
}

function hasBalancedDelimiters(wgsl) {
  const stack = [];
  const pairs = new Map([
    [")", "("],
    ["]", "["],
    ["}", "{"],
  ]);
  let lineComment = false;
  let blockCommentDepth = 0;
  for (let i = 0; i < wgsl.length; i += 1) {
    const ch = wgsl[i];
    const next = wgsl[i + 1] ?? "";
    if (lineComment) {
      if (ch === "\n") {
        lineComment = false;
      }
      continue;
    }
    if (blockCommentDepth > 0) {
      if (ch === "/" && next === "*") {
        blockCommentDepth += 1;
        i += 1;
      } else if (ch === "*" && next === "/") {
        blockCommentDepth -= 1;
        i += 1;
      }
      continue;
    }
    if (ch === "/" && next === "/") {
      lineComment = true;
      i += 1;
      continue;
    }
    if (ch === "/" && next === "*") {
      blockCommentDepth = 1;
      i += 1;
      continue;
    }
    if (ch === "(" || ch === "[" || ch === "{") {
      stack.push(ch);
    } else if (pairs.has(ch)) {
      if (stack.pop() !== pairs.get(ch)) {
        return false;
      }
    }
  }
  return stack.length === 0 && blockCommentDepth === 0;
}

function nextTestIndex(source, index) {
  const found = source.indexOf("\ng.test(", index);
  return found < 0 ? source.length : found;
}

function hasMutationBetween(source, name, start, end) {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const mutation = new RegExp(`\\b${escaped}\\s*(?:\\+=|=)`, "g");
  mutation.lastIndex = start;
  const match = mutation.exec(source);
  return match !== null && match.index < end;
}

function addCase(rel, line, localIndex, wgsl) {
  wgsl = wgsl.trim();
  if (
    wgsl === "" ||
    wgsl.includes("${") ||
    !sourceLooksLikeTranslationUnit(wgsl) ||
    !hasEntryPoint(wgsl) ||
    !hasBalancedDelimiters(wgsl)
  ) {
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

const executionRoot = path.join(ctsRoot, "src/webgpu/shader/execution");
const literalPattern =
  "(`(?:\\\\[\\s\\S]|[^`])*`|'(?:\\\\.|[^'])*'|\"(?:\\\\.|[^\"])*\")";
const declarationPattern = new RegExp(
  `\\b(?:const|let|var)\\s+([A-Za-z_$][\\w$]*)\\s*=\\s*${literalPattern}\\s*;`,
  "g",
);
const directCodePropertyPattern = new RegExp(
  `\\bcode\\s*:\\s*${literalPattern}`,
  "g",
);

mkdirSync(outDir, { recursive: true });
const seen = new Set();
const manifest = ["# id\tcts_path\tline\tsha256\tbytes"];

for (const file of walk(executionRoot).sort()) {
  const source = readFileSync(file, "utf8");
  const rel = path.relative(ctsRoot, file);
  let localIndex = 0;
  let match;

  declarationPattern.lastIndex = 0;
  while ((match = declarationPattern.exec(source)) !== null) {
    const name = match[1];
    const literal = match[2];
    if (literal.includes("${")) {
      continue;
    }
    if (!/^(code|wgsl|shader|source|vsShader|fsShader)$/.test(name)) {
      continue;
    }
    const testEnd = nextTestIndex(source, declarationPattern.lastIndex);
    if (hasMutationBetween(source, name, declarationPattern.lastIndex, testEnd)) {
      continue;
    }
    localIndex = addCase(
      rel,
      lineForIndex(source, match.index),
      localIndex,
      literalText(literal),
    );
  }

  directCodePropertyPattern.lastIndex = 0;
  while ((match = directCodePropertyPattern.exec(source)) !== null) {
    const literal = match[1];
    if (literal.includes("${")) {
      continue;
    }
    localIndex = addCase(
      rel,
      lineForIndex(source, match.index),
      localIndex,
      literalText(literal),
    );
  }
}

writeFileSync(manifestPath, `${manifest.join("\n")}\n`);
