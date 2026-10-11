# QA mandiri M4 — LibraryOn 0.5.3 (17)

Paket: [`dist/LibraryOn-local-beta.zip`](../dist/LibraryOn-local-beta.zip), untuk Mac pemilik. Tanggal pengujian: ____. Model Mac/macOS: ____. Suara Indonesia: ____. Suara Inggris: ____.

Laporan pemilik pada 11 Oktober 2026: **alur buka folder → buku → Putar/Jeda → buka ulang lulus**. Kenyamanan suara Indonesia **4/5** dan Inggris **4/5**; pemilik menginginkan pembacaan yang lebih natural. Laporan ini tidak merinci penanda, perpindahan kalimat, offline, VoiceOver, atau sesi 60 menit; butir tersebut tetap belum diuji/tercatat di bawah.

Gunakan PDF berbasis teks dan EPUB reflowable tanpa DRM yang boleh Anda pakai. Simpan hasil di tabel ini. Nilai `Lulus`, `Gagal`, atau `Belum diuji`; tambahkan langkah reproduksi untuk kegagalan. Jangan masukkan isi buku pribadi ke laporan.

| Alur | Hasil | Catatan |
| --- | --- | --- |
| Pilih folder pustaka, buka subfolder, cari dan buka PDF serta EPUB | Belum diuji | |
| Putar, jeda, pindah kalimat, dan lanjutkan suara pada kedua format | Belum diuji | |
| Buat dan buka penanda; ganti buku lalu kembali | Belum diuji | |
| Tutup dan buka ulang aplikasi; posisi visual tetap, audio tidak autoplay | Belum diuji | |
| Ubah bahasa UI Indonesia/English dan suara TTS secara terpisah | Belum diuji | |
| Matikan jaringan setelah suara tersedia; baca dan dengarkan buku lokal | Belum diuji | |
| Jalankan sesi 60 menit; perhatikan crash, audio ganda, dan memori yang terus naik | Belum diuji | |
| Coba VoiceOver serta keyboard pada Library, Reader, dialog, dan Settings | Belum diuji | |
| Jika memakai folder cloud Finder: buka file online-only, putuskan jaringan, coba lagi, lalu periksa progres | Belum diuji | Opsional untuk B12; catat penyedia cloud. |

Nilai kenyamanan suara Indonesia (1–5): **4**. Nilai kenyamanan suara Inggris (1–5): **4**. Catatan: keduanya diinginkan lebih natural; contoh pelafalan angka, singkatan, nama, dan paragraf panjang belum disampaikan.

Temuan penghambat/P0: ____. Setelah perbaikan, alur yang diulang dan hasilnya: ____.

Catatan otomatis pada Mac pengembangan, 11 Oktober 2026: suite 88 tes menghasilkan 84 lulus dan 4 tes opsional dilewati; benchmark komponen 1.000 buku/100 folder serta watcher lulus. UI QA terisolasi berhasil memilih folder, membuka PDF/EPUB, Putar/Jeda, penanda, navigasi bab, pemulihan posisi setelah relaunch, pergantian bahasa UI, penanganan PDF rusak, dan pencarian pustaka sintetis. Catatan otomatis ini **tidak** mengisi hasil pengalaman pengguna di atas dan belum membuktikan sesi 60 menit, kualitas suara subjektif, VoiceOver menyeluruh, atau offline jaringan nyata. Rincian bukti ada di [validasi M4](M4-validation.md).
