#!/usr/bin/env python3
"""Post-process Quarto DOCX for Google Docs upload.

- Removes Word bookmarks (section / figure / table anchors) that GDocs surfaces as clutter.
- Re-embeds any PDF figures as PNG when PyMuPDF is available.
"""

from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
ET.register_namespace("w", W_NS)
ET.register_namespace("", REL_NS)


def _w(tag: str) -> str:
    return f"{{{W_NS}}}{tag}"


def remove_bookmarks(root: ET.Element) -> int:
    removed = 0
    for parent in root.iter():
        for child in list(parent):
            if child.tag in (_w("bookmarkStart"), _w("bookmarkEnd")):
                parent.remove(child)
                removed += 1
    return removed


def repack_docx(unpacked: Path, out_path: Path) -> None:
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file in sorted(unpacked.rglob("*")):
            if file.is_file():
                zf.write(file, file.relative_to(unpacked).as_posix())


def _pdf_to_png(pdf_path: Path, png_path: Path, dpi: int = 300) -> bool:
    try:
        import fitz  # PyMuPDF

        doc = fitz.open(pdf_path)
        page = doc.load_page(0)
        pix = page.get_pixmap(dpi=dpi)
        pix.save(png_path)
        doc.close()
        return True
    except ImportError:
        pass

    # macOS built-in fallback when PyMuPDF is unavailable
    if sys.platform == "darwin":
        import subprocess

        result = subprocess.run(
            ["sips", "-s", "format", "png", str(pdf_path), "--out", str(png_path)],
            capture_output=True,
            text=True,
        )
        return result.returncode == 0 and png_path.exists()

    return False


def convert_pdf_media_to_png(unpacked: Path) -> int:
    media_dir = unpacked / "word" / "media"
    rels_path = unpacked / "word" / "_rels" / "document.xml.rels"
    if not rels_path.exists():
        return 0

    rels_tree = ET.parse(rels_path)
    rels_root = rels_tree.getroot()
    converted = 0
    renames: dict[str, str] = {}
    used_pymupdf: bool | None = None

    for rel in rels_root:
        target = rel.get("Target", "")
        if not target.startswith("media/") or not target.lower().endswith(".pdf"):
            continue
        pdf_path = unpacked / "word" / target
        if not pdf_path.exists():
            continue
        png_name = Path(target).with_suffix(".png").name
        png_path = media_dir / png_name
        if not _pdf_to_png(pdf_path, png_path):
            if used_pymupdf is None:
                try:
                    import fitz  # noqa: F401

                    used_pymupdf = True
                except ImportError:
                    used_pymupdf = False
                    print(
                        "PyMuPDF not installed and sips conversion failed; "
                        "skipping remaining PDF->PNG conversions.",
                        file=sys.stderr,
                    )
            if used_pymupdf is False:
                break
            continue
        rel.set("Target", f"media/{png_name}")
        renames[pdf_path.name] = png_name
        converted += 1

    if converted:
        doc_xml_path = unpacked / "word" / "document.xml"
        text = doc_xml_path.read_text(encoding="utf-8")
        for old, new in renames.items():
            text = text.replace(old, new)
        doc_xml_path.write_text(text, encoding="utf-8")
        rels_tree.write(rels_path, encoding="utf-8", xml_declaration=True)
        for pdf_name in renames:
            pdf_path = media_dir / pdf_name
            if pdf_path.exists():
                pdf_path.unlink()

    return converted


def postprocess(docx_path: Path, out_path: Path | None = None) -> Path:
    if not docx_path.exists():
        raise FileNotFoundError(docx_path)

    destination = out_path or docx_path

    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / "unpacked"
        with zipfile.ZipFile(docx_path, "r") as zf:
            zf.extractall(work)

        doc_xml_path = work / "word" / "document.xml"
        tree = ET.parse(doc_xml_path)
        n_bookmarks = remove_bookmarks(tree.getroot())
        tree.write(doc_xml_path, encoding="utf-8", xml_declaration=True)

        n_pdf = convert_pdf_media_to_png(work)

        staged = Path(tmp) / "out.docx"
        repack_docx(work, staged)
        shutil.copy2(staged, destination)

    print(f"Removed {n_bookmarks} bookmarks")
    if n_pdf:
        print(f"Converted {n_pdf} embedded PDF figure(s) to PNG")
    print(f"Wrote {destination}")
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "docx",
        nargs="?",
        default="reports/chap3_ddm_results.docx",
        help="Input DOCX (default: reports/chap3_ddm_results.docx)",
    )
    parser.add_argument(
        "--output",
        help="Output DOCX path (default: overwrite input)",
    )
    args = parser.parse_args()
    src = Path(args.docx)
    out = Path(args.output) if args.output else src
    if out != src:
        shutil.copy2(src, out)
    postprocess(src if out == src else out, out_path=out)


if __name__ == "__main__":
    main()
