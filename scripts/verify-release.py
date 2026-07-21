#!/usr/bin/env python3
"""Validate release artifacts and optionally list the files to publish."""

from __future__ import annotations

import hashlib
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse
from xml.etree import ElementTree as ET


GROUPS = ("modules", "components", "templates")


@dataclass(frozen=True)
class Artifact:
    extension: str
    group: str
    version: str
    package: Path
    checksum: Path
    update: Path
    manifest_name: str


def fail(message: str) -> None:
    raise SystemExit(f"Error: {message}")


def manifest_for(group: str, directory: Path) -> Path:
    return directory / ("templateDetails.xml" if group == "templates" else f"{directory.name}.xml")


def discover(selected: str) -> list[Artifact]:
    artifacts: list[Artifact] = []
    for group in GROUPS:
        base = Path("repos") / group
        if not base.exists():
            continue
        for directory in sorted(path for path in base.iterdir() if path.is_dir()):
            if selected and directory.name != selected:
                continue
            manifest = manifest_for(group, directory)
            if not manifest.is_file():
                fail(f"manifest not found: {manifest}")
            try:
                root = ET.parse(manifest).getroot()
            except ET.ParseError as error:
                fail(f"invalid source manifest {manifest}: {error}")
            version = (root.findtext("version") or "").strip()
            if not version:
                fail(f"missing <version> in {manifest}")
            server = root.find("./updateservers/server")
            if server is None or not (server.text or "").strip():
                fail(f"missing Update Server in {manifest}")
            package = Path("build/releases/packages") / group / f"{directory.name}_{version}.zip"
            artifacts.append(Artifact(
                directory.name,
                group,
                version,
                package,
                package.with_suffix(".zip.sha256"),
                Path("build/releases/updates") / f"{directory.name}.xml",
                manifest.name,
            ))
    if not artifacts:
        fail(f"extension not found: {selected}" if selected else "no extensions found")
    return artifacts


def verify(artifact: Artifact) -> None:
    for path in (artifact.package, artifact.checksum, artifact.update):
        if not path.is_file():
            fail(f"artifact not found: {path}; run the build first")

    digest = hashlib.sha256(artifact.package.read_bytes()).hexdigest()
    recorded = artifact.checksum.read_text(encoding="utf-8").split(maxsplit=1)[0]
    if recorded != digest:
        fail(f"checksum mismatch: {artifact.package}")

    try:
        update = ET.parse(artifact.update).getroot().find("update")
    except ET.ParseError as error:
        fail(f"invalid update manifest {artifact.update}: {error}")
    if update is None:
        fail(f"missing <update> in {artifact.update}")
    if (update.findtext("version") or "").strip() != artifact.version:
        fail(f"version mismatch in {artifact.update}")
    if (update.findtext("sha256") or "").strip() != digest:
        fail(f"SHA-256 mismatch in {artifact.update}")
    download_url = (update.findtext("./downloads/downloadurl") or "").strip()
    expected_suffix = f"/packages/{artifact.group}/{artifact.package.name}"
    if not urlparse(download_url).scheme or not download_url.endswith(expected_suffix):
        fail(f"invalid download URL in {artifact.update}: {download_url}")
    if urlparse(download_url).hostname == "example.com":
        fail(f"placeholder download URL in {artifact.update}: {download_url}")

    base_url = download_url.removesuffix(expected_suffix)
    expected_update_url = f"{base_url}/updates/{artifact.extension}.xml"

    try:
        with zipfile.ZipFile(artifact.package) as archive:
            bad_file = archive.testzip()
            if bad_file:
                fail(f"corrupt file {bad_file} in {artifact.package}")
            try:
                packaged_manifest = ET.fromstring(archive.read(artifact.manifest_name))
            except KeyError:
                fail(f"manifest not found in {artifact.package}: {artifact.manifest_name}")
            except ET.ParseError as error:
                fail(f"invalid packaged manifest in {artifact.package}: {error}")
            server_url = (packaged_manifest.findtext("./updateservers/server") or "").strip()
            if server_url != expected_update_url:
                fail(
                    f"Update Server mismatch in {artifact.package}: "
                    f"expected {expected_update_url}, found {server_url or '<empty>'}"
                )
    except zipfile.BadZipFile:
        fail(f"invalid ZIP: {artifact.package}")


def main() -> None:
    list_mode = "--list" in sys.argv[1:]
    args = [arg for arg in sys.argv[1:] if arg != "--list"]
    if len(args) > 1:
        fail("usage: verify-release.py [--list] [extension]")
    selected = args[0] if args else ""
    artifacts = discover(selected)
    for artifact in artifacts:
        verify(artifact)

    if list_mode:
        # Packages/checksums are listed first. Update XML files must be uploaded last.
        for artifact in artifacts:
            print(f"immutable\t{artifact.package}\tpackages/{artifact.group}/{artifact.package.name}")
            print(f"immutable\t{artifact.checksum}\tpackages/{artifact.group}/{artifact.checksum.name}")
        for artifact in artifacts:
            print(f"metadata\t{artifact.update}\tupdates/{artifact.update.name}")
    else:
        names = ", ".join(artifact.extension for artifact in artifacts)
        print(f"Verified {len(artifacts)} extension(s): {names}")


if __name__ == "__main__":
    main()
