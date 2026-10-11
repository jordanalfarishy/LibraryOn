# B02 — Urutan PDF dua kolom dan header/footer

Status per 11 Oktober 2026: **sebagian**. Kode dan QA sintetis lulus; gate corpus PDF nyata belum diuji.

Reader PDF sekarang memiliki dua pilihan tersimpan per buku: **Baca dua kolom** mengurutkan teks kolom kiri dari atas ke bawah lalu kolom kanan, dan **Lewati header/footer berulang** mengabaikan teks pendek yang sama di pita margin atas/bawah pada sedikitnya dua halaman. Opsi memengaruhi antrean TTS tanpa mengubah PDF atau cache ekstraksi mentah. Halaman berotasi tetap memakai urutan bawaan; filter tidak membuang seluruh isi halaman.

Bukti:

- Tiga tes `PDFTextLayoutTests` lulus. Fixture dua halaman menggambar kalimat kiri/kanan secara berselang-seling dan mengulang header/footer. Hasil setelah kedua opsi aktif tepat empat kalimat isi per halaman dalam urutan kolom yang diharapkan. Setiap rentang masih cocok dengan seleksi PDFKit.
- QA pada aplikasi terpisah membuka fixture dari folder pustaka, mengaktifkan kedua pilihan di toolbar, dan memulai Putar. Sorotan pertama muncul pada “Kiri 1 kalimat satu.”, bukan header. Pemutar tetap dapat dijeda dan buku dapat dibuka ulang.

Sisa gate: periksa PDF nyata dengan jumlah kolom dan margin bervariasi, catatan kaki, header yang berubah, gambar di antara paragraf, halaman campuran/berotasi, serta efek opsi terhadap resume audio. Ambang geometri saat ini konservatif; pengguna dapat mematikan kedua opsi untuk PDF yang tidak sesuai.
