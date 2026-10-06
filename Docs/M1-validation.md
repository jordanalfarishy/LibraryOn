# Validasi M1 — pustaka lokal LibraryOn

Tanggal: 6 Oktober 2026. Build QA: **0.4.0 (12)**, macOS 27.0.1, Apple Silicon, Xcode 27.0/Swift 6.4. Bundle QA terpisah memakai entitlement sandbox dan bookmark app-scope yang sama dengan build utama.

| Area | Bukti | Hasil |
| --- | --- | --- |
| Indeks lokal | Indeks JSON berversi ditulis atomik di Application Support. Uji menyimpan/memuat ulang indeks, memindah root, menolak path keluar root, dan mensimulasikan kegagalan tulis tanpa kehilangan daftar yang sedang tampil. | Lulus |
| Scan dan rekonsiliasi | Batch 50 item, pembatalan saat ganti root, tambah/pindah/salin/hapus buku, serta folder yang tidak dapat dibaca diuji. Buku hilang tetap tampak untuk relink; progres dan penanda tidak terhapus. | Lulus |
| Identitas dan versi | Rename/move pada volume yang sama mempertahankan ID/progres; salinan memperoleh ID lain. Konten berubah meminta konfirmasi sebelum mereset lokasi; relink file pengganti memindahkan progres/penanda. | Lulus |
| Watcher | Tes FSEvents mendeteksi file baru dan memicu scan otomatis. Segarkan dan pembukaan ulang memeriksa perubahan yang terlewat. | Lulus pada tes macOS di luar sandbox tool |
| Folder dan data | Root ganda ditolak; root yang dilepas menutup Reader, membuang indeks, tetapi membiarkan file, progres, dan penanda. Cache yang dapat dibangun ulang dan reset data diuji terpisah. | Lulus |
| UI sandbox | Dua root PDF/EPUB dipilih melalui panel. Klik dan panah bawah mengganti root; pilihan subfolder tiap root pulih. Reader PDF berpindah halaman dengan panah bawah; kembali ke Library menampilkan progres; quit/relaunch memulihkan root, subfolder, dan progres. | Lulus |
| Build dan tes lokal | `swift test --disable-sandbox --cache-path /private/tmp/pdf-speech-build-cache --manifest-cache local --scratch-path .build` dijalankan di luar sandbox tool dengan cache modul di `/private/tmp`. | **43 tes lulus** |
| CI GitHub | Workflow menjalankan tes, build, pemeriksaan signature dan entitlement. | Menunggu repositori/hasil run |

Uji watcher di dalam sandbox tool tidak menerima event FSEvents, tetapi tes yang sama lulus di luar sandbox tool. Build QA memakai file sintetis di `/private/tmp/LibraryOn-M1-QA`. Uji UI drag-and-drop langsung dan pengukuran p95 peluncuran 1.000 buku masih perlu dijalankan pada validasi rilis/beta; jalur penambahan folder dari drop memakai `addRoot` yang juga dipakai pemilih folder dan sudah diuji otomatis. Tidak ada file sumber yang ditulis oleh aplikasi.
