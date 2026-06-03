#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

function usage() {
  console.error(
    "usage: node tools/wgsl_byte_fragment_trace.mjs --expected FILE --actual FILE --label LABEL --out-dir DIR",
  );
  process.exit(2);
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith("--")) usage();
    if (i + 1 >= argv.length) usage();
    parsed[key.slice(2)] = argv[i + 1];
    i += 1;
  }
  for (const required of ["expected", "actual", "label", "out-dir"]) {
    if (!parsed[required]) usage();
  }
  return parsed;
}

function isAlpha(code) {
  return (
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122) ||
    code === 95
  );
}

function isDigit(code) {
  return code >= 48 && code <= 57;
}

function isIdentifierPart(code) {
  return isAlpha(code) || isDigit(code);
}

function encodeText(text) {
  return text
    .replace(/\\/g, "\\\\")
    .replace(/\t/g, "\\t")
    .replace(/\r/g, "\\r")
    .replace(/\n/g, "\\n");
}

function tokenClass(kind, text) {
  if (kind === "identifier") {
    return WGSL_KEYWORDS.has(text) ? "keyword" : "identifier";
  }
  if (kind === "number") {
    if (/[.eEfFhH]/.test(text)) return "float-literal";
    if (/[uU]$/.test(text)) return "uint-literal";
    if (/[iI]$/.test(text)) return "int-literal";
    return "abstract-int-literal";
  }
  return kind;
}

function policySource(kind, cls) {
  if (kind === "whitespace") return "whitespace:naga-wgsl-writer";
  if (kind === "comment") return "comment:source-preserved";
  if (cls.endsWith("-literal")) return `literal:${cls}`;
  if (cls === "keyword") return "token:wgsl-keyword";
  if (cls === "identifier") return "token:generated-or-source-name";
  return `token:${cls}`;
}

function updateOwnerOnToken(state, fragment) {
  if (fragment.kind !== "identifier") return;
  const text = fragment.text;
  if (state.pendingDeclarationKeyword) {
    state.owner = `${state.pendingDeclarationKeyword}:${text}`;
    state.pendingDeclarationKeyword = "";
    return;
  }
  if (
    state.braceDepth === 0 &&
    ["struct", "fn", "const", "override", "alias"].includes(text)
  ) {
    state.pendingDeclarationKeyword = text;
    return;
  }
  if (state.braceDepth === 0 && text === "var") {
    state.pendingDeclarationKeyword = "var";
  }
}

function scan(text) {
  const fragments = [];
  const state = {
    owner: "module",
    pendingDeclarationKeyword: "",
    braceDepth: 0,
    parenDepth: 0,
    line: 1,
    column: 1,
  };
  let i = 0;
  while (i < text.length) {
    const start = i;
    const line = state.line;
    const column = state.column;
    const code = text.charCodeAt(i);
    let kind = "punctuation";
    if (code === 10 || code === 13 || code === 9 || code === 32) {
      kind = "whitespace";
      while (i < text.length) {
        const c = text.charCodeAt(i);
        if (c !== 10 && c !== 13 && c !== 9 && c !== 32) break;
        advancePosition(state, text[i]);
        i += 1;
      }
    } else if (text.startsWith("//", i)) {
      kind = "comment";
      while (i < text.length && text[i] !== "\n") {
        advancePosition(state, text[i]);
        i += 1;
      }
    } else if (text.startsWith("/*", i)) {
      kind = "comment";
      i += consumeChar(state, text[i]);
      i += consumeChar(state, text[i]);
      while (i < text.length && !text.startsWith("*/", i)) {
        i += consumeChar(state, text[i]);
      }
      if (i < text.length) {
        i += consumeChar(state, text[i]);
        i += consumeChar(state, text[i]);
      }
    } else if (isAlpha(code)) {
      kind = "identifier";
      while (i < text.length && isIdentifierPart(text.charCodeAt(i))) {
        advancePosition(state, text[i]);
        i += 1;
      }
    } else if (isDigit(code)) {
      kind = "number";
      while (i < text.length && /[A-Za-z0-9_.+-]/.test(text[i])) {
        const current = text[i];
        const next = text[i + 1] ?? "";
        if ((current === "+" || current === "-") && !/[eEpP]$/.test(text.slice(start, i))) {
          break;
        }
        if (current === "." && next === ".") break;
        advancePosition(state, current);
        i += 1;
      }
    } else {
      const two = text.slice(i, i + 2);
      const three = text.slice(i, i + 3);
      const width = WGSL_PUNCTUATION3.has(three)
        ? 3
        : WGSL_PUNCTUATION2.has(two)
          ? 2
          : 1;
      for (let n = 0; n < width; n += 1) {
        advancePosition(state, text[i + n]);
      }
      i += width;
    }
    const tokenText = text.slice(start, i);
    const cls = tokenClass(kind, tokenText);
    const fragment = {
      index: fragments.length,
      start,
      end: i,
      line,
      column,
      owner: state.owner,
      blockDepth: state.braceDepth,
      parenDepth: state.parenDepth,
      kind,
      class: cls,
      policy: policySource(kind, cls),
      text: tokenText,
    };
    updateOwnerOnToken(state, fragment);
    if (kind === "punctuation") {
      for (const ch of tokenText) {
        if (ch === "{") state.braceDepth += 1;
        if (ch === "}") state.braceDepth = Math.max(0, state.braceDepth - 1);
        if (ch === "(") state.parenDepth += 1;
        if (ch === ")") state.parenDepth = Math.max(0, state.parenDepth - 1);
      }
      if (state.braceDepth === 0 && tokenText === "}") {
        state.owner = "module";
      }
    }
    fragments.push(fragment);
  }
  return fragments;
}

function consumeChar(state, ch) {
  advancePosition(state, ch);
  return 1;
}

function advancePosition(state, ch) {
  if (ch === "\n") {
    state.line += 1;
    state.column = 1;
  } else {
    state.column += 1;
  }
}

function writeTrace(file, label, side, fragments) {
  const lines = [
    "label\tside\tindex\tbyte_start\tbyte_end\tline\tcolumn\towner\tblock_depth\tparen_depth\tkind\tclass\tpolicy\ttext",
  ];
  for (const item of fragments) {
    lines.push(
      [
        label,
        side,
        item.index,
        item.start,
        item.end,
        item.line,
        item.column,
        item.owner,
        item.blockDepth,
        item.parenDepth,
        item.kind,
        item.class,
        item.policy,
        encodeText(item.text),
      ].join("\t"),
    );
  }
  writeFileSync(file, `${lines.join("\n")}\n`);
}

function comparable(item) {
  if (!item) return "<missing>";
  return `${item.kind}\t${item.class}\t${item.owner}\t${encodeText(item.text)}`;
}

function findFirstDrift(expected, actual) {
  const limit = Math.max(expected.length, actual.length);
  for (let i = 0; i < limit; i += 1) {
    if (comparable(expected[i]) !== comparable(actual[i])) {
      return i;
    }
  }
  return -1;
}

function reportLine(item) {
  if (!item) return "<missing>";
  return [
    `index=${item.index}`,
    `byte=${item.start}..${item.end}`,
    `line=${item.line}`,
    `column=${item.column}`,
    `owner=${item.owner}`,
    `depth=${item.blockDepth}`,
    `kind=${item.kind}`,
    `class=${item.class}`,
    `policy=${item.policy}`,
    `text=${encodeText(item.text)}`,
  ].join("\t");
}

function writeReport(file, label, expected, actual) {
  const first = findFirstDrift(expected, actual);
  const lines = [`label\t${label}`, `first_drift_index\t${first}`];
  if (first >= 0) {
    lines.push(`expected\t${reportLine(expected[first])}`);
    lines.push(`actual\t${reportLine(actual[first])}`);
    const start = Math.max(0, first - 5);
    const end = Math.min(Math.max(expected.length, actual.length), first + 6);
    lines.push("context_side\tcontext");
    for (let i = start; i < end; i += 1) {
      lines.push(`expected\t${reportLine(expected[i])}`);
      lines.push(`actual\t${reportLine(actual[i])}`);
    }
  }
  writeFileSync(file, `${lines.join("\n")}\n`);
}

const WGSL_KEYWORDS = new Set([
  "alias",
  "break",
  "case",
  "const",
  "const_assert",
  "continue",
  "continuing",
  "default",
  "diagnostic",
  "discard",
  "else",
  "enable",
  "false",
  "fn",
  "for",
  "if",
  "let",
  "loop",
  "override",
  "requires",
  "return",
  "struct",
  "switch",
  "true",
  "var",
  "while",
]);

const WGSL_PUNCTUATION2 = new Set([
  "->",
  "==",
  "!=",
  "<=",
  ">=",
  "&&",
  "||",
  "+=",
  "-=",
  "*=",
  "/=",
  "%=",
  "&=",
  "|=",
  "^=",
  "<<",
  ">>",
  "++",
  "--",
]);

const WGSL_PUNCTUATION3 = new Set(["<<=", ">>="]);

const args = parseArgs(process.argv.slice(2));
const outDir = args["out-dir"];
mkdirSync(outDir, { recursive: true });
const expected = scan(readFileSync(args.expected, "utf8"));
const actual = scan(readFileSync(args.actual, "utf8"));
const base = path.join(outDir, `${args.label}.byte`);
writeTrace(`${base}.expected.tsv`, args.label, "expected", expected);
writeTrace(`${base}.actual.tsv`, args.label, "actual", actual);
writeReport(`${base}.first-drift.txt`, args.label, expected, actual);
