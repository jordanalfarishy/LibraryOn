# B06 — Sorotan, catatan, pencarian isi, dan koleksi

Status per 11 Oktober 2026: **sebagian**. PDF didukung untuk sorotan/catatan/pencarian; EPUB dan koleksi buku belum diimplementasikan.

Reader PDF dapat menyimpan sorotan dari teks yang dipilih, menambahkan catatan, membuka/menghapus sorotan, dan mencari kata atau frasa di teks hasil ekstraksi termasuk hasil OCR yang telah direview. Sorotan disimpan sebagai JSON lokal atomik dengan versi skema terpisah dari SwiftData progres; PDF sumber tidak ditulis. Locator menyimpan versi file, halaman, offset, panjang, dan kutipan. Sorotan dari versi file lain tidak digambar atau dibuka tanpa review, agar tidak menunjuk teks yang keliru. Saat buku direlink, entri dipindahkan ke identitas buku baru; kegagalan simpan ditampilkan sebagai notice.

Bukti:

- Tes `ReadingAnnotationsTests` lulus untuk simpan, buka ulang, note, locator usang, relink, dan hapus.
- QA UI pada PDF sintetis: pencarian “Kanan 2” menampilkan dua hasil dan membuka kalimat pada halaman kedua; memilih “Kiri 2 kalimat satu”, membuat sorotan, menyimpan catatan, menutup/membuka ulang buku, dan melihat sorotan serta catatan tetap ada.

Sisa gate: anotasi EPUB yang stabil lewat CFI, pencarian semua bab EPUB, koleksi buku lintas folder, migrasi/backup data anotasi, konflik relink, dan pengujian PDF nyata dengan pilihan multi baris/rotasi. Reset Progres dan Penanda tidak menghapus catatan yang dibuat pengguna.
