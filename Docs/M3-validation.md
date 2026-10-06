# Validasi M3 — pengalaman mendengarkan

Tanggal: 6 Oktober 2026. Build awal: **0.5.0 (14)**. Status: **sedang dikerjakan**.

| Area | Kemajuan | Sisa |
| --- | --- | --- |
| Antrean audio T18 | Pemutar memakai satu ujaran aktif, session token untuk membuang callback lama, serta antrean PDF bertahap yang menunggu batch berikutnya tanpa menandai selesai terlalu cepat. Tes gap dan akhir antrean lulus. | Uji pergantian cepat dan sesi dengar panjang dengan suara nyata |
| Bahasa dan suara T19 | Menu memilih bahasa Indonesia/English (US), hanya menampilkan suara yang tersedia untuk bahasa itu, dan menyediakan **Dengarkan Contoh**. Pilihan disimpan per buku; suara tersimpan yang hilang menampilkan pesan, tanpa fallback diam-diam ke bahasa lain. QA memilih English/Samantha dan memulihkannya setelah buku dibuka ulang. | Uji perangkat tanpa suara untuk bahasa terpilih dan verifikasi audio preview langsung |
| Kontrol T20–T25 | Play/pause, kecepatan, kalimat sebelumnya/berikutnya, sorotan, Baca dari sini, progres terpisah, dan penanda sudah punya implementasi awal. | Lengkapi auto-follow, lifecycle/interupsi audio, dan skenario resume lintas crash/perubahan sumber sesuai DoD |

Suite lengkap lokal: **56 tes lulus**. Build release bertanda tangan dan verifikasi signature lulus. Ini adalah awal M3, belum gate M3.
