# B01 — OCR PDF untuk bacaan

Status per 11 Oktober 2026: **sebagian, belum melewati gate kualitas corpus**.

Reader sekarang menawarkan **Kenali Teks Halaman** pada halaman PDF tanpa teks. OCR memakai Vision lokal hanya untuk halaman tersebut, menampilkan teks dalam lembar review yang dapat dikoreksi, lalu menyimpan hasil pada cache berversi. Halaman PDF yang sudah memiliki teks tetap memakai pemetaan seleksi PDFKit. Hasil OCR yang belum dikoreksi dapat ditandai lokasinya di PDF saat dibacakan; hasil yang diedit tetap dapat dibaca dari tampilan teks tanpa mengklaim lokasi kalimat yang tepat. PDF sumber tidak ditulis.

Bukti saat ini:

- Tes model PDF campuran memverifikasi hanya halaman kosong yang diisi OCR, urutan segmen halaman lain tidak berubah, cache pulih saat dimuat ulang, hasil koreksi tersimpan, versi file yang berubah ditolak, dan bytes PDF sumber tetap sama.
- QA UI pada PDF raster sintetis dua halaman mengenali dua kalimat Indonesia dan dua kalimat Inggris sesuai acuan. Lembar review tampil, satu kalimat Inggris dikoreksi, tombol Putar aktif, sorotan lokasi muncul pada kalimat yang belum dikoreksi, dan teks hasil OCR tersedia setelah buku dibuka ulang.
- PDF gambar kosong menampilkan pesan bahwa OCR tidak menemukan teks dan tetap dapat dinavigasi.

Sisa gate: ukur akurasi pada corpus PDF scan berizin dengan variasi resolusi, tipografi, kemiringan, bahasa Indonesia/Inggris, dan halaman campuran; periksa posisi sorotan pada halaman berotasi; ukur latensi/memori pada file besar; uji pembatalan ketika pindah halaman saat Vision sedang berjalan. Urutan dua kolom dan penyaringan header/footer adalah B02. OCR ini tidak memakai pipeline terjemahan manga B03.
