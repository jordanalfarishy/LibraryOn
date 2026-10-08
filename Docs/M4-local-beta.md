# Paket beta lokal LibraryOn

Build saat ini: `dist/LibraryOn.app` versi 0.5.2 (16), dibungkus dalam `dist/LibraryOn-local-beta.zip`. Paket ditandatangani **ad-hoc** untuk QA di Mac pengembangan. Integritas bundle dan ZIP sudah diperiksa, tetapi paket ini belum ditandatangani Developer ID atau dinotarize, sehingga belum menjadi paket distribusi untuk Mac lain.

## Memakai paket di Mac pengembangan

1. Jalankan `dist/LibraryOn.app` atau ekstrak `dist/LibraryOn-local-beta.zip` ke lokasi uji lokal.
2. Buka folder yang berisi PDF berbasis teks atau EPUB reflowable tanpa DRM. File buku tetap di tempatnya; LibraryOn menyimpan indeks, cache, progres, dan penanda di data aplikasi lokal.
3. Buka Pengaturan dengan Cmd+, untuk memilih suara bawaan dan tampilan EPUB. Cmd+O memilih folder, Space memutar/menjeda, Option+panah berpindah kalimat, dan Cmd+[ kembali ke pustaka.
4. Untuk evaluasi lima peserta, gunakan [protokol beta](M4-beta-protocol.md) dan catat hasil tiap peserta tanpa mengunggah bukunya.

## Prasyarat distribusi eksternal

Siapkan identitas Developer ID Application dan akses notarization milik pemilik proyek, lalu lakukan signing distribusi, notarization, stapling, dan uji instalasi di Mac bersih. Ulangi tes alur, offline, kinerja, serta regresi setelah paket akhir dibuat. Catat identitas build, hasil notarization, dan hasil instalasi di [validasi M4](M4-validation.md). Jangan mengganti status T32 menjadi selesai sebelum pemeriksaan itu lulus.

Lisensi kode pihak ketiga berada di `LibraryOn.app/Contents/Resources/Licenses` pada bundle dan ZIP, bersumber dari `Licenses/epubjs-BSD-2-Clause.txt` serta `Vendor/ZIPFoundation/LICENSE` di repo. Batas format dan fitur yang belum didukung tercatat di [README](../README.md) dan [PRD](../PRD.md).
