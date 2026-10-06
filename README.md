# LibraryOn

Aplikasi macOS untuk menjelajahi folder PDF/EPUB dan mendengarkannya dengan suara sistem. Build lokal saat ini **0.5.2 (16)**.

## Menjalankan

Prasyarat: macOS 14 atau lebih baru, Xcode, dan Apple Silicon.

```bash
bash Scripts/build-app.sh
open "dist/LibraryOn.app"
```

Saat pertama kali dibuka, pilih folder yang berisi PDF atau EPUB. Aplikasi mengingat folder tersebut. Buku tetap berada di lokasi asal; data progres dan cache berada di container aplikasi.

Build mengambil ikon terbaru dari `AppIcon/Icons-iOS-Default-1024@1x.png` dan `Icons-iOS-Dark-1024@1x.png` untuk varian terang/gelap, lalu memberi margin yang sesuai untuk ikon macOS. Build mendaftarkan ulang aplikasi agar ikon Dock/Finder diperbarui. Buka ulang aplikasi setelah build.

## Cakupan build saat ini

- Penjelajah subfolder, grid/daftar, pencarian nama, folder terakhir, serta pembaruan saat folder berubah melalui Finder.
- Folder pustaka dapat ditambahkan dengan memilih folder atau menyeretnya dari Finder ke jendela LibraryOn. Hasil pemindaian muncul per batch, sehingga pustaka besar mulai terlihat sebelum scan selesai.
- Beberapa folder pustaka tetap terlihat di bagian atas panel samping; tiap folder mengingat posisi penjelajahnya sendiri. Panah atas/bawah memilih folder, panah kanan/kiri membuka dan menutup subfolder. Kartu buku memakai pratinjau halaman pertama yang disimpan di cache.
- Klik tunggal memilih kartu buku; klik ganda, tombol **Buka buku terpilih**, atau Enter membukanya. Buku dapat diurutkan berdasarkan nama, terakhir dibaca, atau terakhir diubah.
- Setiap buku menampilkan bar posisi baca di grid, daftar, dan kartu lanjutkan. PDF memakai halaman dari total halaman; EPUB memakai perkiraan berdasarkan bab dari total bagian spine. Buku yang belum dibuka menunjukkan bar kosong; buku lama menghitung total saat kartunya tampil.
- Jika folder pustaka dipindah atau aksesnya hilang, **Pilih Ulang Folder** mengganti lokasi pada entri pustaka yang sama. Buku yang masih memiliki identitas file yang sama mempertahankan progres dan penanda; memilih folder yang sudah terdaftar sebagai pustaka lain ditolak.
- Indeks pustaka disimpan lokal agar daftar buku dan subfolder langsung muncul saat aplikasi dibuka. Daftar lama ditandai sampai pemindaian ulang selesai. Buku yang hilang tetap ditampilkan agar progresnya bisa dihubungkan ke file pengganti; perubahan isi buku meminta konfirmasi sebelum posisi baca dimulai ulang.
- Folder pustaka juga dapat diganti dari menu toolbar saat Reader terbuka; perpindahan memuat ulang tampilan Library untuk folder tujuan.
- PDF dengan tampilan asli atau teks, TTS suara macOS, sorotan kalimat, dan progres. Ekstraksi teks berjalan di latar belakang; teks serta antrean TTS tersedia bertahap dan disimpan dalam cache berversi. Halaman tanpa teks ditandai dan tidak dilompati otomatis. Tampilan teks bisa diseleksi untuk menyalin, memulai bacaan per kalimat, atau kembali ke posisi kalimat pada PDF.
- EPUB 2/3 reflowable tampil pada build sandbox dengan daftar isi, navigasi bab, CFI, dan TTS per bab. Pemetaan teks per bab disimpan dalam cache berversi. Konten HTTP/HTTPS dari buku diblokir; EPUB dengan skrip/interaksi aktif ditolak dengan pesan yang jelas. [Validasi M0](Docs/M0-validation.md) dan [M2](Docs/M2-validation.md) merinci pengujian dan batasnya.
- Title bar Reader menampilkan nama buku. EPUB menempatkan navigasi bab, daftar isi, penanda, dan tipografi di sana; PDF menempatkan daftar isi, penanda, serta terjemahan manga di sana. Bar bawah memuat navigasi halaman/tampilan PDF di kiri, pemutar suara di tengah, serta slider kecepatan dan pilihan suara di kanan. Bahasa dan suara dapat dipilih per buku; menu suara menyediakan contoh singkat. Seleksi teks di PDF atau EPUB lalu tekan Putar untuk membaca dari awal seleksi dan meneruskan isi berikutnya.
- Scroll manual pada PDF asli, PDF teks, atau EPUB menghentikan ikuti bacaan otomatis tanpa menjeda suara. Tombol **Kembali ke Bacaan** di kiri bawah memusatkan kalimat aktif dan mengaktifkan ikuti bacaan lagi.
- Pada tampilan asli PDF, pilih Muat Halaman, Muat Lebar, Muat Tinggi, 50–200%, atau 100% dari menu tampilan di kiri bawah. Panah atas/bawah berpindah ke halaman sebelumnya/berikutnya.
- Pada macOS 15 atau lebih baru, tombol gelembung bahasa di Reader PDF membuka **Terjemahan manga**. Aplikasi mengenali teks pada halaman aktif, menerjemahkan Jepang ke Indonesia atau Inggris memakai model bahasa macOS, lalu menampilkan hasil di panel samping dan sebagai overlay sementara pada halaman gambar maupun PDF ber-layer teks. Tombol **Asli/Terjemahan** membandingkan hasil tanpa mengubah PDF. Model bahasa mungkin perlu diunduh sekali melalui persetujuan sistem; status persiapannya tetap terlihat di bawah jendela setelah panel ditutup. Status ini berupa indikator aktivitas, karena Translation framework tidak menyediakan persentase unduhan bagi aplikasi. Setelah model tersedia, teks halaman diproses di perangkat.
- Menu data di Library menyediakan **Bersihkan Cache** untuk data yang dapat dibuat ulang dan **Reset Progres dan Penanda** sebagai tindakan terpisah dengan konfirmasi. EPUB menyediakan pilihan ukuran font, spasi baris, serta tema.
- Reader memulihkan halaman PDF atau lokasi EPUB terakhir tanpa langsung memutar audio. Di title bar, ikon Daftar Isi dan Penanda menyatukan navigasi, penambahan penanda, serta daftar penanda. Posisi visual PDF dan kalimat audio disimpan terpisah; bar bawah tidak menampilkan status kalimat yang berulang.

Ini masih build prototipe. EPUB yang halaman pertamanya hanya berisi fitur yang tidak dapat dirender sebagai gambar atau teks memakai placeholder. Metadata penulis, OCR untuk TTS umum, pemrosesan PDF multi-kolom, pemulihan offset kata terpilih setelah relaunch, dan pengujian besar lintas format belum selesai sesuai [PRD](PRD.md). Terjemahan manga masih eksperimental: tulisan vertikal, furigana, dialog bergaya, halaman berotasi, dan ketepatan posisi overlay belum divalidasi pada corpus manga nyata. Hasil terjemahan tersimpan pada cache lokal hingga 20 halaman dan dapat dihapus oleh macOS saat membersihkan cache aplikasi. Build ini ditandatangani ad-hoc untuk pengujian lokal; distribusi ke perangkat lain memerlukan sertifikat pengembang dan notarization.

Nama aplikasi di layar sekarang LibraryOn. Bundle ID `com.joalfa.pdfspeech` dan kunci data lama tetap dipakai agar pustaka, progres, dan penanda dari build sebelumnya tidak hilang. Dukungan daftar video dan membuka player default direncanakan setelah MVP; posisi video belum dapat dilacak otomatis ketika diputar di aplikasi lain.

## Dependensi

- [ZIPFoundation 0.9.20](https://github.com/weichsel/ZIPFoundation), source dan lisensi di `Vendor/ZIPFoundation`.
- [epub.js 0.3.93](https://github.com/futurepress/epub.js), bundle dan lisensi di `Sources/PDFSpeech/Resources` serta `Licenses`.
