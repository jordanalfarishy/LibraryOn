# LibraryOn

LibraryOn is a native macOS app for browsing folders of PDF, EPUB, TXT, and DOCX books, reading them, and listening with installed system voices. The library also lists videos and opens them in the default macOS player. Files stay in their original folders; the app stores its index, reading positions, bookmarks, and rebuildable cache locally.

_Bahasa Indonesia: LibraryOn membantu menjelajahi folder PDF/EPUB/TXT/DOCX, membaca, dan mendengarkan buku dengan suara sistem. Video juga tampil di pustaka dan dibuka lewat pemutar default macOS. File tetap di folder asal. [PRD berbahasa Indonesia](PRD.md) memuat rancangan dan status lengkap._

## Project status

This repository contains a **prototype**, currently version **0.8.1 (24)**. The M0–M3 implementation gates have passed. M4 verification and the B01–B12/B15 backlog gates remain open where noted. The local app build uses an ad-hoc signature. There is no notarized release or verified clean-Mac installer yet. The earlier [M4 local beta package](Docs/M4-local-beta.md) remains version 0.5.3.

## Requirements and build

- macOS 14 or later on Apple Silicon; Xcode with a Swift 6 toolchain.
- A local, DRM-free, reflowable EPUB, text-based PDF, UTF-8/UTF-16 TXT, or simple DOCX for the main reading flow.

```bash
git clone https://github.com/jordanalfarishy/LibraryOn.git
cd LibraryOn
bash Scripts/build-app.sh
open dist/LibraryOn.app
```

The build uses vendored dependencies and creates `dist/LibraryOn.app`. A local QA archive of version 0.8.1 is available at [LibraryOn-0.8.1-local.zip](dist/LibraryOn-0.8.1-local.zip). Reopen the app after rebuilding. The generated `dist/` and `.build/` directories are ignored by Git. Run the test suite with `swift test` on macOS. The optional 1,000-book/FSEvents benchmark is documented in [M4 validation](Docs/M4-validation.md).

## What works now

- Browse multiple library roots and subfolders; search titles, sort, and switch between grid and list views. The saved index appears while the folder is checked again in the background. The Library header keeps the same toolbar height after returning from a book, and empty states provide actions for adding a folder, refreshing, or clearing a search.
- Add a Google Drive for desktop, OneDrive, or iCloud Drive folder from Finder with **Add from Cloud**. LibraryOn indexes supported files without downloading every cover; an online-only book is prepared when opened. Folder access and bookmarks remain local; reading progress stays locally available and can also use the optional sync below.
- Choose a Google Drive or OneDrive folder in Settings to sync reading positions through one `LibraryOn-progress.json` file. Local progress remains available offline; visual and audio positions merge separately. The [versioned JSON format](Docs/Progress-sync-format.md) is designed for a future mobile app using its system file provider. Real provider and mobile interoperability checks remain open.
- Read text-based PDFs in original or text view, and reflowable EPUB 2/3 books with chapters, contents, typography, and themes.
- At the first or last PDF page, the page arrows open the previous or next readable book in the current Library order. EPUB chapter arrows cross book boundaries at the first or last chapter; TXT/DOCX readers have book arrows in the toolbar. Previous books open at the end, and next books open at the start. Videos are skipped.
- Read TXT and simple DOCX paragraphs with TTS. Export a TXT/DOCX reading to local CAF audio through the macOS Save dialog.
- Run local OCR on an image-only PDF page, review or correct the recognized text, then read it with TTS. Results are cached without editing the PDF. This B01 flow has passed synthetic QA; accuracy on varied scans remains open.
- For a text-based PDF, choose **PDF reading layout** to read two columns in visual order and skip repeated headers or footers. Options persist per book. This B02 flow has passed synthetic QA; varied real-world layouts remain open.
- Listen using installed Indonesian or English system voices, with play/pause, sentence navigation, speed, voice preview, and per-book voice choices. Nearby sentences are spoken together to reduce gaps while retaining per-sentence progress and highlighting.
- Keep listening after returning to the Library or opening another book. A compact player floats above the other reader; its own toolbar shows one action to switch audio to that book. Reading progress appears over each book cover so grid cards stay aligned.
- Add per-book pronunciation replacements from the Voice menu. Spoken words are highlighted in the PDF, EPUB, or PDF text view when the system voice supplies word timing.
- Set a 15, 30, or 60 minute sleep timer; Now Playing metadata and media controls follow active TTS playback on macOS.
- Highlight selected PDF text, add a note, and search the extracted PDF content. Highlights and notes persist outside the PDF file; EPUB annotations and book collections remain in development.
- Resume visual and audio positions separately, follow the spoken sentence, and save bookmarks. Manual scrolling pauses auto-follow without pausing speech.
- Choose **Interface language** in Settings independently of the book's TTS language. Indonesian, English, and Follow System are available; the interface changes immediately.
- Recover from missing or changed book files by relinking or reviewing them. Cache clearing leaves books, progress, and bookmarks intact; a separate confirmed action resets reading data.

The target-shaped **Return to Reading** control is icon-only in PDF and EPUB readers. Its tooltip and VoiceOver name remain available.

| Shortcut | Action |
| --- | --- |
| Cmd+O | Choose a library folder |
| Cmd+, | Open Settings |
| Enter | Open the selected book |
| Cmd+[ | Return to the library |
| Space | Play or pause in Reader |
| Option+← / Option+→ | Previous / next sentence |
| ↑ / ↓ | Previous / next PDF page; cross into the adjacent book at a boundary |

## Scope and limitations

- Scanned/image-only PDFs require the on-demand OCR action before TTS. OCR quality on varied scans and two-column layouts still need validation. Fixed-layout, interactive, scripted, and DRM-protected EPUBs are outside the current reader scope.
- TXT currently accepts UTF-8/UTF-16 and DOCX extracts basic paragraph text; complex Word layout, tables, tracked changes, and embedded objects need validation. Audio export writes CAF files using installed system voices; long exports, overwrite behavior, and permission to distribute recordings have not been validated.
- Cloud folders require the provider's desktop sync app and a folder visible in Finder. Availability and download time depend on that provider; LibraryOn does not connect to cloud accounts directly.
- Manga translation on macOS 15+ is **experimental**: it processes the active PDF page locally. On macOS 26+, fast OCR scans a page once; **Scan More Thoroughly** adds overlapping crops when dialogue is missed. Older macOS versions use the legacy OCR path. Dialogue translations appear progressively in the side panel so the artwork remains visible; selecting the highlight icon draws a thin outline around one dialogue. The panel also lets you correct OCR before retranslating. Real manga layouts, model download, speed, and memory still need broader beta validation.
- The core reader has no account, analytics, or document upload path. Remote HTTP/HTTPS content inside EPUBs is blocked. macOS may need to download a translation language model before its local translation feature is available.
- The local beta gate still needs the owner's [solo QA](Docs/M4-local-qa.md), offline and accessibility checks, and complete performance measurements. A five-person usability/voice study and Developer ID signing plus notarization are separate external distribution gates (B13–B14). See [M4 validation](Docs/M4-validation.md).

## Documentation and licenses

- [Product requirements and milestone status (Indonesian)](PRD.md)
- [M0](Docs/M0-validation.md), [M1](Docs/M1-validation.md), [M2](Docs/M2-validation.md), [M3](Docs/M3-validation.md), and [M4](Docs/M4-validation.md) validation notes
- [B01 OCR validation](Docs/B01-validation.md)
- [B02 PDF layout validation](Docs/B02-validation.md)
- [B04 pronunciation and word-highlight validation](Docs/B04-validation.md)
- [B05 sleep timer and media controls validation](Docs/B05-validation.md)
- [B06 PDF highlights, notes, and search validation](Docs/B06-validation.md)
- [B07 TXT, DOCX, and audio export validation](Docs/B07-validation.md)
- [Playback continuity validation](Docs/Playback-continuity-validation.md)
- [Local beta package guide](Docs/M4-local-beta.md), [solo QA checklist](Docs/M4-local-qa.md), and [five-person external beta protocol](Docs/M4-beta-protocol.md)
- Third-party notices: [ZIPFoundation (MIT)](Vendor/ZIPFoundation/LICENSE) and [epub.js (BSD 2-Clause)](Licenses/epubjs-BSD-2-Clause.txt). Both notices are also copied into built app bundles.

The LibraryOn project itself does not yet have a top-level `LICENSE` file.
