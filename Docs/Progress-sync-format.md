# Sinkronisasi progres lewat folder cloud

LibraryOn 0.8.0 menyimpan posisi bacaan tetap di database lokal, lalu menggabungkannya dengan **satu** file `LibraryOn-progress.json` di folder yang dipilih pengguna melalui Finder. Folder dapat berasal dari Google Drive for desktop atau OneDrive. Buku dan penanda tidak diunggah oleh fitur ini; penyedia folderlah yang menyinkronkan file JSON. Tidak ada login cloud di LibraryOn.

## Menggunakan di Mac

1. Pastikan aplikasi Google Drive atau OneDrive membuat folder yang tersedia di Finder dan dapat ditulis.
2. Buka **Pengaturan → Sinkronisasi progres → Pilih folder…** dan pilih folder tersebut. LibraryOn membuat `LibraryOn-progress.json` di sana. Folder sinkronisasi boleh terpisah dari folder buku.
3. Pilih **Sinkronkan sekarang** untuk menarik pembaruan segera. Selama aplikasi aktif, perubahan posisi dikirim setelah jeda singkat dan file diperiksa ulang setiap 30 detik. Saat offline, progres tetap tersimpan lokal dan dicoba lagi pada pemeriksaan berikutnya.
4. Perangkat lain harus memilih folder cloud dan akun yang sama. Nama folder pustaka, path relatif buku di dalamnya, format, serta ukuran file harus cocok. Nama folder pustaka yang duplikat di satu Mac tidak dipasangkan otomatis.

**Reset Progres dan Penanda** membuat penanda reset global pada file sinkronisasi. Progres di perangkat lain terhapus saat aplikasi mereka membaca file tersebut; penanda buku saat ini hanya lokal. **Putuskan** menghentikan sinkronisasi tanpa menghapus progres lokal atau file cloud.

## Kontrak format untuk aplikasi mobile

File adalah JSON UTF-8 dengan `schemaVersion: 1`. `books` berisi rekaman menurut ID portabel. ID adalah SHA-256 heksadesimal huruf kecil dari `NFC(libraryName) + NUL + NFC(relativePath) + NUL + format + NUL + decimal(fileSize)`. Path relatif memakai pemisah `/`; indeks dimulai dari nol. `changedAt` adalah milidetik sejak Unix epoch. Contoh disingkat:

```json
{
  "schemaVersion": 1,
  "books": {
    "<sha256-id-portabel>": {
      "libraryName": "Pustaka",
      "relativePath": "Novel/Buku.epub",
      "format": "epub",
      "fileSize": 128,
      "visual": {
        "value": {"pdfPage": 0, "epubChapter": 3, "epubCFI": "epubcfi(...)"},
        "version": {"changedAt": 1791763200000, "deviceID": "device-uuid", "sequence": 12}
      },
      "audio": {
        "value": {"sentenceIndex": 25, "epubAudioChapter": 2, "epubAudioCFI": "epubcfi(...)"},
        "version": {"changedAt": 1791763201000, "deviceID": "device-uuid", "sequence": 13}
      },
      "completion": {
        "value": false,
        "version": {"changedAt": 1791763201000, "deviceID": "device-uuid", "sequence": 13}
      }
    }
  }
}
```

Posisi visual, posisi audio, dan status selesai memiliki versi terpisah. Saat membaca file, aplikasi menggabungkan tiap bidang menurut `(changedAt, sequence, deviceID)` yang lebih baru; **jangan** memakai halaman/kalimat terbesar karena pengguna dapat sengaja kembali ke awal. `resetAllVersion` adalah penanda reset global opsional: bidang dengan versi lebih lama atau sama harus dibuang. Data lokal perangkat tetap disimpan agar perubahan offline dapat diunggah lagi ketika folder tersedia. File yang rusak atau memiliki `schemaVersion` tidak dikenal tidak boleh ditimpa.

Di mobile, pilih folder yang sama melalui pengelola dokumen sistem dan baca/tulis file tersebut dengan izin provider. Fitur ini menyiapkan format bersama; aplikasi mobile LibraryOn belum ada di repository. Akses background, waktu unduh, dan perilaku konflik berbeda antarpenyedia. Satu file tidak menjamin resolusi sempurna ketika dua perangkat mengubah **bidang yang sama** saat offline; versi paling baru menurut aturan di atas menang. Aplikasi menahan salinan lokal, tetapi conflict copy yang dibuat penyedia belum digabung otomatis. Uji langsung Google Drive, OneDrive, dan pemulihan konflik tetap menjadi gate B15.
