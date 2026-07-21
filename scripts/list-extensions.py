#!/usr/bin/env python3
"""Print the extension sources used by the release build."""

from __future__ import annotations

import subprocess
from pathlib import Path
from xml.etree import ElementTree as ET


GROUPS = {
    "modules": "Module",
    "components": "Component",
    "templates": "Template",
}


def manifest_for(group: str, directory: Path) -> Path:
    name = "templateDetails.xml" if group == "templates" else f"{directory.name}.xml"
    return directory / name


def revision(directory: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(directory), "rev-parse", "--short", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else "-"


def main() -> None:
    rows: list[tuple[str, str, str, str]] = []
    for group, type_name in GROUPS.items():
        base = Path("repos") / group
        if not base.is_dir():
            continue
        for directory in sorted(path for path in base.iterdir() if path.is_dir()):
            manifest = manifest_for(group, directory)
            try:
                version = (ET.parse(manifest).getroot().findtext("version") or "-").strip()
            except (FileNotFoundError, ET.ParseError):
                version = "INVALID"
            rows.append((type_name, directory.name, version, revision(directory)))

    headers = ("TYPE", "EXTENSION", "VERSION", "REVISION")
    widths = [
        max(len(headers[index]), *(len(row[index]) for row in rows))
        for index in range(len(headers))
    ]

    def print_row(row: tuple[str, ...]) -> None:
        print("  ".join(value.ljust(widths[index]) for index, value in enumerate(row)).rstrip())

    print_row(headers)
    print_row(tuple("-" * width for width in widths))
    for row in rows:
        print_row(row)
    print(f"\n{len(rows)} extension(s)")


if __name__ == "__main__":
    main()
