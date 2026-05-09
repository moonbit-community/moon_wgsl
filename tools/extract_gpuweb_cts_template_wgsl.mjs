#!/usr/bin/env node
import { createHash } from "node:crypto";
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

function usage() {
  console.error(
    "usage: node tools/extract_gpuweb_cts_template_wgsl.mjs CTS_ROOT VALID_DIR VALID_MANIFEST INVALID_DIR INVALID_MANIFEST",
  );
  process.exit(2);
}

const [, , ctsRoot, validOutDir, validManifestPath, invalidOutDir, invalidManifestPath] =
  process.argv;
if (!ctsRoot || !validOutDir || !validManifestPath || !invalidOutDir || !invalidManifestPath) {
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

function hasBalancedDelimiters(source) {
  const stack = [];
  const pairs = new Map([
    [")", "("],
    ["]", "["],
    ["}", "{"],
  ]);
  let quote = "";
  let lineComment = false;
  let blockCommentDepth = 0;
  for (let i = 0; i < source.length; i += 1) {
    const ch = source[i];
    const next = source[i + 1] ?? "";
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
    if (quote !== "") {
      if (ch === "\\" && i + 1 < source.length) {
        i += 1;
      } else if (ch === quote) {
        quote = "";
      }
      continue;
    }
    if (ch === "/" && next === "/") {
      lineComment = true;
      i += 1;
    } else if (ch === "/" && next === "*") {
      blockCommentDepth = 1;
      i += 1;
    } else if (ch === "`" || ch === "'" || ch === "\"") {
      quote = ch;
    } else if (ch === "(" || ch === "[" || ch === "{") {
      stack.push(ch);
    } else if (pairs.has(ch)) {
      if (stack.pop() !== pairs.get(ch)) {
        return false;
      }
    }
  }
  return stack.length === 0 && blockCommentDepth === 0 && quote === "";
}

function findMatchingBrace(source, openIndex) {
  let depth = 0;
  let quote = "";
  let lineComment = false;
  let blockCommentDepth = 0;
  for (let i = openIndex; i < source.length; i += 1) {
    const ch = source[i];
    const next = source[i + 1] ?? "";
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
    if (quote !== "") {
      if (ch === "\\" && i + 1 < source.length) {
        i += 1;
      } else if (ch === quote) {
        quote = "";
      }
      continue;
    }
    if (ch === "/" && next === "/") {
      lineComment = true;
      i += 1;
    } else if (ch === "/" && next === "*") {
      blockCommentDepth = 1;
      i += 1;
    } else if (ch === "`" || ch === "'" || ch === "\"") {
      quote = ch;
    } else if (ch === "{") {
      depth += 1;
    } else if (ch === "}") {
      depth -= 1;
      if (depth === 0) {
        return i;
      }
    }
  }
  return -1;
}

function findStatementEnd(source, start) {
  let quote = "";
  let depth = 0;
  for (let i = start; i < source.length; i += 1) {
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
    } else if (ch === "{" || ch === "(" || ch === "[") {
      depth += 1;
    } else if (ch === "}" || ch === ")" || ch === "]") {
      depth -= 1;
    } else if (ch === ";" && depth === 0) {
      return i;
    }
  }
  return -1;
}

function extractLiteralAt(source, start) {
  const quote = source[start];
  if (quote !== "`" && quote !== "'" && quote !== "\"") {
    return undefined;
  }
  for (let i = start + 1; i < source.length; i += 1) {
    const ch = source[i];
    if (ch === "\\" && i + 1 < source.length) {
      i += 1;
      continue;
    }
    if (ch === quote) {
      return source.slice(start, i + 1);
    }
  }
  return undefined;
}

function parseObjectStringMap(source, objectStart) {
  const objectEnd = findMatchingBrace(source, objectStart);
  if (objectEnd < 0) {
    return undefined;
  }
  const body = source.slice(objectStart + 1, objectEnd);
  const entries = new Map();
  const entryPattern =
    /(?:^|,)\s*(?:([A-Za-z_$][\w$]*)|'([^']+)'|"([^"]+)")\s*:\s*/g;
  let match;
  while ((match = entryPattern.exec(body)) !== null) {
    const key = match[1] ?? match[2] ?? match[3];
    const literalStart = objectStart + 1 + entryPattern.lastIndex;
    const literal = extractLiteralAt(source, literalStart);
    if (literal === undefined || literal.includes("${")) {
      continue;
    }
    entries.set(key, literalText(literal));
    entryPattern.lastIndex += literal.length;
  }
  return { end: objectEnd + 1, entries };
}

function collectObjectMaps(source) {
  const maps = new Map();
  const constObjectPattern = /\bconst\s+([A-Za-z_$][\w$]*)\s*=\s*{/g;
  let match;
  while ((match = constObjectPattern.exec(source)) !== null) {
    const parsed = parseObjectStringMap(source, constObjectPattern.lastIndex - 1);
    if (parsed === undefined || parsed.entries.size === 0) {
      continue;
    }
    maps.set(match[1], parsed.entries);
    constObjectPattern.lastIndex = parsed.end;
  }
  return maps;
}

function collectFunctionBodies(source) {
  const bodies = [];
  const fnPattern = /\.fn\s*\(\s*t\s*=>\s*{/g;
  let match;
  while ((match = fnPattern.exec(source)) !== null) {
    const open = fnPattern.lastIndex - 1;
    const close = findMatchingBrace(source, open);
    if (close < 0) {
      continue;
    }
    bodies.push({ start: open + 1, end: close, text: source.slice(open + 1, close) });
    fnPattern.lastIndex = close + 1;
  }
  return bodies;
}

function expressionValues(expr, env) {
  expr = expr.trim();
  if (/^[`'"]/.test(expr)) {
    const literal = extractLiteralAt(expr, 0);
    if (literal === expr && !literal.includes("${")) {
      return [literalText(literal)];
    }
    if (literal === expr && literal.startsWith("`")) {
      return templateValues(literal, env);
    }
  }
  if (/^[A-Za-z_$][\w$]*$/.test(expr)) {
    return env.get(expr) ?? [];
  }
  const plusParts = splitTopLevelPlus(expr);
  if (plusParts.length > 1) {
    let values = [""];
    for (const part of plusParts) {
      const nextValues = expressionValues(part, env);
      if (nextValues.length === 0) {
        return [];
      }
      const combined = [];
      for (const left of values) {
        for (const right of nextValues) {
          combined.push(left + right);
        }
      }
      values = combined;
    }
    return values;
  }
  return [];
}

function splitTopLevelPlus(expr) {
  const parts = [];
  let start = 0;
  let quote = "";
  let depth = 0;
  for (let i = 0; i < expr.length; i += 1) {
    const ch = expr[i];
    if (quote !== "") {
      if (ch === "\\" && i + 1 < expr.length) {
        i += 1;
      } else if (ch === quote) {
        quote = "";
      }
      continue;
    }
    if (ch === "`" || ch === "'" || ch === "\"") {
      quote = ch;
    } else if (ch === "(" || ch === "[" || ch === "{") {
      depth += 1;
    } else if (ch === ")" || ch === "]" || ch === "}") {
      depth -= 1;
    } else if (ch === "+" && depth === 0) {
      parts.push(expr.slice(start, i).trim());
      start = i + 1;
    }
  }
  parts.push(expr.slice(start).trim());
  return parts;
}

function templateValues(literal, env) {
  const text = literal.slice(1, -1);
  const parts = [];
  const interpolation = /\$\{\s*([A-Za-z_$][\w$]*)\s*\}/g;
  let cursor = 0;
  let match;
  while ((match = interpolation.exec(text)) !== null) {
    const raw = text.slice(cursor, match.index);
    parts.push([raw]);
    const values = env.get(match[1]);
    if (values === undefined || values.length === 0) {
      return [];
    }
    parts.push(values);
    cursor = interpolation.lastIndex;
  }
  if (text.includes("${")) {
    return [];
  }
  parts.push([text.slice(cursor)]);
  let out = [""];
  for (const options of parts) {
    const next = [];
    for (const prefix of out) {
      for (const option of options) {
        next.push(prefix + option);
      }
    }
    out = next;
  }
  return out;
}

function collectLocalEnv(body, objectMaps) {
  const env = new Map();
  const declarationPattern = /\b(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=/g;
  let match;
  while ((match = declarationPattern.exec(body)) !== null) {
    const name = match[1];
    const statementEnd = findStatementEnd(body, declarationPattern.lastIndex);
    if (statementEnd < 0) {
      continue;
    }
    const expr = body.slice(declarationPattern.lastIndex, statementEnd).trim();
    const mapLookup = /^([A-Za-z_$][\w$]*)\s*\[\s*t\.params\.[A-Za-z_$][\w$]*\s*\](?:\.[A-Za-z_$][\w$]*)?$/.exec(
      expr,
    );
    if (mapLookup !== null && objectMaps.has(mapLookup[1])) {
      env.set(name, [...objectMaps.get(mapLookup[1]).values()]);
    } else {
      const values = expressionValues(expr, env);
      if (values.length > 0) {
        env.set(name, values);
      }
    }
    declarationPattern.lastIndex = statementEnd + 1;
  }
  return env;
}

function addCase(bucket, rel, line, wgsl) {
  wgsl = wgsl.trim();
  if (
    wgsl === "" ||
    wgsl.includes("${") ||
    !sourceLooksLikeTranslationUnit(wgsl) ||
    !hasBalancedDelimiters(wgsl)
  ) {
    return;
  }
  if (!/(^|\n)\s*(@[^\n]*\n\s*)*fn\b/.test(wgsl) && /(^|\n)\s*let\b/.test(wgsl)) {
    return;
  }
  const dedupeKey = `${rel}\0${wgsl}`;
  if (bucket.seen.has(dedupeKey)) {
    return;
  }
  bucket.seen.add(dedupeKey);
  bucket.index += 1;
  const hash = createHash("sha256").update(wgsl).digest("hex");
  const id = `${sanitizeIdPart(rel)}_${String(bucket.index).padStart(3, "0")}_${hash.slice(0, 12)}`;
  writeFileSync(path.join(bucket.outDir, `${id}.wgsl`), `${wgsl}\n`);
  bucket.manifest.push(
    `${id}\t${rel}\t${line}\t${hash}\t${Buffer.byteLength(wgsl, "utf8")}`,
  );
}

mkdirSync(validOutDir, { recursive: true });
mkdirSync(invalidOutDir, { recursive: true });
const validBucket = {
  outDir: validOutDir,
  manifest: ["# id\tcts_path\tline\tsha256\tbytes"],
  seen: new Set(),
  index: 0,
};
const invalidBucket = {
  outDir: invalidOutDir,
  manifest: ["# id\tcts_path\tline\tsha256\tbytes"],
  seen: new Set(),
  index: 0,
};

const validationRoot = path.join(ctsRoot, "src/webgpu/shader/validation");
const expectPattern = /expectCompileResult\(\s*(true|false)\s*,\s*([^),]+)\s*\)/g;

for (const file of walk(validationRoot).sort()) {
  const source = readFileSync(file, "utf8");
  const rel = path.relative(ctsRoot, file);
  const objectMaps = collectObjectMaps(source);
  if (objectMaps.size === 0) {
    continue;
  }
  for (const body of collectFunctionBodies(source)) {
    const env = collectLocalEnv(body.text, objectMaps);
    if (env.size === 0) {
      continue;
    }
    let match;
    expectPattern.lastIndex = 0;
    while ((match = expectPattern.exec(body.text)) !== null) {
      const expected = match[1] === "true";
      const expr = match[2];
      const values = expressionValues(expr, env);
      const line = lineForIndex(source, body.start + match.index);
      for (const wgsl of values) {
        addCase(expected ? validBucket : invalidBucket, rel, line, wgsl);
      }
    }
  }
}

writeFileSync(validManifestPath, `${validBucket.manifest.join("\n")}\n`);
writeFileSync(invalidManifestPath, `${invalidBucket.manifest.join("\n")}\n`);
