# PRD — LibraryOn

| Atribut | Nilai |
| --- | --- |
| Versi | 3.4 — progres portabel melalui folder cloud pilihan |
| Tanggal | 12 Oktober 2026 |
| Nama aplikasi | LibraryOn |
| Platform | Aplikasi native macOS, minimum macOS 14; Apple Silicon untuk MVP |
| Fokus | Membaca dan mendengarkan PDF/EPUB/TXT/DOCX dengan text-to-speech; video melalui pemutar eksternal, folder cloud melalui Finder, dan terjemahan manga PDF per halaman |
| Status | Build 0.8.0 (23); gate implementasi M0–M3 lulus; verifikasi beta lokal M4, B01–B12, dan B15 berlanjut |

## 1. Ringkasan produk

LibraryOn adalah aplikasi Mac untuk membuka folder berisi ebook, menjelajahi subfolder dan buku di dalamnya, lalu membaca atau mendengarkan melalui text-to-speech (TTS). Buku dibuka langsung dari lokasi aslinya. Pengguna dapat mengikuti sorotan kalimat yang sedang dibacakan, mulai mendengarkan dari bagian tertentu, dan melanjutkan posisi terakhir ketika membuka aplikasi kembali. Pustaka juga menampilkan file video dan membukanya di aplikasi pemutar default macOS, tanpa memutar video di dalam LibraryOn.

**Janji produk:** “Buka folder buku Anda, pilih bacaan, lalu tekan Play.”

MVP berfokus pada PDF berbasis teks dan EPUB reflowable tanpa DRM, penjelajahan folder yang cepat, serta suara sistem yang dapat digunakan offline setelah tersedia di perangkat. File ebook tetap di folder pengguna; aplikasi hanya menyimpan indeks, sampul, cache pemrosesan, pengaturan, dan progres. Saat diluncurkan kembali, aplikasi menampilkan folder terakhir agar pengguna langsung dapat memilih buku.

Keputusan yang telah dikonfirmasi pengguna: nama aplikasi LibraryOn; akses koleksi melalui beberapa folder pustaka yang dapat dipilih langsung, tanpa alur impor buku satu per satu; sampul buku memakai halaman pertama; judul buku dan tindakan bacaan berada di title bar Reader, sedangkan player serta navigasi halaman PDF berada di bawah; seleksi teks dapat menjadi titik mulai TTS; setiap buku menampilkan progres baca. Pengguna juga menginginkan terjemahan manga PDF yang diproses saat halaman dibuka dan, setelah MVP, daftar video yang membuka pemutar default. Aplikasi direncanakan untuk penggunaan pribadi di Mac, dengan bahasa bacaan Indonesia dan Inggris, tanpa akun atau pemrosesan dokumen di server. Progres bacaan dapat disinkronkan melalui satu file di folder Google Drive/OneDrive yang dipilih pengguna; rancangan formatnya portabel untuk aplikasi mobile kelak dan tidak bergantung pada iCloud. Ketersediaan file online bergantung pada penyedia folder tersebut. Riset referensi berasal dari dokumentasi resmi; belum ada benchmark langsung terhadap aplikasi pesaing.

### Status implementasi per 12 Oktober 2026

Status di bawah merujuk pada kode prototipe yang ada, **bukan** tanda bahwa acceptance criteria dan pengujian rilis sudah lulus. `Ada` berarti alur dasar tersedia; `Sebagian` berarti fungsi utama ada tetapi masih ada batas penting; `Belum` berarti belum dibuat.

| Area | Status | Yang tersedia saat ini | Batas yang masih ada |
| --- | --- | --- | --- |
| Pustaka folder | Sebagian | Beberapa folder akar dengan akses persisten, indeks lokal berversi, scan bertahap, watcher, relink buku hilang, dan konfirmasi isi berubah; satu header berisi nama folder, jumlah buku/folder, dan segarkan, dengan tombol kembali hanya di subfolder; grid/daftar, pencarian, urutan, serta progres per buku; root dan subfolder pulih saat relaunch | Benchmark komponen 1.000 buku ada, tetapi startup/UI p95, drag-and-drop langsung di build sandbox, serta audit keyboard/VoiceOver menyeluruh masih menjadi validasi beta |
| Folder cloud melalui Finder (P1) | Sebagian | **Tambah dari Cloud** mendaftarkan folder cloud yang terlihat di Finder; indeks memakai metadata tanpa mengunduh semua sampul, file online disiapkan dengan coordinated read saat dibuka, dan kegagalan unduh menampilkan tindakan coba lagi | Belum diuji end-to-end pada Google Drive dan OneDrive nyata, file online-only, jaringan putus, perubahan identitas penyedia, atau waktu unduh; tidak ada koneksi akun cloud langsung |
| Sinkronisasi progres portabel (P1) | Sebagian | Folder sinkronisasi dapat dipilih di Settings; progres visual, audio, dan selesai digabung per buku ke satu `LibraryOn-progress.json` dengan versi bidang, ID buku portabel, cache lokal offline, reset global, dan tindakan sinkron manual; format v1 didokumentasikan untuk aplikasi mobile | Uji cloud nyata lintas Mac, konflik simultan/clock skew, restore saat provider membuat conflict copy, struktur pustaka berbeda antarperangkat, akses folder mobile, dan UX saat pembaruan tiba ketika Reader terbuka belum selesai; [format sinkronisasi](Docs/Progress-sync-format.md) |
| Sampul dan identitas visual | Ada | Pratinjau halaman pertama PDF/EPUB sebagai sampul; ikon terang/gelap dari `AppIcon` dengan margin Dock; aksen aplikasi mengikuti ikon | Beberapa halaman EPUB yang tidak dapat dirender masih memakai placeholder |
| PDF Reader | Sebagian | Tampilan asli/teks, navigasi halaman, zoom termasuk Muat Tinggi per halaman, outline, seleksi kata untuk mulai TTS; teks dan antrean audio tersedia bertahap dari halaman pertama lalu tiap 16 halaman, dengan cache berversi; halaman tanpa teks ditandai dan tidak dilompati otomatis; OCR lokal per halaman tanpa teks dapat ditinjau/dikoreksi lalu dibaca, tanpa mengubah PDF sumber; opsi urutan dua kolom dan filter header/footer berulang | OCR dan tata letak baru diuji pada corpus sintetis; QA dokumen nyata dan beban besar masih perlu |
| EPUB Reader | Sebagian | EPUB 2/3 reflowable tampil pada build sandbox dengan bab, daftar isi, CFI, footnote, font, spasi, dan tema; cache pemetaan per bab berversi; konten HTTP/HTTPS diblokir; EPUB dengan skrip/interaksi aktif ditolak; locator dalam bab panjang bertahan setelah font, spasi, resize, dan reopen | Belum ada dukungan fixed-layout/interaktif; ragam buku nyata masih perlu validasi beta |
| Terjemahan manga PDF (P1) | Sebagian | Tombol Reader pada macOS 15+, OCR halaman aktif, pilihan Jepang → Indonesia/Inggris, terjemahan lokal yang muncul bertahap di panel, koreksi OCR dan terjemahkan ulang per dialog, sakelar Asli/Terjemahan, serta garis tipis opsional untuk menandai lokasi dialog pilihan tanpa menutup gambar; macOS 26+ menyediakan OCR cepat satu lintasan dan **Pindai Lebih Teliti**, sedangkan OS lebih lama memakai jalur OCR lama; cache lokal maksimal 20 halaman dan status persiapan model di jendela utama | Uji manga nyata baru tersedia sebagai tes corpus opsional; kualitas berbagai tata letak, halaman berotasi, unduhan model yang belum terpasang, latensi, memori, dan alur UI menyeluruh belum divalidasi |
| Kontrol data lokal | Sebagian | Bersihkan Cache menghapus data yang dapat dibangun ulang; Reset Progres dan Penanda memakai konfirmasi terpisah; tes memastikan cache tidak menghapus progres | Belum diuji dengan koleksi besar dan skenario proses aktif/akses folder hilang |
| TTS | Sebagian | Suara sistem, play/pause, kalimat sebelum/sesudah, slider kecepatan, sorotan aktif, timer tidur, dan pemutar ringkas lintas Library/buku; sesi buku yang didengar tetap berjalan saat buku lain dibuka. Reader buku lain menampilkan navigasi halaman dan tindakan untuk beralih suara, sehingga hanya pemutar buku aktif yang memiliki transport TTS; pilihan suara dan kamus pelafalan per buku. Kalimat berdekatan pada halaman/paragraf sama dibacakan dalam satu ucapan hingga batas panjang aman; progres dan sorotan tetap per kalimat. Pilihan otomatis mendahulukan suara terpasang berkualitas tinggi | Penilaian dengar ulang Indonesia pada build 0.7.1, media keys, uji perangkat audio fisik, sesi 60 menit, dan pergantian akar saat sumber terlepas tetap di QA; karakter dasar suara sistem masih membatasi naturalitas |
| TXT/DOCX dan audio | Sebagian | TXT UTF-8/UTF-16 dan paragraf DOCX sederhana dibaca dengan TTS; ekspor CAF lewat dialog Save dan suara sistem lokal lulus pada build QA sandbox | Ragam DOCX nyata, ekspor panjang/penimpaan, dan ketentuan distribusi rekaman suara belum divalidasi; [bukti B07](Docs/B07-validation.md) |
| Posisi dan penanda | Sebagian | Halaman visual PDF dan indeks kalimat audio disimpan terpisah; EPUB menyimpan posisi visual dan audio per bab secara terpisah; bookmark PDF/EPUB dapat dibuat, dibuka, dihapus, dan ditandai perlu tinjau jika sumber berubah | Crash paksa di berbagai titik dan ragam EPUB nyata tetap di QA M4 |
| Bar progres per buku | Sebagian | Grid/daftar menampilkan bar posisi untuk setiap file: halaman/total halaman PDF, bab/total bagian EPUB, atau kosong sebelum dibuka | Persentase EPUB masih perkiraan berbasis bab; belum mengukur posisi di dalam bab dan belum menguji migrasi data pada semua instalasi lama |
| Antarmuka dan aksesibilitas | Sebagian | Settings memisahkan bahasa UI Indonesia/English/Ikuti Sistem dari bahasa TTS; pergantian UI langsung berlaku pada Library, Reader PDF/EPUB, progres, dan dialog folder. Kontrol Kembali ke Bacaan memakai ikon dengan nama VoiceOver/tooltip. Cmd+O, Cmd+,, Cmd+[, Space, Option+panah audio, Enter, dan panah halaman PDF tersedia | Audit VoiceOver/keyboard menyeluruh serta seluruh variasi pesan gagal belum selesai |
| Distribusi | Sebagian | Build lokal bertanda tangan ad-hoc, lisensi dependency ikut di bundle, repo sumber tersedia publik | Signing Developer ID, notarization, dan uji instalasi Mac bersih belum ada; belum ada lisensi proyek di root repo |

Pada akhir M3, **72 tes lokal lulus** mencakup kontrak locator, cache kedua format, antrean PDF bertahap, jeda saat menunggu batch, notifikasi tidur/keluar, PDF campuran, render ulang EPUB, pilihan suara per buku, scroll manual EPUB, serta urutan 400 kalimat referensi. Run M4 sebelumnya pada 11 Oktober berisi **88 tes: 84 lulus, 4 tes opsional dilewati, 0 gagal** di luar sandbox tool; benchmark release terpisah lulus 2/2. Build QA terisolasi telah diuji lewat UI PDF/EPUB dan pustaka besar sintetis. [Workflow GitHub Actions macOS](https://github.com/jordanalfarishy/LibraryOn/actions/workflows/macos.yml) tersedia; perubahan terbaru belum diverifikasi pada CI. Sintesis suara Indonesia/Inggris tanpa jaringan menghasilkan frame audio dan callback pada M0. Detail ada di [validasi M0](Docs/M0-validation.md), [validasi M1](Docs/M1-validation.md), [validasi M2](Docs/M2-validation.md), [validasi M3](Docs/M3-validation.md), dan [validasi M4](Docs/M4-validation.md). Hasil ini belum membuktikan unduhan file cloud nyata, alur UI unduhan model yang belum terpasang, kualitas manga nyata, atau target rilis di Bagian 8.

Run regresi pada 12 Oktober berisi **115 tes: 110 lulus, 5 opsional dilewati, 0 gagal** di luar sandbox tool; lima tes baru memeriksa identitas portabel, merge posisi, reset dua perangkat simulasi, penanganan file rusak, dan pemulihan arsip lokal. Satu tes tambahan ekspor suara Indonesia dua kalimat lulus saat diaktifkan terpisah. QA UI sebelumnya memeriksa ekspor CAF, pemutaran lintas TXT/PDF/EPUB, header pustaka tunggal, pemutar mengambang di Reader buku lain, progres di thumbnail, dan empty state. Penilaian dengar untuk perbaikan kontinuitas TTS, pemeriksaan UI interaktif B08–B11, pembukaan video dengan pemutar eksternal, serta sinkronisasi Google Drive/OneDrive nyata belum selesai; [validasi B08–B12](Docs/B08-B12-validation.md) memisahkan bukti otomatis dari gate manual. Pengujian CI untuk perubahan backlog ini belum dicatat.

**Kemajuan B03 — sebagian:** Pipeline halaman aktif berjalan dari PDFKit ke Vision dan Translation framework. Hasil terjemahan muncul bertahap di panel, sementara PDF asli tetap terbaca; pengguna dapat menyorot lokasi satu dialog dengan garis tipis, mengoreksi OCR, lalu menerjemahkan ulang. Pada macOS 26+, OCR cepat memindai satu halaman penuh dan opsi **Pindai Lebih Teliti** menambah crop tumpang tindih; OS sebelumnya memakai jalur Vision lama. Berpindah halaman membatalkan pekerjaan sebelumnya. Cache lokal dibatasi 20 halaman, dibedakan menurut versi file, halaman, bahasa, dan mode OCR; hasil OCR dapat dipakai ulang saat bahasa tujuan berubah. Respons batch dicocokkan ke dialog melalui ID; blok yang belum selesai dicoba satu per satu dan kegagalan mempertahankan teks asli. Status persiapan model tetap tampil di jendela utama ketika panel ditutup. Pasangan Jepang → Indonesia berhasil diuji secara lokal dengan kalimat sintetis pada Mac pengembangan. B03 tetap belum selesai sampai corpus manga nyata, akurasi OCR/penanda dialog pada ragam tata letak, performa, fallback kegagalan, dan perilaku model yang belum terpasang diverifikasi.

**Kemajuan B12 — sebagian:** Akar folder cloud dari Finder sekarang dapat dipilih tanpa login di LibraryOn. Pemindaian mengindeks metadata PDF/EPUB tanpa membuka setiap file online; saat sebuah buku dibuka, coordinated read menyiapkannya dan kegagalan memberi pesan yang dapat dicoba ulang. Identitas buku cloud memakai path relatif di dalam root agar penggantian file lokal oleh penyedia tidak otomatis memutus progres; rename/move oleh penyedia masih memerlukan validasi. Tes otomatis mencakup persistensi root, pembacaan terkoordinasi pada file lokal, penggantian file di path sama, dan file hilang. Pengujian dengan penyedia cloud nyata serta kondisi online/offline tetap terbuka.

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
- Telusuri hierarki subfolder melalui sidebar dan tombol kembali pada subfolder; area utama menampilkan folder dan buku dalam grid sampul atau daftar.
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
- **Folder cloud melalui Finder:** pengguna dapat menambah folder Google Drive for desktop atau OneDrive yang sudah muncul di Finder. Indeks tidak mengunduh seluruh isi; buku online disiapkan ketika dibuka. Ketersediaan file serta unduhan bergantung pada aplikasi penyedia cloud.
- **Sinkronisasi progres portabel:** pengguna memilih folder cloud tempat satu file JSON progres berada. Progres tetap lokal untuk offline; perubahan visual, audio, dan selesai digabung per buku ketika folder tersedia. Aplikasi mobile kelak memakai format dan folder yang sama melalui file explorer/provider sistem. iCloud bukan prasyarat.
- **Terjemahan manga PDF otomatis per halaman:** setelah pengguna mengaktifkan mode ini, halaman yang dibuka menjalankan OCR dan terjemahan lokal. Hasil muncul bertahap di panel samping; pengguna dapat menandai lokasi satu dialog dengan garis tipis atau memperbaiki teks OCR dan menerjemahkan ulang, tanpa mengubah file asli. Bahasa awal Jepang → Indonesia jika pasangan bahasa tersedia pada perangkat; pengguna dapat memilih Inggris.
- Kamus pelafalan, penyorotan per kata, sleep timer, dan kontrol media sistem.
- Highlight permanen, catatan, pencarian isi buku, koleksi/tag, dan ekspor anotasi.
- Format TXT/DOCX; ekspor audio dengan progres dan pembatalan setelah kemampuan engine lokal divalidasi.

### P2 — eksplorasi

- Mode manga lanjutan: penataan balon yang lebih alami, penyuntingan banyak dialog sekaligus, dan pembacaan panel otomatis setelah akurasinya terbukti.
- Model suara lokal tambahan dan audiobook berbab.
- Daftar file video di pustaka folder dan pembukaan file melalui aplikasi pemutar default. Pelacakan progres video lintas pemutar dieksplorasi terpisah.

### Di luar cakupan awal

Pembuatan/editing ebook, toko buku, DRM removal, voice cloning, kolaborasi, Windows/Android, dan pengenalan suara bukan bagian dari MVP. **Login akun cloud di LibraryOn, layanan sinkronisasi milik LibraryOn, suara berbasis server, unggah dokumen untuk OCR/terjemahan, dan fitur impor web tidak masuk roadmap PRD ini.** Sinkronisasi progres memakai satu file di folder penyedia yang dipilih pengguna, tanpa ketergantungan pada iCloud; aplikasi mobile adalah proyek berikutnya. Folder cloud pada P1 memakai aplikasi sinkronisasi pihak ketiga yang sudah terpasang dan terlihat di Finder; penyedia tersebut dapat mengunduh buku saat dibuka. Untuk fitur manga, macOS juga mungkin mengunduh model bahasa setelah persetujuan pengguna; tanpa model yang sudah terpasang, LibraryOn tidak mengirim halaman ke layanan online sebagai pengganti. Penggabungan beberapa folder akar menjadi satu katalog serta operasi rename, move, dan delete file sumber dari aplikasi juga di luar MVP; pengguna mengelola file melalui Finder. Beberapa akar tetap dapat didaftarkan dan dinavigasi satu per satu. EPUB fixed-layout, buku interaktif, teks vertikal/RTL untuk alur EPUB, serta pembacaan makna tabel/rumus/gambar belum dijanjikan. PDF terkunci belum didukung; pengguna diminta menyediakan file yang bisa diakses.

## 5. Batas dukungan dokumen

| Jenis dokumen | Perilaku MVP |
| --- | --- |
| PDF teks satu kolom | Dukungan utama untuk membaca, ekstraksi teks, TTS, dan posisi |
| PDF teks dengan layout kompleks | Dapat dibuka; TTS bersifat best effort dengan pratinjau teks. Tidak menjanjikan urutan dua kolom yang benar |
| PDF scan tanpa teks | Dapat ditampilkan; OCR lokal per halaman dapat dijalankan setelah tindakan pengguna, hasilnya ditinjau/dikoreksi sebelum TTS; kualitas masih perlu verifikasi pada scan nyata |
| PDF manga bergambar | Dapat dibuka sebagai PDF biasa pada MVP; mode terjemahan per halaman direncanakan pada P1 dan memerlukan OCR serta pasangan bahasa lokal yang tersedia |
| PDF campuran | Tandai halaman tanpa teks. Saat TTS mencapai halaman tersebut, berhenti dan tawarkan melewati halaman; jangan melewatkannya diam-diam |
| EPUB 2/3 reflowable tanpa DRM | Dukungan utama untuk teks, daftar isi, tampilan ulang, dan TTS |
| EPUB ber-DRM atau fixed-layout | Tolak alur membaca dengan penjelasan format yang didukung |
| EPUB dengan font terobfuscasi | Uji secara khusus; jika belum didukung, gunakan font aplikasi. Jangan menyamakan obfuscation font dengan DRM buku |

Batas awal yang diusulkan: 100 MB per file, PDF hingga 1.000 halaman, dan EPUB hingga 500 MB setelah ekstraksi. Batas diverifikasi pada tahap teknis awal. Buku di luar batas tetap terlihat di folder dengan penanda keterbatasan; pembukaannya ditolak sebelum pemrosesan berat dengan pesan yang menyebut batasnya.

Folder pada disk lokal merupakan baseline dukungan. Volume eksternal yang sedang terpasang dapat dipilih; saat volume terlepas, tampilkan status tidak tersedia dan simpan progres. Folder cloud P1 memerlukan aplikasi penyedia yang menampilkan folder di Finder. File yang sudah tersedia lokal dapat dibuka offline; file online-only memerlukan ketersediaan penyedia dan mungkin jaringan. LibraryOn tidak memicu unduhan massal untuk indeks atau sampul, dan tidak menjamin pembukaan file online saat offline. Network share dan pemulihan identitas lintas volume belum masuk jaminan MVP.

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

### Membuka pustaka cloud dari Finder — P1

Pengguna memilih **Tambah dari Cloud**, lalu menunjuk folder Google Drive for desktop, OneDrive, atau iCloud Drive yang sudah terlihat di Finder. Library menampilkan struktur dan metadata PDF/EPUB tanpa mengunduh semua buku untuk sampul. Ketika buku online-only dibuka, tampilkan status menyiapkan buku sambil menunggu penyedia menyediakan file. Jika gagal, pertahankan item dan progres, jelaskan bahwa koneksi atau aplikasi sinkronisasi perlu diperiksa, lalu sediakan percobaan ulang. Perpindahan root atau pilihan buku membatalkan pembukaan yang masih berjalan. LibraryOn tidak meminta kredensial cloud dan tidak mengunggah buku.

### Menerjemahkan manga PDF per halaman — P1

Di Reader PDF, pengguna mengaktifkan terjemahan manga dan memilih bahasa tujuan; pilihan awal adalah Indonesia. Halaman asli tampil segera. Hanya halaman yang sedang dibuka yang diproses: gunakan layer teks PDF bila lokasinya valid, atau render halaman untuk OCR bila berupa gambar; teks yang ditemukan dikelompokkan menjadi blok dialog lalu diterjemahkan. Hasil muncul bertahap di panel samping sehingga gambar tetap terlihat. Ikon sorot pada satu dialog menggambar garis tipis di lokasi asal; pengguna dapat mematikan sorotan itu, membandingkan **Asli / Terjemahan**, dan mengoreksi OCR per dialog untuk diterjemahkan ulang. Pada macOS 26+, OCR cepat memindai satu halaman penuh, sedangkan **Pindai Lebih Teliti** menambah crop untuk teks yang terlewat. Sistem lebih lama memakai jalur OCR sebelumnya. File PDF sumber tidak diedit. Saat berpindah halaman, pekerjaan halaman lama dibatalkan dan halaman baru diproses; halaman yang pernah dibuka boleh dimuat dari cache lokal yang tervalidasi, tanpa menerjemahkan seluruh buku di muka.

Alur awal menargetkan Jepang → Indonesia, tetapi pasangan bahasa harus diperiksa pada perangkat dengan `LanguageAvailability`; pasangan yang tidak tersedia menampilkan alasan dan pilihan bahasa lain, bukan diam-diam memakai layanan online. Model bahasa yang belum terpasang hanya diunduh oleh mekanisme sistem setelah persetujuan pengguna. Sesudah terpasang, OCR dan terjemahan berjalan di perangkat tanpa mengirim gambar atau teks manga ke server. Pada macOS 14, Reader biasa tetap tersedia dan kontrol terjemahan menjelaskan bahwa fitur ini memerlukan macOS 15 atau lebih baru. Manga dengan teks vertikal, furigana, huruf bergaya, dan urutan panel yang rumit menjadi corpus validasi; hasil OCR/terjemahan yang tidak yakin ditandai agar pengguna dapat membandingkan dengan halaman asli. Pembacaan TTS atas teks terjemahan serta ekspor PDF terjemahan tidak termasuk versi pertama fitur ini.

Rancangan ini **memungkinkan secara teknis, tetapi kualitas manga belum terbukti**: PDFKit dapat merender halaman, Vision menyediakan hasil OCR beserta lokasinya, dan Translation framework menerjemahkan teks di perangkat. Kemampuan menerjemahkan pasangan bahasa serta kualitas penempatan balon harus dibuktikan pada corpus manga nyata sebelum diberi label selesai. Apple menyatakan terjemahan `TranslationSession` diproses di perangkat, tetapi sistem dapat mengumpulkan metrik penggunaan API tanpa isi teks; kebijakan privasi produk perlu menjelaskan hal itu. [PDFKit](https://developer.apple.com/documentation/PDFKit/PDFPage), [Vision](https://developer.apple.com/documentation/vision/vnrecognizetextrequest), [TranslationSession](https://developer.apple.com/documentation/translation/translationsession), [macOS 15 Translation](https://developer.apple.com/documentation/macOS-Release-Notes/macos-15-release-notes).

### Struktur layar

| Layar/area | Isi utama |
| --- | --- |
| Library sidebar | Daftar folder pustaka, pohon subfolder aktif, menu Kelola Pustaka, dan Tambah dari Cloud (P1) |
| Library toolbar | Breadcrumb, kembali, pencarian beserta cakupan, grid/daftar, urutan, dan Segarkan |
| Library utama | Folder, sampul buku, progres, status ketersediaan, serta kartu Lanjutkan Membaca |
| Reader title bar | Judul buku; navigasi bab, daftar isi, penanda, dan tipografi EPUB; daftar isi, penanda, dan terjemahan PDF |
| Reader utama | PDF asli, teks hasil ekstraksi, atau EPUB; sorotan kalimat aktif |
| Mode manga PDF (P1) | Pilihan bahasa, progres per halaman, hasil bertahap di panel, sakelar Asli/Terjemahan, koreksi OCR per dialog, sorot lokasi dialog opsional, serta Pindai Lebih Teliti pada macOS 26+ |
| Player bawah | Halaman/tampilan PDF di kiri, kalimat sebelumnya, Play/Pause dan berikutnya di tengah, kecepatan dan suara di kanan, serta Kembali ke bacaan saat diperlukan |
| Settings | Suara default per bahasa, tema, folder terbaru, ukuran/pembersihan cache, dan bantuan |

Prinsip tampilan: konten menjadi pusat perhatian, sidebar dan kartu buku ringkas dengan margin konsisten, title bar Reader menggantikan judul aplikasi saat buku terbuka, kontrol audio selalu mudah ditemukan, ikon memiliki label aksesibilitas, dan informasi teknis parser tidak muncul dalam alur normal.

## 7. Kebutuhan fungsional dan acceptance criteria

| ID | Kebutuhan | Kriteria penerimaan |
| --- | --- | --- |
| FR-01 | Buka folder dan akses persisten | Directory picker dan drop folder mendaftarkan folder akar yang dapat dibaca. Buku tetap di lokasi asal. Folder yang sama tidak didaftarkan ganda; relaunch tidak meminta pilih ulang ketika akses masih valid |
| FR-02 | Pemindaian bertahap | Tampilkan item yang sudah ditemukan sebelum seluruh subtree selesai. Membuka buku tidak menunggu metadata seluruh koleksi. Scan dapat dibatalkan/dilanjutkan; error satu subfolder tidak menghentikan yang lain atau menghapus indeks/progres sebelumnya |
| FR-03 | Penjelajah folder dan buku | Sidebar hierarki, breadcrumb, grid/daftar, sorting, dan pencarian bercakupan bekerja. Folder dan buku dapat dipilih dengan mouse/keyboard. Judul kosong memakai nama file; sampul kosong memakai placeholder; hasil search menunjukkan path |
| FR-04 | PDF reader | Pengguna bisa berpindah halaman, zoom termasuk Muat Tinggi pada halaman aktif, membuka outline jika ada, dan beralih tampilan asli/teks. Pemilihan kalimat di teks dapat dikembalikan ke halaman asal |
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
| FR-15 | Folder terbaru dan cache | Ganti folder akar menyimpan posisi dan menghentikan scan akar sebelumnya; sumber audio yang masih berjalan mempertahankan akses foldernya sampai sesi dihentikan/diganti. Hapus dari Folder Terbaru mencabut referensi akses dan menghentikan audio jika folder itu sumbernya, tanpa menghapus buku atau progres. Bersihkan Cache hanya menghapus data yang dapat dibangun ulang; reset progres/bookmark adalah tindakan terpisah dengan konfirmasi |
| FR-16 | Offline dan privasi | Jelajah, baca, bookmark, dan TTS bekerja tanpa jaringan ketika folder/file tersedia lokal serta suara sudah terpasang. Tidak ada upload dokumen, akun LibraryOn, atau analytics pihak ketiga pada MVP. File cloud online-only mengikuti ketersediaan penyedia, sesuai FR-26 |
| FR-17 | Keyboard dan aksesibilitas | Cmd+O membuka folder; Enter membuka item terpilih; panah menavigasi Library; Cmd+[ kembali. Space play/pause berlaku di Reader saat fokus bukan input teks; Option+panah kiri/kanan navigasi kalimat. Semua tindakan tersedia lewat menu/VoiceOver |
| FR-18 | Lifecycle aplikasi | Minimize tidak memutus audio selama Mac terjaga. Quit atau penutupan jendela utama menyimpan lalu menghentikan sesi. Setelah sleep atau perangkat audio terputus, kembali dalam keadaan pause |
| FR-19 | Kegagalan yang dapat dipulihkan | File rusak/terkunci, folder tak dapat diakses, volume terlepas, suara hilang, dan ekstraksi gagal memiliki pesan spesifik serta tindakan coba ulang/pilih ulang folder/temukan buku/pilih suara yang relevan |
| FR-20 | Pembaruan koleksi | Add/rename/move/delete melalui Finder tercermin otomatis saat aplikasi aktif. Segarkan memindai ulang. Rekonsiliasi setelah relaunch/wake memulihkan perubahan yang terlewat tanpa menduplikasi entri |
| FR-21 | Identitas dan sumber berubah | Rename/move teridentifikasi dalam akar pada volume yang sama mempertahankan progres. Salinan berbeda tidak digabung. Sumber hilang ditandai tidak tersedia; isi berubah membatalkan cache lama, pause sesi, dan memvalidasi posisi sebelum dilanjutkan |
| FR-22 | Restore penjelajahan | Relaunch kembali ke Library pada folder/subfolder terakhir beserta grid/daftar, sorting, dan scroll. Kembali dari Reader memulihkan konteks pemilihan buku. Indeks belum terverifikasi ditandai, bukan dianggap sudah mutakhir |
| FR-23 (P1) | Auto-translate manga PDF lokal | Setelah mode diaktifkan, hanya halaman aktif yang diekstrak/OCR dan diterjemahkan. Halaman asli tampil saat proses berlangsung; pindah halaman membatalkan pekerjaan lama. Hasil muncul bertahap di panel, terkait dengan area asal melalui sorotan garis tipis opsional untuk satu dialog, dan dapat dibandingkan dengan teks asli. Pengguna dapat memperbaiki OCR per dialog dan menerjemahkan ulang; kesalahan per blok tidak menghilangkan sisa hasil. macOS 26+ menyediakan OCR cepat serta Pindai Lebih Teliti, OS sebelumnya memakai jalur lama. Cache dibedakan menurut versi file, halaman, bahasa, dan mode/versi pipeline. Pasangan bahasa/model tidak tersedia menghasilkan pesan dan tindakan yang jelas; tidak ada unggah halaman atau teks |
| FR-24 | Progres pada setiap buku | Grid dan daftar selalu menunjukkan bar posisi baca per PDF/EPUB. PDF memakai halaman aktif ÷ total halaman; EPUB menampilkan estimasi menurut bagian spine dan diberi label perkiraan. Buku belum dibuka menunjukkan bar kosong. Nilai dipertahankan setelah keluar/relaunch dan reset melalui tindakan Reset Progres |
| FR-25 | Bahasa antarmuka | Settings menyediakan Ikuti Sistem, Indonesia, dan English yang terpisah dari bahasa/suara TTS. Perubahan berlaku tanpa relaunch pada Settings, Library, Reader PDF/EPUB, progres, dialog folder, serta label aksesibilitas. Mengganti bahasa UI tidak mengubah pilihan suara buku. Kontrol Kembali ke Bacaan memakai ikon tanpa teks visual, tetapi tooltip dan nama VoiceOver tetap tersedia |
| FR-26 (P1) | Pustaka cloud melalui Finder | Tambah dari Cloud menerima folder penyedia yang tampil di Finder tanpa login di LibraryOn. Pemindaian metadata serta grid tidak mengunduh seluruh buku. Membuka file online-only menampilkan status, menyiapkan file lewat akses terkoordinasi, lalu membuka Reader; gagal/offline memberi alasan dan percobaan ulang tanpa menghapus indeks, progres, atau penanda. Pergantian root/buku membatalkan pembukaan lama; perubahan file oleh penyedia tidak diam-diam mengaitkan progres ke buku lain |
| FR-27 (P1) | Pemutar lintas buku | Kembali dari Reader saat TTS aktif mempertahankan sesi dan menampilkan pemutar ringkas di Library atau Reader buku lain. Pemutar menunjukkan judul sumber dan kalimat aktif, menyediakan Putar/Jeda, kalimat sebelum/sesudah, kembali ke buku sumber, dan tutup. Membuka buku lain tidak memulai suara otomatis; Putar pada buku baru menghentikan sumber lama sebelum suara baru berjalan. Quit menghentikan sesi |

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
| NFR-09 | Kualitas suara | Untuk beta lokal, pemilik menguji sendiri suara Indonesia dan Inggris dengan target kenyamanan ≥ 4/5 per bahasa serta mencatat suara, versi OS, dan masalah pelafalan angka, singkatan, nama, serta paragraf panjang. Sebelum distribusi eksternal, uji minimal 5 pengguna dengan target median ≥ 4/5 per bahasa |
| NFR-10 | Respons Library | Pada corpus 1.000 buku/100 subfolder, batch pertama terlihat ≤ 2 detik setelah folder lokal diberi akses; pindah folder terindeks ≤ 300 ms dan hasil pencarian indeks ≤ 500 ms, p95 dari 20 percobaan |
| NFR-11 | Pembaruan folder | Pada disk lokal, perubahan Finder terlihat ≤ 5 detik setelah operasi selesai dalam ≥ 19 dari 20 percobaan; scan terputus/izin ditolak tidak dianggap sebagai penghapusan file |
| NFR-12 (P1) | Respons terjemahan manga | Reader tetap dapat dinavigasi selama OCR/terjemahan; perpindahan halaman membatalkan pekerjaan lama tanpa menampilkan hasil pada halaman yang salah. Latensi per halaman, penggunaan memori, akurasi OCR, dan keterbacaan terjemahan diukur pada corpus manga sebelum ambang rilis ditetapkan |
| NFR-13 (P1) | Pustaka cloud | Pada Google Drive for desktop, OneDrive, dan iCloud Drive dengan folder Finder yang tersedia, ukur waktu indeks dan pembukaan buku online-only, jumlah file yang terunduh tanpa dibuka, perilaku saat offline/unduhan gagal, serta pemulihan setelah file berubah. Ambang waktu ditetapkan setelah pengukuran penyedia nyata; nol unduhan massal yang dipicu oleh indeks/sampul |

Uji kegunaan beta lokal dilakukan pemilik secara mandiri: pilih folder → temukan buku di subfolder → buka → Play → pause → pilih/lanjutkan buku setelah relaunch, lalu catat hambatan dan hasil uji dengar. Sebelum distribusi eksternal, minimal 4 dari 5 pengguna harus menyelesaikan alur ini tanpa bantuan dan NFR-09 mencapai ambang median. Tidak diperlukan telemetry tersembunyi. Jika suara Indonesia tidak memenuhi ambang, jangan mengklaim dukungan nyaman sebelum suara atau cakupan produk diperbaiki.

## 9. Tech stack yang direkomendasikan

Prototipe saat ini memakai Swift Package Manager/SwiftUI, PDFKit, WKWebView dengan epub.js 0.3.93 lokal, ZIPFoundation 0.9.20, AVSpeechSynthesizer, NLTokenizer, FSEvents, SwiftData untuk progres dan penanda, UserDefaults untuk daftar root serta state penjelajah, dan indeks JSON berversi di Application Support. Tes memakai XCTest. Workflow GitHub Actions macOS sudah lulus. NLLanguageRecognizer, Swift Testing, OSLog/Instruments, atau DMG bertanda tangan pengembang masih **rencana**, belum implementasi terverifikasi.

### Stack MVP

| Lapisan | Pilihan | Alasan dan batasan |
| --- | --- | --- |
| Bahasa/toolchain | Swift 6, Xcode stabil yang mendukung deployment target macOS 14 | Integrasi framework macOS; pin versi Xcode pada CI ketika proyek dibuat |
| UI aplikasi | SwiftUI + AppKit melalui NSViewRepresentable | Library, settings, toolbar native; AppKit untuk integrasi PDFView dan interaksi desktop |
| Akses folder | NSOpenPanel, security-scoped bookmarks, entitlement user-selected read-only dan app-scope bookmarks | Akses persisten hanya ke folder pilihan pengguna; resolve/refresh izin saat relaunch, mulai/akhiri akses sesuai lifetime pekerjaan |
| Folder cloud P1 | Folder Finder dari aplikasi sinkronisasi pihak ketiga, URL resource values, NSFileCoordinator, dan unduhan ubiquity bila diperlukan | Indeks metadata tanpa membaca semua isi; file online-only disiapkan saat dibuka. Tidak ada API akun cloud atau layanan sinkronisasi LibraryOn |
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
| Backend | Tidak digunakan | Buku, posisi, TTS, OCR, dan terjemahan yang direncanakan diproses di perangkat; folder cloud P1 disediakan oleh aplikasi pihak ketiga melalui Finder, tanpa backend LibraryOn |

Security-scoped bookmarks dipakai untuk mempertahankan akses folder pilihan pengguna lintas peluncuran. Bookmark akses macOS berbeda dari bookmark halaman bacaan. Pengelolaan start/stop akses dan penyegaran bookmark yang stale termasuk tanggung jawab aplikasi. [Dokumentasi NSURL](https://developer.apple.com/documentation/foundation/nsurl), [entitlement App Sandbox](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html).

FSEvents memberi sinyal perubahan yang dapat digabung atau terlewat. Aplikasi melakukan scan ulang sesuai flag, termasuk pemindaian penuh bila event hilang, serta rekonsiliasi saat kembali aktif. [Panduan FSEvents Apple](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html).

PDFKit menyediakan objek seleksi dan rentang teks yang dapat menjadi dasar pemetaan sumber. Pemilihan stack ini tidak berarti PDFKit menjamin urutan baca semua PDF. [Dokumentasi PDFSelection](https://developer.apple.com/documentation/pdfkit/pdfselection).

AVSpeechSynthesizer menyediakan antrean utterance dan kontrol pause/resume/stop, sedangkan delegate memberi kejadian ucapan. Controller aplikasi tetap harus mengelola navigasi, pembatalan, dan posisi lintas sesi. [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer), [delegate](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate).

Parameter rate Apple bukan pengali durasi audio yang terjamin, dan perubahan setelah utterance diantrekan tidak mengubah utterance tersebut. Karena itu MVP memakai skala Lambat–Normal–Cepat; label 1,5×/2× hanya ditambahkan setelah kalibrasi yang dapat dipertanggungjawabkan. [Dokumentasi rate](https://developer.apple.com/documentation/avfaudio/avspeechutterance/rate).

epub.js menyediakan rendering serta lokasi CFI. Pemakaian di WKWebView, pemetaan kalimat, dan restore posisi adalah pekerjaan integrasi yang perlu divalidasi. ZIPFoundation menyediakan akses arsip ZIP dari Swift. [epub.js](https://github.com/futurepress/epub.js), [API lokasi](https://github.com/futurepress/epub.js/blob/master/documentation/md/API.md), [ZIPFoundation](https://github.com/weichsel/ZIPFoundation).

Readium Swift tidak dipilih sebagai default karena dokumentasi getting started berfokus pada iOS/iPadOS; kompatibilitas native macOS tidak diasumsikan. [Readium Swift](https://readium.org/swift-toolkit/latest/documentation/readium/getting-started/).

NaturalLanguage menjadi dasar segmentasi, sedangkan SwiftData menyediakan penyimpanan model lokal. [Segmentasi kalimat](https://developer.apple.com/documentation/naturallanguage/nltokenunit/sentence), [SwiftData](https://developer.apple.com/documentation/swiftdata).

### Stack tahap berikutnya

- Render dan OCR manga: PDFKit lebih dulu memakai layer teks yang memiliki lokasi valid; untuk halaman gambar, PDFKit merender halaman aktif. Pada macOS 26+, Vision `RecognizeDocumentsRequest` memindai halaman penuh terlebih dahulu dan dapat menambah crop tumpang tindih atas pilihan pengguna; OS lebih lama memakai `VNRecognizeTextRequest`. Keduanya mengembalikan teks serta kotak lokasi. Periksa bahasa OCR yang didukung pada OS aktual; uji teks vertikal, furigana, dan balon bergaya sebelum mengklaim kualitas manga. [PDFPage](https://developer.apple.com/documentation/pdfkit/pdfpage/thumbnail%28of%3Afor%3A%29), [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest), [hasil/lokasi OCR](https://developer.apple.com/documentation/vision/vnrecognizedtextobservation).
- Terjemahan manga: Apple Translation framework (`TranslationSession`) pada macOS 15+, memproses blok teks di perangkat. `LanguageAvailability` memeriksa Jepang → Indonesia dan pasangan lain saat runtime; model yang belum terpasang memerlukan unduhan sistem dengan persetujuan pengguna. Tidak ada fallback jaringan ke penyedia eksternal. [TranslationSession](https://developer.apple.com/documentation/translation/translationsession), [LanguageAvailability](https://developer.apple.com/documentation/translation/languageavailability), [unduhan model](https://developer.apple.com/documentation/translation/translating-text-within-your-app).
- Tampilan dan cache: teks terjemahan berada di panel; anotasi sementara pada `PDFView` hanya menggambar garis lokasi dialog yang dipilih. Simpan hasil per versi konten + nomor halaman + bahasa + mode/versi OCR/terjemahan di Caches. Koreksi OCR per dialog memicu terjemahan ulang. Anotasi tidak disimpan ke PDF sumber.
- Video pasca-MVP: `UniformTypeIdentifiers` untuk mengenali jenis file, `NSWorkspace.open(_:)` untuk menyerahkan file ke aplikasi pemutar default, dan Quick Look Thumbnailing hanya bila thumbnail lokal diperlukan. AVPlayer dapat mengukur posisi **hanya jika pemutaran berada di dalam kendali aplikasi/integrasi yang tersedia**, sehingga jalur pemutar eksternal tidak diberi janji progres otomatis. [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace), [AVPlayer dan pengamatan progres](https://developer.apple.com/documentation/avfoundation/monitoring-playback-progress-in-your-app).

## 10. Arsitektur dan model data

### Aliran data

```text
Directory picker / drop folder / Tambah dari Cloud (P1)
          ↓
FolderAccessService → security-scoped bookmark
          ↓
DirectoryIndexer ← FolderWatcher + rekonsiliasi
          ↓
Library → pohon folder + grid/daftar buku
          ↓ pengguna membuka buku
SourceResolver → file sumber + versi konten
          ↓ file cloud online-only: coordinated read saat dibuka (P1)
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

Modul utama: `Library`, `FolderAccess`, `DirectoryIndex`, `Reader`, `DocumentProcessing`, `Speech`, `Persistence`, dan `Settings`. Pada P1, `CloudFileAccess` menyiapkan file Finder yang belum tersedia lokal ketika dibuka; `MangaTranslation` menerima hanya halaman PDF aktif dan menjalankan render → OCR → pengelompokan teks → terjemahan lokal → panel hasil serta sorotan lokasi opsional. Adapter dokumen dan speech engine memiliki antarmuka terpisah agar format/suara baru tidak mengharuskan perubahan seluruh UI. Arsitektur tetap satu aplikasi tanpa layanan server.

| Entitas | Data inti |
| --- | --- |
| LibraryRoot | ID, display name, bookmark akses macOS, penanda folder cloud, volume identity, resolved URL terakhir, status akses, waktu scan |
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

File asli di folder pengguna merupakan sumber kebenaran. Untuk folder lokal, ID buku tidak menggunakan path atau hash isi sebagai satu-satunya identitas: rename dapat mengubah path, sedangkan dua salinan identik tetap merupakan dua entri. Folder cloud saat ini memakai root ID + path relatif karena penyedia dapat mengganti inode saat mengunduh/mengganti file; konsekuensinya rename/move cloud belum menjamin progres otomatis mengikuti file. Gunakan file/volume identity bila andal, locator lokasi, dan fingerprint konten saat diperlukan. Hash seluruh koleksi tidak menjadi syarat untuk menampilkan Library.

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

Pemindaian hanya mengindeks folder/file: tidak menyalin semua buku, mengekstrak semua EPUB, atau menyiapkan TTS seluruh koleksi. Pada folder cloud P1, metadata diindeks tanpa memaksa unduhan semua file online-only; sampul untuk file tersebut memakai placeholder hingga buku tersedia lokal. Saat dibuka, file disiapkan dengan coordinated read di luar main thread. Prioritaskan isi folder aktif, sampul yang terlihat, dan buku yang dibuka; pekerjaan lanjutan memakai concurrency terbatas. File tersembunyi, package aplikasi, symlink, dan alias tidak diikuti secara rekursif pada MVP agar traversal tidak berputar atau keluar dari folder yang dipilih.

Watcher melakukan debounce lalu memicu rekonsiliasi area yang berubah. Scan mencatat status berhasil/gagal per direktori; file hanya dinyatakan hilang setelah area terkait selesai dipindai dengan akses valid. Kehilangan izin, volume terlepas, atau scan dibatalkan tidak boleh menyebabkan penghapusan massal indeks. Saat scan selesai, perubahan dibukukan secara konsisten ke database.

Sebelum membuka file atau melanjutkan audio, verifikasi akses, keberadaan sumber, dan version signature. Saat memproses, periksa apakah sumber berubah; hasil yang berasal dari versi tidak konsisten dibuang dan dicoba ulang secara terbatas. Isi berubah saat sesi berjalan menyebabkan pause serta invalidasi cache. Jika file tidak tersedia, cache tidak menjadi pengganti buku offline secara diam-diam.

Rename/move pada volume yang sama dicocokkan menggunakan identitas yang tersedia. Jika identitas berubah karena file diganti atau dipindah lintas volume, lakukan relink eksplisit dan verifikasi fingerprint/isi sebelum menerapkan progres lama. Folder akar yang sama dipilih ulang memulihkan catatan sebelumnya bila identitasnya dapat diverifikasi; folder berbeda dibuat sebagai root baru.

Semua penulisan aplikasi terbatas pada database dan cache di container sendiri. Cache ditulis atomik, dapat dibersihkan, dan tidak membuat file pendamping di direktori buku. Pada kegagalan disk penuh, hentikan pekerjaan cache dan tampilkan tindakan pemulihan tanpa mengubah sumber atau menghilangkan progres yang telah tersimpan.

Pipeline manga P1 memprioritaskan halaman yang terlihat. Setiap permintaan membawa ID buku, versi konten, indeks halaman, mode OCR, dan generation token; hasil dari halaman atau versi lama dibuang. OCR dan terjemahan satu halaman tidak memblokir navigasi atau TTS Reader. Hasil muncul bertahap di panel; sorotan pada PDF hanya lokasi satu dialog yang dipilih. Cache lokal dibatasi ukurannya, dapat dihapus tanpa menghapus buku/progres, dan invalid saat PDF atau konfigurasi bahasa/mode OCR berubah. Tidak ada unggah gambar maupun teks hasil OCR.

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
| File cloud online-only tidak tersedia atau penyedia mengganti path | Buku gagal dibuka atau progres salah buku | Status menyiapkan/gagal yang dapat dicoba ulang, akses terkoordinasi, ID path relatif yang divalidasi, dan uji pada penyedia nyata; jangan menghapus progres karena file belum terunduh |
| Perubahan file terlewat atau isi diganti | Indeks dan posisi tidak valid | Rekonsiliasi, version signature, invalidasi cache, dan validasi locator sebelum resume |
| Parser diperbarui | Posisi lama berubah | Cache berversi, source locator, cuplikan pemulihan, dan uji migrasi |
| OCR manga gagal pada tulisan vertikal, furigana, atau balon bergaya | Terjemahan hilang atau salah urutan | Corpus manga berizin, pembandingan hasil per blok, tampilan asli selalu tersedia; bila Vision tidak memadai, evaluasi model lokal lain sebelum menjanjikan dukungan |
| Pasangan bahasa atau model terjemahan tidak tersedia | Jepang → Indonesia tidak bekerja pada sebagian perangkat | Periksa `LanguageAvailability` saat runtime, uji pada versi macOS sasaran, dan tampilkan pesan/opsi bahasa yang tersedia tanpa layanan online |
| Sorotan lokasi mengarah ke dialog yang salah | Pembaca sulit mencocokkan teks dan gambar | Tampilkan terjemahan di panel, gambar hanya diberi garis tipis atas permintaan pengguna, dan verifikasi koordinat/urutan pada corpus; jangan menulis ke PDF sumber |
| Banyak fitur masuk sebelum alur inti stabil | Waktu rilis membesar | P0 menjadi batas MVP; terjemahan manga, OCR, dan anotasi lanjutan dikerjakan pada P1 setelah alur inti stabil |

Keputusan awal yang bisa diterapkan tanpa menunda dokumen: macOS 14+, Apple Silicon, beberapa folder pustaka tersimpan dengan satu folder akar aktif, grid sampul sebagai tampilan awal, UI Indonesia/English dengan pilihan Ikuti Sistem, dukungan bacaan Indonesia/Inggris yang diatur terpisah, dan beta DMG setelah gate distribusi lulus. Ikon dari folder `AppIcon` sudah digunakan pada prototipe. Terjemahan manga lokal ditargetkan untuk macOS 15+ pada P1; pengguna macOS 14 tetap dapat membaca PDF biasa. Dukungan Intel, penggabungan beberapa akar folder dalam satu katalog, harga/model bisnis, serta kanal Mac App Store diputuskan setelah validasi MVP.

## 12. Daftar task implementasi

Daftar ini memuat **35 task MVP dan 15 task backlog**. Status **Sebagian** berarti implementasi awal sudah ada tetapi *definition of done* belum terpenuhi; **Belum** berarti task belum dimulai secara berarti; **Selesai** hanya dipakai setelah seluruh kriteria dan verifikasinya lulus. Saat ini **7 task MVP Sebagian dan 28 Selesai**; di backlog, B01–B12 serta B15 Sebagian. Owner berikut adalah peran, bukan penugasan kepada orang tertentu. Dependensi menyatakan task yang harus selesai sebelum output task dapat dinyatakan tuntas. ID lama dipertahankan; T33–T35 adalah tambahan untuk pustaka folder dan ditempatkan pada milestone terkait.

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
| Selesai | T12 | Buat ReadingDocument, TextSegment, locator, dan cache berversi | Engineer | T03–T05, T08 | Kontrak kedua format sama; cache memakai versi sumber/extractor dan pemetaan dapat diuji |
| Selesai | T13 | Bangun adapter PDF dan tampilan asli | Engineer | T12, T09 | Halaman, zoom, outline, klasifikasi scan/campuran, dan mapping bekerja |
| Selesai | T14 | Bangun normalisasi dan segmentasi kalimat | Engineer | T12 | Baris terpotong, singkatan, Unicode, dan lintas halaman diuji dengan referensi |
| Selesai | T15 | Bangun tampilan teks PDF dan perpindahan ke sumber | Engineer | T13, T14, T06 | FR-04/06 terpenuhi; tidak ada sorotan palsu ketika mapping gagal |
| Selesai | T16 | Bangun adapter/render EPUB lokal dan bridge | Engineer | T04, T12, T14 | FR-05 terpenuhi; konten jarak jauh/skrip buku terblokir; struktur buku tetap terbaca |
| Selesai | T17 | Tambahkan navigasi bab/halaman, tema, dan tipografi | Engineer | T15, T16 | Resize/font tidak memindahkan locator; tema tidak merusak keterbacaan |

**Gate M2 per 6 Oktober 2026: lulus untuk dukungan utama PDF teks satu kolom dan EPUB reflowable.** Teks PDF dan antrean TTS dimulai dari batch yang sudah siap; halaman tanpa teks menghentikan transisi otomatis, termasuk di ujung dokumen. Cache pemetaan EPUB per bab sekarang persisten dengan versi sumber/extractor dan digest isi. QA EPUB 120 paragraf menunjukkan locator dalam bab tetap terlihat setelah perubahan font, spasi, resize, dan reopen. Enam task M2 selesai; variasi penerbit, beban besar, dan audit rilis tetap di M4. Bukti dan batas rinci ada di [validasi M2](Docs/M2-validation.md).

### Milestone 3 — pengalaman mendengarkan

| Status | ID | Task | Owner | Dependensi | Definition of done |
| --- | --- | --- | --- | --- | --- |
| Selesai | T18 | Bangun SpeechEngine dan PlaybackController | Engineer | T02, T12, T14 | State, queue terbatas, cancel, session token, dan akhir dokumen teruji |
| Selesai | T19 | Implementasikan picker/preview suara dan bahasa per buku | Engineer | T18, T08 | FR-08 lulus termasuk suara hilang dan bahasa tanpa suara |
| Selesai | T20 | Buat player, rate, dan previous/next sentence | Engineer | T18, T06 | FR-07/09 lulus; klik cepat tidak menghasilkan audio tumpang tindih |
| Selesai | T21 | Integrasikan sorotan aktif pada PDF teks/asli dan EPUB | Engineer | T15, T16, T18 | FR-10 lulus dengan pemetaan sumber dan callback sesi yang benar |
| Selesai | T22 | Implementasikan Baca dari sini, auto-follow, dan kembali ke bacaan | Engineer | T20, T21 | FR-11/12 lulus; seleksi dan scroll manual tetap nyaman |
| Selesai | T23 | Simpan/pulihkan posisi audio dan visual | Engineer | T08, T17, T18, T35 | FR-13 lulus pada relaunch/crash, rename file, dan perubahan tampilan; sumber berubah tidak menerima locator lama tanpa validasi |
| Selesai | T24 | Implementasikan bookmark dan navigasinya | Engineer | T17, T23 | FR-14 lulus pada dua format dan setelah reopen |
| Selesai | T25 | Tangani lifecycle, audio terputus, dan sumber berubah/hilang | Engineer | T20, T23, T34, T35 | FR-18/21 lulus; volume terlepas atau isi berubah saat play menyebabkan pause dan pemulihan yang jelas |

**Gate implementasi M3 lulus pada 8 Oktober 2026.** T18–T25 selesai di kode dengan 72 tes lulus dan QA UI PDF/EPUB. Antrean TTS bertahap dan session token mencegah audio tumpang tindih pada 100 perpindahan kalimat cepat. Suara/bahasa per buku, preview, sorotan aktif, auto-follow, dan kontrol player diuji. Posisi visual serta audio EPUB dipulihkan secara terpisah: reopen mempertahankan Bab 1 yang terlihat, sedangkan Putar kembali ke Bab 2 yang terakhir didengar. Penanda EPUB bertahan setelah reopen dan navigasi antarbab. Saat sumber PDF berubah dalam Reader, aplikasi menutup sesi, mempertahankan progres, dan menampilkan tindakan Tinjau Buku setelah scan berikutnya. Jalur sleep, terminate, dan perubahan output audio diuji lewat event handler. Uji perangkat fisik, crash paksa, sesi 60 menit, dan corpus beta tetap menjadi verifikasi M4; detail dan batas bukti ada di [validasi M3](Docs/M3-validation.md).

### Milestone 4 — verifikasi dan beta lokal

M4 menargetkan paket **internal pada Mac pemilik**. Paket ad-hoc dapat dipakai untuk QA lokal tanpa Developer ID. Penilaian kegunaan/suara oleh pemilik menggantikan studi lima peserta pada gate ini. Distribusi eksternal tetap memerlukan studi multi pengguna, Developer ID, notarization, dan uji instalasi Mac bersih (B13–B14). Perubahan cakupan ini tidak menghapus target teknis NFR-01–08/10–11 atau mengubah hasil yang belum terukur menjadi lulus.

| Status | ID | Task | Owner | Dependensi | Definition of done |
| --- | --- | --- | --- | --- | --- |
| Sebagian | T26 | Lengkapi Settings, bahasa UI, keyboard, VoiceOver, dan empty/error states | Engineer + Design | T10–T25, T34, T35 | FR-17/19/25 lulus; fokus input tidak mengambil shortcut pemutar; akses folder yang hilang memiliki pemulihan |
| Sebagian | T27 | Uji alur inti otomatis dan integrasi dengan corpus | QA + Engineer | T11, T17, T20–T26 | Semua FR memiliki bukti uji; posisi, pergantian sesi, scan parsial, dan rekonsiliasi folder tercakup |
| Sebagian | T28 | Benchmark Library, pembaruan folder, audio, dan memori | QA + Engineer | T27 | NFR-01–07 serta NFR-10/11 terukur; pelanggaran diperbaiki atau target direvisi secara eksplisit |
| Sebagian | T29 | Uji offline, WebView, akses folder, dan pembersihan cache | QA + Engineer | T27 | FR-16/NFR-08 lulus; tidak ada request konten remote, traversal di luar root berizin, atau modifikasi file sumber |
| Sebagian | T30 | Uji kegunaan dan suara mandiri oleh pemilik | Product + QA | T28, T29 | Alur inti dan suara Indonesia/Inggris diuji pada perangkat pemilik; hasil serta penghambat dicatat tanpa mengarang penilaian |
| Sebagian | T31 | Perbaiki temuan penghambat dan jalankan ulang uji terdampak | Engineer + QA | T30 | Tidak ada kegagalan P0 terbuka; regresi area perubahan lulus |
| Sebagian | T32 | Siapkan paket beta lokal ad-hoc dan panduan | Engineer + Product | T31 | Bundle/ZIP terverifikasi, lisensi dan batas format jelas, alur inti di Mac pengembangan lulus; belum dinyatakan cocok untuk distribusi eksternal |

**M4 lokal masih berjalan per 11 Oktober 2026.** T26 mendapat Settings dengan pilihan bahasa antarmuka Indonesia/English yang terpisah dari suara TTS, shortcut Reader, label aksesibilitas tambahan, retry error, dan tombol kembali ke bacaan berbentuk ikon. T27 memiliki 88 tes (84 lulus, 4 opsional dilewati) serta QA UI PDF/EPUB dan pustaka sintetis, tetapi matriks semua FR dan corpus nyata belum tuntas. Benchmark komponen release pada 1.000 file/100 folder mencatat batch buku pertama p95 0,0031 detik, scan lengkap 0,0569 detik, pencarian 0,0024 detik, perpindahan folder 0,0025 detik, dan watcher 20/20 dengan p95 0,5129 detik. Startup/UI p95, audio, sesi 60 menit, dan memori gabungan belum terukur. T29 memiliki uji traversal/symlink dan cache; uji jaringan dimatikan serta audit lalu lintas proses masih terbuka. Pemilik melaporkan alur inti QA mandiri T30 lulus dan kenyamanan suara Indonesia/Inggris masing-masing 4/5; naturalitas pembacaan masih ingin ditingkatkan. Butir QA lain belum dicatat. Bukti dan formulir tersedia di [validasi M4](Docs/M4-validation.md), [QA mandiri](Docs/M4-local-qa.md), dan [panduan paket lokal](Docs/M4-local-beta.md).

### Backlog pasca-MVP

| Status | ID | Prioritas | Task | Dependensi / gate |
| --- | --- | --- | --- | --- |
| Sebagian | B01 | P1 | OCR lokal, halaman campuran, dan review hasil | T32; alur kode/UI sintetis lulus, tetapi akurasi, latensi, memori, halaman berotasi, dan bahasa Vision pada corpus nyata belum diverifikasi; [bukti B01](Docs/B01-validation.md) |
| Sebagian | B02 | P1 | Reading order dua kolom dan filter header/footer | T32; opsi per buku, fixture dua kolom/dua halaman, mapping sumber, dan QA UI sintetis lulus; perlu corpus PDF nyata termasuk variasi margin, rotasi, serta halaman dua kolom campuran; [bukti B02](Docs/B02-validation.md) |
| Sebagian | B03 | P1 | Auto-translate manga PDF lokal per halaman: OCR cepat/teliti, panel hasil bertahap, koreksi OCR, sorotan lokasi dialog, cache, dan pembatalan saat pindah halaman | T32; FR-23/NFR-12 lulus pada corpus manga tanpa unggah dokumen; OCR TTS umum di B01 terpisah |
| Sebagian | B04 | P1 | Kamus pelafalan dan sorotan kata | T32; editor per buku, substitusi ujaran, pemetaan sumber, dan sorotan berbasis callback tersedia; butuh QA timing/akurasi pada suara dan dokumen nyata; [bukti B04](Docs/B04-validation.md) |
| Sebagian | B05 | P1 | Sleep timer dan media keys/Now Playing | T32; timer 15/30/60 menit dan integrasi perintah/metadata macOS sudah ada, tes timer lulus; perlu QA Control Center, keyboard media, sleep/wake, dan lintas suara pada aplikasi paket; [bukti B05](Docs/B05-validation.md) |
| Sebagian | B06 | P1 | Highlight permanen, catatan, pencarian isi, dan koleksi | T32; sorotan/catatan PDF dan pencarian isi buku aktif, persistensi/relink/locator usang teruji; EPUB, koleksi buku, dan migrasi data masih terbuka; [bukti B06](Docs/B06-validation.md) |
| Sebagian | B07 | P1 | Dukungan TXT/DOCX dan ekspor audio | T32; TXT UTF-8/UTF-16, DOCX paragraf, dan ekspor CAF suara sistem lulus pada fixture/build QA; perlu ragam DOCX nyata, ekspor panjang/penimpaan, serta ketentuan distribusi rekaman; [bukti B07](Docs/B07-validation.md) |
| Sebagian | B08 | P2 | Penyempurnaan manga: penyuntingan banyak dialog, tata balon, dan urutan panel | B03; editor multi-dialog, gabung/pisah balon, urutan, dan penyimpanan per halaman sudah ada; manfaat dan akurasi pada manga berizin serta UI nyata belum diuji; [bukti B08–B12](Docs/B08-B12-validation.md) |
| Sebagian | B09 | P2 | Suara lokal tambahan, peningkatan naturalitas pembacaan, dan audiobook berbab | T32; suara sistem Premium/Enhanced didahulukan, contoh berisi tanda baca/angka/singkatan, dan ekspor CAF per bab TXT/DOCX tersedia; evaluasi dengar, format lain, resource, dan model suara tambahan belum selesai; [bukti B08–B12](Docs/B08-B12-validation.md) |
| Sebagian | B10 | P2 | Tampilkan file video di folder pustaka sebagai item daftar/grid dengan judul, format, dan thumbnail/placeholder; tombol Putar membuka file di aplikasi pemutar default macOS | T32; pemindaian format, placeholder, aksi pemutar default, dan pesan galat tersedia; akses security-scoped/pemutar nyata serta kasus file hilang belum diuji di UI paket; [bukti B08–B12](Docs/B08-B12-validation.md) |
| Sebagian | B11 | P2 | Progres video: sediakan status manual atau integrasi khusus pemutar yang mendukung pengembalian posisi; tampilkan bar video hanya jika sumber progres jelas | B10; pilihan manual 25/50/75/100%, hapus/reset, dan bar berlabel Manual tersedia; QA UI serta pemulihan setelah buka ulang belum dicatat; tidak ada klaim sinkronisasi otomatis; [bukti B08–B12](Docs/B08-B12-validation.md) |
| Sebagian | B12 | P1 | Pustaka cloud melalui folder Finder: indeks metadata, pembukaan on-demand, status gagal/coba lagi, serta progres lokal | T09, T27, T29, T32; pembatalan NSFileCoordinator ditambahkan; FR-26/NFR-13 masih perlu uji Google Drive for desktop, OneDrive, dan iCloud Drive nyata termasuk offline/perubahan file; [bukti B08–B12](Docs/B08-B12-validation.md) |
| [ ] | B13 | P1 | Validasi beta eksternal dengan minimal 5 pengguna | T30–T32; minimal 4/5 alur mandiri lulus dan median kenyamanan suara Indonesia/Inggris ≥ 4/5 |
| [ ] | B14 | P1 | Distribusi eksternal: Developer ID, notarization, stapling, dan instalasi Mac bersih | T32, B13; paket bertanda tangan distribusi terverifikasi pada Mac lain |
| Sebagian | B15 | P1 | Sinkronisasi progres lintas perangkat lewat satu file pada folder cloud pilihan | B12; format JSON portabel, koordinasi file, merge per posisi, reset, dan QA dua perangkat simulasi tersedia; QA Google Drive/OneDrive nyata, konflik provider, serta adapter mobile tetap terbuka; [kontrak format](Docs/Progress-sync-format.md) |

**Batas progres video:** Membuka file melalui `NSWorkspace` menyerahkan pemutaran ke aplikasi lain. LibraryOn tidak menerima posisi waktu dari semua pemutar default. Karena itu bar video saat ini hanya muncul setelah pengguna menetapkan progres manual; membuka video tidak membuat atau mengubah persentase. Tidak ada sinkronisasi posisi otomatis lintas pemutar.

Rincian pekerjaan B03 agar status prototipe tidak disamakan dengan fitur siap rilis:

| Status | Subtask B03 | Bukti / langkah berikutnya |
| --- | --- | --- |
| Selesai pada prototipe | OCR halaman aktif dan lokasi teks PDF gambar/layer teks | Tes PDF sintetis untuk halaman gambar/teks lulus; OCR cepat satu lintasan, mode teliti, penggabungan kolom vertikal, dan penyaringan furigana memiliki tes regresi |
| Selesai pada prototipe | Hasil bertahap di panel, sakelar asli, koreksi OCR per dialog, dan sorotan lokasi sementara | Respons batch dicocokkan lewat ID; garis tipis lokasi diuji tanpa menulis ke PDF sumber. Kualitas UI pada manga nyata belum lulus gate |
| Selesai pada prototipe | Cache lokal berversi dan dibatasi 20 halaman | Tes baca ulang dari instans baru, versi file berbeda, batas file, dan pemakaian ulang OCR lintas bahasa tujuan tersedia |
| Sebagian | Terjemahan Jepang → Indonesia/Inggris dan pembatalan saat pindah halaman | API Jepang → Indonesia berhasil untuk kalimat sintetis; alur UI penuh, unduhan model, dan pembalikan cepat belum diverifikasi |
| Sebagian | Tes corpus manga nyata | Runner opsional menerima PDF lokal dan menghasilkan laporan lokasi/latensi; corpus berizin minimal 20 halaman serta hasil terukur belum tercatat |
| Belum | Validasi kualitas manga dan target kinerja | Ukur OCR, kecocokan sorotan lokasi, latensi, memori, teks vertikal/furigana, kegagalan per blok, dan manfaat mode teliti |

## 13. Rencana pengujian dan syarat rilis

Corpus M0 yang tersedia berisi 30 file sintetis: 10 PDF teks satu kolom, 10 EPUB reflowable (campuran EPUB 2/3), dan 10 kasus batas/negatif termasuk Unicode, pemenggalan baris, scan/gambar, dua kolom, file rusak, marker DRM, fixed-layout, serta EPUB dengan resource/skrip eksternal. File terkunci dan file sebesar ambang batas belum dibuat. Teks acuan 400 kalimat berbahasa Indonesia; variasi bahasa Inggris masih perlu ditambahkan untuk QA rilis.

Dataset penjelajahan M0 memuat 1.000 entri buku sintetis dalam 100 subfolder, termasuk hierarki dua tingkat, nama Unicode, judul sama pada 100 lokasi, dan duplikat isi. Volume image HFS+ terlepas/terpasang kembali telah diuji pada build sandbox. Direktori yang izinnya dicabut diuji otomatis pada M1 dan tidak menghapus buku/progres yang sudah diindeks; folder kosong, file non-ebook, serta symlink/alias tetap memerlukan uji UI lanjutan. Dataset ini untuk menguji fungsi indeks/Library, bukan menggantikan corpus kualitas bacaan atau pengukuran latensi p95.

QA menyiapkan 20 kalimat acuan per dokumen dukungan utama (400 total), termasuk lokasi dan urutan yang benar. Semua transisi bab dan sampel batas halaman dicatat terpisah. Uji audio nyata melengkapi tes state machine; mock engine tidak cukup untuk menyatakan kualitas suara atau ketepatan callback.

Skenario wajib: pilih folder pertama kali, telusuri subfolder dan breadcrumb, grid/daftar, search bercakupan, buka buku, kembali ke Library, restore subfolder/scroll saat relaunch, scan batal/parsial, rename/move/copy/delete melalui Finder, file diganti pada path sama, folder akar dipindah, izin dicabut, volume terlepas, reconnect, dan event watcher terlewat. Verifikasi bahwa kasus tidak tersedia tidak menghapus progres dan bahwa sumber tidak berubah setelah memakai aplikasi atau membersihkan cache.

Untuk B12, ulangi alur pada folder Finder Google Drive for desktop, OneDrive, dan iCloud Drive: indeks file online-only tanpa unduhan massal, buka buku saat online, buka buku yang sudah tersedia lokal saat offline, tangani kegagalan unduh, batalkan pembukaan saat berpindah root, dan ubah file/rename melalui penyedia. Catat identitas/progres serta waktu unduh per penyedia. Tes otomatis yang memakai file lokal hanya membuktikan kontrak dasar coordinated read, bukan perilaku penyedia nyata.

Pengujian bacaan tetap mencakup suara belum terpasang, jaringan mati, dokumen scan, kalimat lintas halaman, pergantian suara saat play, klik next berulang, navigasi visual saat audio berjalan, resize EPUB, reopen/crash, sleep, perangkat audio terputus, disk penuh, dan file berubah saat sesi aktif.

Sebelum B03 dinyatakan selesai, siapkan corpus manga PDF berizin/sintetis yang mencakup minimal 20 halaman Jepang dengan tulisan horizontal/vertikal, furigana, balon kecil, efek suara, teks di atas gambar, dan beberapa urutan panel. Catat akurasi OCR cepat vs teliti, kecocokan pasangan Jepang → Indonesia, keterbacaan panel dan ketepatan sorotan lokasi, waktu proses tiap halaman, pembatalan saat membalik cepat, penggunaan cache, serta perilaku offline setelah model sistem terpasang. Jika kualitas belum memadai, tampilkan keterbatasan dan jangan menjanjikan terjemahan penuh otomatis.

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
