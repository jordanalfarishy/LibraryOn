# B07 — TXT, DOCX, dan ekspor audio

Status per 11 Oktober 2026: **sebagian**. TXT dan DOCX teks sederhana dapat dibuka dan dibacakan. Ekspor bacaan TXT/DOCX menjadi CAF menggunakan suara sistem lokal berhasil pada Mac pengembangan; cakupan DOCX kompleks dan hak distribusi rekaman dari suara sistem belum dinyatakan lulus.

TXT didukung dalam UTF-8 dan UTF-16, dengan batas 20 MB. DOCX membaca teks paragraf dari `word/document.xml` dalam ZIP tanpa mengubah sumber, juga dengan batas XML 20 MB. Reader menampilkan kalimat, mulai membaca dari kalimat pilihan, menyimpan posisi audio, dan memakai kontrol suara serta timer yang sama. Ekspor memilih lokasi dengan dialog Save macOS, menghasilkan CAF mono Float32, dan menulis file sementara di container aplikasi sebelum memindahkannya ke lokasi yang dipilih. Entitlement sandbox memberi akses baca/tulis hanya pada file yang dipilih pengguna lewat dialog sistem.

Bukti:

- `TextFileAdapterTests`: 2 tes lulus untuk indeks, TXT UTF-8/UTF-16, DOCX paragraf, dan sumber yang tidak berubah.
- `SpeechAudioExporterTests` dengan `LIBRARYON_AUDIO_EXPORT_LIVE=1` di luar sandbox tool: 1 tes lulus; file CAF dapat dibuka oleh `AVAudioFile` dan memiliki frame audio.
- QA UI build sandbox: DOCX dibuka dengan dua kalimat; dialog ekspor menyimpan `/private/tmp/LibraryOn-B07-QA.caf`; `afinfo` membaca 72.278 frame, 22.050 Hz, durasi sekitar 3,28 detik.

Sisa gate: DOCX dengan tabel, daftar, catatan kaki, perubahan terlacak, dan konten tertanam; TXT encoding selain UTF-8/UTF-16; ekspor dokumen panjang, pembatalan, ruang disk habis, serta penimpaan file yang ada; dan verifikasi ketentuan penggunaan suara sistem untuk membagikan rekaman. CAF dipakai karena format buffer suara sistem dapat ditulis tanpa encoder tambahan. API rujukan: [AVSpeechSynthesizer.write](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write%28_%3Atobuffercallback%3A%29), [AVAudioFile.write](https://developer.apple.com/documentation/avfaudio/avaudiofile/write%28from%3A%29-6qgec), [akses file pilihan pengguna](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.user-selected.read-write).
