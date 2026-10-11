import AppKit
import SwiftUI

private struct FolderBranch: Identifiable {
    let path: String
    let name: String
    let children: [FolderBranch]
    var id: String { path }
    var outlineChildren: [FolderBranch]? { children.isEmpty ? nil : children }
}

private enum FolderTree {
    static func build(from entries: [FolderEntry], rootName: String) -> FolderBranch {
        let byParent = Dictionary(grouping: entries.filter { !$0.path.isEmpty }, by: \.parentPath)
        func make(_ path: String, _ name: String) -> FolderBranch {
            let children = (byParent[path] ?? [])
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map { make($0.path, $0.name) }
            return FolderBranch(path: path, name: name, children: children)
        }
        return make("", rootName)
    }
}

struct LibraryView: View {
    @Environment(LibraryModel.self) private var library
    @Environment(\.locale) private var locale
    @State private var showResetConfirmation = false
    @State private var isFolderDropTargeted = false

    var body: some View {
        ZStack {
            if !library.isReaderOpen {
                if library.activeRootID == nil { emptyLibrary }
                else { libraryNavigation }
            }

            ForEach(library.readerBooks) { book in
                let visible = library.isReaderOpen && library.activeBook?.id == book.id
                ReaderView(book: book, isVisible: visible)
                    .opacity(visible ? 1 : 0)
                    .allowsHitTesting(visible)
                    .disabled(!visible)
                    .accessibilityHidden(!visible)
                    .zIndex(visible ? 1 : 0)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let book = library.playbackBook,
               let player = library.playbackPlayer,
               !library.isReaderOpen {
                FloatingPlayer(book: book, player: player, compact: false,
                               onOpen: { library.showPlaybackBook() },
                               onClose: { library.dismissPlayback() })
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let book = library.playbackBook,
               let player = library.playbackPlayer,
               library.isReaderOpen,
               library.activeBook?.id != book.id {
                FloatingPlayer(book: book, player: player,
                               compact: true,
                               onOpen: { library.showPlaybackBook() },
                               onClose: { library.dismissPlayback() })
                    .padding(.horizontal, 24)
                    .padding(.bottom, 84)
            }
        }
        .tint(AppTheme.accent)
        .overlay {
            if isFolderDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppTheme.accent, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            var accepted = false
            for url in urls {
                if library.addRoot(url) { accepted = true }
            }
            return accepted
        } isTargeted: { targeted in
            isFolderDropTargeted = targeted
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            library.scan()
        }
        .confirmationDialog("Reset semua progres dan penanda bacaan?",
                            isPresented: $showResetConfirmation) {
            Button("Reset Progres dan Penanda", role: .destructive) {
                library.resetReadingData()
            }
        } message: {
            Text("Posisi baca, progres video manual, dan semua penanda akan dihapus. File dan folder pustaka tetap ada.")
        }
        .alert("Isi buku berubah", isPresented: Binding(
            get: { library.pendingChangedBook != nil },
            set: { if !$0 { library.pendingChangedBook = nil } }
        )) {
            Button("Buka dari Awal") { library.confirmOpenChangedBook() }
            Button("Batal", role: .cancel) { library.pendingChangedBook = nil }
        } message: {
            Text("Posisi bacaan lama mungkin tidak cocok dengan isi file ini. Buka dari awal akan mengatur ulang posisi, tetapi tetap menyimpan penanda Anda.")
        }
    }

    private var emptyLibrary: some View {
        VStack(spacing: 0) {
            libraryHeader
            Divider()
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 58, height: 58)
                            .background(AppTheme.quietAccent,
                                        in: RoundedRectangle(cornerRadius: 15))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mulai pustaka Anda")
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                            Text("Pilih folder dari Mac atau layanan cloud yang tersambung ke Finder. Buku dan video di dalamnya akan muncul di sini.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 10) {
                            Button("Buka Folder Buku…", systemImage: "folder") {
                                library.chooseFolder()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Tambah dari Cloud…", systemImage: "cloud") {
                                library.chooseCloudFolder()
                            }
                            .buttonStyle(.bordered)
                        }
                        .controlSize(.large)
                        Divider()
                        HStack(spacing: 18) {
                            if !library.roots.isEmpty {
                                Menu("Buka folder sebelumnya") {
                                    ForEach(library.roots) { root in
                                        Button(root.name) { library.activateRoot(root.id) }
                                    }
                                }
                                .fixedSize()
                            }
                            Menu("Kelola Data") {
                                Button("Bersihkan Cache") { library.clearCache() }
                                    .disabled(library.isClearingCache)
                                Button("Reset Progres dan Penanda…", role: .destructive) {
                                    showResetConfirmation = true
                                }
                            }
                            .fixedSize()
                            Spacer(minLength: 0)
                        }
                        .font(.caption)
                        if let notice = library.dataNotice {
                            Text(InterfaceLocalization.string(notice, locale: locale))
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        if let error = library.scanError {
                            Text(InterfaceLocalization.string(error, locale: locale))
                                .font(.callout).foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: 500, alignment: .leading)
                    .padding(30)
                    .background(AppTheme.surface,
                                in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(AppTheme.border))
                    .padding(28)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: viewport.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.canvas)
    }

    private var libraryNavigation: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("FOLDER PUSTAKA")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            Button("Tambah Folder…") { library.chooseFolder() }
                            Button("Tambah dari Cloud…", systemImage: "cloud") { library.chooseCloudFolder() }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        .help("Tambah folder pustaka")
                        .accessibilityLabel("Tambah folder pustaka")
                    }
                    .padding(.horizontal, 17)
                    rootList
                }
                .padding(.top, 10)
                .padding(.bottom, 6)
                .frame(height: min(42 + CGFloat(library.roots.count) * 43, 214))
                Divider().padding(.horizontal, 14)
                if let active = library.activeRoot {
                    Text("\(InterfaceLocalization.string("DI DALAM", locale: locale)) \(active.name.uppercased())")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 17)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    folderOutline
                        .id(active.id)
                }
                Divider().padding(.horizontal, 14)
                Menu {
                    Button("Buka Folder Lain…") { library.chooseFolder() }
                    Button("Tambah dari Cloud…", systemImage: "cloud") { library.chooseCloudFolder() }
                    Button("Pilih Ulang Lokasi Folder Ini…") { library.relinkActiveRoot() }
                    Button("Lepas Folder Ini", role: .destructive) { library.forgetActiveRoot() }
                    Divider()
                    Button("Bersihkan Cache") { library.clearCache() }
                        .disabled(library.isClearingCache)
                    Button("Reset Progres dan Penanda…", role: .destructive) {
                        showResetConfirmation = true
                    }
                } label: {
                    Label("Kelola Pustaka", systemImage: "folder.badge.gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .frame(minWidth: 220)
            .background(AppTheme.canvas)
        } detail: {
            libraryContent
                .id(library.activeRootID)
                .navigationTitle("")
        }
    }

    private var rootList: some View {
        let selection = Binding<UUID?>(
            get: { library.activeRootID },
            set: { id in
                guard let id, id != library.activeRootID else { return }
                library.activateRoot(id)
            }
        )
        return List(selection: selection) {
            ForEach(library.roots) { root in
                HStack(spacing: 9) {
                    Image(systemName: root.cloudBacked == true ? "cloud" :
                        (library.activeRootID == root.id ? "folder.fill" : "folder"))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(root.name).fontWeight(.medium).lineLimit(1)
                        if let hint = root.pathHint {
                            Text(hint).font(.caption2)
                                .foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .tag(root.id)
                .help(root.pathHint.map { $0 + "/" + root.name } ?? root.name)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private var folderOutline: some View {
        let root = FolderTree.build(from: library.folders, rootName: "Semua Buku")
        let selection = Binding<String?>(
            get: { library.selectedFolder },
            set: { library.selectedFolder = $0 ?? ""; library.search = "" }
        )
        return List(selection: selection) {
            Label("Semua Buku", systemImage: "books.vertical.fill")
                .tag("")
            OutlineGroup(root.children, children: \.outlineChildren) { branch in
                Label(branch.name, systemImage: "folder")
                    .lineLimit(1)
                    .tag(branch.path)
                    .help(branch.path)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private var libraryContent: some View {
        @Bindable var library = library
        return VStack(spacing: 0) {
            if let id = library.openingCloudBookID,
               let book = library.books.first(where: { $0.id == id }) {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(String(format: InterfaceLocalization.string("Menyiapkan buku cloud: %@", locale: locale), book.title))
                        .lineLimit(1)
                    Spacer()
                    Button("Batal") { library.cancelCloudOpen() }
                }
                .font(.callout)
                .padding(9)
                .background(AppTheme.quietAccent)
            }
            if let notice = library.dataNotice {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                    Text(InterfaceLocalization.string(notice, locale: locale))
                    Spacer()
                    Button { library.dataNotice = nil } label: {
                        Image(systemName: "xmark")
                    }
                    .help("Tutup pemberitahuan")
                    .accessibilityLabel("Tutup pemberitahuan")
                }
                .font(.callout)
                .padding(9)
                .background(AppTheme.surface)
            }
            if let error = library.scanError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(InterfaceLocalization.string(error, locale: locale))
                    Spacer()
                    if let video = library.books.first(where: {
                        $0.id == library.selectedBookID && $0.format == .video
                    }) {
                        Button("Coba Lagi") { library.open(video) }
                        Button("Segarkan folder") { library.scan() }
                    } else if let book = library.books.first(where: { $0.id == library.cloudOpenErrorBookID }) {
                        Button("Coba Lagi") { library.open(book) }
                    } else if let book = library.books.first(where: { $0.id == library.selectedBookID }),
                       library.unavailableBookIDs.contains(book.id) {
                        Button("Temukan Buku…") { library.relinkBook(book) }
                    } else if let book = library.books.first(where: { $0.id == library.selectedBookID }),
                              library.changedBookIDs.contains(book.id) {
                        Button("Tinjau Buku") { library.open(book) }
                    } else {
                        Button("Pilih Ulang Folder…") { library.relinkActiveRoot() }
                    }
                }
                .font(.callout)
                .padding(9)
                .background(.orange.opacity(0.13))
            }
            if let notice = library.indexNotice {
                Text(InterfaceLocalization.string(notice, locale: locale))
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
            }
            if !library.isIndexVerified && !library.books.isEmpty {
                Label(library.isScanning
                      ? "Menampilkan indeks tersimpan; sedang memeriksa perubahan folder…"
                      : "Indeks belum terverifikasi. Segarkan folder sebelum membuka buku.",
                      systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }
            libraryHeader
            Divider()
            if library.visibleFolders.isEmpty && library.visibleBooks.isEmpty {
                emptyContent
            } else {
                booksArea
                    .id("\(library.cacheRevision):\(library.progressRevision):\(library.videoProgressRevision)")
            }
        }
        .background(AppTheme.canvas)
        .searchable(text: $library.search, prompt: "Cari judul atau nama file")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    if let book = library.visibleBooks.first(where: { $0.id == library.selectedBookID }) {
                        library.open(book)
                    }
                } label: {
                    Image(systemName: library.visibleBooks.first(where: {
                        $0.id == library.selectedBookID
                    })?.format == .video ? "play.rectangle" : "book")
                }
                .disabled(!library.visibleBooks.contains { $0.id == library.selectedBookID })
                .keyboardShortcut(.return, modifiers: [])
                .help("Buka item terpilih (↩)")
                .accessibilityLabel("Buka item terpilih")
                if !library.search.isEmpty {
                    Toggle("Seluruh pustaka", isOn: $library.searchAllFolders)
                        .toggleStyle(.checkbox)
                        .help("Cari di semua folder pustaka")
                }
                Menu {
                    Button("Nama buku") {
                        library.sortByRecent = false
                        library.sortByModified = false
                    }
                    Button("Terakhir dibaca") {
                        library.sortByRecent = true
                        library.sortByModified = false
                    }
                    Button("Terakhir diubah") {
                        library.sortByRecent = false
                        library.sortByModified = true
                    }
                } label: { Image(systemName: "arrow.up.arrow.down") }
                .help("Urutkan buku")
                .accessibilityLabel("Urutkan buku")
                Button {
                    library.listMode.toggle()
                } label: {
                    Image(systemName: library.listMode ? "square.grid.2x2" : "list.bullet")
                }
                .help(library.listMode ? "Tampilan grid" : "Tampilan daftar")
                .accessibilityLabel(library.listMode ? "Tampilan grid" : "Tampilan daftar")
            }
        }
    }

    private var libraryHeader: some View {
        HStack(spacing: 14) {
            if !library.selectedFolder.isEmpty {
                Button {
                    let parent = (library.selectedFolder as NSString).deletingLastPathComponent
                    library.selectedFolder = parent == "." ? "" : parent
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                .help("Ke folder induk")
                .accessibilityLabel("Ke folder induk")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(library.selectedFolder.isEmpty
                     ? library.activeRoot?.name ?? InterfaceLocalization.string("Pustaka", locale: locale)
                     : (library.selectedFolder as NSString).lastPathComponent)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                if library.activeRootID == nil {
                    Text("Belum ada folder pustaka")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let videoCount = library.visibleBooks.filter { $0.format == .video }.count
                    let bookCount = library.visibleBooks.count - videoCount
                    Text(videoCount == 0
                         ? String(format: InterfaceLocalization.string("%d buku · %d folder", locale: locale),
                                  bookCount, library.visibleFolders.count)
                         : String(format: InterfaceLocalization.string(
                            "%d buku · %d video · %d folder", locale: locale),
                            bookCount, videoCount, library.visibleFolders.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if library.activeRootID != nil {
                if library.isScanning { ProgressView().controlSize(.small) }
                Button { library.scan() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                    .help("Segarkan folder")
                    .accessibilityLabel("Segarkan folder")
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .frame(minHeight: 94)
        .background(AppTheme.canvas)
    }

    private var emptyContent: some View {
        VStack(spacing: 13) {
            Image(systemName: library.isScanning ? "arrow.clockwise" :
                  (library.search.isEmpty ? "books.vertical" : "magnifyingglass"))
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 58, height: 58)
                .background(AppTheme.quietAccent,
                            in: RoundedRectangle(cornerRadius: 15))
            Text(library.isScanning ? "Memindai pustaka…" :
                 (library.search.isEmpty ? "Belum ada item di folder ini" : "Tidak ada hasil"))
                .font(.title3.weight(.semibold))
            Text(library.search.isEmpty
                 ? "Buku PDF, EPUB, TXT, DOCX, dan video dari folder ini akan muncul di sini."
                 : "Coba kata kunci lain atau cari di semua folder pustaka.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if library.isScanning {
                ProgressView().controlSize(.small)
                    .padding(.top, 4)
            } else if !library.search.isEmpty {
                Button("Hapus pencarian") { library.search = "" }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            } else {
                Button("Segarkan folder", systemImage: "arrow.clockwise") {
                    library.scan()
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: 380)
        .padding(30)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppTheme.border))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var booksArea: some View {
        @Bindable var library = library
        return ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if library.selectedFolder.isEmpty && library.search.isEmpty,
                   let recent = library.books.filter({ $0.format != .video })
                    .filter({ library.progressStore.value(for: $0.id) != nil })
                    .max(by: { (library.progressStore.value(for: $0.id)?.lastOpened ?? .distantPast) <
                                (library.progressStore.value(for: $1.id)?.lastOpened ?? .distantPast) }) {
                    Button { library.open(recent) } label: {
                        HStack(spacing: 16) {
                            BookCoverImage(book: recent)
                                .frame(width: 50, height: 68)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Lanjutkan membaca")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                                Text(recent.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                BookProgressBar(book: recent)
                                    .frame(maxWidth: 300)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(16)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppTheme.border))
                    }
                    .buttonStyle(.plain)
                }

                if !library.visibleFolders.isEmpty && library.search.isEmpty {
                    Text("Folder").font(.title3.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        ForEach(library.visibleFolders) { folder in
                            Button { library.selectedFolder = folder.path } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(AppTheme.accent)
                                    Text(folder.name).lineLimit(1)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.border))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Text(LocalizedStringKey(library.search.isEmpty ? "Buku dan Video" : "Hasil pencarian"))
                        .font(.title3.weight(.semibold))
                }
                if library.listMode {
                    LazyVStack(spacing: 5) {
                        ForEach(library.visibleBooks) { book in
                            BookListRow(book: book)
                                .id(book.id)
                        }
                    }
                    .scrollTargetLayout()
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130, maximum: 180), spacing: 14)],
                              alignment: .leading, spacing: 16) {
                        ForEach(library.visibleBooks) { book in
                            BookGridCard(book: book)
                                .id(book.id)
                        }
                    }
                    .scrollTargetLayout()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.canvas)
        .scrollPosition(id: $library.scrollAnchor)
    }
}

private struct FloatingPlayer: View {
    @Environment(\.locale) private var locale
    let book: BookFile
    @Bindable var player: SpeechPlayer
    let compact: Bool
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            BookCoverImage(book: book)
                .frame(width: compact ? 32 : 36, height: compact ? 43 : 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(String(format: InterfaceLocalization.string("Kalimat %d / %d", locale: locale),
                            player.currentIndex + 1, player.segments.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
            Button { player.previous() } label: {
                Image(systemName: "backward.end.fill")
            }
            .foregroundStyle(.primary)
            .disabled(player.segments.isEmpty)
            .help("Kalimat sebelumnya")
            .accessibilityLabel("Kalimat sebelumnya")
            Button {
                if player.isPlaying { player.pause() }
                else { player.play() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .disabled(player.segments.isEmpty)
            .help(player.isPlaying ? "Jeda" : "Putar")
            .accessibilityLabel(player.isPlaying ? "Jeda" : "Putar")
            Button { player.next() } label: {
                Image(systemName: "forward.end.fill")
            }
            .foregroundStyle(.primary)
            .disabled(player.segments.isEmpty)
            .help("Kalimat berikutnya")
            .accessibilityLabel("Kalimat berikutnya")
            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 24)
            if compact {
                Button { onOpen() } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .help("Buka Buku")
                .accessibilityLabel("Buka Buku")
            } else {
                Button("Buka Buku") { onOpen() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Button { onClose() } label: { Image(systemName: "xmark") }
                .foregroundStyle(.secondary)
                .help("Tutup pemutar")
                .accessibilityLabel("Tutup pemutar")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: compact ? 500 : 780)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppTheme.border))
        .shadow(color: .black.opacity(0.26), radius: 24, y: 10)
    }
}

private struct BookGridCard: View {
    @Environment(LibraryModel.self) private var library
    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool
    let book: BookFile

    var body: some View {
        Button {
            library.selectedBookID = book.id
            isFocused = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                BookCoverImage(book: book)
                    .aspectRatio(0.72, contentMode: .fit)
                    .overlay(alignment: .bottom) {
                        if book.format == .video,
                           let progress = library.videoProgressStore.value(for: book.id) {
                            VideoProgressBar(progress: progress, title: book.title)
                                .padding(6)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                        } else if book.format != .video,
                                  library.progressStore.value(for: book.id) != nil {
                            BookProgressBar(book: book, showsLabel: false)
                                .padding(6)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                        }
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(book.formatLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        if library.unavailableBookIDs.contains(book.id) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .help(InterfaceLocalization.string(
                                    library.activeRoot?.cloudBacked == true
                                        ? "File cloud tidak tersedia · buka untuk mencoba lagi"
                                        : "File tidak tersedia · klik untuk hubungkan", locale: locale))
                        }
                    }
                    .frame(height: 16)
                }
                .frame(height: 56, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .padding(10)
        .background(library.selectedBookID == book.id ? AppTheme.quietAccent : AppTheme.surface,
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(library.selectedBookID == book.id ? AppTheme.accent.opacity(0.7) : AppTheme.border))
        .simultaneousGesture(TapGesture(count: 2).onEnded { library.open(book) })
        .onKeyPress(.return) {
            library.open(book)
            return .handled
        }
        .contextMenu { bookContextMenu(book, library: library) }
        .help(book.relativePath)
    }
}

private struct BookListRow: View {
    @Environment(LibraryModel.self) private var library
    @FocusState private var isFocused: Bool
    let book: BookFile

    var body: some View {
        Button {
            library.selectedBookID = book.id
            isFocused = true
        } label: {
            HStack(spacing: 11) {
                BookCoverImage(book: book)
                    .frame(width: 38, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("\(book.formatLabel) · \(book.relativePath)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if library.unavailableBookIDs.contains(book.id) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .help(InterfaceLocalization.string(
                            library.activeRoot?.cloudBacked == true
                                ? "Buka untuk mencoba mengunduh lagi" : "Temukan file",
                            locale: InterfaceLocalization.currentLocale))
                } else if book.format == .video,
                          let progress = library.videoProgressStore.value(for: book.id) {
                    VideoProgressBar(progress: progress, title: book.title)
                        .frame(width: 112)
                } else if book.format != .video,
                          library.progressStore.value(for: book.id) != nil {
                    BookProgressBar(book: book, showsLabel: false)
                        .frame(width: 112)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .background(library.selectedBookID == book.id ? AppTheme.quietAccent : AppTheme.surface,
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(library.selectedBookID == book.id ? AppTheme.accent.opacity(0.7) : AppTheme.border))
        .simultaneousGesture(TapGesture(count: 2).onEnded { library.open(book) })
        .onKeyPress(.return) {
            library.open(book)
            return .handled
        }
        .contextMenu { bookContextMenu(book, library: library) }
    }
}

@MainActor @ViewBuilder private func bookContextMenu(_ book: BookFile,
                                                     library: LibraryModel) -> some View {
    if book.format == .video {
        Button("Putar Video") { library.open(book) }
        Menu("Tandai progres manual") {
            ForEach([25, 50, 75, 100], id: \.self) { percent in
                Button("\(percent)%") { library.setVideoProgress(percent, for: book) }
            }
        }
        if library.videoProgressStore.value(for: book.id) != nil {
            Button("Hapus progres manual") { library.setVideoProgress(nil, for: book) }
        }
    } else {
        Button("Buka Buku") { library.open(book) }
    }
}

private struct VideoProgressBar: View {
    let progress: VideoProgress
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: Double(progress.percent), total: 100)
                .tint(AppTheme.accent)
            Text("Manual · \(progress.percent)%")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .help("Progres manual · \(progress.percent)%")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progres manual \(title)")
        .accessibilityValue("\(progress.percent)%")
    }
}

private struct BookProgressBar: View {
    @Environment(LibraryModel.self) private var library
    @Environment(\.locale) private var locale
    let book: BookFile
    var showsLabel = true
    @State private var measuredCount: Int?

    private var version: String {
        "\(book.id):\(book.size):\(book.modifiedAt.timeIntervalSince1970)"
    }

    var body: some View {
        var progress = library.progressStore.value(for: book.id) ?? BookProgressValue()
        if let measuredCount {
            switch book.format {
            case .pdf: progress.pdfPageCount = measuredCount
            case .epub: progress.epubChapterCount = measuredCount
            case .txt, .docx: progress.pdfPageCount = measuredCount
            case .video: break
            }
        }
        return VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: progress.fraction(for: book.format))
                .tint(progress.fraction(for: book.format) == 0 ? .clear : AppTheme.accent)
                .accessibilityLabel("\(locale.language.languageCode?.identifier == "en" ? "Progress" : "Progres") \(book.title)")
                .accessibilityValue(progress.progressLabel(for: book.format, locale: locale))
            if showsLabel {
                Text(progress.progressLabel(for: book.format, locale: locale))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .task(id: version) {
            measuredCount = nil
            guard let saved = library.progressStore.value(for: book.id),
                  saved.lastOpened != .distantPast else { return }
            let needsCount = book.format == .epub
                ? saved.epubChapterCount == nil : saved.pdfPageCount == nil
            guard needsCount else { return }
            let count = await Task.detached(priority: .utility) {
                BookLength.count(for: book)
            }.value
            guard !Task.isCancelled, let count, count > 0 else { return }
            switch book.format {
            case .pdf: library.progressStore.savePDFPageCount(book.id, count: count)
            case .epub: library.progressStore.saveEPUB(book.id, chapterCount: count)
            case .txt, .docx: library.progressStore.savePDFPageCount(book.id, count: count)
            case .video: break
            }
            measuredCount = count
        }
    }
}

private struct BookCoverImage: View {
    let book: BookFile
    @State private var cover: NSImage?
    @State private var needsDownload = false

    private var version: String {
        "\(book.id):\(book.size):\(book.modifiedAt.timeIntervalSince1970)"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(book.format == .pdf
                          ? Color.orange.opacity(0.13) : AppTheme.accent.opacity(0.13))
                if let cover {
                    Image(nsImage: cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    VStack(spacing: 7) {
                        Image(systemName: needsDownload ? "cloud.and.arrow.down" :
                            (book.format == .pdf ? "doc.richtext" :
                             (book.format == .video ? "play.rectangle" : "book.closed")))
                            .font(.system(size: min(geometry.size.width * 0.28, 42),
                                          weight: .ultraLight))
                        if geometry.size.width > 70 {
                            Text(book.formatLabel)
                                .font(.caption2.monospaced())
                        }
                    }
                    .foregroundStyle(book.format == .pdf ? .orange : AppTheme.accent)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .task(id: version) {
            cover = nil
            needsDownload = await Task.detached(priority: .utility) {
                CloudFileAccess.needsDownload(book.url)
            }.value
            guard !Task.isCancelled else { return }
            if let data = await BookCoverStore.shared.data(for: book),
               !Task.isCancelled {
                cover = NSImage(data: data)
            }
        }
    }
}
