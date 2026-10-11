# B04 — Kamus pelafalan dan sorotan kata

Status per 11 Oktober 2026: **sebagian**. Alur sintetis lulus; timing pada banyak suara/dokumen belum terukur.

Menu Suara menyediakan **Kamus Pelafalan** per buku. Pengguna dapat menambah pasangan teks asli → teks yang diucapkan. Pencocokan peka batas kata, mengabaikan huruf besar/kecil, dan memilih frasa paling panjang saat aturan tumpang tindih. Substitusi hanya diberikan ke `AVSpeechUtterance`; PDF/EPUB, cache ekstraksi, dan posisi baca tetap memakai teks asli. Callback `willSpeakRangeOfSpeechString` dipetakan kembali ke rentang asli untuk sorotan kata. Jika pemetaan PDF tidak aman, sorotan kalimat tetap digunakan; OCR tanpa geometri kata tetap disorot di tampilan teks.

Bukti:

- Tiga tes baru lulus untuk substitusi, frasa bertumpuk, persistensi per buku, serta pemetaan rentang PDF dengan pemenggalan baris dan EPUB.
- QA UI aplikasi terpisah menambah “Kiri” → “kiri pendek”, menyimpan, dan membuka ulang editor; nilai tetap ada. Tampilan teks menunjukkan kata aktif mengikuti pembacaan pada fixture PDF dua kolom.

Sisa gate: dengarkan hasil berbagai suara Indonesia/Inggris, ukur ketepatan callback kata pada kalimat nyata, singkatan dan Unicode, uji sorotan EPUB/PDF secara menyeluruh termasuk sumber yang dinormalisasi, dan evaluasi kontras/VoiceOver. Callback kata bergantung pada engine suara sistem; saat tidak tersedia, sorotan kalimat tetap ada.
