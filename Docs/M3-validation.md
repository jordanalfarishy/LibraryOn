# Validasi M3 — pengalaman mendengarkan

Tanggal: 6 Oktober 2026. Build saat ini: **0.5.1 (15)**. Status: **sedang dikerjakan**.

| Area | Kemajuan | Sisa |
| --- | --- | --- |
| Antrean audio T18 | Pemutar memakai satu ujaran aktif, session token untuk membuang callback lama, serta antrean PDF bertahap yang menunggu batch berikutnya tanpa menandai selesai terlalu cepat. Tes gap dan akhir antrean lulus. | Uji pergantian cepat dan sesi dengar panjang dengan suara nyata |
| Bahasa dan suara T19 | Menu memilih bahasa Indonesia/English (US), hanya menampilkan suara yang tersedia untuk bahasa itu, dan menyediakan **Dengarkan Contoh**. Pilihan disimpan per buku; suara tersimpan yang hilang menampilkan pesan, tanpa fallback diam-diam ke bahasa lain. QA memilih English/Samantha dan memulihkannya setelah buku dibuka ulang. | Uji perangkat tanpa suara untuk bahasa terpilih dan verifikasi audio preview langsung |
| Auto-follow dan Baca dari sini T22 | Seleksi teks dan Baca dari sini diuji pada PDF/EPUB. Scroll manual pada PDF asli/teks dan EPUB menangguhkan auto-follow tanpa menjeda audio; tombol **Kembali ke Bacaan** memusatkan kalimat aktif dan mengaktifkan follow lagi. QA UI memakai PDF 8 halaman dan EPUB 120 paragraf sintetis; pada PDF halaman visual tetap 3/8 saat kalimat audio dimajukan, lalu kembali ke 1/8. EPUB tetap di paragraf sekitar 50 saat audio berjalan, lalu kembali ke paragraf aktif sekitar 1. Scroll ulang setelah kembali kembali menangguhkan follow. | Tambah uji variasi input trackpad, scrollbar, keyboard, dan format EPUB lain pada gate akhir M3 |
| Kontrol T20/T21/T23–T25 | Play/pause, kecepatan, kalimat sebelumnya/berikutnya, sorotan, progres terpisah, dan penanda sudah punya implementasi awal. | Uji klik cepat, lifecycle/interupsi audio, dan resume lintas crash/perubahan sumber sesuai DoD |

Suite lengkap lokal: **57 tes lulus**, termasuk regresi scroll manual EPUB yang mempertahankan posisi audio. Build QA release ditandatangani ad-hoc dan verifikasi signature lulus. Gate M3 belum selesai.
