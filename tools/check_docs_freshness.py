#!/usr/bin/env python3
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"documentation freshness check failed: {message}", file=sys.stderr)
    sys.exit(1)


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


def check_release_metadata() -> None:
    release = module_version("moon_wgsl")
    for module in ["wgsl", "moon_wgsl_naga", "moon_wgsl_naga_oil"]:
        other = module_version(module)
        if other != release:
            fail(f"workspace module versions are not synchronized: moon_wgsl={release}, {module}={other}")
    check_tools_manifest_freshness(release)

    wesl_version = module_version("moon_wesl")
    wesl_dependency = manifest_dependency_version(
        REPO_ROOT / "tools" / "moon.mod", "Milky2018/moon_wesl"
    )
    if wesl_dependency != wesl_version:
        fail(
            "tools/moon.mod dependency Milky2018/moon_wesl is stale: "
            f"expected {wesl_version}, found {wesl_dependency}"
        )


def main() -> None:
    check_release_metadata()
    print("documentation freshness checks passed")


if __name__ == "__main__":
    main()
