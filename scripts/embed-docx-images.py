#!/usr/bin/env python3
"""Embed file-linked DOCX images and preserve their native aspect ratios."""

from __future__ import annotations

import argparse
import os
import re
import struct
import tempfile
import urllib.parse
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path


RELATIONSHIP_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
IMAGE_RELATIONSHIP = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
MAX_DRAWING_HEIGHT_EMU = 4_400_000


def local_target(raw_target: str) -> Path:
    parsed = urllib.parse.urlparse(raw_target)
    if parsed.scheme != "file":
        raise ValueError(f"refusing to embed non-file image target: {raw_target}")
    path = Path(urllib.parse.unquote(parsed.path)).resolve()
    if not path.is_file():
        raise FileNotFoundError(f"linked DOCX image not found: {path}")
    return path


def png_size(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if len(header) != 24 or header[:8] != PNG_SIGNATURE or header[12:16] != b"IHDR":
        raise ValueError(f"expected a PNG screenshot: {path}")
    width, height = struct.unpack(">II", header[16:24])
    if width < 1 or height < 1:
        raise ValueError(f"invalid PNG dimensions: {path}")
    return width, height


def preserve_drawing_aspect(document_xml: bytes, relationship_id: str, source: Path) -> bytes:
    """Correct LibreOffice HTML-import extents without changing image pixels."""

    link = f'r:link="{relationship_id}"'.encode()
    inline_pattern = re.compile(rb"<wp:inline\b.*?</wp:inline>", flags=re.DOTALL)
    matches = [match for match in inline_pattern.finditer(document_xml) if link in match.group(0)]
    if len(matches) != 1:
        raise ValueError(
            f"expected one inline drawing for {relationship_id}, found {len(matches)}"
        )

    match = matches[0]
    drawing = match.group(0)
    extent = re.search(rb'<wp:extent cx="(\d+)" cy="(\d+)"/>', drawing)
    if extent is None:
        raise ValueError(f"drawing extent missing for {relationship_id}")

    width_px, height_px = png_size(source)
    width_emu = int(extent.group(1))
    height_emu = round(width_emu * height_px / width_px)
    if height_emu > MAX_DRAWING_HEIGHT_EMU:
        width_emu = round(width_emu * MAX_DRAWING_HEIGHT_EMU / height_emu)
        height_emu = MAX_DRAWING_HEIGHT_EMU
    drawing, wp_count = re.subn(
        rb'<wp:extent cx="\d+" cy="\d+"/>',
        f'<wp:extent cx="{width_emu}" cy="{height_emu}"/>'.encode(),
        drawing,
        count=1,
    )
    drawing, a_count = re.subn(
        rb'<a:ext cx="\d+" cy="\d+"/>',
        f'<a:ext cx="{width_emu}" cy="{height_emu}"/>'.encode(),
        drawing,
        count=1,
    )
    if wp_count != 1 or a_count != 1:
        raise ValueError(f"could not update both drawing extents for {relationship_id}")
    return document_xml[: match.start()] + drawing + document_xml[match.end() :]


def embed_images(docx: Path) -> int:
    document_name = "word/document.xml"
    relationships_name = "word/_rels/document.xml.rels"

    with zipfile.ZipFile(docx) as archive:
        document_xml = archive.read(document_name)
        relationships_xml = archive.read(relationships_name)

    ET.register_namespace("", RELATIONSHIP_NS)
    relationships = ET.fromstring(relationships_xml)
    linked: list[tuple[str, Path, str]] = []
    used_names: set[str] = set()

    for relationship in relationships:
        if relationship.get("Type") != IMAGE_RELATIONSHIP:
            continue
        if relationship.get("TargetMode") != "External":
            continue
        relationship_id = relationship.attrib["Id"]
        source = local_target(relationship.attrib["Target"])
        name = source.name
        counter = 2
        while name in used_names:
            name = f"{source.stem}-{counter}{source.suffix}"
            counter += 1
        used_names.add(name)
        package_name = f"word/media/{name}"
        relationship.set("Target", f"media/{name}")
        relationship.attrib.pop("TargetMode", None)
        linked.append((relationship_id, source, package_name))

    if not linked:
        return 0

    for relationship_id, source, _ in linked:
        document_xml = preserve_drawing_aspect(document_xml, relationship_id, source)
        link = f'r:link="{relationship_id}"'.encode()
        embed = f'r:embed="{relationship_id}"'.encode()
        document_xml, replacements = re.subn(re.escape(link), embed, document_xml)
        if replacements != 1:
            raise ValueError(
                f"expected one drawing reference for {relationship_id}, found {replacements}"
            )

    relationships_xml = ET.tostring(
        relationships,
        encoding="utf-8",
        xml_declaration=True,
    )

    handle, temporary_name = tempfile.mkstemp(
        prefix=f".{docx.stem}.", suffix=".docx", dir=docx.parent
    )
    os.close(handle)
    temporary = Path(temporary_name)
    try:
        with zipfile.ZipFile(docx) as source_archive, zipfile.ZipFile(
            temporary, "w"
        ) as destination_archive:
            for info in source_archive.infolist():
                if info.filename == document_name:
                    destination_archive.writestr(info, document_xml)
                elif info.filename == relationships_name:
                    destination_archive.writestr(info, relationships_xml)
                else:
                    destination_archive.writestr(info, source_archive.read(info.filename))
            for _, image, package_name in linked:
                destination_archive.write(
                    image,
                    package_name,
                    compress_type=zipfile.ZIP_DEFLATED,
                )
        os.replace(temporary, docx)
        docx.chmod(0o644)
    finally:
        temporary.unlink(missing_ok=True)
    return len(linked)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("docx", type=Path)
    args = parser.parse_args()
    count = embed_images(args.docx.resolve())
    print(f"EMBEDDED_DOCX_IMAGES {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
