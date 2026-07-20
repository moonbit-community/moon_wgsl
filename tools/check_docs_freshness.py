#!/usr/bin/env python3
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"documentation freshness check failed: {message}", file=sys.stderr)
    sys.exit(1)


def non_comment_rows(path: Path) -> int:
    count = 0
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and stripped.split("\t")[0] != "id":
            count += 1
    return count


def module_version(module: str) -> str:
    path = REPO_ROOT / "modules" / module / "moon.mod"
    text = path.read_text()
    match = re.search(r'^version = "([^"]+)"$', text, re.MULTILINE)
    if not match:
      fail(f"missing version in {path.relative_to(REPO_ROOT)}")
    return match.group(1)


def manifest_version(path: Path) -> str:
    text = path.read_text()
    match = re.search(r'^version = "([^"]+)"$', text, re.MULTILINE)
    if not match:
        fail(f"missing version in {path.relative_to(REPO_ROOT)}")
    return match.group(1)


def manifest_dependency_version(path: Path, package: str) -> str:
    text = path.read_text()
    match = re.search(rf'"{re.escape(package)}@([^"]+)"', text)
    if not match:
        fail(f"missing dependency {package} in {path.relative_to(REPO_ROOT)}")
    return match.group(1)


def check_tools_manifest_freshness(release: str) -> None:
    path = REPO_ROOT / "tools" / "moon.mod"
    version = manifest_version(path)
    if version != release:
        fail(f"tools/moon.mod version is stale: expected {release}, found {version}")
    for package in ["Milky2018/wgsl", "Milky2018/moon_wgsl_naga_oil"]:
        dep_version = manifest_dependency_version(path, package)
        if dep_version != release:
            fail(f"tools/moon.mod dependency {package} is stale: expected {release}, found {dep_version}")


def check_naga_oil_parity_doc() -> None:
    docs = (REPO_ROOT / "docs" / "naga_oil-parity.md").read_text()
    release = module_version("moon_wgsl")
    for module in ["wgsl", "moon_wgsl_naga", "moon_wgsl_naga_oil"]:
        other = module_version(module)
        if other != release:
            fail(f"workspace module versions are not synchronized: moon_wgsl={release}, {module}={other}")
    check_tools_manifest_freshness(release)
    if f"workspace release line is `{release}`" not in docs:
        fail(f"docs/naga_oil-parity.md does not record current release {release}")
    if f"current `main` (workspace line `{release}`)" not in docs:
        fail(f"docs/naga_oil-parity.md downstream verification still references a stale release")

    cases = non_comment_rows(REPO_ROOT / "testdata" / "external_naga_oil_compose_parity.tsv")
    oracle_blocked = non_comment_rows(
        REPO_ROOT / "testdata" / "external_naga_oil_compose_oracle_blocked.tsv"
    )
    comparable = cases - oracle_blocked
    trace_cases = non_comment_rows(REPO_ROOT / "testdata" / "naga_writer_trace_cases.tsv")
    expected_fragments = [
        f"`cases={cases}`",
        f"`comparable={comparable}`",
        f"`oracle-blocked={oracle_blocked}`",
        f"`writer-exact={comparable}`",
        f"`byte-exact={comparable}`",
        f"passes {trace_cases} cases",
    ]
    for fragment in expected_fragments:
        if fragment not in docs:
            fail(f"docs/naga_oil-parity.md is missing current parity fragment: {fragment}")


def main() -> None:
    check_naga_oil_parity_doc()
    print("documentation freshness checks passed")


if __name__ == "__main__":
    main()
