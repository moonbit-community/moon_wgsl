#!/usr/bin/env python3
"""Generate JSONL golden output with the pinned wesl 0.3.2 reference runner."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / "Cargo.toml"
RUNNER = ROOT / "target" / "debug" / "wesl-ref-runner"


def run_json(request: dict[str, object]) -> dict[str, object]:
    proc = subprocess.run(
        [str(RUNNER)],
        input=json.dumps(request, separators=(",", ":")),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        return {
            "status": "err",
            "stage": "runner",
            "message": proc.stderr.strip(),
        }
    return json.loads(proc.stdout)


def load_cases(path: Path) -> list[dict[str, object]]:
    cases: list[dict[str, object]] = []
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if stripped == "" or stripped.startswith("#"):
            continue
        case = json.loads(stripped)
        if "case" not in case:
            case["case"] = f"{path.stem}:{line_no}"
        cases.append(case)
    return cases


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "corpus",
        nargs="?",
        type=Path,
        default=ROOT / "corpus" / "smoke.jsonl",
        help="JSONL request corpus",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="output JSONL path",
    )
    args = parser.parse_args()

    corpus = args.corpus.resolve()
    out = args.out
    if out is None:
      out = ROOT / "golden" / f"{corpus.stem}.wesl-0.3.2.jsonl"
    out = out.resolve()

    subprocess.run(
        ["cargo", "build", "--manifest-path", str(MANIFEST)],
        check=True,
    )
    out.parent.mkdir(parents=True, exist_ok=True)

    with out.open("w", encoding="utf-8") as handle:
        for case in load_cases(corpus):
            request = dict(case)
            name = str(request.pop("case"))
            response = run_json(request)
            record = {
                "case": name,
                "request": request,
                "response": response,
            }
            handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True))
            handle.write("\n")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
