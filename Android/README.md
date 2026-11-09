# LibraryOn untuk Android (pratinjau 0.1.0)

Proyek Android native ini berada di folder tersendiri dan belum setara dengan versi macOS. Aplikasi memakai Android Storage Access Framework (SAF), sehingga pengguna memilih folder buku dan folder progres melalui pemilih dokumen sistem. Buku tetap berada di folder asalnya.

## Build dan jalankan

- Android Studio dengan Android SDK Platform 36, atau JDK 17+ dan SDK yang sama.
- Android 8.0 (API 26) atau lebih baru untuk perangkat.

```bash
cd Android
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

APK debug hasil build ada di `app/build/outputs/apk/debug/app-debug.apk`. Proyek ini belum memiliki paket rilis yang ditandatangani untuk distribusi.

## Alur yang tersedia

1. Ketuk **+ Folder**, pilih folder pustaka, lalu izinkan akses. Beberapa akar pustaka dapat disimpan dan dipilih bergantian. Folder dipindai ulang saat dipilih atau saat tombol ↻ ditekan.
2. Telusuri folder atau cari judul. PDF dibuka sebagai halaman visual dengan navigasi dan zoom 1–3×. EPUB reflowable, TXT UTF-8/UTF-16, dan DOCX sederhana dibaca sebagai teks. Video dibuka di pemutar Android lain.
3. Untuk EPUB/TXT/DOCX, ketuk **Dengarkan** untuk suara sistem Indonesia atau Inggris. Posisi bab/halaman dan kalimat suara disimpan lokal; tombol ✓ menandai buku selesai.
4. Untuk sinkronisasi, pilih **Folder progres** yang sama dengan folder sinkronisasi macOS, lalu ketuk **Sinkronkan sekarang**. Android membaca, menggabungkan, dan menulis `LibraryOn-progress.json` skema v1 sesuai [kontrak bersama](../Docs/Progress-sync-format.md).

## Batas versi awal

- PDF belum memiliki ekstraksi teks, OCR, atau TTS. EPUB ditampilkan sebagai teks bab; gambar, CSS kompleks, dan tata letak khusus belum ditampilkan. DOCX hanya mengambil paragraf sederhana.
- TTS bekerja selama layar pembaca aktif. Belum ada pemutar latar belakang, pilihan suara rinci, bookmark, anotasi, sampul, atau terjemahan manga.
- Sinkronisasi dipicu secara manual. Salinan konflik dari Google Drive/OneDrive belum digabung otomatis. Nama folder pustaka, path relatif, format, dan ukuran berkas harus cocok dengan Mac agar ID buku sama. Penyedia yang tidak melaporkan ukuran berkas akan menghasilkan ID yang tidak cocok.
- Google Drive/OneDrive nyata dan perangkat Android fisik belum diuji. Akses folder bergantung pada kemampuan penyedia file Android yang dipasang pengguna.

## Verifikasi lokal

Build `:app:assembleDebug` berhasil. Pada emulator Pixel 10 (Android 37.1), folder SAF berisi fixture repo berhasil dipindai; PDF, EPUB, TXT, dan DOCX dibuka; TTS menyorot kalimat; `LibraryOn-progress.json` skema v1 berhasil dibuat. Uji suara fisik dan sinkronisasi dua perangkat masih terbuka.
