#!/usr/bin/env python3
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(os.environ.get("SRCROOT", ".")).resolve()
SCAN_DIRS = [
    ROOT / "HoAh",
    ROOT / "HoAhTests",
]
IGNORE_DIRS = {"build", "DerivedData", ".git", ".swiftpm"}
ALLOWED_USERDEFAULTS_FILE = ROOT / "HoAh" / "Services" / "UserDefaultsManager.swift"

USERDEFAULTS_PATTERN = re.compile(r"\bUserDefaults\s*\(")
APPSTORAGE_PATTERN = re.compile(r"@AppStorage\s*\(([^)]*)\)", re.DOTALL)


def is_ignored(path: pathlib.Path) -> bool:
    return any(part in IGNORE_DIRS for part in path.parts)


def read_text(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def main() -> int:
    violations: list[str] = []

    for base_dir in SCAN_DIRS:
        if not base_dir.exists():
            continue
        for path in base_dir.rglob("*.swift"):
            if is_ignored(path):
                continue
            if path == ALLOWED_USERDEFAULTS_FILE:
                continue

            text = read_text(path)
            if not text:
                continue

            lines = text.splitlines()

            for index, line in enumerate(lines, start=1):
                stripped = line.lstrip()
                if stripped.startswith("//"):
                    continue
                prev_line = lines[index - 2] if index >= 2 else ""
                allow_standard = (
                    "validate-defaults: allow-standard" in line
                    or "validate-defaults: allow-standard" in prev_line
                )
                if "UserDefaults.standard" in line:
                    if allow_standard:
                        continue
                    violations.append(
                        f"{path}:{index}: Use UserDefaults.hoah/AppSettingsStore instead of UserDefaults.standard.\n"
                        f"    {line.strip()}"
                    )
                elif USERDEFAULTS_PATTERN.search(line):
                    violations.append(
                        f"{path}:{index}: Direct UserDefaults(...) init is forbidden; use UserDefaults.hoah or AppSettingsStore.\n"
                        f"    {line.strip()}"
                    )

            for match in APPSTORAGE_PATTERN.finditer(text):
                args = match.group(1)
                line_no = text.count("\n", 0, match.start()) + 1
                line_text = lines[line_no - 1] if 0 <= line_no - 1 < len(lines) else "@AppStorage"

                if "store:" not in args:
                    violations.append(
                        f"{path}:{line_no}: @AppStorage must specify store: .hoah.\n"
                        f"    {line_text.strip()}"
                    )
                elif re.search(r"store\s*:\s*\.hoah", args) is None:
                    violations.append(
                        f"{path}:{line_no}: @AppStorage must use store: .hoah.\n"
                        f"    {line_text.strip()}"
                    )

    if violations:
        print("error: Forbidden UserDefaults/@AppStorage usage detected:", file=sys.stderr)
        for item in violations:
            print(f"error: {item}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
