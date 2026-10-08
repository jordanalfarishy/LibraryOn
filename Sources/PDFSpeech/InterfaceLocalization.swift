import Foundation

enum InterfaceLocalization {
    static var currentLocale: Locale {
        let choice = UserDefaults.standard.string(forKey: "LibraryOn.uiLanguage") ?? "system"
        return choice == "system" ? .autoupdatingCurrent : Locale(identifier: choice)
    }

    static func string(_ key: String, locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? "id"
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        let exact = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        if exact != key || language != "en" { return exact }

        let patterns: [(prefix: String, suffix: String, template: String)] = [
            ("Akses folder tidak dapat disimpan: ", "", "Akses folder tidak dapat disimpan: %@"),
            ("Folder tidak dapat dibuka: ", "", "Folder tidak dapat dibuka: %@"),
            ("Folder \"", "\" tidak tersedia. Pilih ulang foldernya.",
             "Folder \"%@\" tidak tersedia. Pilih ulang foldernya."),
            ("Folder \"", "\" tidak tersedia. Pasang kembali volume atau pilih ulang foldernya.",
             "Folder \"%@\" tidak tersedia. Pasang kembali volume atau pilih ulang foldernya."),
            ("Akses ke \"", "\" perlu diperbarui. Pilih ulang foldernya.",
             "Akses ke \"%@\" perlu diperbarui. Pilih ulang foldernya."),
            ("Progres dan penanda telah dihubungkan ke \"", "\".",
             "Progres dan penanda telah dihubungkan ke \"%@\"."),
            ("Cache tidak dapat dibersihkan: ", "", "Cache tidak dapat dibersihkan: %@"),
            ("Indeks pustaka belum tersimpan: ", "", "Indeks pustaka belum tersimpan: %@"),
            ("Teks PDF gagal disiapkan: ", "", "Teks PDF gagal disiapkan: %@"),
            ("Buku EPUB tidak dapat ditampilkan: ", "", "Buku EPUB tidak dapat ditampilkan: %@"),
            ("Gagal menyimpan penanda: ", "", "Gagal menyimpan penanda: %@"),
            ("Gagal menghapus penanda: ", "", "Gagal menghapus penanda: %@")
        ]
        for pattern in patterns where key.hasPrefix(pattern.prefix) && key.hasSuffix(pattern.suffix) {
            let value = String(key.dropFirst(pattern.prefix.count).dropLast(pattern.suffix.count))
            let format = bundle.localizedString(forKey: pattern.template,
                                                value: pattern.template, table: "Localizable")
            return String(format: format, string(value, locale: locale))
        }
        return key
    }

    static func string(_ key: String) -> String {
        string(key, locale: currentLocale)
    }
}
