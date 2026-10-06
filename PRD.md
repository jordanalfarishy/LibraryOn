# PRD — LibraryOn

| Atribut | Nilai |
| --- | --- |
| Versi | 2.2 — gate M1 fondasi pustaka |
| Tanggal | 6 Oktober 2026 |
| Nama aplikasi | LibraryOn |
| Platform | Aplikasi native macOS, minimum macOS 14; Apple Silicon untuk MVP |
| Fokus | Membaca dan mendengarkan PDF/EPUB dengan text-to-speech; terjemahan manga PDF per halaman pada P1 |
| Status | Build 0.4.0 (12) tersedia; gate M0 dan M1 lulus, verifikasi beta tetap berjalan |

## 1. Ringkasan produk

LibraryOn adalah aplikasi Mac untuk membuka folder berisi ebook, menjelajahi subfolder dan buku di dalamnya, lalu membaca atau mendengarkan melalui text-to-speech (TTS). Buku dibuka langsung dari lokasi aslinya. Pengguna dapat mengikuti sorotan kalimat yang sedang dibacakan, mulai mendengarkan dari bagian tertentu, dan melanjutkan posisi terakhir ketika membuka aplikasi kembali. Setelah MVP, pustaka juga direncanakan dapat menampilkan file video dan membukanya di aplikasi pemutar default yang dipilih pengguna, tanpa memutar video di dalam LibraryOn.

**Janji produk:** “Buka folder buku Anda, pilih bacaan, lalu tekan Play.”

MVP berfokus pada PDF berbasis teks dan EPUB reflowable tanpa DRM, penjelajahan folder yang cepat, serta suara sistem yang dapat digunakan offline setelah tersedia di perangkat. File ebook tetap di folder pengguna; aplikasi hanya menyimpan indeks, sampul, cache pemrosesan, pengaturan, dan progres. Saat diluncurkan kembali, aplikasi menampilkan folder terakhir agar pengguna langsung dapat memilih buku.

Keputusan yang telah dikonfirmasi pengguna: nama aplikasi LibraryOn; akses koleksi melalui beberapa folder pustaka yang dapat dipilih langsung, tanpa alur impor buku satu per satu; sampul buku memakai halaman pertama; kontrol Reader berada di bawah; seleksi teks dapat menjadi titik mulai TTS; setiap buku menampilkan progres baca. Pengguna juga menginginkan terjemahan manga PDF yang diproses saat halaman dibuka dan, setelah MVP, daftar video yang membuka pemutar default. Aplikasi direncanakan untuk penggunaan pribadi di Mac, dengan bahasa bacaan Indonesia dan Inggris, tanpa akun, sinkronisasi, atau pemrosesan dokumen di server. Riset referensi berasal dari dokumentasi resmi; belum ada benchmark langsung terhadap aplikasi pesaing.

### Status implementasi per 6 Oktober 2026

Status di bawah merujuk pada kode prototipe yang ada, **bukan** tanda bahwa acceptance criteria dan pengujian rilis sudah lulus. `Ada` berarti alur dasar tersedia; `Sebagian` berarti fungsi utama ada tetapi masih ada batas penting; `Belum` berarti belum dibuat.

| Area | Status | Yang tersedia saat ini | Batas yang masih ada |
| --- | --- | --- | --- |
| Pustaka folder | Sebagian | Beberapa folder akar dengan akses persisten, indeks lokal berversi, scan bertahap, watcher, relink buku hilang, dan konfirmasi isi berubah; sidebar, breadcrumb, grid/daftar, pencarian nama, urutan nama/terakhir dibaca/terakhir diubah, serta progres per buku; root dan subfolder pulih saat relaunch | Benchmark p95 1.000 buku, drag-and-drop langsung di build sandbox, serta audit keyboard/VoiceOver menyeluruh masih menjadi validasi beta |
| Sampul dan identitas visual | Ada | Pratinjau halaman pertama PDF/EPUB sebagai sampul; ikon terang/gelap dari `AppIcon` dengan margin Dock; aksen aplikasi mengikuti ikon | Beberapa halaman EPUB yang tidak dapat dirender masih memakai placeholder |
| PDF Reader | Sebagian | Tampilan asli/teks, halaman atas/bawah, zoom muat halaman/lebar/tinggi dan persentase, outline, seleksi kata untuk mulai TTS | Belum ada OCR untuk TTS umum, penataan dua kolom, atau klasifikasi halaman campuran |
| EPUB Reader | Sebagian | EPUB 2/3 reflowable tampil pada build sandbox dengan bab, daftar isi, CFI, footnote, font, spasi, dan tema; konten HTTP/HTTPS diblokir; EPUB dengan skrip/interaksi aktif ditolak dengan pesan jelas | Belum ada dukungan fixed-layout/interaktif; uji ragam buku nyata, sesi panjang, dan ketahanan semua locator masih diperlukan |
| Terjemahan manga PDF | Sebagian | Tombol Reader pada macOS 15+, OCR halaman aktif, pilihan Jepang → Indonesia/Inggris, terjemahan lokal, panel hasil, overlay sementara untuk gambar dan layer teks, sakelar Asli/Terjemahan, fallback per dialog, dan cache lokal maksimal 20 halaman; persiapan model bahasa serta statusnya berada di jendela utama agar tetap terlihat saat panel ditutup | Baru diuji dengan PDF sintetis; unduhan model yang belum terpasang, tulisan vertikal/furigana, halaman berotasi, kecocokan overlay pada manga nyata, latensi, memori, dan alur UI menyeluruh belum divalidasi |
| Kontrol data lokal | Sebagian | Bersihkan Cache menghapus data yang dapat dibangun ulang; Reset Progres dan Penanda memakai konfirmasi terpisah; tes memastikan cache tidak menghapus progres | Belum diuji dengan koleksi besar dan skenario proses aktif/akses folder hilang |
| TTS | Sebagian | Suara sistem, play/pause, kalimat sebelum/sesudah, slider kecepatan, sorotan aktif; kontrol bawah dengan player di tengah | Preview suara, bahasa per buku, media keys, dan uji audio panjang belum ada |
| Posisi dan penanda | Sebagian | Halaman visual PDF dan indeks kalimat audio disimpan terpisah; EPUB memakai CFI dan indeks kalimat; bookmark PDF/EPUB dapat dibuat, dibuka, dihapus | Resume dari offset kata terseleksi, validasi locator saat isi file berubah, dan uji reopen/crash menyeluruh belum ada |
| Bar progres per buku | Sebagian | Grid/daftar menampilkan bar posisi untuk setiap file: halaman/total halaman PDF, bab/total bagian EPUB, atau kosong sebelum dibuka | Persentase EPUB masih perkiraan berbasis bab; belum mengukur posisi di dalam bab dan belum menguji migrasi data pada semua instalasi lama |
| Aksesibilitas dan distribusi | Sebagian | Cmd+O, Enter, panah halaman PDF, label kontrol dasar, build aplikasi lokal bertanda tangan ad-hoc | Audit VoiceOver/keyboard, signing pengembang, notarization, dan uji Mac bersih belum ada |

Build dan tes otomatis saat pembaruan ini: **44 tes lulus** mencakup corpus M0, pemetaan PDF, identitas 1.000 buku, akses root, indeks persisten, batch scan, rekonsiliasi file, izin subfolder, watcher, relink, sampul, seleksi teks, posisi/penanda, progres, kontrol data, OCR/overlay/cache manga, dan state unduhan bahasa. [GitHub Actions run #2](https://github.com/jordanalfarishy/LibraryOn/actions/runs/37440973472) lulus untuk tes, build, signature, dan entitlement pada commit akhir M1. Sintesis suara Indonesia/Inggris tanpa jaringan menghasilkan frame audio dan callback. EPUB 2/3 serta volume QA terlepas/terpasang diverifikasi pada aplikasi sandbox. Detail ada di [validasi M0](Docs/M0-validation.md) dan [validasi M1](Docs/M1-validation.md). Hasil ini belum membuktikan alur UI unduhan model yang belum terpasang, kualitas manga nyata, atau target rilis di Bagian 8.

**Kemajuan B03 — sebagian:** Pipeline halaman aktif sudah berjalan dari PDFKit ke Vision dan Translation framework. Hasil tampil pada panel dan overlay sementara PDF gambar/layer teks yang dapat dimatikan tanpa menulis ke file sumber; latar overlay telah diperiksa lewat render PDF. Berpindah halaman membatalkan pekerjaan sebelumnya dan cache lokal dibatasi 20 halaman, dapat dipakai setelah proses baru, serta dibedakan menurut versi file, halaman, bahasa, dan pipeline. Respons batch dicocokkan ke dialog melalui ID; kegagalan batch memicu percobaan per dialog, sementara blok yang gagal mempertahankan teks asli. Persiapan model dipindahkan dari panel ke jendela utama; indikator status tetap tampil ketika panel ditutup dan memantau hingga model tersedia, dengan tindakan Coba Lagi. Pasangan Jepang → Indonesia berhasil diuji secara lokal dengan kalimat sintetis pada Mac pengembangan. B03 tetap belum selesai sampai corpus manga nyata, ketepatan overlay pada ragam tata letak, performa, fallback kegagalan per blok, dan perilaku model yang belum terpasang diverifikasi.

**Kemajuan terbaru — T09, T33, T35:** **Pilih Ulang Folder** mengganti bookmark root aktif tanpa membuat root baru. Indeks disimpan atomik dan dipulihkan saat root tidak tersedia. Uji memverifikasi folder pindah, ID/progres yang bertahan, bookmark stale melalui resolver tiruan, rekonsiliasi add/rename/move/copy/delete, file tidak terbaca, file hilang, isi berubah, dan relink eksplisit yang mempertahankan penanda. QA sandbox memverifikasi volume HFS+ terlepas/terpasang dan pemulihan subfolder. Corpus besar masih menunggu benchmark pada T28.

## 2. Masalah, pengguna, dan hasil yang dituju

### Masalah utama

- Pengguna sudah mengelompokkan buku dalam folder dan ingin memilihnya dengan nyaman tanpa menggandakan atau menyusun ulang koleksi.
- Pengguna ingin menyelesaikan bacaan panjang ketika mata lelah atau sambil melakukan aktivitas lain.
- Perpindahan dari membaca visual ke mendengarkan sering kehilangan konteks dan posisi.
- PDF dapat memiliki urutan teks buruk, header berulang, atau halaman scan sehingga hasil TTS tidak nyaman.
- Manga PDF sering berupa gambar; teks dialog perlu dikenali dan diterjemahkan tanpa memproses seluruh buku sekaligus atau menutupi gambar secara permanen.
- Banyaknya pengaturan suara dan fitur tambahan dapat menghambat tindakan sederhana: buka buku lalu dengarkan.

### Pengguna sasaran

| Pengguna | Kebutuhan utama | Hasil yang dituju |
| --- | --- | --- |
| Pembaca ebook pribadi | Mendengarkan buku milik sendiri | Menyelesaikan bacaan secara bertahap tanpa kehilangan posisi |
| Mahasiswa dan pembelajar | Mengikuti teks sembari mendengarkan | Menavigasi dan mengulang bagian yang belum dipahami |
| Profesional | Membaca dokumen panjang saat bekerja | Beralih antara audio dan teks dengan cepat |
| Pembaca manga | Memahami dialog pada halaman PDF bergambar | Melihat terjemahan halaman yang sedang dibaca sambil tetap dapat memeriksa teks asli |
| Pengguna yang membutuhkan bantuan membaca | Kontrol yang jelas, keyboard, VoiceOver | Mengakses alur inti tanpa bergantung pada mouse |

**User story utama:** Sebagai pembaca, saya ingin memilih folder koleksi, menelusuri subfolder dan sampul buku, membuka PDF atau EPUB, lalu mendengarkan dari kalimat yang saya pilih. Ketika kembali ke aplikasi, folder dan posisi bacaan saya tetap tersedia.

## 3. Referensi dan arah diferensiasi

| Referensi | Temuan yang relevan | Penerapan yang diusulkan |
| --- | --- | --- |
| [Voice Dream Reader](https://apps.apple.com/us/app/voice-dream-reader/id972112040) | Pembaca Mac dengan TTS, PDF/EPUB, dan mengikuti teks yang dibacakan | Membaca dan mendengarkan menjadi satu alur utama |
| [Speech Central](https://apps.apple.com/us/app/speech-central-text-to-speech/id1223093645) | Kontrol suara dan pembersihan elemen PDF | Pemrosesan dokumen serta kebijakan offline yang jelas |
| [Readest](https://www.readest.com/docs/listen) | Pemutar ringkas, navigasi kalimat, dan sorotan teks | Kontrol audio dekat dengan area baca |
| [Readwise Reader](https://docs.readwise.io/reader) | Pustaka berbagai format, highlight, dan catatan | Pustaka sederhana yang bisa berkembang menjadi alur belajar |
| [NaturalReader](https://help.naturalreaders.com/en/articles/11511024-reading-and-listening-options-personal-version) | OCR untuk scan dan pemrosesan ulang teks PDF | Status kesiapan dokumen dan pemulihan saat teks tidak bisa dibaca |

Hipotesis pembeda: aplikasi yang terasa nyaman di Mac, menampilkan koleksi sesuai susunan folder pengguna, langsung dapat dipakai tanpa akun, dan konsisten menjaga posisi baca/dengar. Kualitas pelafalan Indonesia dan Inggris harus dibuktikan melalui pengujian; belum diklaim lebih baik dari pesaing.

## 4. Cakupan dan prioritas

P0 wajib untuk MVP. P1 adalah pengembangan setelah MVP. P2 adalah eksplorasi berikutnya. Semua fitur P0 merupakan syarat rilis, kecuali cakupan diubah secara eksplisit setelah validasi teknis.

### P0 — MVP

- Pilih folder pustaka melalui directory picker atau drag-and-drop folder. Beberapa folder akar dapat terdaftar dan dipilih dari sidebar; satu akar aktif pada satu waktu. Pengguna dapat kembali ke folder terakhir.
- Telusuri hierarki subfolder melalui sidebar dan breadcrumb; area utama menampilkan folder dan buku dalam grid sampul atau daftar.
- Buka PDF teks dan EPUB 2/3 reflowable tanpa DRM langsung dari file sumber, tanpa menyalin ebook ke pustaka aplikasi.
- Ingat folder akar, subfolder terakhir, mode grid/daftar, urutan, dan posisi scroll. Peluncuran berikutnya kembali ke Library, dengan akses cepat ke bacaan terakhir.
- Pencarian nama file/judul/penulis dalam subfolder beserta turunannya atau seluruh folder pustaka; perubahan file melalui Finder diperbarui otomatis.
- PDF dengan tampilan asli serta tampilan teks untuk mendengarkan; EPUB dengan font, ukuran, spasi, dan tema yang dapat diatur.
- Navigasi halaman PDF, daftar isi jika tersedia, serta bab EPUB.
- TTS suara sistem; pilih bahasa/suara, preview suara, play/pause, kalimat sebelumnya/berikutnya, dan kecepatan.
- Sorotan kalimat aktif, ikuti bacaan otomatis, serta perintah mulai membaca dari teks yang dipilih.
- Penyimpanan posisi baca dan posisi audio secara terpisah, lalu pemulihan pada sesi berikutnya.
- Bookmark sederhana dengan cuplikan teks.
- Keyboard shortcuts, label VoiceOver, light/dark mode, dan pengaturan lokal.
- Pesan kegagalan yang dapat ditindaklanjuti untuk dokumen tidak didukung, hasil scan, file rusak, dan suara tidak tersedia.

### P1 — setelah MVP

- OCR lokal untuk PDF scan dan halaman campuran; urutan teks dua kolom serta penyaringan header/footer yang dapat ditinjau.
- **Terjemahan manga PDF otomatis per halaman:** setelah pengguna mengaktifkan mode ini, halaman yang dibuka menjalankan OCR dan terjemahan lokal, lalu menampilkan hasil di atas/di samping halaman tanpa mengubah file asli. Bahasa awal Jepang → Indonesia jika pasangan bahasa tersedia pada perangkat; pengguna dapat memilih pasangan lain yang didukung.
- Kamus pelafalan, penyorotan per kata, sleep timer, dan kontrol media sistem.
- Highlight permanen, catatan, pencarian isi buku, koleksi/tag, dan ekspor anotasi.
- Format TXT/DOCX; ekspor audio dengan progres dan pembatalan setelah kemampuan engine lokal divalidasi.

### P2 — eksplorasi

- Mode manga lanjutan: penataan balon yang lebih alami, koreksi teks hasil OCR, dan pembacaan panel otomatis setelah akurasinya terbukti.
- Model suara lokal tambahan dan audiobook berbab.
- Daftar file video di pustaka folder dan pembukaan file melalui aplikasi pemutar default. Pelacakan progres video lintas pemutar dieksplorasi terpisah.

### Di luar cakupan awal

Pembuatan/editing ebook, toko buku, DRM removal, voice cloning, kolaborasi, Windows/Android, dan pengenalan suara bukan bagian dari MVP. **Sinkronisasi cloud/online, akun, suara berbasis server, unggah dokumen untuk OCR/terjemahan, dan fitur impor web tidak masuk roadmap PRD ini.** Satu-satunya kebutuhan jaringan yang mungkin muncul untuk fitur manga adalah unduhan awal model bahasa oleh macOS setelah persetujuan pengguna; tanpa model yang sudah terpasang, fitur tidak mengirim halaman ke layanan online sebagai pengganti. Penggabungan beberapa folder akar menjadi satu katalog serta operasi rename, move, dan delete file sumber dari aplikasi juga di luar MVP; pengguna mengelola file melalui Finder. Beberapa akar tetap dapat didaftarkan dan dinavigasi satu per satu. EPUB fixed-layout, buku interaktif, teks vertikal/RTL untuk alur EPUB, serta pembacaan makna tabel/rumus/gambar belum dijanjikan. PDF terkunci belum didukung; pengguna diminta menyediakan file yang bisa diakses.

## 5. Batas dukungan dokumen

| Jenis dokumen | Perilaku MVP |
| --- | --- |
| PDF teks satu kolom | Dukungan utama untuk membaca, ekstraksi teks, TTS, dan posisi |
| PDF teks dengan layout kompleks | Dapat dibuka; TTS bersifat best effort dengan pratinjau teks. Tidak menjanjikan urutan dua kolom yang benar |
| PDF scan tanpa teks | Dapat ditampilkan; TTS dinonaktifkan dengan alasan “Dokumen ini memerlukan OCR” |
| PDF manga bergambar | Dapat dibuka sebagai PDF biasa pada MVP; mode terjemahan per halaman direncanakan pada P1 dan memerlukan OCR serta pasangan bahasa lokal yang tersedia |
| PDF campuran | Tandai halaman tanpa teks. Saat TTS mencapai halaman tersebut, berhenti dan tawarkan melewati halaman; jangan melewatkannya diam-diam |
| EPUB 2/3 reflowable tanpa DRM | Dukungan utama untuk teks, daftar isi, tampilan ulang, dan TTS |
| EPUB ber-DRM atau fixed-layout | Tolak alur membaca dengan penjelasan format yang didukung |
| EPUB dengan font terobfuscasi | Uji secara khusus; jika belum didukung, gunakan font aplikasi. Jangan menyamakan obfuscation font dengan DRM buku |

Batas awal yang diusulkan: 100 MB per file, PDF hingga 1.000 halaman, dan EPUB hingga 500 MB setelah ekstraksi. Batas diverifikasi pada tahap teknis awal. Buku di luar batas tetap terlihat di folder dengan penanda keterbatasan; pembukaannya ditolak sebelum pemrosesan berat dengan pesan yang menyebut batasnya.

Folder pada disk lokal merupakan baseline dukungan. Volume eksternal yang sedang terpasang dapat dipilih; saat volume terlepas, tampilkan status tidak tersedia dan simpan progres. Folder yang memerlukan pengunduhan dari layanan penyimpanan lain tidak termasuk jaminan offline; aplikasi tidak memicu unduhan massal. Network share dan pemulihan identitas lintas volume belum masuk jaminan MVP.

“Siap didengarkan” berarti ada bagian teks yang berhasil dipetakan, bukan jaminan semua halaman telah selesai diproses. Status pemrosesan lanjutan dan halaman bermasalah tetap terlihat.

## 6. Alur pengguna dan layar

### Alur pertama kali

1. Pengguna membuka aplikasi dan melihat tombol **Buka Folder Buku**.
2. Pengguna memilih direktori koleksi. Aplikasi menyimpan akses ke folder tersebut beserta subfoldernya.
3. Library langsung menampilkan subfolder dan file PDF/EPUB yang ditemukan. Sampul dan metadata dimuat bertahap, sementara penelusuran sudah dapat digunakan.
4. Pengguna memilih subfolder, melihat sampul/judul, lalu membuka buku dengan double-click atau Enter; klik sekali memilih item.
5. Buku diproses saat dibuka, lalu pengguna menekan **Play**. Kalimat aktif disorot dan pembacaan berlanjut.
6. Pengguna kembali ke Library untuk memilih buku lain. Subfolder dan posisi scroll tetap sama.

### Membuka aplikasi kembali

Library muncul pada folder akar dan subfolder terakhir, dengan mode tampilan dan urutan sebelumnya. Indeks tersimpan ditampilkan segera, lalu diperiksa ulang di latar belakang. Aplikasi tidak langsung membuka reader; kartu **Lanjutkan Membaca** menyediakan akses ke buku terakhir dan posisinya. Tidak ada audio yang mulai otomatis setelah memilih folder, membuka buku, atau meluncurkan aplikasi.

Jika akses folder masih valid, pengguna tidak perlu memilihnya lagi. Jika folder tidak ditemukan atau izin hilang, tampilkan koleksi tersimpan dengan status tidak tersedia dan tindakan **Pilih Ulang Folder** / **Buka Folder Lain**. Jika hanya subfolder terakhir yang hilang, kembali ke induk terdekat yang masih ada.

### Memilih buku dengan nyaman

- Sidebar menampilkan pohon folder dengan expand/collapse dan penanda folder aktif. Struktur mengikuti folder sumber, bukan kategori buatan aplikasi.
- Grid merupakan tampilan awal: subfolder lebih dahulu, kemudian buku dengan sampul, judul/nama file, format, serta progres. Mode daftar menambahkan penulis, ukuran, dan waktu perubahan.
- Breadcrumb dapat diklik untuk naik ke induk. Tombol kembali memulihkan folder, pilihan item, dan posisi scroll sebelumnya.
- Urutan awal berdasarkan nama secara natural; tersedia judul, terakhir dibaca, dan terakhir diubah. Pilihan disimpan per folder akar.
- Pencarian memiliki cakupan eksplisit **Folder ini + subfolder** atau **Seluruh pustaka**. Hasil menyertakan path relatif agar buku bernama sama dapat dibedakan. Saat indeks belum lengkap, tampilkan status pencarian sementara dan perbarui hasil saat scan berjalan.
- Shortcut **Terakhir Dibaca**, **Sedang Dibaca**, dan **Selesai** berlaku untuk folder akar aktif. Hasil pencarian/status dapat membuka lokasi folder buku.
- Folder kosong, folder yang belum selesai dipindai, folder tak terbaca, dan pencarian tanpa hasil memiliki tampilan berbeda. File selain format yang didukung disembunyikan; folder biasa tetap dapat dijelajahi.

### Perubahan koleksi melalui Finder

Penambahan, rename, pemindahan, atau penghapusan file diperbarui di Library. Buku yang berganti nama/pindah di dalam folder akar pada volume lokal yang sama mempertahankan progres jika identitas file dapat dikenali. Salinan terpisah tetap menjadi entri terpisah. Jika identitas tidak pasti, sediakan **Temukan Buku**; jangan memasangkan progres berdasarkan kemiripan nama saja.

File atau volume yang tidak tersedia tidak menghapus progres/bookmark. Jika sumber berubah atau hilang saat sedang dibaca, pause audio, simpan posisi, lalu tampilkan tindakan pemulihan. Buku yang isinya berubah diproses ulang; posisi lama hanya dipakai jika pemetaan dapat divalidasi.

### Berpindah dari membaca ke mendengarkan

Pengguna memilih teks lalu menjalankan **Baca dari sini** melalui toolbar atau menu konteks. Di tampilan teks, tindakan per kalimat juga tersedia. Seleksi biasa tetap berfungsi untuk menyalin teks. Pemutar berpindah ke awal kalimat yang dipilih dan membatalkan antrean sebelumnya.

### Menjelajah saat audio berjalan

Scroll atau perpindahan halaman secara manual tidak mengubah posisi audio. Tindakan tersebut menonaktifkan ikuti bacaan otomatis. Tombol **Kembali ke bacaan** memulihkan tampilan ke kalimat aktif. Membuka buku lain menghentikan dan menyimpan sesi buku sebelumnya; MVP hanya memiliki satu sesi audio aktif.

### Menerjemahkan manga PDF per halaman — P1

Di Reader PDF, pengguna mengaktifkan **Terjemahkan Otomatis** dan memilih bahasa tujuan; pilihan awal adalah Indonesia. Halaman asli tampil segera. Hanya halaman yang sedang dibuka yang diproses: gunakan layer teks PDF bila lokasinya valid, atau render halaman untuk OCR bila berupa gambar; teks yang ditemukan dikelompokkan menjadi blok dialog lalu diterjemahkan. Hasil muncul bertahap sebagai teks yang terikat ke area asalnya; jika ruang balon sempit, pengguna dapat membaca hasil lengkap di panel samping. Tombol **Asli / Terjemahan** selalu tersedia, dan file PDF sumber tidak diedit. Saat berpindah halaman, pekerjaan halaman lama dibatalkan dan halaman baru diproses; halaman yang pernah dibuka boleh dimuat dari cache lokal yang tervalidasi, tanpa menerjemahkan seluruh buku di muka.

Alur awal menargetkan Jepang → Indonesia, tetapi pasangan bahasa harus diperiksa pada perangkat dengan `LanguageAvailability`; pasangan yang tidak tersedia menampilkan alasan dan pilihan bahasa lain, bukan diam-diam memakai layanan online. Model bahasa yang belum terpasang hanya diunduh oleh mekanisme sistem setelah persetujuan pengguna. Sesudah terpasang, OCR dan terjemahan berjalan di perangkat tanpa mengirim gambar atau teks manga ke server. Pada macOS 14, Reader biasa tetap tersedia dan kontrol terjemahan menjelaskan bahwa fitur ini memerlukan macOS 15 atau lebih baru. Manga dengan teks vertikal, furigana, huruf bergaya, dan urutan panel yang rumit menjadi corpus validasi; hasil OCR/terjemahan yang tidak yakin ditandai agar pengguna dapat membandingkan dengan halaman asli. Pembacaan TTS atas teks terjemahan serta ekspor PDF terjemahan tidak termasuk versi pertama fitur ini.

Rancangan ini **memungkinkan secara teknis, tetapi kualitas manga belum terbukti**: PDFKit dapat merender halaman, Vision menyediakan hasil OCR beserta lokasinya, dan Translation framework menerjemahkan teks di perangkat. Kemampuan menerjemahkan pasangan bahasa serta kualitas penempatan balon harus dibuktikan pada corpus manga nyata sebelum diberi label selesai. Apple menyatakan terjemahan `TranslationSession` diproses di perangkat, tetapi sistem dapat mengumpulkan metrik penggunaan API tanpa isi teks; kebijakan privasi produk perlu menjelaskan hal itu. [PDFKit](https://developer.apple.com/documentation/PDFKit/PDFPage), [Vision](https://developer.apple.com/documentation/vision/vnrecognizetextrequest), [TranslationSession](https://developer.apple.com/documentation/translation/translationsession), [macOS 15 Translation](https://developer.apple.com/documentation/macOS-Release-Notes/macos-15-release-notes).

### Struktur layar

| Layar/area | Isi utama |
| --- | --- |
| Library sidebar | Folder akar aktif, pohon subfolder, Terakhir Dibaca/Sedang Dibaca/Selesai, Buka Folder Lain |
| Library toolbar | Breadcrumb, kembali, pencarian beserta cakupan, grid/daftar, urutan, dan Segarkan |
| Library utama | Folder, sampul buku, progres, status ketersediaan, serta kartu Lanjutkan Membaca |
| Reader sidebar | Bab/halaman dan bookmark; dapat disembunyikan |
| Reader utama | PDF asli, teks hasil ekstraksi, atau EPUB; sorotan kalimat aktif |
| Mode manga PDF (P1) | Terjemahkan Otomatis, pilihan bahasa, progres per halaman, tampilan Asli/Terjemahan, dan panel hasil yang tidak menimpa file sumber |
| Player bawah | Sebelumnya, Play/Pause, berikutnya, suara, kecepatan, posisi, dan Kembali ke bacaan |
| Settings | Suara default per bahasa, tema, folder terbaru, ukuran/pembersihan cache, dan bantuan |

Prinsip tampilan: konten menjadi pusat perhatian, kontrol audio selalu mudah ditemukan, ikon memiliki label aksesibilitas, dan informasi teknis parser tidak muncul dalam alur normal.

## 7. Kebutuhan fungsional dan acceptance criteria

| ID | Kebutuhan | Kriteria penerimaan |
| --- | --- | --- |
| FR-01 | Buka folder dan akses persisten | Directory picker dan drop folder mendaftarkan folder akar yang dapat dibaca. Buku tetap di lokasi asal. Folder yang sama tidak didaftarkan ganda; relaunch tidak meminta pilih ulang ketika akses masih valid |
| FR-02 | Pemindaian bertahap | Tampilkan item yang sudah ditemukan sebelum seluruh subtree selesai. Membuka buku tidak menunggu metadata seluruh koleksi. Scan dapat dibatalkan/dilanjutkan; error satu subfolder tidak menghentikan yang lain atau menghapus indeks/progres sebelumnya |
| FR-03 | Penjelajah folder dan buku | Sidebar hierarki, breadcrumb, grid/daftar, sorting, dan pencarian bercakupan bekerja. Folder dan buku dapat dipilih dengan mouse/keyboard. Judul kosong memakai nama file; sampul kosong memakai placeholder; hasil search menunjukkan path |
| FR-04 | PDF reader | Pengguna bisa berpindah halaman, zoom, membuka outline jika ada, dan beralih tampilan asli/teks. Pemilihan kalimat di teks dapat dikembalikan ke halaman asal |
| FR-05 | EPUB reader | Bab mengikuti spine buku; TOC dan tautan internal menuju lokasi yang benar. Perubahan font, ukuran jendela, dan spasi tidak menghilangkan posisi |
| FR-06 | Ekstraksi dan segmentasi | Teks diproses bertahap dan dipecah menjadi kalimat. Penggabungan baris/paragraf tidak menghilangkan keterkaitan dengan sumber. Tidak ada halaman tanpa teks yang dilompati diam-diam |
| FR-07 | Play/Pause/Resume | Pause menghentikan audio dan resume melanjutkan dalam sesi yang sama. Akhir bagian berlanjut ke bagian berikutnya tanpa klik tambahan pada dokumen yang didukung |
| FR-08 | Pemilihan suara/bahasa | Daftar hanya berisi suara yang benar-benar tersedia melalui API. Ada preview dan override bahasa per buku. Suara hilang memunculkan pilihan pengganti; jangan diam-diam memakai bahasa berbeda |
| FR-09 | Kecepatan dan navigasi audio | Tersedia kontrol dari Lambat hingga Cepat dengan nilai Normal. Sebelumnya/berikutnya bergerak satu kalimat. Perubahan suara/kecepatan dimulai ulang dari awal kalimat aktif dan tidak memutar antrean lama |
| FR-10 | Sorotan dan posisi sumber | Tampilan teks/EPUB menyorot kalimat yang sedang dibaca. PDF asli memakai sorotan jika pemetaan valid; jika tidak valid, tawarkan tampilan teks tanpa menggambar sorotan yang keliru |
| FR-11 | Baca dari sini | Perintah pada teks menghentikan sesi lama dan memulai kalimat target. Seleksi teks dan copy tetap dapat digunakan tanpa memicu audio |
| FR-12 | Ikuti bacaan | Scroll manual menghentikan auto-follow tanpa menghentikan suara. Kembali ke bacaan memusatkan kalimat aktif dan mengaktifkan follow lagi |
| FR-13 | Resume lintas sesi | Posisi disimpan pada pergantian kalimat, pause, pindah buku, dan quit. Setelah relaunch/crash, resume paling jauh mengulang satu kalimat tersimpan dan tidak autoplay |
| FR-14 | Bookmark | Pengguna dapat menyimpan, membuka, dan menghapus bookmark. Cuplikan dan lokasinya tetap benar setelah resize atau perubahan font |
| FR-15 | Folder terbaru dan cache | Ganti folder akar menyimpan posisi serta menghentikan audio/scan akar sebelumnya, dengan progres per folder tetap tersimpan. Hapus dari Folder Terbaru mencabut referensi akses serta menghentikan pekerjaan folder itu, tanpa menghapus buku atau progres. Bersihkan Cache hanya menghapus data yang dapat dibangun ulang; reset progres/bookmark adalah tindakan terpisah dengan konfirmasi |
| FR-16 | Offline dan privasi | Jelajah, baca, bookmark, dan TTS bekerja tanpa jaringan ketika folder/file lokal tersedia serta suara sudah terpasang. Tidak ada upload dokumen, akun, atau analytics pihak ketiga pada MVP |
| FR-17 | Keyboard dan aksesibilitas | Cmd+O membuka folder; Enter membuka item terpilih; panah menavigasi Library; Cmd+[ kembali. Space play/pause berlaku di Reader saat fokus bukan input teks; Option+panah kiri/kanan navigasi kalimat. Semua tindakan tersedia lewat menu/VoiceOver |
| FR-18 | Lifecycle aplikasi | Minimize tidak memutus audio selama Mac terjaga. Quit atau penutupan jendela utama menyimpan lalu menghentikan sesi. Setelah sleep atau perangkat audio terputus, kembali dalam keadaan pause |
| FR-19 | Kegagalan yang dapat dipulihkan | File rusak/terkunci, folder tak dapat diakses, volume terlepas, suara hilang, dan ekstraksi gagal memiliki pesan spesifik serta tindakan coba ulang/pilih ulang folder/temukan buku/pilih suara yang relevan |
| FR-20 | Pembaruan koleksi | Add/rename/move/delete melalui Finder tercermin otomatis saat aplikasi aktif. Segarkan memindai ulang. Rekonsiliasi setelah relaunch/wake memulihkan perubahan yang terlewat tanpa menduplikasi entri |
| FR-21 | Identitas dan sumber berubah | Rename/move teridentifikasi dalam akar pada volume yang sama mempertahankan progres. Salinan berbeda tidak digabung. Sumber hilang ditandai tidak tersedia; isi berubah membatalkan cache lama, pause sesi, dan memvalidasi posisi sebelum dilanjutkan |
| FR-22 | Restore penjelajahan | Relaunch kembali ke Library pada folder/subfolder terakhir beserta grid/daftar, sorting, dan scroll. Kembali dari Reader memulihkan konteks pemilihan buku. Indeks belum terverifikasi ditandai, bukan dianggap sudah mutakhir |
| FR-23 (P1) | Auto-translate manga PDF lokal | Setelah mode diaktifkan, hanya halaman aktif yang diekstrak/OCR dan diterjemahkan. Halaman asli tampil saat proses berlangsung; pindah halaman membatalkan pekerjaan lama. Teks hasil terkait dengan area asal, dapat dibandingkan dengan teks asli, dan kesalahan per blok tidak menghilangkan sisa hasil. Cache dibedakan menurut versi file, halaman, bahasa, dan versi pipeline. Pasangan bahasa/model tidak tersedia menghasilkan pesan dan tindakan yang jelas; tidak ada unggah halaman atau teks |
| FR-24 | Progres pada setiap buku | Grid dan daftar selalu menunjukkan bar posisi baca per PDF/EPUB. PDF memakai halaman aktif ÷ total halaman; EPUB menampilkan estimasi menurut bagian spine dan diberi label perkiraan. Buku belum dibuka menunjukkan bar kosong. Nilai dipertahankan setelah keluar/relaunch dan reset melalui tindakan Reset Progres |

Progres merupakan lokasi saat ini dalam alur teks, bukan jumlah unik konten yang sudah didengarkan. Nilai EPUB berbasis bab adalah estimasi karena panjang bab tidak sama. Pengguna dapat menandai selesai secara manual; menyelesaikan bagian terakhir yang didukung menandai selesai otomatis. Buku yang memiliki halaman scan yang dilewati tidak otomatis dianggap sudah seluruhnya didengarkan.

## 8. Target kualitas dan ukuran keberhasilan

Angka berikut adalah target penerimaan yang diusulkan, bukan hasil benchmark. Baseline: Mac Apple Silicon M1, RAM 8 GB, SSD lokal, release build, suara sudah terpasang, PDF/EPUB biasa berukuran maksimal 20 MB. Setiap pengukuran mencatat versi macOS dan suara.

| ID | Aspek | Target / cara ukur |
| --- | --- | --- |
| NFR-01 | Peluncuran | Library tersimpan interaktif ≤ 3 detik pada p95 dari 20 peluncuran, folder lokal dengan 1.000 buku di 100 subfolder; verifikasi koleksi berjalan di latar belakang |
| NFR-02 | Waktu mulai mendengarkan | Dari tombol Play hingga audio pertama ≤ 2 detik pada p95 dari 20 percobaan dengan teks siap; dari memilih Buka Buku pada file lokal referensi hingga bagian pertama siap ≤ 10 detik |
| NFR-03 | Respons kontrol | Respons visual play/pause ≤ 100 ms dan pause/stop audio ≤ 500 ms pada 20 percobaan |
| NFR-04 | Stabilitas | Sesi 60 menit dan 100 perpindahan kalimat tidak crash, memutar dua suara, kehilangan urutan, atau terus menaikkan memori tanpa batas |
| NFR-05 | Memori | Target peak gabungan aplikasi dan proses WebKit < 500 MB untuk file referensi; ukur ulang pada file batas. Pemrosesan besar harus tetap bisa dibatalkan |
| NFR-06 | Urutan bacaan | Pada 20 dokumen dukungan utama, semua transisi bab/halaman sampel benar dan ≥ 95% dari 400 kalimat referensi berurutan serta terpetakan benar |
| NFR-07 | Ketahanan posisi | Semua skenario restart, pause, resize, font change, dan pemulihan crash di corpus utama mempertahankan posisi sesuai FR-13 |
| NFR-08 | Offline | Alur inti lulus dengan jaringan dimatikan setelah suara tersedia; pemeriksaan jaringan tidak menemukan permintaan konten EPUB jarak jauh atau upload buku |
| NFR-09 | Kualitas suara | Uji dengar Indonesia dan Inggris dengan minimal 5 pengguna. Target median kenyamanan ≥ 4/5 per bahasa; catat suara dan versi OS, termasuk pelafalan angka, singkatan, nama, dan paragraf panjang |
| NFR-10 | Respons Library | Pada corpus 1.000 buku/100 subfolder, batch pertama terlihat ≤ 2 detik setelah folder lokal diberi akses; pindah folder terindeks ≤ 300 ms dan hasil pencarian indeks ≤ 500 ms, p95 dari 20 percobaan |
| NFR-11 | Pembaruan folder | Pada disk lokal, perubahan Finder terlihat ≤ 5 detik setelah operasi selesai dalam ≥ 19 dari 20 percobaan; scan terputus/izin ditolak tidak dianggap sebagai penghapusan file |
| NFR-12 (P1) | Respons terjemahan manga | Reader tetap dapat dinavigasi selama OCR/terjemahan; perpindahan halaman membatalkan pekerjaan lama tanpa menampilkan hasil pada halaman yang salah. Latensi per halaman, penggunaan memori, akurasi OCR, dan keterbacaan terjemahan diukur pada corpus manga sebelum ambang rilis ditetapkan |

Uji kegunaan beta: minimal 4 dari 5 pengguna dapat pilih folder → temukan buku di subfolder → buka → Play → pause → pilih/lanjutkan buku setelah relaunch tanpa bantuan. Target ini diukur melalui sesi uji yang disetujui peserta; tidak memerlukan telemetry tersembunyi. Jika suara Indonesia tidak memenuhi ambang, jangan mengklaim dukungan nyaman sebelum suara atau cakupan produk diperbaiki.

## 9. Tech stack yang direkomendasikan

Prototipe saat ini memakai Swift Package Manager/SwiftUI, PDFKit, WKWebView dengan epub.js 0.3.93 lokal, ZIPFoundation 0.9.20, AVSpeechSynthesizer, NLTokenizer, FSEvents, SwiftData untuk progres dan penanda, UserDefaults untuk daftar root serta state penjelajah, dan indeks JSON berversi di Application Support. Tes memakai XCTest. Workflow GitHub Actions macOS sudah lulus. NLLanguageRecognizer, Swift Testing, OSLog/Instruments, atau DMG bertanda tangan pengembang masih **rencana**, belum implementasi terverifikasi.

### Stack MVP

| Lapisan | Pilihan | Alasan dan batasan |
| --- | --- | --- |
| Bahasa/toolchain | Swift 6, Xcode stabil yang mendukung deployment target macOS 14 | Integrasi framework macOS; pin versi Xcode pada CI ketika proyek dibuat |
| UI aplikasi | SwiftUI + AppKit melalui NSViewRepresentable | Library, settings, toolbar native; AppKit untuk integrasi PDFView dan interaksi desktop |
| Akses folder | NSOpenPanel, security-scoped bookmarks, entitlement user-selected read-only dan app-scope bookmarks | Akses persisten hanya ke folder pilihan pengguna; resolve/refresh izin saat relaunch, mulai/akhiri akses sesuai lifetime pekerjaan |
| Indeks folder | FileManager enumeration + URL resource values | Daftar folder/file bertahap, file identity dan version signature; metadata/sampul dimuat sesuai kebutuhan |
| Pemantauan folder | FSEvents + rekonsiliasi saat launch/wake/Segarkan | Perubahan subtree menjadi pemicu scan; event bukan sumber kebenaran tunggal |
| PDF | PDFKit: PDFDocument, PDFPage, PDFView, PDFSelection | Render, navigasi, ekstraksi, dan lokasi teks; urutan baca kompleks tetap memerlukan logika tambahan |
| EPUB | WKWebView + epub.js yang dibundel lokal; entitlement network.client dan WKContentRuleList untuk blokir HTTP/HTTPS | Render reflowable, TOC, dan EPUB CFI pada sandbox; izin koneksi proses WebKit diperlukan, tetapi buku tidak boleh memuat resource jarak jauh; EPUB berskrip ditolak |
| Arsip EPUB | ZIPFoundation + FileManager | Ekstraksi bertahap ke direktori milik buku dengan pembatasan ukuran dan validasi path |
| TTS | AVFoundation/AVFAudio: AVSpeechSynthesizer, AVSpeechUtterance, AVSpeechSynthesisVoice | Suara sistem dan kontrol ucapan; gunakan yang tersedia di runtime |
| Bahasa dan kalimat | NaturalLanguage: NLTokenizer, NLLanguageRecognizer | Segmentasi dan saran bahasa; pengguna tetap dapat override |
| Metadata persisten | SwiftData untuk progres/penanda; UserDefaults untuk root/state penjelajah; JSON berversi di Application Support untuk indeks folder/buku | Pemisahan data bacaan dari indeks yang dapat dipindai ulang; indeks ditulis atomik dan kegagalan tulis tidak menghapus daftar aktif |
| File/cache | File sumber dibaca di folder pengguna; Application Support untuk data persisten, Caches untuk sampul/ekstraksi | Tidak membuat salinan ebook permanen atau sidecar di folder pengguna; cache berversi dapat dibangun ulang |
| Preferensi | UserDefaults untuk preferensi sederhana | Tema, sidebar, serta suara default; bukan tempat file atau teks buku |
| Concurrency | Swift Concurrency, actor untuk scan/rekonsiliasi/cache | Pekerjaan dibatasi dan dapat dibatalkan; UI serta framework yang memerlukan main actor tetap di main actor |
| Dependency/build | Swift Package Manager dengan ZIPFoundation vendored 0.9.20; epub.js lokal 0.3.93 | Versi dan lisensi dependency disimpan di repo; tidak ada dependency CDN. Karena dependency SwiftPM lokal, tidak ada Package.resolved eksternal |
| Pengujian | Swift Testing untuk domain; XCTest/XCUITest untuk integrasi dan UI | Corpus dokumen, posisi, antrean audio, lifecycle, dan alur pengguna |
| Diagnosis/performa | OSLog, signpost, Instruments | Log lokal tanpa isi dokumen; ukur latensi, memory, dan resource leak |
| CI dan distribusi | GitHub Actions runner macOS dengan SwiftPM; signed/notarized DMG untuk beta | Workflow tes/build/verifikasi bundle lulus pada GitHub; penandatanganan distribusi memerlukan akun/sertifikat pemilik |
| Backend | Tidak digunakan | Buku, posisi, TTS, OCR, dan terjemahan yang direncanakan diproses di perangkat; tidak ada layanan sinkronisasi aplikasi |

Security-scoped bookmarks dipakai untuk mempertahankan akses folder pilihan pengguna lintas peluncuran. Bookmark akses macOS berbeda dari bookmark halaman bacaan. Pengelolaan start/stop akses dan penyegaran bookmark yang stale termasuk tanggung jawab aplikasi. [Dokumentasi NSURL](https://developer.apple.com/documentation/foundation/nsurl), [entitlement App Sandbox](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html).

FSEvents memberi sinyal perubahan yang dapat digabung atau terlewat. Aplikasi melakukan scan ulang sesuai flag, termasuk pemindaian penuh bila event hilang, serta rekonsiliasi saat kembali aktif. [Panduan FSEvents Apple](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html).

PDFKit menyediakan objek seleksi dan rentang teks yang dapat menjadi dasar pemetaan sumber. Pemilihan stack ini tidak berarti PDFKit menjamin urutan baca semua PDF. [Dokumentasi PDFSelection](https://developer.apple.com/documentation/pdfkit/pdfselection).

AVSpeechSynthesizer menyediakan antrean utterance dan kontrol pause/resume/stop, sedangkan delegate memberi kejadian ucapan. Controller aplikasi tetap harus mengelola navigasi, pembatalan, dan posisi lintas sesi. [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer), [delegate](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate).

Parameter rate Apple bukan pengali durasi audio yang terjamin, dan perubahan setelah utterance diantrekan tidak mengubah utterance tersebut. Karena itu MVP memakai skala Lambat–Normal–Cepat; label 1,5×/2× hanya ditambahkan setelah kalibrasi yang dapat dipertanggungjawabkan. [Dokumentasi rate](https://developer.apple.com/documentation/avfaudio/avspeechutterance/rate).

epub.js menyediakan rendering serta lokasi CFI. Pemakaian di WKWebView, pemetaan kalimat, dan restore posisi adalah pekerjaan integrasi yang perlu divalidasi. ZIPFoundation menyediakan akses arsip ZIP dari Swift. [epub.js](https://github.com/futurepress/epub.js), [API lokasi](https://github.com/futurepress/epub.js/blob/master/documentation/md/API.md), [ZIPFoundation](https://github.com/weichsel/ZIPFoundation).

Readium Swift tidak dipilih sebagai default karena dokumentasi getting started berfokus pada iOS/iPadOS; kompatibilitas native macOS tidak diasumsikan. [Readium Swift](https://readium.org/swift-toolkit/latest/documentation/readium/getting-started/).

NaturalLanguage menjadi dasar segmentasi, sedangkan SwiftData menyediakan penyimpanan model lokal. [Segmentasi kalimat](https://developer.apple.com/documentation/naturallanguage/nltokenunit/sentence), [SwiftData](https://developer.apple.com/documentation/swiftdata).

### Stack tahap berikutnya

- Render dan OCR manga: PDFKit lebih dulu memakai layer teks yang memiliki lokasi valid; untuk halaman gambar, PDFKit merender halaman aktif pada resolusi yang memadai dan Apple Vision (`VNRecognizeTextRequest`) mengenali teks Jepang beserta kotak lokasinya. Periksa bahasa OCR yang didukung pada OS aktual; uji teks vertikal, furigana, dan balon bergaya sebelum mengklaim kualitas manga. [PDFPage](https://developer.apple.com/documentation/pdfkit/pdfpage/thumbnail%28of%3Afor%3A%29), [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest), [hasil/lokasi OCR](https://developer.apple.com/documentation/vision/vnrecognizedtextobservation).
- Terjemahan manga: Apple Translation framework (`TranslationSession`) pada macOS 15+, memproses blok teks di perangkat. `LanguageAvailability` memeriksa Jepang → Indonesia dan pasangan lain saat runtime; model yang belum terpasang memerlukan unduhan sistem dengan persetujuan pengguna. Tidak ada fallback jaringan ke penyedia eksternal. [TranslationSession](https://developer.apple.com/documentation/translation/translationsession), [LanguageAvailability](https://developer.apple.com/documentation/translation/languageavailability), [unduhan model](https://developer.apple.com/documentation/translation/translating-text-within-your-app).
- Tampilan dan cache: overlay SwiftUI/AppKit yang diposisikan dari koordinat OCR ke `PDFView`; simpan hasil per versi konten + nomor halaman + bahasa + versi OCR/terjemahan di Caches. Overlay tidak disimpan sebagai anotasi dalam PDF sumber.
- Video pasca-MVP: `UniformTypeIdentifiers` untuk mengenali jenis file, `NSWorkspace.open(_:)` untuk menyerahkan file ke aplikasi pemutar default, dan Quick Look Thumbnailing hanya bila thumbnail lokal diperlukan. AVPlayer dapat mengukur posisi **hanya jika pemutaran berada di dalam kendali aplikasi/integrasi yang tersedia**, sehingga jalur pemutar eksternal tidak diberi janji progres otomatis. [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace), [AVPlayer dan pengamatan progres](https://developer.apple.com/documentation/avfoundation/monitoring-playback-progress-in-your-app).

## 10. Arsitektur dan model data

### Aliran data

```text
Directory picker / drop folder
          ↓
FolderAccessService → security-scoped bookmark
          ↓
DirectoryIndexer ← FolderWatcher + rekonsiliasi
          ↓
Library → pohon folder + grid/daftar buku
          ↓ pengguna membuka buku
SourceResolver → file sumber + versi konten
          ↓
PDFAdapter / EPUBAdapter
          ↓
ReadingDocument → TextSegment + SourceLocator
          ↓
PlaybackController → AppleSpeechEngine → audio
          ↓ event kalimat aktif
ReaderCoordinator → sorotan + auto-follow
          ↓
ProgressRepository → SwiftData
```

Modul utama: `Library`, `FolderAccess`, `DirectoryIndex`, `Reader`, `DocumentProcessing`, `Speech`, `Persistence`, dan `Settings`. Pada P1, `MangaTranslation` menerima hanya halaman PDF aktif dan menjalankan render → OCR → pengelompokan teks → terjemahan lokal → overlay. Adapter dokumen dan speech engine memiliki antarmuka terpisah agar format/suara baru tidak mengharuskan perubahan seluruh UI. Arsitektur tetap satu aplikasi tanpa layanan server.

| Entitas | Data inti |
| --- | --- |
| LibraryRoot | ID, display name, bookmark akses macOS, volume identity, resolved URL terakhir, status akses, waktu scan |
| FolderNode | rootID, identitas direktori, parentID, path relatif, status scan; struktur mencerminkan sumber |
| Book | ID, rootID, folderID, path relatif, file/volume identity bila tersedia, size/mtime, fingerprint konten bertahap, format, judul/penulis, cover, status ketersediaan, waktu pertama ditemukan/buka |
| LibraryViewState | rootID, subfolder terakhir, folder expanded, grid/daftar, sorting, scope pencarian, selected bookID, scroll anchor |
| ReadingDocument | bookID, versi extractor, daftar bagian, kemampuan, issue per halaman/bagian |
| TextSegment | ID stabil dalam versi ekstraksi, urutan, sectionID, teks ucapan, source spans, bahasa |
| SourceLocator | PDF: indeks halaman + rentang UTF-16, bisa beberapa halaman; EPUB: spine href + CFI range; cuplikan teks untuk pemulihan |
| ReadingProgress | viewLocator, audioLocator, segmentID, suara, rate, timestamp; posisi visual dan audio tidak saling menimpa |
| Bookmark | ID, bookID, sourceLocator, cuplikan, judul opsional, waktu dibuat |
| BookPreferences | Override bahasa/suara, tampilan teks, font, spasi, dan tema bila berbeda dari default |
| MangaPageTranslationCache (P1) | bookID, versi file, indeks halaman, bahasa asal/tujuan, versi OCR/model, blok teks asal/hasil, kotak lokasi, status/kesalahan; dapat dibangun ulang dan tidak mengubah PDF |

File asli di folder pengguna merupakan sumber kebenaran. ID buku tidak menggunakan path atau hash isi sebagai satu-satunya identitas: rename dapat mengubah path, sedangkan dua salinan identik tetap merupakan dua entri. Gunakan file/volume identity bila andal, locator lokasi, dan fingerprint konten saat diperlukan. Hash seluruh koleksi tidak menjadi syarat untuk menampilkan Library.

Segmen dan sampul disimpan sebagai cache dengan kunci bookID + content version + extractor version. Saat ini SwiftData menyimpan progres/penanda bacaan, UserDefaults menyimpan bookmark akses root dan state penjelajah, dan JSON di Application Support menyimpan indeks yang dapat dibangun ulang. Saat isi file berubah, prototipe meminta konfirmasi untuk membuka dari awal sambil mempertahankan penanda. Pencocokan locator/cuplikannya yang lebih presisi menjadi pekerjaan T23; posisi lama tidak dipakai diam-diam. Progres pada sumber yang hilang tetap disimpan sampai pengguna memilih reset data.

### Kontrak posisi dan audio

- Normalisasi spasi, pemenggalan baris, dan penyatuan kalimat harus menyimpan pemetaan balik ke rentang sumber; jangan memakai offset teks bersih langsung pada PDF asli.
- PDF memakai range UTF-16 untuk integrasi NSRange. Uji karakter aksen, emoji, ligature, dan kalimat yang melintasi halaman.
- EPUB memakai locator CFI yang tetap valid setelah font/ukuran berubah. Highlight harus tidak merusak struktur yang dipakai CFI; validasi pada prototype.
- Satu kalimat menjadi unit navigasi. Kalimat sangat panjang boleh dipotong menjadi beberapa utterance internal dengan identitas kalimat yang sama.
- Antrean audio terbatas pada beberapa segmen ke depan. Seek, perubahan suara, dan pindah buku menaikkan session token agar callback lama tidak mengubah sesi baru.
- State audio: `idle → preparing → playing ↔ paused → finished`, dengan `failed` untuk error. Pause/resume dalam sesi memakai posisi engine; pemulihan setelah aplikasi berhenti dimulai dari awal kalimat tersimpan.
- Jangan menjanjikan timestamp detik atau durasi tepat untuk suara yang belum disintesis. MVP menampilkan bab/halaman dan progres teks; estimasi waktu, jika ditambahkan, harus diberi label estimasi.

### Pemrosesan file dan konten lokal

Pemindaian hanya mengindeks folder/file: tidak menyalin semua buku, mengekstrak semua EPUB, atau menyiapkan TTS seluruh koleksi. Prioritaskan isi folder aktif, sampul yang terlihat, dan buku yang dibuka; pekerjaan lanjutan memakai concurrency terbatas. File tersembunyi, package aplikasi, symlink, dan alias tidak diikuti secara rekursif pada MVP agar traversal tidak berputar atau keluar dari folder yang dipilih.

Watcher melakukan debounce lalu memicu rekonsiliasi area yang berubah. Scan mencatat status berhasil/gagal per direktori; file hanya dinyatakan hilang setelah area terkait selesai dipindai dengan akses valid. Kehilangan izin, volume terlepas, atau scan dibatalkan tidak boleh menyebabkan penghapusan massal indeks. Saat scan selesai, perubahan dibukukan secara konsisten ke database.

Sebelum membuka file atau melanjutkan audio, verifikasi akses, keberadaan sumber, dan version signature. Saat memproses, periksa apakah sumber berubah; hasil yang berasal dari versi tidak konsisten dibuang dan dicoba ulang secara terbatas. Isi berubah saat sesi berjalan menyebabkan pause serta invalidasi cache. Jika file tidak tersedia, cache tidak menjadi pengganti buku offline secara diam-diam.

Rename/move pada volume yang sama dicocokkan menggunakan identitas yang tersedia. Jika identitas berubah karena file diganti atau dipindah lintas volume, lakukan relink eksplisit dan verifikasi fingerprint/isi sebelum menerapkan progres lama. Folder akar yang sama dipilih ulang memulihkan catatan sebelumnya bila identitasnya dapat diverifikasi; folder berbeda dibuat sebagai root baru.

Semua penulisan aplikasi terbatas pada database dan cache di container sendiri. Cache ditulis atomik, dapat dibersihkan, dan tidak membuat file pendamping di direktori buku. Pada kegagalan disk penuh, hentikan pekerjaan cache dan tampilkan tindakan pemulihan tanpa mengubah sumber atau menghilangkan progres yang telah tersimpan.

Pipeline manga P1 memprioritaskan halaman yang terlihat. Setiap permintaan membawa ID buku, versi konten, indeks halaman, dan generation token; hasil dari halaman atau versi lama dibuang. OCR dan terjemahan satu halaman tidak memblokir navigasi atau TTS Reader. Cache lokal dibatasi ukurannya, dapat dihapus tanpa menghapus buku/progres, dan invalid saat PDF atau konfigurasi bahasa berubah. Tidak ada unggah gambar maupun teks hasil OCR.

EPUB diperlakukan sebagai konten tidak tepercaya: batasi hasil ekstraksi dan jumlah entry, tolak path keluar direktori/symlink yang tidak aman, serta tolak EPUB dengan skrip/event handler aktif sebelum WebView dibuka. WKContentRuleList memblokir HTTP/HTTPS dan hanya bridge aplikasi yang dibundel diizinkan. Resource lokal disajikan melalui handler terkontrol; jangan membuka akses file sistem umum dari WebView. Tautan eksternal hanya dibuka setelah tindakan pengguna.

## 11. Risiko dan keputusan yang perlu divalidasi

| Risiko | Dampak | Mitigasi / gate |
| --- | --- | --- |
| Suara Indonesia berbeda antarperangkat/OS | Janji utama kurang nyaman | Enumerasi suara aktual, uji offline serta uji dengar; jangan mengasumsikan suara Siri atau semua suara premium dapat dipakai |
| Urutan teks PDF tidak sesuai tampilan | Audio membingungkan | Corpus satu kolom sebagai baseline; pratinjau teks, status keterbatasan, dan pengujian dua kolom pada P1 |
| Render EPUB di WKWebView tidak stabil | Resume atau sorotan salah | Prototype offline, CFI, font, ukuran jendela, footnote, dan bab panjang sebelum implementasi penuh |
| Rate atau callback engine berbeda | Sorotan/seek tertinggal | Sorotan kalimat sebagai baseline, session token, dan pengujian suara/OS yang didukung |
| Dokumen besar memblokir UI | Aplikasi terasa macet | Pekerjaan bertahap, pembatalan, batas input, cache, dan pengukuran memory |
| Folder besar dan banyak sampul | Pemilihan buku lambat | Indeks bertahap, lazy loading, concurrency terbatas, dan benchmark 1.000 buku |
| Folder dipindah, izin berubah, atau volume terlepas | Buku tidak bisa dibuka | Resolve bookmark, status unavailable, pilih ulang/relink; pertahankan progres |
| Perubahan file terlewat atau isi diganti | Indeks dan posisi tidak valid | Rekonsiliasi, version signature, invalidasi cache, dan validasi locator sebelum resume |
| Parser diperbarui | Posisi lama berubah | Cache berversi, source locator, cuplikan pemulihan, dan uji migrasi |
| OCR manga gagal pada tulisan vertikal, furigana, atau balon bergaya | Terjemahan hilang atau salah urutan | Corpus manga berizin, pembandingan hasil per blok, tampilan asli selalu tersedia; bila Vision tidak memadai, evaluasi model lokal lain sebelum menjanjikan dukungan |
| Pasangan bahasa atau model terjemahan tidak tersedia | Jepang → Indonesia tidak bekerja pada sebagian perangkat | Periksa `LanguageAvailability` saat runtime, uji pada versi macOS sasaran, dan tampilkan pesan/opsi bahasa yang tersedia tanpa layanan online |
| Overlay menutupi gambar atau dialog yang salah | Manga sulit dibaca | Tampilkan hasil yang bisa dibuka/ditutup, panel alternatif, dan verifikasi koordinat/urutan pada corpus; jangan menulis ke PDF sumber |
| Banyak fitur masuk sebelum alur inti stabil | Waktu rilis membesar | P0 menjadi batas MVP; terjemahan manga, OCR, dan anotasi lanjutan dikerjakan pada P1 setelah alur inti stabil |

Keputusan awal yang bisa diterapkan tanpa menunda dokumen: macOS 14+, Apple Silicon, beberapa folder pustaka tersimpan dengan satu folder akar aktif, grid sampul sebagai tampilan awal, UI Bahasa Indonesia dengan struktur lokalisasi, dukungan bacaan Indonesia/Inggris, dan beta DMG. Ikon dari folder `AppIcon` sudah digunakan pada prototipe. Terjemahan manga lokal ditargetkan untuk macOS 15+ pada P1; pengguna macOS 14 tetap dapat membaca PDF biasa. Dukungan Intel, penggabungan beberapa akar folder dalam satu katalog, harga/model bisnis, serta kanal Mac App Store diputuskan setelah validasi MVP.

## 12. Daftar task implementasi

Daftar ini memuat **35 task MVP dan 11 task backlog**. Status **Sebagian** berarti implementasi awal sudah ada tetapi *definition of done* belum terpenuhi; **Belum** berarti task belum dimulai secara berarti; **Selesai** hanya dipakai setelah seluruh kriteria dan verifikasinya lulus. Saat ini **18 task MVP Sebagian, 3 Belum, dan 14 Selesai**. Owner berikut adalah peran, bukan penugasan kepada orang tertentu. Dependensi menyatakan task yang harus selesai sebelum output task dapat dinyatakan tuntas. ID lama dipertahankan; T33–T35 adalah tambahan untuk pustaka folder dan ditempatkan pada milestone terkait.

### Milestone 0 — validasi fondasi

| Status | ID | Task | Owner | Dependensi | Definition of done |
| --- | --- | --- | --- | --- | --- |
| Selesai | T01 | Tetapkan corpus dokumen, folder, dan skenario uji | Product + QA | — | 30 dokumen uji berizin/sintetis, kalimat referensi, hierarki folder, serta dataset indeks 1.000 buku/100 subfolder tersedia |
| Selesai | T02 | Prototype suara Apple Indonesia/Inggris | Engineer + QA | T01 | Play/pause/rate/seek/callback diuji offline; daftar suara dan kekurangan terukur |
| Selesai | T03 | Prototype PDF extraction dan source mapping | Engineer | T01 | PDF satu kolom, Unicode, pemenggalan baris, dan lintas halaman bisa disorot dari segmen |
| Selesai | T04 | Prototype EPUB dalam WKWebView | Engineer | T01 | EPUB 2/3 offline, TOC, CFI, resize, font, footnote, dan pembatasan konten lulus; dependency dipin |
| Selesai | T33 | Prototype akses folder persisten dan identitas file | Engineer + QA | T01 | Pilih root, relaunch, bookmark stale, rename/move, volume terlepas, dan pilih ulang diuji pada build sandbox; batas dukungan tercatat |
| Selesai | T05 | Putuskan kesiapan stack dan ambang awal | Product + Engineer | T02–T04, T33 | Hasil akses folder, risiko, batas ukuran, dan keputusan lanjut/perbaiki terdokumentasi |

**Gate M0 per 6 Oktober 2026: lulus.** EPUB 2/3, pembatasan konten jarak jauh, penolakan EPUB aktif, suara/PDF, dan volume pustaka terlepas/terpasang telah diperiksa pada build QA sandbox. Batas ukuran yang belum ditegakkan dan pengujian rilis tetap tercatat di [validasi M0](Docs/M0-validation.md). M1 ditutup berdasarkan [validasi M1](Docs/M1-validation.md); benchmark dan audit rilis berada pada M4.

### Milestone 1 — fondasi aplikasi dan pustaka

| Status | ID | Task | Owner | Dependensi | Definition of done |
| --- | --- | --- | --- | --- | --- |
| Selesai | T06 | Wireframe penjelajah folder, Library, Reader, Player, dan error states | Design + Product | T05 | Pilih folder → telusuri grid/daftar → buka → dengar → kembali/relaunch dapat ditinjau dengan keyboard |
| Selesai | T07 | Buat proyek SwiftUI, modul, sandbox, dan CI | Engineer | T05 | Build macOS 14+ berhasil; dependency/asset terkunci; CI menjalankan build dan tes dasar |
| Selesai | T08 | Implementasikan schema dan repository lokal | Engineer | T07 | Root, folder nodes, file identity/version, browser state, posisi terpisah, dan bookmark tersedia |
| Selesai | T09 | Implementasikan folder picker, akses persisten, dan indeks bertahap | Engineer | T08, T33 | FR-01/02 lulus; folder ganda, scan batal, izin subfolder ditolak, dan penyimpanan indeks gagal tertangani |
| Selesai | T10 | Buat pohon folder, breadcrumb, grid/daftar, pencarian, progres buku, dan restore Library | Engineer | T06, T08, T09 | FR-03/22/24 lulus; placeholder tampil saat metadata belum siap; kembali dari Reader mempertahankan konteks dan bar progres |
| Selesai | T34 | Implementasikan watcher dan rekonsiliasi folder | Engineer | T09 | FR-20 lulus; add/rename/move/delete serta event terlewat diperiksa ulang tanpa duplikasi/penghapusan keliru |
| Selesai | T35 | Implementasikan identitas buku, versi konten, dan relink | Engineer | T08, T09, T34 | Rename lokal mempertahankan ID; copy tetap terpisah; source missing dan content changed dikenali serta progres tersimpan |
| Selesai | T11 | Kelola folder terbaru, reset data, dan pembersihan cache | Engineer | T08, T09 | FR-15 lulus; lepas root menghentikan pekerjaan/sesi; sumber tetap utuh dan bersihkan cache mempertahankan progres |

**Gate M1 per 6 Oktober 2026: lulus untuk fondasi pustaka.** Build **0.4.0 (12)** memakai nama LibraryOn; bundle ID `com.joalfa.pdfspeech` dan kunci data lama dipertahankan untuk kontinuitas. Indeks lokal berversi tampil saat relaunch dan diverifikasi ulang di latar belakang. Scan batch 50 item, watcher, relink, rekonsiliasi file/izin, folder ganda, root offline, dan kegagalan penyimpanan diuji. QA sandbox memverifikasi dua root, navigasi panah, subfolder dan progres yang pulih, klik tunggal memilih buku, klik ganda/Enter membuka Reader, serta Enter dalam pencarian tidak membuka buku. [GitHub Actions](https://github.com/jordanalfarishy/LibraryOn/actions/workflows/macos.yml) menjalankan tes, build, signature, dan entitlement; hasil awal lulus dan bukti lengkap ada di [validasi M1](Docs/M1-validation.md). Pengukuran kinerja 1.000 buku, drag-and-drop UI langsung, migrasi lintas instalasi, dan audit VoiceOver penuh tetap pada M4; gate M1 tidak berarti beta siap rilis.

### Milestone 2 — mesin dokumen dan reader

| Status | ID | Task | Owner | Dependensi | Definition of done |
| --- | --- | --- | --- | --- | --- |
| Sebagian | T12 | Buat ReadingDocument, TextSegment, locator, dan cache berversi | Engineer | T03–T05, T08 | Kontrak kedua format sama; cache memakai versi sumber/extractor dan pemetaan dapat diuji |
| Sebagian | T13 | Bangun adapter PDF dan tampilan asli | Engineer | T12, T09 | Halaman, zoom, outline, klasifikasi scan/campuran, dan mapping bekerja |
| Sebagian | T14 | Bangun normalisasi dan segmentasi kalimat | Engineer | T12 | Baris terpotong, singkatan, Unicode, dan lintas halaman diuji dengan referensi |
| Sebagian | T15 | Bangun tampilan teks PDF dan perpindahan ke sumber | Engineer | T13, T14, T06 | FR-04/06 terpenuhi; tidak ada sorotan palsu ketika mapping gagal |
| Sebagian | T16 | Bangun adapter/render EPUB lokal dan bridge | Engineer | T04, T12, T14 | FR-05 terpenuhi; konten jarak jauh/skrip buku terblokir; struktur buku tetap terbaca |
| Sebagian | T17 | Tambahkan navigasi bab/halaman, tema, dan tipografi | Engineer | T15, T16 | Resize/font tidak memindahkan locator; tema tidak merusak keterbacaan |

### Milestone 3 — pengalaman mendengarkan

| Status | ID | Task | Owner | Dependensi | Definition of done |
| --- | --- | --- | --- | --- | --- |
| Sebagian | T18 | Bangun SpeechEngine dan PlaybackController | Engineer | T02, T12, T14 | State, queue terbatas, cancel, session token, dan akhir dokumen teruji |
| Sebagian | T19 | Implementasikan picker/preview suara dan bahasa per buku | Engineer | T18, T08 | FR-08 lulus termasuk suara hilang dan bahasa tanpa suara |
| Sebagian | T20 | Buat player, rate, dan previous/next sentence | Engineer | T18, T06 | FR-07/09 lulus; klik cepat tidak menghasilkan audio tumpang tindih |
| Sebagian | T21 | Integrasikan sorotan aktif pada PDF teks/asli dan EPUB | Engineer | T15, T16, T18 | FR-10 lulus dengan pemetaan sumber dan callback sesi yang benar |
| Sebagian | T22 | Implementasikan Baca dari sini, auto-follow, dan kembali ke bacaan | Engineer | T20, T21 | FR-11/12 lulus; seleksi dan scroll manual tetap nyaman |
| Sebagian | T23 | Simpan/pulihkan posisi audio dan visual | Engineer | T08, T17, T18, T35 | FR-13 lulus pada relaunch/crash, rename file, dan perubahan tampilan; sumber berubah tidak menerima locator lama tanpa validasi |
| Sebagian | T24 | Implementasikan bookmark dan navigasinya | Engineer | T17, T23 | FR-14 lulus pada dua format dan setelah reopen |
| Sebagian | T25 | Tangani lifecycle, audio terputus, dan sumber berubah/hilang | Engineer | T20, T23, T34, T35 | FR-18/21 lulus; volume terlepas atau isi berubah saat play menyebabkan pause dan pemulihan yang jelas |

### Milestone 4 — verifikasi dan beta

| Status | ID | Task | Owner | Dependensi | Definition of done |
| --- | --- | --- | --- | --- | --- |
| Sebagian | T26 | Lengkapi Settings, keyboard, VoiceOver, dan empty/error states | Engineer + Design | T10–T25, T34, T35 | FR-17/19 lulus; fokus input tidak mengambil shortcut pemutar; akses folder yang hilang memiliki pemulihan |
| Sebagian | T27 | Uji alur inti otomatis dan integrasi dengan corpus | QA + Engineer | T11, T17, T20–T26 | Semua FR memiliki bukti uji; posisi, pergantian sesi, scan parsial, dan rekonsiliasi folder tercakup |
| Belum | T28 | Benchmark Library, pembaruan folder, audio, dan memori | QA + Engineer | T27 | NFR-01–07 serta NFR-10/11 terukur; pelanggaran diperbaiki atau target direvisi secara eksplisit |
| Sebagian | T29 | Uji offline, WebView, akses folder, dan pembersihan cache | QA + Engineer | T27 | FR-16/NFR-08 lulus; tidak ada request konten remote, traversal di luar root berizin, atau modifikasi file sumber |
| Belum | T30 | Uji kegunaan dan suara bersama minimal 5 pengguna | Product + QA | T28, T29 | Target kegunaan dan NFR-09 diukur; temuan penghambat tercatat |
| Belum | T31 | Perbaiki temuan penghambat dan jalankan ulang uji terdampak | Engineer + QA | T30 | Tidak ada kegagalan P0 terbuka; regresi area perubahan lulus |
| Sebagian | T32 | Siapkan build beta, signing, notarization, dan panduan | Engineer + Product | T31 | Paket bisa diinstal di Mac bersih; lisensi dependency dan batas format jelas |

### Backlog pasca-MVP

| Status | ID | Prioritas | Task | Dependensi / gate |
| --- | --- | --- | --- | --- |
| [ ] | B01 | P1 | OCR lokal, halaman campuran, dan review hasil | T32; akurasi serta bahasa Vision diverifikasi |
| [ ] | B02 | P1 | Reading order dua kolom dan filter header/footer | T32; corpus tambahan dan mapping sumber tetap benar |
| Sebagian | B03 | P1 | Auto-translate manga PDF lokal per halaman: ekstraksi/OCR Jepang, pemeriksaan pasangan bahasa, terjemahan, overlay, cache, dan pembatalan saat pindah halaman | T32, B01; FR-23/NFR-12 lulus pada corpus manga tanpa unggah dokumen |
| [ ] | B04 | P1 | Kamus pelafalan dan sorotan kata | T32; engine TTS dan pemetaan sumber mendukung timing yang dibutuhkan |
| [ ] | B05 | P1 | Sleep timer dan media keys/Now Playing | T32; lifecycle serta tombol sistem teruji |
| [ ] | B06 | P1 | Highlight permanen, catatan, pencarian isi, dan koleksi | T32; locator stabil dan uji migrasi |
| [ ] | B07 | P1 | Dukungan TXT/DOCX dan ekspor audio | T32; adapter format dan kemampuan/lisensi ekspor engine lokal tervalidasi |
| [ ] | B08 | P2 | Penyempurnaan manga: koreksi OCR, tata balon, dan urutan panel | B03; manfaat dan akurasi diuji pada manga berizin |
| [ ] | B09 | P2 | Suara lokal tambahan dan audiobook berbab | T32; kualitas, resource perangkat, serta kebutuhan pengguna terbukti |
| [ ] | B10 | P2 | Tampilkan file video di folder pustaka sebagai item daftar/grid dengan judul, format, dan thumbnail/placeholder; tombol Putar membuka file di aplikasi pemutar default macOS | T32; ekstensi/UTType didukung, akses security-scoped tervalidasi, file hilang/format tanpa pemutar menampilkan pesan, dan tidak ada pemutar video internal |
| [ ] | B11 | P2 | Progres video: sediakan status manual atau integrasi khusus pemutar yang mendukung pengembalian posisi; tampilkan bar video hanya jika sumber progres jelas | B10; uji integrasi per pemutar dan jangan mengklaim sinkronisasi otomatis universal |

**Batas progres video:** Membuka file melalui `NSWorkspace` menyerahkan pemutaran ke aplikasi lain. LibraryOn tidak menerima posisi waktu dari semua pemutar default. Progres otomatis hanya layak dijanjikan jika video diputar oleh player yang kita kendalikan atau ada integrasi khusus dengan player tertentu; pilihan backlog saat tetap memakai pemutar eksternal adalah progres manual, status “sudah dibuka”, atau bar yang dinonaktifkan sampai posisi yang sah tersedia.

Rincian pekerjaan B03 agar status prototipe tidak disamakan dengan fitur siap rilis:

| Status | Subtask B03 | Bukti / langkah berikutnya |
| --- | --- | --- |
| Selesai pada prototipe | OCR halaman aktif dan lokasi teks PDF gambar/layer teks | Tes PDF sintetis untuk halaman gambar dan teks lulus |
| Selesai pada prototipe | Pemetaan hasil terjemahan ke dialog, panel, sakelar asli, dan overlay sementara | Respons batch diuji dalam urutan berbeda; render latar/teks dan pemulihan halaman asli diuji tanpa mengubah file |
| Selesai pada prototipe | Cache lokal berversi dan dibatasi 20 halaman | Tes baca ulang dari instans baru, versi file berbeda, dan batas file lulus |
| Sebagian | Terjemahan Jepang → Indonesia/Inggris dan pembatalan saat pindah halaman | API Jepang → Indonesia berhasil untuk kalimat sintetis; alur UI penuh, unduhan model, dan pembalikan cepat belum diverifikasi |
| Belum | Validasi kualitas manga dan target kinerja | Siapkan corpus 20 halaman, ukur OCR, overlay, latensi, memori, teks vertikal/furigana, serta kegagalan per blok |

## 13. Rencana pengujian dan syarat rilis

Corpus M0 yang tersedia berisi 30 file sintetis: 10 PDF teks satu kolom, 10 EPUB reflowable (campuran EPUB 2/3), dan 10 kasus batas/negatif termasuk Unicode, pemenggalan baris, scan/gambar, dua kolom, file rusak, marker DRM, fixed-layout, serta EPUB dengan resource/skrip eksternal. File terkunci dan file sebesar ambang batas belum dibuat. Teks acuan 400 kalimat berbahasa Indonesia; variasi bahasa Inggris masih perlu ditambahkan untuk QA rilis.

Dataset penjelajahan M0 memuat 1.000 entri buku sintetis dalam 100 subfolder, termasuk hierarki dua tingkat, nama Unicode, judul sama pada 100 lokasi, dan duplikat isi. Volume image HFS+ terlepas/terpasang kembali telah diuji pada build sandbox. Direktori yang izinnya dicabut diuji otomatis pada M1 dan tidak menghapus buku/progres yang sudah diindeks; folder kosong, file non-ebook, serta symlink/alias tetap memerlukan uji UI lanjutan. Dataset ini untuk menguji fungsi indeks/Library, bukan menggantikan corpus kualitas bacaan atau pengukuran latensi p95.

QA menyiapkan 20 kalimat acuan per dokumen dukungan utama (400 total), termasuk lokasi dan urutan yang benar. Semua transisi bab dan sampel batas halaman dicatat terpisah. Uji audio nyata melengkapi tes state machine; mock engine tidak cukup untuk menyatakan kualitas suara atau ketepatan callback.

Skenario wajib: pilih folder pertama kali, telusuri subfolder dan breadcrumb, grid/daftar, search bercakupan, buka buku, kembali ke Library, restore subfolder/scroll saat relaunch, scan batal/parsial, rename/move/copy/delete melalui Finder, file diganti pada path sama, folder akar dipindah, izin dicabut, volume terlepas, reconnect, dan event watcher terlewat. Verifikasi bahwa kasus tidak tersedia tidak menghapus progres dan bahwa sumber tidak berubah setelah memakai aplikasi atau membersihkan cache.

Pengujian bacaan tetap mencakup suara belum terpasang, jaringan mati, dokumen scan, kalimat lintas halaman, pergantian suara saat play, klik next berulang, navigasi visual saat audio berjalan, resize EPUB, reopen/crash, sleep, perangkat audio terputus, disk penuh, dan file berubah saat sesi aktif.

Sebelum B03 dinyatakan selesai, siapkan corpus manga PDF berizin/sintetis yang mencakup minimal 20 halaman Jepang dengan tulisan horizontal/vertikal, furigana, balon kecil, efek suara, teks di atas gambar, dan beberapa urutan panel. Catat akurasi OCR, kecocokan pasangan Jepang → Indonesia, keterbacaan overlay, waktu proses tiap halaman, pembatalan saat membalik cepat, penggunaan cache, dan perilaku offline setelah model sistem terpasang. Jika kualitas belum memadai, tampilkan keterbatasan dan jangan menjanjikan terjemahan penuh otomatis.

**Syarat beta:** seluruh FR P0 dan target NFR lulus atau direvisi secara eksplisit dalam versi PRD baru; tidak ada masalah kehilangan data, audio tumpang tindih, posisi berpindah diam-diam, atau kegagalan offline yang belum diselesaikan. Distribusi eksternal memerlukan signing/notarization dan sumber daya akun pengembang dari pemilik proyek.

## 14. Estimasi dan urutan pelaksanaan

Estimasi revisi untuk satu macOS engineer berpengalaman dengan dukungan design/QA paruh waktu: **9–14 minggu untuk MVP P0**, belum termasuk terjemahan manga P1, antrean review toko, pengadaan akun/sertifikat, dan perubahan besar setelah prototype. Tambahan dibanding v1.0 mencakup penjelajah folder, pemantauan perubahan, serta pemulihan identitas/akses. Estimasi manga ditetapkan sesudah uji OCR tulisan vertikal dan pasangan bahasa pada perangkat sasaran; estimasi MVP diperbarui setelah T05.

| Tahap | Kisaran waktu | Hasil |
| --- | --- | --- |
| Validasi fondasi | 1–2 minggu | Bukti akses folder persisten, suara, PDF mapping, dan EPUB native integration |
| Fondasi aplikasi/pustaka | 2–3 minggu | Directory browser, akses folder, indeks/watcher, database, dan desain alur |
| Reader dan dokumen | 2–3 minggu | Dua format dapat dibaca dan dipetakan |
| Pengalaman mendengarkan | 2–3 minggu | Player, sorotan, navigasi, resume, dan bookmark |
| Verifikasi dan beta | 2–3 minggu | Hasil QA folder dan bacaan, perbaikan, dan build distribusi |

Rentang total mengasumsikan sebagian desain dan verifikasi berjalan bersamaan dengan implementasi; durasi baris tidak dijumlahkan secara kaku. Langkah implementasi pertama adalah T01–T04 dan T33, ditutup dengan keputusan T05, kemudian fondasi aplikasi sesuai dependensi.
