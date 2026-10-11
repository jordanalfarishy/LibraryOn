# Pemutaran TTS lintas Library dan buku

Status per 11 Oktober 2026: **alur utama lulus pada build QA lokal**. Sesi buku yang sedang berbunyi dipertahankan ketika Reader ditutup. Pemutar ringkas tampil di Library dan ketika buku lain sedang dibuka, dengan judul sumber, posisi kalimat, Putar/Jeda, kalimat sebelum/sesudah, Buka Buku, dan Tutup. Saat buku kedua mulai diputar, sesi pertama dihentikan sehingga tidak ada dua TTS bersamaan. Menutup pemutar membatalkan timer dan melepaskan sesi. Bila folder akar diganti, akses security-scoped sumber audio dipertahankan sampai sesi dihentikan atau diganti.

Bukti:

- `PlaybackContinuityTests`: 2 tes lulus untuk kembali ke Library, membuka buku lain, mengambil alih audio, dan menutup pemutar.
- QA UI build sandbox dengan TXT panjang: buku A masih berstatus Jeda/Pause dan posisi kalimat bertambah setelah Library dan buku B dibuka; Putar di B menghilangkan pemutar A.
- QA lintas format dengan PDF dan EPUB sintetis: PDF tetap berjalan di Library dan saat EPUB dibuka; Putar di EPUB mengambil alih, lalu EPUB tetap berjalan ketika TXT dibuka. Jeda dan lanjut dari pemutar ringkas berhasil.
- QA UI build 0.6.0 terbaru: EPUB tersembunyi meneruskan audio ke bab 2 saat TXT terbuka; tombol Buka Buku menampilkan bab 2 dan status Jeda tanpa galat. Regresi unit memastikan pesan render WebView yang kosong sesaat tidak menutupi bab yang sudah valid dan sedang dibacakan.

Sisa QA: sesi sangat panjang, pergantian akar dengan volume terlepas, perubahan file sumber saat Reader tersembunyi, dan pengujian media keys/Control Center saat pemutar ringkas aktif.
