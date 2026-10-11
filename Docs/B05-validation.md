# B05 — Timer tidur dan kontrol media macOS

Status per 11 Oktober 2026: **sebagian**. Kode dan tes timer lulus; QA perangkat untuk media keys/Control Center belum selesai.

Reader PDF, EPUB, TXT, dan DOCX menyediakan timer tidur 15/30/60 menit dari kontrol audio, menampilkan waktu berakhir, serta opsi mematikan timer. Timer mengikuti waktu nyata, dapat diganti, dan dijeda saat habis; timer tetap berjalan ketika pengguna kembali ke Library sambil mendengarkan buku dan dibatalkan saat sesi audio dihentikan atau diganti. `NowPlayingBridge` mempublikasikan judul buku dan status putar/jeda tanpa durasi palsu, lalu menerima perintah play, pause, toggle, kalimat berikutnya/sebelumnya dari remote command center macOS. Metadata dibersihkan ketika pemutar berhenti.

Tes `SpeechPlayerTests` memverifikasi timer lama dibatalkan ketika diganti, timer baru menjeda antrean yang menunggu, dan pembatalan menghapus deadline; delapan tes pemutar lulus dalam run tertarget. Dokumentasi API: [Now Playing](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter), [remote command center](https://developer.apple.com/documentation/mediaplayer/remote-command-center-events).

Sisa gate: uji manual tombol media keyboard/headset dan Control Center pada Mac paket, pergantian aplikasi audio, sleep/wake, timer saat bab berganti, dan status setelah dokumen selesai. Tidak ada angka durasi/elapsed media karena panjang ujaran `AVSpeechSynthesizer` tidak disediakan sebagai timeline yang stabil.
