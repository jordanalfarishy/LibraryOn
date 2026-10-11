#!/usr/bin/env python3
"""Generate small offline TXT/DOCX reading fixtures."""
from pathlib import Path
import sys
import zipfile

folder = Path(sys.argv[1])
folder.mkdir(parents=True, exist_ok=True)
(folder / "simple.txt").write_text(
    "Buku ini dibaca dari TXT.\n\nThis is the second paragraph.\n",
    encoding="utf-8",
)
(folder / "utf16.txt").write_text("Teks UTF-16 juga dibaca.", encoding="utf-16")

document = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
 <w:body>
  <w:p><w:r><w:t>Dokumen </w:t></w:r><w:r><w:t>Word pertama.</w:t></w:r></w:p>
  <w:p><w:r><w:t>Second paragraph.</w:t></w:r></w:p>
 </w:body>
</w:document>'''
with zipfile.ZipFile(folder / "simple.docx", "w", zipfile.ZIP_DEFLATED) as archive:
    archive.writestr("[Content_Types].xml", '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
 <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
 <Default Extension="xml" ContentType="application/xml"/>
 <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''')
    archive.writestr("_rels/.rels", '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
 <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''')
    archive.writestr("word/document.xml", document)

print(folder)
