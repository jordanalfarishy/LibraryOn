# Paket beta lokal LibraryOn

Arsip M4 awal [`dist/LibraryOn-local-beta.zip`](../dist/LibraryOn-local-beta.zip) berisi versi **0.5.3 (17)** dan telah diperiksa integritasnya pada saat dibuat. `dist/LibraryOn.app` sekarang mengikuti build pengembangan **0.8.1 (24)** dengan navigasi antar buku dan sinkronisasi progres portabel di atas B01–B12 serta perbaikan kontinuitas TTS. Keduanya ditandatangani **ad-hoc** untuk QA di Mac pemilik, belum menggunakan Developer ID atau notarization untuk distribusi ke Mac lain.

Arsip QA versi baru tersedia sebagai [`dist/LibraryOn-0.8.1-local.zip`](../dist/LibraryOn-0.8.1-local.zip). Build baru belum menggantikan bukti gate M4 lama atau verifikasi instalasi Mac lain; lihat [validasi B08–B12](B08-B12-validation.md) dan [format sinkronisasi progres](Progress-sync-format.md).

## Memakai paket di Mac pengembangan

1. Jalankan `dist/LibraryOn.app` untuk versi pengembangan terbaru, atau ekstrak `dist/LibraryOn-local-beta.zip` untuk membandingkan dengan beta M4 awal.
2. Buka folder yang berisi PDF berbasis teks atau EPUB reflowable tanpa DRM. File buku tetap di tempatnya; LibraryOn menyimpan indeks, cache, progres, dan penanda di data aplikasi lokal.
3. Buka Pengaturan dengan Cmd+, untuk memilih suara bawaan dan tampilan EPUB. Cmd+O memilih folder, Space memutar/menjeda, Option+panah berpindah kalimat, dan Cmd+[ kembali ke pustaka.
4. Jalankan [QA mandiri M4](M4-local-qa.md) dan catat hasil alur, kenyamanan suara Indonesia/Inggris, serta masalah yang ditemukan. Jangan mengunggah buku pribadi.

## Prasyarat distribusi eksternal

Distribusi eksternal adalah B13–B14. Sebelum membagikan paket ke Mac lain, lakukan [studi lima peserta](M4-beta-protocol.md), siapkan identitas Developer ID Application dan akses notarization milik pemilik proyek, lalu lakukan signing distribusi, notarization, stapling, dan uji instalasi di Mac bersih. Ulangi tes alur, offline, kinerja, serta regresi setelah paket akhir dibuat. Catat buktinya di [validasi M4](M4-validation.md).

Lisensi kode pihak ketiga berada di `LibraryOn.app/Contents/Resources/Licenses` pada bundle dan ZIP, bersumber dari `Licenses/epubjs-BSD-2-Clause.txt` serta `Vendor/ZIPFoundation/LICENSE` di repo. Batas format dan fitur yang belum didukung tercatat di [README](../README.md) dan [PRD](../PRD.md).
