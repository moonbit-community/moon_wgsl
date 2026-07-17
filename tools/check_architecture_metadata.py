#!/usr/bin/env python3
import json
import hashlib
import os
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = REPO_ROOT / "testdata" / "architecture_guardrails_manifest.json"


def fail(message: str) -> None:
    print(f"architecture metadata check failed: {message}", file=sys.stderr)
    sys.exit(1)


def issue_status(issue_id: str) -> str:
    path = REPO_ROOT / "issues" / f"{issue_id}.md"
    if not path.exists():
        fail(f"migration exception references missing issue: {issue_id}")
    match = re.search(r"^- Status: ([a-z_]+)$", path.read_text(), re.MULTILINE)
    if not match:
        fail(f"cannot read status for migration issue: {issue_id}")
    return match.group(1)


def require_unresolved_exception(issue_id: str, description: str) -> None:
    status = issue_status(issue_id)
    if status in {"closed", "deferred"}:
        fail(
            f"{description} is still excepted by {issue_id}, "
            f"but that issue is {status}"
        )


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


def package_paths(module_root: Path) -> set[str]:
    paths: set[str] = set()
    for path in module_root.glob("**/moon.pkg"):
        relative = path.parent.relative_to(module_root)
        paths.add("." if str(relative) == "." else str(relative))
    return paths


def check_module_packages(manifest: dict) -> None:
    for relative, policy in manifest.get("module_packages", {}).items():
        module_root = REPO_ROOT / relative
        if not module_root.exists():
            fail(f"module package root missing: {relative}")
        actual = package_paths(module_root)
        allowed = set(policy.get("allowed", []))
        internal = set(policy.get("internal", []))
        exceptions = policy.get("exceptions", {})
        unexpected = sorted(actual - allowed - internal - set(exceptions))
        if unexpected:
            fail(
                f"{relative} has package(s) outside its public inventory: "
                + ", ".join(unexpected)
            )
        missing_public = sorted(allowed - actual)
        if missing_public:
            fail(
                f"{relative} is missing public package(s): "
                + ", ".join(missing_public)
            )
        missing_internal = sorted(internal - actual)
        if missing_internal:
            fail(
                f"{relative} is missing internal package(s): "
                + ", ".join(missing_internal)
            )
        invalid_internal = sorted(
            package for package in internal if not package.startswith("internal/")
        )
        if invalid_internal:
            fail(
                f"{relative} internal inventory must use internal/ paths: "
                + ", ".join(invalid_internal)
            )
        for package, issue_id in exceptions.items():
            if package not in actual:
                fail(
                    f"{relative}/{package} migration exception is stale; "
                    f"remove the {issue_id} exception"
                )
            require_unresolved_exception(
                issue_id,
                f"{relative}/{package} public package",
            )


def check_internal_package_imports(manifest: dict) -> None:
    package_files = sorted(
        list((REPO_ROOT / "modules").glob("**/moon.pkg"))
        + list((REPO_ROOT / "tools").glob("**/moon.pkg"))
    )
    for policy in manifest.get("internal_package_roots", []):
        owner_root = (REPO_ROOT / policy["module"]).resolve()
        import_prefix = policy["import_prefix"]
        for path in package_files:
            imports = parse_moon_pkg_imports(path)
            if not any(item.startswith(import_prefix) for item in imports):
                continue
            resolved = path.resolve()
            if resolved == owner_root / "moon.pkg" or owner_root in resolved.parents:
                continue
            fail(
                f"{path.relative_to(REPO_ROOT)} imports implementation package "
                f"under {import_prefix}"
            )


def policy_files(policy: dict) -> list[Path]:
    files: set[Path] = set()
    globs = policy.get("globs", ["*.mbt", "*.mbti", "moon.pkg"])
    excludes = policy.get("exclude", [])
    for relative in policy["paths"]:
        root = REPO_ROOT / relative
        if not root.exists():
            fail(f"concept ownership path missing: {relative}")
        candidates = [root] if root.is_file() else [
            path
            for glob in globs
            for path in root.glob(f"**/{glob}")
        ]
        for path in candidates:
            rel = str(path.relative_to(REPO_ROOT))
            if any(path.match(pattern) or Path(rel).match(pattern) for pattern in excludes):
                continue
            files.add(path)
    return sorted(files)


def check_concept_ownership(manifest: dict) -> None:
    for policy in manifest.get("concept_ownership", []):
        pattern = re.compile(policy["forbidden"])
        matches: list[str] = []
        for path in policy_files(policy):
            text = path.read_text()
            match = pattern.search(text)
            if match:
                matches.append(
                    f"{path.relative_to(REPO_ROOT)}:{match.group(0)}"
                )
        issue_id = policy.get("exception_issue")
        if matches:
            if not issue_id:
                fail(
                    f"{policy['name']} violates conceptual ownership: "
                    + ", ".join(matches[:8])
                )
            require_unresolved_exception(issue_id, policy["name"])
        elif issue_id:
            fail(
                f"{policy['name']} migration exception is stale; "
                f"remove the {issue_id} exception"
            )


def parse_interface_imports(text: str) -> dict[str, str]:
    aliases: dict[str, str] = {}
    in_import_block = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped == "import {":
            in_import_block = True
            continue
        if in_import_block and stripped.startswith("}"):
            break
        if not in_import_block:
            continue
        match = re.fullmatch(r'"([^"]+)",?', stripped)
        if match:
            package = match.group(1)
            aliases[package.rsplit("/", 1)[-1]] = package
    return aliases


def package_interface_index() -> dict[str, Path]:
    index: dict[str, Path] = {}
    for path in (REPO_ROOT / "modules").glob("**/pkg.generated.mbti"):
        match = re.search(r'^package "([^"]+)"$', path.read_text(), re.MULTILINE)
        if match:
            index[match.group(1)] = path
    return index


def exported_type_methods(
    interface_path: Path,
    type_name: str,
    interfaces: dict[str, Path],
) -> set[str]:
    text = interface_path.read_text()
    methods = set(
        re.findall(
            rf"^pub fn {re.escape(type_name)}::([A-Za-z0-9_]+)\(",
            text,
            re.MULTILINE,
        )
    )
    if methods:
        return methods
    using = re.search(
        rf"^pub using @([A-Za-z0-9_]+) \{{type {re.escape(type_name)}\}}$",
        text,
        re.MULTILINE,
    )
    if not using:
        return set()
    alias = using.group(1)
    package = parse_interface_imports(text).get(alias)
    if not package or package not in interfaces:
        fail(
            f"cannot resolve re-exported type {type_name} from "
            f"{interface_path.relative_to(REPO_ROOT)}"
        )
    return exported_type_methods(interfaces[package], type_name, interfaces)


def check_exported_type_methods(manifest: dict) -> None:
    interfaces = package_interface_index()
    for policy in manifest.get("exported_type_methods", []):
        relative = policy["interface"]
        path = REPO_ROOT / relative
        if not path.exists():
            fail(f"type interface file missing: {relative}")
        actual = exported_type_methods(path, policy["type"], interfaces)
        expected = set(policy["allowed"])
        issue_id = policy.get("exception_issue")
        if actual != expected:
            details = []
            extra = sorted(actual - expected)
            missing = sorted(expected - actual)
            if extra:
                details.append("extra methods: " + ", ".join(extra))
            if missing:
                details.append("missing methods: " + ", ".join(missing))
            if not issue_id:
                fail(
                    f"{relative} {policy['type']} method inventory changed; "
                    + "; ".join(details)
                )
            require_unresolved_exception(
                issue_id,
                f"{relative} {policy['type']} method inventory",
            )
        elif issue_id:
            fail(
                f"{relative} {policy['type']} method exception is stale; "
                f"remove the {issue_id} exception"
            )


def check_source_symlinks(manifest: dict) -> None:
    configured: set[Path] = set()
    for entry in manifest.get("source_symlink_exceptions", []):
        relative = entry["path"]
        target = entry["target"]
        issue_id = entry["issue"]
        path = REPO_ROOT / relative
        configured.add(path)
        if not path.is_symlink():
            fail(
                f"{relative} source symlink exception is stale; "
                f"remove the {issue_id} exception"
            )
        actual = os.readlink(path)
        if actual != target:
            fail(f"{relative} must target {target}, found {actual}")
        require_unresolved_exception(issue_id, f"{relative} source symlink")
    if manifest.get("forbid_unlisted_source_symlinks", False):
        unlisted = sorted(
            str(path.relative_to(REPO_ROOT))
            for path in (REPO_ROOT / "modules").glob("**/*")
            if path.is_symlink() and path not in configured
        )
        if unlisted:
            fail("unlisted source symlink(s): " + ", ".join(unlisted))


def check_source_owners(manifest: dict) -> None:
    for policy in manifest.get("source_owners", []):
        owner_relative = policy["owner"]
        owner = REPO_ROOT / owner_relative
        if not owner.is_file() or owner.is_symlink():
            fail(
                f"{policy['concept']} owner must be one regular source file: "
                f"{owner_relative}"
            )
        for retired_relative in policy.get("retired_paths", []):
            retired = REPO_ROOT / retired_relative
            if retired.exists() or retired.is_symlink():
                fail(
                    f"{policy['concept']} retired duplicate path still exists: "
                    f"{retired_relative}"
                )
        owner_digest = hashlib.sha256(owner.read_bytes()).digest()
        duplicates: list[str] = []
        for scan_relative in policy.get("copy_scan_paths", []):
            scan_root = REPO_ROOT / scan_relative
            if not scan_root.exists():
                fail(f"source ownership scan path missing: {scan_relative}")
            for candidate in scan_root.glob("**/*.mbt"):
                if candidate.resolve() == owner.resolve():
                    continue
                if hashlib.sha256(candidate.read_bytes()).digest() == owner_digest:
                    duplicates.append(str(candidate.relative_to(REPO_ROOT)))
        if duplicates:
            fail(
                f"{policy['concept']} has copied implementation source: "
                + ", ".join(sorted(duplicates))
            )


def main() -> None:
    if not MANIFEST.exists():
        fail(f"missing manifest: {MANIFEST.relative_to(REPO_ROOT)}")
    manifest = json.loads(MANIFEST.read_text())
    check_package_imports(manifest)
    check_public_api(manifest)
    check_module_packages(manifest)
    check_internal_package_imports(manifest)
    check_concept_ownership(manifest)
    check_exported_type_methods(manifest)
    check_source_owners(manifest)
    check_source_symlinks(manifest)
    print("architecture metadata checks passed")


if __name__ == "__main__":
    main()
