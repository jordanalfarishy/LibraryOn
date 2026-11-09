package com.libraryon.android

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.provider.DocumentsContract
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.widget.BaseAdapter
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.PopupMenu
import android.widget.TextView
import android.widget.Toast
import java.util.concurrent.Executors

class MainActivity : Activity() {
    private val library by lazy { DocumentLibrary(this) }
    private val progress by lazy { ProgressRepository(this) }
    private val worker = Executors.newSingleThreadExecutor()
    private var currentRoot: LibraryRoot? = null
    private var allBooks = emptyList<Book>()
    private var currentFolder = ""
    private var search = ""
    private var scanGeneration = 0
    private lateinit var rootButton: TextView
    private lateinit var folderLabel: TextView
    private lateinit var status: TextView
    private lateinit var list: ListView
    private val entries = mutableListOf<Entry>()

    private sealed interface Entry {
        data class Folder(val path: String, val name: String) : Entry
        data class Volume(val book: Book) : Entry
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        buildScreen()
        val roots = library.roots()
        currentRoot = roots.firstOrNull { it.uri.toString() == library.selectedRoot } ?: roots.firstOrNull()
        if (currentRoot != null) scan() else render()
    }

    override fun onResume() {
        super.onResume()
        if (::list.isInitialized) render()
    }

    private fun buildScreen() {
        val outer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Ui.background)
            setPadding(dp(18), dp(18), dp(18), 0)
            setOnApplyWindowInsetsListener { view, insets ->
                val top = if (Build.VERSION.SDK_INT >= 30) {
                    insets.getInsets(WindowInsets.Type.statusBars()).top
                } else insets.systemWindowInsetTop
                val bottom = if (Build.VERSION.SDK_INT >= 30) {
                    insets.getInsets(WindowInsets.Type.navigationBars()).bottom
                } else insets.systemWindowInsetBottom
                view.setPadding(dp(18), top + dp(18), dp(18), bottom)
                insets
            }
        }
        val heading = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        heading.addView(Ui.text(this, "LibraryOn", 29f, Ui.ink, true))
        heading.addView(Ui.text(this, "Pustaka di perangkat Anda", 13f, Ui.muted))
        outer.addView(heading)

        val rootRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(22), 0, dp(12))
        }
        rootButton = Ui.button(this, "Pilih pustaka  ▾").apply { setOnClickListener { showRoots(it) } }
        rootRow.addView(rootButton, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        rootRow.addView(Ui.button(this, "+ Folder", true).apply {
            setOnClickListener { chooseTree(REQUEST_LIBRARY) }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            leftMargin = dp(8)
        })
        outer.addView(rootRow)

        val syncRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        syncRow.addView(Ui.button(this, "Folder progres").apply {
            setOnClickListener { chooseTree(REQUEST_SYNC) }
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        syncRow.addView(Ui.button(this, "Sinkronkan sekarang").apply {
            setOnClickListener { syncNow() }
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { leftMargin = dp(8) })
        outer.addView(syncRow)

        val input = EditText(this).apply {
            hint = "Cari judul buku"
            textSize = 15f
            setSingleLine(true)
            setPadding(dp(14), dp(8), dp(14), dp(8))
            background = Ui.rounded(-1, dp(13).toFloat(), 0xFFE6E1EF.toInt())
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                    search = s?.toString()?.trim().orEmpty()
                    render()
                }
                override fun afterTextChanged(s: Editable?) = Unit
            })
        }
        outer.addView(input, LinearLayout.LayoutParams(-1, -2).apply {
            topMargin = dp(18)
            bottomMargin = dp(12)
        })

        val pathRow = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
        folderLabel = Ui.text(this, "", 15f, Ui.ink, true)
        pathRow.addView(folderLabel, LinearLayout.LayoutParams(0, -2, 1f))
        pathRow.addView(Ui.button(this, "↻").apply { setOnClickListener { scan() } })
        outer.addView(pathRow)
        status = Ui.text(this, "", 13f, Ui.muted).apply { setPadding(0, dp(9), 0, dp(7)) }
        outer.addView(status)
        list = ListView(this).apply {
            divider = null
            dividerHeight = dp(8)
            setBackgroundColor(Ui.background)
            adapter = BookAdapter()
            setOnItemClickListener { _, _, position, _ ->
                when (val entry = entries[position]) {
                    is Entry.Folder -> { currentFolder = entry.path; render() }
                    is Entry.Volume -> open(entry.book)
                }
            }
        }
        outer.addView(list, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(outer)
    }

    private fun showRoots(anchor: View) {
        val popup = PopupMenu(this, anchor)
        val roots = library.roots()
        roots.forEachIndexed { index, root -> popup.menu.add(0, index, index, root.name) }
        popup.menu.add(0, 1000, roots.size, "+ Tambah folder pustaka")
        if (currentRoot != null) popup.menu.add(0, 1001, roots.size + 1, "Lepas folder ini")
        popup.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                1000 -> chooseTree(REQUEST_LIBRARY)
                1001 -> {
                    currentRoot?.let { library.removeRoot(it.uri) }
                    currentRoot = library.roots().firstOrNull()
                    library.selectedRoot = currentRoot?.uri?.toString()
                    currentFolder = ""
                    scan()
                }
                else -> {
                    currentRoot = roots[item.itemId]
                    library.selectedRoot = currentRoot?.uri?.toString()
                    currentFolder = ""
                    scan()
                }
            }
            true
        }
        popup.show()
    }

    private fun chooseTree(request: Int) {
        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }, request)
    }

    @Deprecated("Uses the platform document picker result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK) return
        val uri = data?.data ?: return
        val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            contentResolver.takePersistableUriPermission(uri, flags)
            if (requestCode == REQUEST_LIBRARY) {
                currentRoot = library.addRoot(uri)
                currentFolder = ""
                scan()
            } else if (requestCode == REQUEST_SYNC) {
                if (flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION == 0) {
                    showMessage("Folder progres perlu izin tulis")
                    return
                }
                progress.syncFolder = uri
                showMessage("Folder progres dipilih. Ketuk Sinkronkan sekarang.")
            }
        } catch (error: Exception) { showMessage(error.message ?: "Folder tidak dapat diakses") }
    }

    private fun scan() {
        val root = currentRoot
        val generation = ++scanGeneration
        allBooks = emptyList()
        status.text = if (root == null) "Tambahkan folder untuk mulai membaca." else "Memindai ${root.name}…"
        render()
        if (root == null) return
        worker.execute {
            val result = runCatching { library.scan(root) }
            runOnUiThread {
                if (generation != scanGeneration) return@runOnUiThread
                result.onSuccess {
                    allBooks = it
                    status.text = "${it.size} berkas ditemukan"
                    render()
                }
                    .onFailure { status.text = "Folder tidak tersedia: ${it.message}" }
            }
        }
    }

    private fun render() {
        if (!::list.isInitialized) return
        rootButton.text = currentRoot?.name?.let { "$it  ▾" } ?: "Pilih pustaka  ▾"
        folderLabel.text = if (currentFolder.isEmpty()) "Semua buku" else "‹  $currentFolder"
        folderLabel.setOnClickListener {
            if (currentFolder.isNotEmpty()) {
                currentFolder = currentFolder.substringBeforeLast('/', "")
                render()
            }
        }
        entries.clear()
        val filtered = if (search.isNotEmpty()) allBooks.filter {
            it.title.contains(search, true) || it.relativePath.contains(search, true)
        } else allBooks.filter {
            currentFolder.isEmpty() || it.relativePath.startsWith("$currentFolder/")
        }
        if (search.isEmpty()) {
            val folderPrefix = if (currentFolder.isEmpty()) "" else "$currentFolder/"
            filtered.mapNotNull { book ->
                val remaining = book.relativePath.removePrefix(folderPrefix)
                if (!remaining.contains('/')) null else remaining.substringBefore('/')
            }.distinct().sorted().forEach { name ->
                entries.add(Entry.Folder(folderPrefix + name, name))
            }
            filtered.filter { !it.relativePath.removePrefix(folderPrefix).contains('/') }
                .forEach { entries.add(Entry.Volume(it)) }
        } else filtered.forEach { entries.add(Entry.Volume(it)) }
        if (currentRoot == null) status.text = "Tambahkan folder pustaka melalui pemilih file Android."
        else if (!status.text.toString().startsWith("Memindai") && !status.text.toString().startsWith("Folder tidak")) {
            status.text = "${allBooks.size} berkas ditemukan"
        }
        (list.adapter as BaseAdapter).notifyDataSetChanged()
    }

    private fun open(book: Book) {
        if (book.format in setOf("mp4", "m4v", "mov", "webm")) {
            try {
                startActivity(Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(book.uri, "video/*")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                })
            } catch (_: Exception) { showMessage("Tidak ada pemutar video untuk berkas ini") }
        } else startActivity(Intent(this, ReaderActivity::class.java).apply {
            putExtra("uri", book.uri.toString())
            putExtra("rootName", book.rootName)
            putExtra("relativePath", book.relativePath)
            putExtra("title", book.title)
            putExtra("format", book.format)
            putExtra("size", book.size)
        })
    }

    private fun syncNow() {
        status.text = "Menyinkronkan progres…"
        worker.execute {
            val result = runCatching { progress.sync() }
            runOnUiThread {
                result.onSuccess {
                    render()
                    status.text = "Progres tersinkron (${it} buku)."
                }
                    .onFailure { status.text = "Sinkronisasi gagal: ${it.message}" }
            }
        }
    }

    private fun showMessage(message: String) = Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private inner class BookAdapter : BaseAdapter() {
        override fun getCount() = entries.size
        override fun getItem(position: Int) = entries[position]
        override fun getItemId(position: Int) = position.toLong()
        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            val entry = entries[position]
            val row = LinearLayout(this@MainActivity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(14), dp(13), dp(14), dp(13))
                background = Ui.rounded(-1, dp(16).toFloat())
            }
            val marker = Ui.text(this@MainActivity, when (entry) {
                is Entry.Folder -> "▣"
                is Entry.Volume -> when (entry.book.format) {
                    "pdf" -> "PDF"; "epub" -> "EP"; "txt" -> "TXT"; "docx" -> "DOC"; else -> "▶"
                }
            }, 12f, Ui.accent, true).apply {
                gravity = Gravity.CENTER
                background = Ui.rounded(Ui.accentPale, dp(11).toFloat())
            }
            row.addView(marker, LinearLayout.LayoutParams(dp(48), dp(56)))
            val detail = LinearLayout(this@MainActivity).apply { orientation = LinearLayout.VERTICAL }
            val title = if (entry is Entry.Folder) entry.name else (entry as Entry.Volume).book.title
            detail.addView(Ui.text(this@MainActivity, title, 16f, Ui.ink, true).apply { maxLines = 2 })
            val subtitle = if (entry is Entry.Folder) "Folder" else {
                val book = (entry as Entry.Volume).book
                val value = progress.label(book)
                "${book.format.uppercase()} · $value"
            }
            detail.addView(Ui.text(this@MainActivity, subtitle, 12f, Ui.muted).apply { maxLines = 2 })
            row.addView(detail, LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(12) })
            row.addView(Ui.text(this@MainActivity, "›", 25f, Ui.muted))
            return row
        }
    }

    companion object {
        private const val REQUEST_LIBRARY = 10
        private const val REQUEST_SYNC = 11
    }
}
