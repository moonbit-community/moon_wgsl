#!/usr/bin/env python3
import json
import os
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = REPO_ROOT / "testdata" / "architecture_guardrails_manifest.json"


def fail(message: str) -> None:
    print(f"architecture metadata check failed: {message}", file=sys.stderr)
    sys.exit(1)


def parse_moon_pkg_imports(path: Path) -> list[str]:
    imports: set[str] = set()
    in_import_block = False
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if stripped == "import {":
            in_import_block = True
            continue
        if in_import_block and stripped.startswith("}"):
            in_import_block = False
            continue
        if not in_import_block:
            continue
        match = re.fullmatch(r'"([^"]+)",?', stripped)
        if match:
            imports.add(match.group(1))
    return sorted(imports)


def check_package_imports(manifest: dict) -> None:
    expected_packages = {
        (REPO_ROOT / package).resolve(): sorted(imports)
        for package, imports in manifest["package_imports"].items()
    }
    actual_packages = {
        path.resolve()
        for path in (REPO_ROOT / "modules").glob("**/moon.pkg")
    }
    missing = sorted(
        str(path.relative_to(REPO_ROOT)) for path in expected_packages if path not in actual_packages
    )
    if missing:
        fail("manifest references missing moon.pkg file(s): " + ", ".join(missing))
    extra = sorted(
        str(path.relative_to(REPO_ROOT)) for path in actual_packages if path not in expected_packages
    )
    if extra:
        fail("moon.pkg file(s) missing from dependency manifest: " + ", ".join(extra))
    for path, expected_imports in expected_packages.items():
        actual_imports = parse_moon_pkg_imports(path)
        if actual_imports != expected_imports:
            rel = path.relative_to(REPO_ROOT)
            missing_imports = sorted(set(expected_imports) - set(actual_imports))
            extra_imports = sorted(set(actual_imports) - set(expected_imports))
            details = []
            if missing_imports:
                details.append("missing imports: " + ", ".join(missing_imports))
            if extra_imports:
                details.append("unexpected imports: " + ", ".join(extra_imports))
            fail(f"{rel} dependency boundary changed; " + "; ".join(details))


def check_public_api(manifest: dict) -> None:
    for relative, policy in manifest["public_api"].items():
        path = REPO_ROOT / relative
        if not path.exists():
            fail(f"public API file missing: {relative}")
        text = path.read_text()
        for pattern in policy.get("required", []):
            if not re.search(pattern, text):
                fail(f"{relative} is missing required public API pattern: {pattern}")
        for pattern in policy.get("forbidden", []):
            match = re.search(pattern, text)
            if match:
                fail(f"{relative} exposes forbidden public API: {match.group(0)}")


def check_symlinks(manifest: dict) -> None:
    for relative, target in manifest["symlinks"].items():
        path = REPO_ROOT / relative
        if not path.is_symlink():
            fail(f"{relative} must be a symlink")
        actual = os.readlink(path)
        if actual != target:
            fail(f"{relative} must target {target}, found {actual}")


def main() -> None:
    if not MANIFEST.exists():
        fail(f"missing manifest: {MANIFEST.relative_to(REPO_ROOT)}")
    manifest = json.loads(MANIFEST.read_text())
    check_package_imports(manifest)
    check_public_api(manifest)
    check_symlinks(manifest)
    print("architecture metadata checks passed")


if __name__ == "__main__":
    main()
