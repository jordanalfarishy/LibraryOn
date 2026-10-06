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
    @State private var showResetConfirmation = false
    @State private var isFolderDropTargeted = false

    var body: some View {
        Group {
            if library.isReaderOpen, let book = library.activeBook {
                ReaderView(book: book)
                    .id(book.id)
            } else if library.activeRootID == nil {
                emptyLibrary
            } else {
                libraryNavigation
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
            Text("Posisi baca dan semua penanda akan dihapus. File buku dan folder pustaka tetap ada.")
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
        VStack(spacing: 15) {
            Image(systemName: "books.vertical")
                .font(.system(size: 57, weight: .ultraLight))
                .foregroundStyle(AppTheme.accent)
            Text("Buku Anda, dalam satu tempat")
                .font(.largeTitle.bold())
            Text("Pilih atau tarik folder berisi PDF dan EPUB. Subfolder akan tampil seperti susunan di Finder.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Button("Buka Folder Buku…") { library.chooseFolder() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            if !library.roots.isEmpty {
                Menu("Folder Terakhir") {
                    ForEach(library.roots) { root in
                        Button(root.name) { library.activateRoot(root.id) }
                    }
                }
            }
            Menu("Kelola Data") {
                Button("Bersihkan Cache") { library.clearCache() }
                    .disabled(library.isClearingCache)
                Button("Reset Progres dan Penanda…", role: .destructive) {
                    showResetConfirmation = true
                }
            }
            if let notice = library.dataNotice {
                Text(notice).font(.callout).foregroundStyle(.secondary)
            }
            if let error = library.scanError {
                Text(error).foregroundStyle(.orange).font(.callout)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var libraryNavigation: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("FOLDER PUSTAKA")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button { library.chooseFolder() } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        .help("Tambah folder pustaka")
                    }
                    .padding(.horizontal, 7)
                    rootList
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(height: min(46 + CGFloat(library.roots.count) * 53, 220))
                Divider()
                if let active = library.activeRoot {
                    Text("DI DALAM \(active.name.uppercased())")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 19)
                        .padding(.top, 10)
                    folderOutline
                        .id(active.id)
                }
                Divider()
                Menu {
                    Button("Buka Folder Lain…") { library.chooseFolder() }
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
                .padding(12)
            }
            .frame(minWidth: 220)
            .navigationTitle("Pustaka")
        } detail: {
            libraryContent
                .id(library.activeRootID)
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
                    Image(systemName: library.activeRootID == root.id ? "folder.fill" : "folder")
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
    }

    private var libraryContent: some View {
        @Bindable var library = library
        return VStack(spacing: 0) {
            if let notice = library.dataNotice {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                    Text(notice)
                    Spacer()
                    Button { library.dataNotice = nil } label: {
                        Image(systemName: "xmark")
                    }
                    .help("Tutup pemberitahuan")
                }
                .font(.callout)
                .padding(9)
                .background(.quaternary.opacity(0.45))
            }
            if let error = library.scanError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                    Spacer()
                    Button("Pilih Ulang Folder…") { library.relinkActiveRoot() }
                }
                .font(.callout)
                .padding(9)
                .background(.orange.opacity(0.13))
            }
            if let notice = library.indexNotice {
                Text(notice)
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
            HStack(spacing: 8) {
                Button {
                    let parent = (library.selectedFolder as NSString).deletingLastPathComponent
                    library.selectedFolder = parent == "." ? "" : parent
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(library.selectedFolder.isEmpty)
                .help("Ke folder induk")

                breadcrumb
                Spacer()
                if library.isScanning { ProgressView().controlSize(.small) }
                Button { library.scan() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Segarkan folder")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            Divider()
            if library.visibleFolders.isEmpty && library.visibleBooks.isEmpty {
                ContentUnavailableView(
                    library.search.isEmpty ? "Belum ada buku di folder ini" : "Tidak ada hasil",
                    systemImage: library.search.isEmpty ? "folder" : "magnifyingglass",
                    description: Text(library.isScanning ? "Sedang memindai folder…" :
                                      "PDF dan EPUB dari folder yang dipilih akan muncul di sini.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                booksArea
                    .id("\(library.cacheRevision):\(library.progressRevision)")
            }
        }
        .searchable(text: $library.search, prompt: "Cari judul atau nama file")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !library.search.isEmpty {
                    Toggle("Seluruh pustaka", isOn: $library.searchAllFolders)
                        .toggleStyle(.checkbox)
                        .help("Cari di semua folder pustaka")
                }
                Menu {
                    Button("Nama buku") { library.sortByRecent = false }
                    Button("Terakhir dibaca") { library.sortByRecent = true }
                } label: { Image(systemName: "arrow.up.arrow.down") }
                .help("Urutkan buku")
                Button {
                    library.listMode.toggle()
                } label: {
                    Image(systemName: library.listMode ? "square.grid.2x2" : "list.bullet")
                }
                .help(library.listMode ? "Tampilan grid" : "Tampilan daftar")
            }
        }
    }

    private var breadcrumb: some View {
        let parts = library.selectedFolder.split(separator: "/").map(String.init)
        return HStack(spacing: 4) {
            Button(library.activeRoot?.name ?? "Buku") { library.selectedFolder = "" }
                .buttonStyle(.plain)
                .fontWeight(parts.isEmpty ? .semibold : .regular)
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Button(part) {
                    library.selectedFolder = parts.prefix(index + 1).joined(separator: "/")
                }
                .buttonStyle(.plain)
                .fontWeight(index == parts.count - 1 ? .semibold : .regular)
            }
        }
        .lineLimit(1)
    }

    private var booksArea: some View {
        @Bindable var library = library
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if library.selectedFolder.isEmpty && library.search.isEmpty,
                   let recent = library.books
                    .filter({ library.progressStore.value(for: $0.id) != nil })
                    .max(by: { (library.progressStore.value(for: $0.id)?.lastOpened ?? .distantPast) <
                                (library.progressStore.value(for: $1.id)?.lastOpened ?? .distantPast) }) {
                    Button { library.open(recent) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.accent)
                            VStack(alignment: .leading) {
                                Text("Lanjutkan membaca").font(.caption).foregroundStyle(.secondary)
                                Text(recent.title).font(.headline).lineLimit(1)
                                Text(recent.relativePath).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                BookProgressBar(book: recent)
                                    .frame(maxWidth: 240)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(AppTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                if !library.visibleFolders.isEmpty && library.search.isEmpty {
                    Text("Folder").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        ForEach(library.visibleFolders) { folder in
                            Button { library.selectedFolder = folder.path } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(AppTheme.accent)
                                    Text(folder.name).lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(13)
                                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Text(library.search.isEmpty ? "Buku" : "Hasil pencarian")
                        .font(.headline)
                    Text("\(library.visibleBooks.count)")
                        .foregroundStyle(.secondary)
                }
                if library.listMode {
                    LazyVStack(spacing: 2) {
                        ForEach(library.visibleBooks) { book in
                            BookListRow(book: book)
                                .id(book.id)
                        }
                    }
                    .scrollTargetLayout()
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 142, maximum: 190), spacing: 20)],
                              alignment: .leading, spacing: 22) {
                        ForEach(library.visibleBooks) { book in
                            BookGridCard(book: book)
                                .id(book.id)
                        }
                    }
                    .scrollTargetLayout()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
        }
        .scrollPosition(id: $library.scrollAnchor)
    }
}

private struct BookGridCard: View {
    @Environment(LibraryModel.self) private var library
    let book: BookFile

    var body: some View {
        Button { library.open(book) } label: {
            VStack(alignment: .leading, spacing: 8) {
                BookCoverImage(book: book)
                    .aspectRatio(0.72, contentMode: .fit)
                Text(book.title).font(.subheadline.weight(.medium)).lineLimit(2)
                Text(book.folderPath.isEmpty ? book.format.rawValue.uppercased() : book.folderPath)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                if library.unavailableBookIDs.contains(book.id) {
                    Label("File tidak tersedia · klik untuk hubungkan", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
                BookProgressBar(book: book)
            }
        }
        .buttonStyle(.plain)
        .help(book.relativePath)
    }
}

private struct BookListRow: View {
    @Environment(LibraryModel.self) private var library
    let book: BookFile

    var body: some View {
        Button { library.open(book) } label: {
            HStack(spacing: 13) {
                BookCoverImage(book: book)
                    .frame(width: 34, height: 47)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).fontWeight(.medium)
                    Text(book.relativePath).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    BookProgressBar(book: book)
                        .frame(maxWidth: 220)
                }
                Spacer()
                if library.unavailableBookIDs.contains(book.id) {
                    Label("Temukan file", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text(book.format.rawValue.uppercased())
                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct BookProgressBar: View {
    @Environment(LibraryModel.self) private var library
    let book: BookFile
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
            }
        }
        return VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: progress.fraction(for: book.format))
                .tint(AppTheme.accent)
                .accessibilityLabel("Progres \(book.title)")
                .accessibilityValue(progress.progressLabel(for: book.format))
            Text(progress.progressLabel(for: book.format))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .task(id: version) {
            measuredCount = nil
            guard let saved = library.progressStore.value(for: book.id),
                  saved.lastOpened != .distantPast else { return }
            let needsCount = book.format == .pdf
                ? saved.pdfPageCount == nil : saved.epubChapterCount == nil
            guard needsCount else { return }
            let count = await Task.detached(priority: .utility) {
                BookLength.count(for: book)
            }.value
            guard !Task.isCancelled, let count, count > 0 else { return }
            switch book.format {
            case .pdf: library.progressStore.savePDFPageCount(book.id, count: count)
            case .epub: library.progressStore.saveEPUB(book.id, chapterCount: count)
            }
            measuredCount = count
        }
    }
}

private struct BookCoverImage: View {
    let book: BookFile
    @State private var cover: NSImage?

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
                        Image(systemName: book.format == .pdf ? "doc.richtext" : "book.closed")
                            .font(.system(size: min(geometry.size.width * 0.28, 42),
                                          weight: .ultraLight))
                        if geometry.size.width > 70 {
                            Text(book.format.rawValue.uppercased())
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
            if let data = await BookCoverStore.shared.data(for: book),
               !Task.isCancelled {
                cover = NSImage(data: data)
            }
        }
    }
}
