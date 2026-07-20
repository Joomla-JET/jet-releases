#!/usr/bin/env python3
"""Build a Joomla extension package and its update-server metadata."""

from __future__ import annotations

import hashlib
import os
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


EXCLUDED_NAMES = {
    ".git", ".gitignore", ".idea", ".DS_Store", "node_modules",
    "vendor", "test", "tests", "__pycache__",
}
EXCLUDED_SUFFIXES = {".log", ".md"}
TYPE_NAMES = {"modules": "module", "components": "component", "templates": "template"}


def fail(message: str) -> None:
    raise SystemExit(f"Error: {message}")


def child_text(root: ET.Element, name: str, default: str = "") -> str:
    node = root.find(name)
    return (node.text or "").strip() if node is not None else default


def indent_xml(root: ET.Element) -> bytes:
    ET.indent(root, space="    ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n"


def main() -> None:
    if len(sys.argv) != 4:
        fail("usage: package-extension.py <modules|components|templates> <name> <base_url>")

    group, extension, base_url = sys.argv[1], sys.argv[2], sys.argv[3].rstrip("/")
    if group not in TYPE_NAMES:
        fail(f"unsupported extension type: {group}")

    source = Path("repos") / group / extension
    if not source.is_dir():
        fail(f"extension directory not found: {source}")

    manifest = source / ("templateDetails.xml" if group == "templates" else f"{extension}.xml")
    if not manifest.is_file():
        fail(f"manifest not found: {manifest}")

    try:
        manifest_tree = ET.parse(manifest)
    except ET.ParseError as error:
        fail(f"invalid manifest {manifest}: {error}")

    root = manifest_tree.getroot()
    version = child_text(root, "version")
    if not version:
        fail(f"missing <version> in {manifest}")

    package_dir = Path("build/releases/packages") / group
    updates_dir = Path("build/releases/updates")
    package_dir.mkdir(parents=True, exist_ok=True)
    updates_dir.mkdir(parents=True, exist_ok=True)

    zip_name = f"{extension}_{version}.zip"
    zip_path = package_dir / zip_name
    update_url = f"{base_url}/updates/{extension}.xml"
    download_url = f"{base_url}/packages/{group}/{zip_name}"

    # The installable package always contains its update-server registration.
    update_servers = root.find("updateservers")
    if update_servers is None:
        update_servers = ET.SubElement(root, "updateservers")
    server = update_servers.find("server")
    if server is None:
        server = ET.SubElement(update_servers, "server")
    server.attrib.update({"type": "extension", "priority": "1", "name": f"{extension} updates"})
    server.text = update_url
    packaged_manifest = indent_xml(root)

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for current_root, dirs, files in os.walk(source):
            dirs[:] = sorted(name for name in dirs if name not in EXCLUDED_NAMES)
            for name in sorted(files):
                if name in EXCLUDED_NAMES or any(name.endswith(suffix) for suffix in EXCLUDED_SUFFIXES):
                    continue
                path = Path(current_root) / name
                archive_name = path.relative_to(source).as_posix()
                if path == manifest:
                    archive.writestr(archive_name, packaged_manifest)
                else:
                    archive.write(path, archive_name)

    sha256 = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    zip_path.with_suffix(".zip.sha256").write_text(f"{sha256}  {zip_name}\n", encoding="utf-8")

    update_root = ET.Element("updates")
    update = ET.SubElement(update_root, "update")
    values = {
        "name": child_text(root, "name", extension),
        "description": child_text(root, "description", extension),
        "element": child_text(root, "element", extension),
        "type": TYPE_NAMES[group],
        "version": version,
    }
    for tag, value in values.items():
        ET.SubElement(update, tag).text = value

    client_name = root.attrib.get("client", "site")
    if TYPE_NAMES[group] in {"module", "template"}:
        ET.SubElement(update, "client").text = "1" if client_name == "administrator" else "0"

    downloads = ET.SubElement(update, "downloads")
    download = ET.SubElement(downloads, "downloadurl", {"type": "full", "format": "zip"})
    download.text = download_url
    tags = ET.SubElement(update, "tags")
    ET.SubElement(tags, "tag").text = "stable"
    ET.SubElement(update, "maintainer").text = child_text(root, "author", "Unknown")
    author_url = child_text(root, "authorUrl")
    if author_url:
        ET.SubElement(update, "maintainerurl").text = author_url
    ET.SubElement(update, "targetplatform", {"name": "joomla", "version": "(4|5)\\.[0-9]+"})
    ET.SubElement(update, "php_minimum").text = "8.1"
    ET.SubElement(update, "sha256").text = sha256

    update_path = updates_dir / f"{extension}.xml"
    update_path.write_bytes(indent_xml(update_root))

    print(f"Package: {zip_path}")
    print(f"Checksum: {zip_path}.sha256")
    print(f"Update manifest: {update_path}")


if __name__ == "__main__":
    main()
