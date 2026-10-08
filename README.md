# LibraryOn

LibraryOn is a native macOS app for browsing folders of PDF and EPUB books, reading them, and listening with installed system voices. Books stay in their original folders; the app stores its index, reading positions, bookmarks, and rebuildable cache locally.

_Bahasa Indonesia: LibraryOn membantu menjelajahi folder PDF/EPUB, membaca, dan mendengarkan buku dengan suara sistem. File buku tetap di folder asal. [PRD berbahasa Indonesia](PRD.md) memuat rancangan dan status lengkap._

## Project status

This repository contains a **prototype**, currently version **0.5.2 (16)**. The M0–M3 implementation gates have passed; [M4 beta verification](Docs/M4-validation.md) remains open. The local app build uses an ad-hoc signature. There is no notarized release or verified clean-Mac installer yet.

## Requirements and build

- macOS 14 or later on Apple Silicon; Xcode with a Swift 6 toolchain.
- A local, DRM-free, reflowable EPUB or text-based PDF for the main reading flow.

```bash
git clone https://github.com/jordanalfarishy/LibraryOn.git
cd LibraryOn
bash Scripts/build-app.sh
open dist/LibraryOn.app
```

The build uses vendored dependencies and creates `dist/LibraryOn.app`. Reopen the app after rebuilding. The generated `dist/` and `.build/` directories are ignored by Git. Run the test suite with `swift test` on macOS. The optional 1,000-book/FSEvents benchmark is documented in [M4 validation](Docs/M4-validation.md).

## What works now

- Browse multiple library roots and subfolders; search titles, sort, and switch between grid and list views. The saved index appears while the folder is checked again in the background.
- Read text-based PDFs in original or text view, and reflowable EPUB 2/3 books with chapters, contents, typography, and themes.
- Listen using installed Indonesian or English system voices, with play/pause, sentence navigation, speed, voice preview, and per-book voice choices.
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
| ↑ / ↓ | Previous / next PDF page |

## Scope and limitations

- Scanned/image-only PDFs need OCR for general TTS; multi-column reading order is not yet supported. Fixed-layout, interactive, scripted, and DRM-protected EPUBs are outside the current reader scope.
- Manga translation on macOS 15+ is **experimental**: it processes the active PDF page locally and can show temporary overlays, but real manga layouts, model download, speed, and memory still need beta validation.
- The core reader has no account, analytics, or document upload path. Remote HTTP/HTTPS content inside EPUBs is blocked. macOS may need to download a translation language model before its local translation feature is available.
- The beta gate still needs broader device and document testing, a five-person usability/voice study, and Developer ID signing plus notarization. See [M4 validation](Docs/M4-validation.md) for evidence and remaining work.

## Documentation and licenses

- [Product requirements and milestone status (Indonesian)](PRD.md)
- [M0](Docs/M0-validation.md), [M1](Docs/M1-validation.md), [M2](Docs/M2-validation.md), [M3](Docs/M3-validation.md), and [M4](Docs/M4-validation.md) validation notes
- [Local beta package guide](Docs/M4-local-beta.md) and [five-person beta protocol](Docs/M4-beta-protocol.md)
- Third-party notices: [ZIPFoundation (MIT)](Vendor/ZIPFoundation/LICENSE) and [epub.js (BSD 2-Clause)](Licenses/epubjs-BSD-2-Clause.txt). Both notices are also copied into built app bundles.

The LibraryOn project itself does not yet have a top-level `LICENSE` file.
