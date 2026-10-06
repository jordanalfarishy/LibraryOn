#!/usr/bin/env python3
"""Buat corpus sintetis M0 dan dataset indeks; aman dijalankan ulang."""

import csv
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "Tests/Fixtures/M0"
DOCS = OUTPUT / "documents"
INDEX = OUTPUT / "index-1000"
WORDS = [
    "satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan", "sembilan", "sepuluh",
    "sebelas", "dua belas", "tiga belas", "empat belas", "lima belas", "enam belas", "tujuh belas",
    "delapan belas", "sembilan belas", "dua puluh",
]


def epub(path: Path, version: int, book: int, *, nav: bool = True, footnote: bool = False,
         remote: bool = False, fixed: bool = False, drm_marker: bool = False) -> None:
    chapters = []
    for chapter in range(2):
        paragraphs = "\n".join(
            f"<p id='p{number+1}'>Buku EPUB {book} memiliki kalimat {WORDS[number]}.</p>"
            for number in range(chapter * 10, chapter * 10 + 10)
        )
        if chapter == 0 and footnote:
            paragraphs += "<p><a href='chapter2.xhtml#note'>Lihat catatan kaki</a>.</p>"
        if chapter == 1 and footnote:
            paragraphs += "<aside id='note'>Catatan kaki lokal.</aside>"
        if chapter == 0 and remote:
            paragraphs += "<p><img src='https://example.invalid/tracker.png' alt='remote' /></p>"
            paragraphs += "<script src='https://example.invalid/remote.js'></script>"
        chapters.append(
            "<?xml version='1.0' encoding='utf-8'?>"
            "<html xmlns='http://www.w3.org/1999/xhtml'><head><title>Bab</title></head>"
            f"<body><h1>Bab {chapter+1}</h1>{paragraphs}</body></html>"
        )

    package_version = "3.0" if version == 3 else "2.0"
    properties = " properties='nav'" if version == 3 and nav else ""
    navigation_item = (
        f"<item id='nav' href='nav.xhtml' media-type='application/xhtml+xml'{properties}/>"
        if nav else ""
    )
    nav_document = (
        "<?xml version='1.0' encoding='utf-8'?>"
        "<html xmlns='http://www.w3.org/1999/xhtml' xmlns:epub='http://www.idpf.org/2007/ops'>"
        "<head><title>Daftar Isi</title></head><body><nav epub:type='toc'><ol>"
        "<li><a href='chapter1.xhtml'>Bab satu</a></li>"
        "<li><a href='chapter2.xhtml'>Bab dua</a></li>"
        "</ol></nav></body></html>"
    )
    ncx_item = "<item id='ncx' href='toc.ncx' media-type='application/x-dtbncx+xml'/>" if version == 2 else ""
    spine_toc = " toc='ncx'" if version == 2 else ""
    fixed_meta = "<meta property='rendition:layout'>pre-paginated</meta>" if fixed else ""
    opf = (
        "<?xml version='1.0' encoding='utf-8'?>"
        f"<package xmlns='http://www.idpf.org/2007/opf' version='{package_version}' unique-identifier='uid'>"
        f"<metadata xmlns:dc='http://purl.org/dc/elements/1.1/'><dc:identifier id='uid'>m0-{book}</dc:identifier>"
        f"<dc:title>Buku EPUB {book}</dc:title><dc:language>id</dc:language>{fixed_meta}</metadata>"
        "<manifest><item id='c1' href='chapter1.xhtml' media-type='application/xhtml+xml'/>"
        "<item id='c2' href='chapter2.xhtml' media-type='application/xhtml+xml'/>"
        f"{navigation_item}{ncx_item}</manifest>"
        f"<spine{spine_toc}><itemref idref='c1'/><itemref idref='c2'/></spine></package>"
    )
    ncx = (
        "<?xml version='1.0' encoding='utf-8'?>"
        "<ncx xmlns='http://www.daisy.org/z3986/2005/ncx/' version='2005-1'>"
        "<head></head><docTitle><text>Daftar Isi</text></docTitle><navMap>"
        "<navPoint id='n1' playOrder='1'><navLabel><text>Bab satu</text></navLabel>"
        "<content src='chapter1.xhtml'/></navPoint>"
        "<navPoint id='n2' playOrder='2'><navLabel><text>Bab dua</text></navLabel>"
        "<content src='chapter2.xhtml'/></navPoint></navMap></ncx>"
    )
    container = (
        "<?xml version='1.0' encoding='utf-8'?>"
        "<container version='1.0' xmlns='urn:oasis:names:tc:opendocument:xmlns:container'>"
        "<rootfiles><rootfile full-path='OEBPS/book.opf' "
        "media-type='application/oebps-package+xml'/></rootfiles></container>"
    )
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        archive.writestr("META-INF/container.xml", container)
        archive.writestr("META-INF/com.apple.ibooks.display-options.xml",
                         "<display_options><platform name='*'><option name='fixed-layout'>false</option>"
                         "</platform></display_options>")
        archive.writestr("OEBPS/book.opf", opf)
        archive.writestr("OEBPS/chapter1.xhtml", chapters[0])
        archive.writestr("OEBPS/chapter2.xhtml", chapters[1])
        if nav:
            archive.writestr("OEBPS/nav.xhtml", nav_document)
        if version == 2:
            archive.writestr("OEBPS/toc.ncx", ncx)
        if drm_marker:
            archive.writestr("META-INF/encryption.xml", "<encryption/>")


def main() -> None:
    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)
    DOCS.mkdir(parents=True)
    INDEX.mkdir(parents=True)
    subprocess.run([
        "swift", "-module-cache-path", "/private/tmp/pdf-speech-swift-cache",
        str(ROOT / "Scripts/generate-m0-pdfs.swift"), str(DOCS)
    ], check=True)
    for book in range(1, 11):
        epub(DOCS / f"epub-{book:02d}.epub", 2 if book <= 5 else 3, book,
             footnote=book in (4, 9))
    epub(DOCS / "edge-remote.epub", 3, 21, remote=True)
    epub(DOCS / "edge-fixed-layout.epub", 3, 22, fixed=True)
    epub(DOCS / "edge-no-nav.epub", 3, 23, nav=False)
    epub(DOCS / "edge-drm-marker.epub", 2, 24, drm_marker=True)
    (DOCS / "edge-corrupt.epub").write_bytes(b"not a zip archive")

    references = []
    for kind in ("pdf", "epub"):
        for book in range(1, 11):
            for number in range(20):
                references.append({
                    "file": f"{kind}-{book:02d}.{kind}",
                    "section": number // 10,
                    "sentence": number + 1,
                    "text": f"Buku {kind.upper()} {book} memiliki kalimat {WORDS[number]}."
                })
    with (OUTPUT / "reference-sentences.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["file", "section", "sentence", "text"])
        writer.writeheader()
        writer.writerows(references)

    folders = [INDEX / f"Rak-{number:03d}" for number in range(1, 96)]
    folders += [INDEX / "Rak-095" / f"Bagian-{number:03d}" for number in range(96, 101)]
    for folder_number, folder in enumerate(folders):
        folder.mkdir(parents=True)
        for book_number in range(10):
            index = folder_number * 10 + book_number + 1
            source = DOCS / ("pdf-01.pdf" if index % 2 else "epub-01.epub")
            name = ("Judul Sama" if book_number == 0 else
                    "Cerita 日本語" if index == 502 else f"Buku-{index:04d}")
            shutil.copyfile(source, folder / f"{name}{source.suffix}")
    manifest = {
        "license": "Seluruh konten dibuat secara sintetis oleh generator proyek ini.",
        "primary_pdf": 10,
        "primary_epub": 10,
        "edge_pdf": 5,
        "edge_epub": 5,
        "documents_total": 30,
        "reference_sentences": len(references),
        "index_folders": 100,
        "index_books": 1000,
        "notes": "PDF rusak dan EPUB rusak sengaja tidak dapat dibuka; DRM marker/fixed layout dipakai untuk uji penolakan."
    }
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"Corpus M0: {manifest['documents_total']} dokumen, {len(references)} kalimat, 100 folder/1000 buku di {OUTPUT}")


if __name__ == "__main__":
    main()
