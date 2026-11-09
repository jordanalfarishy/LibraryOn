package com.libraryon.android

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.UUID

/** Android implementation of Docs/Progress-sync-format.md. */
class ProgressRepository(private val context: Context) {
    private val prefs = context.getSharedPreferences("progress", Context.MODE_PRIVATE)
    private val resolver get() = context.contentResolver

    var syncFolder: Uri?
        get() = prefs.getString("syncFolder", null)?.let(Uri::parse)
        set(value) { prefs.edit().putString("syncFolder", value?.toString()).apply() }

    private fun document(): JSONObject = JSONObject(prefs.getString("document", null)
        ?: "{\"schemaVersion\":1,\"books\":{}}")

    private fun save(document: JSONObject) {
        prefs.edit().putString("document", document.toString()).apply()
    }

    private fun bookRecord(document: JSONObject, book: Book): JSONObject {
        val books = document.getJSONObject("books")
        return books.optJSONObject(book.portableId) ?: JSONObject().apply {
            put("libraryName", book.rootName)
            put("relativePath", book.relativePath)
            put("format", book.format)
            put("fileSize", book.size)
            books.put(book.portableId, this)
        }
    }

    fun visualPage(book: Book): Int = document().optJSONObject("books")
        ?.optJSONObject(book.portableId)?.optJSONObject("visual")
        ?.optJSONObject("value")?.optInt("pdfPage", 0) ?: 0

    fun epubChapter(book: Book): Int = document().optJSONObject("books")
        ?.optJSONObject(book.portableId)?.optJSONObject("visual")
        ?.optJSONObject("value")?.optInt("epubChapter", 0) ?: 0

    fun audioSentence(book: Book): Int = document().optJSONObject("books")
        ?.optJSONObject(book.portableId)?.optJSONObject("audio")
        ?.optJSONObject("value")?.optInt("sentenceIndex", 0) ?: 0

    fun audioChapter(book: Book): Int? = document().optJSONObject("books")
        ?.optJSONObject(book.portableId)?.optJSONObject("audio")
        ?.optJSONObject("value")?.takeIf { it.has("epubAudioChapter") }
        ?.optInt("epubAudioChapter")

    fun label(book: Book): String {
        val record = document().optJSONObject("books")?.optJSONObject(book.portableId)
            ?: return "Belum dibaca"
        if (record.optJSONObject("completion")?.optBoolean("value") == true) return "Selesai"
        val value = record.optJSONObject("visual")?.optJSONObject("value") ?: return "Belum dibaca"
        return when (book.format) {
            "pdf" -> "Halaman ${value.optInt("pdfPage") + 1}"
            "epub" -> "Bab ${value.optInt("epubChapter") + 1}"
            else -> "Terakhir dibuka"
        }
    }

    @Synchronized fun saveVisual(book: Book, pdfPage: Int = 0, epubChapter: Int = 0) {
        val document = document()
        val value = JSONObject().put("pdfPage", pdfPage.coerceAtLeast(0))
            .put("epubChapter", epubChapter.coerceAtLeast(0)).put("epubCFI", "")
        bookRecord(document, book).put("visual", field(value))
        save(document)
    }

    @Synchronized fun saveAudio(book: Book, sentenceIndex: Int, chapter: Int? = null) {
        val document = document()
        val value = JSONObject().put("sentenceIndex", sentenceIndex.coerceAtLeast(0))
        if (chapter != null) value.put("epubAudioChapter", chapter)
        bookRecord(document, book).put("audio", field(value))
        save(document)
    }

    @Synchronized fun markFinished(book: Book, finished: Boolean) {
        val document = document()
        bookRecord(document, book).put("completion", field(finished))
        save(document)
    }

    private fun field(value: Any): JSONObject {
        val deviceID = prefs.getString("deviceID", null) ?: UUID.randomUUID().toString().also {
            prefs.edit().putString("deviceID", it).apply()
        }
        val sequence = prefs.getInt("sequence", 0) + 1
        prefs.edit().putInt("sequence", sequence).apply()
        return JSONObject().put("value", value).put("version", JSONObject()
            .put("changedAt", System.currentTimeMillis())
            .put("deviceID", deviceID).put("sequence", sequence))
    }

    /** Reads the provider's current file, merges per field, then writes the merged v1 document. */
    @Synchronized fun sync(): Int {
        val tree = syncFolder ?: error("Pilih folder progres dahulu")
        val local = document()
        val target = findSyncFile(tree)
        val remote = if (target == null) JSONObject("{\"schemaVersion\":1,\"books\":{}}") else {
            val bytes = resolver.openInputStream(target)?.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    require(output.size() + count <= 10_000_000) { "File progres terlalu besar" }
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            } ?: error("File progres tidak dapat dibaca")
            try { JSONObject(String(bytes, Charsets.UTF_8)) }
            catch (_: Exception) { error("File progres rusak; tidak ditimpa") }
        }
        require(remote.optInt("schemaVersion", -1) == 1 && remote.optJSONObject("books") != null) {
            "Versi atau isi file progres tidak didukung; tidak ditimpa"
        }
        val merged = merge(local, remote)
        if (merged.toString() != remote.toString()) {
            val parent = DocumentsContract.buildDocumentUriUsingTree(tree,
                DocumentsContract.getTreeDocumentId(tree))
            val output = target ?: DocumentsContract.createDocument(resolver, parent,
                "application/json", FILE_NAME) ?: error("Tidak dapat membuat file progres")
            resolver.openOutputStream(output, "wt")?.use { it.write(merged.toString(2).toByteArray(Charsets.UTF_8)) }
                ?: error("File progres tidak dapat ditulis")
        }
        save(merged)
        return merged.getJSONObject("books").length()
    }

    private fun findSyncFile(tree: Uri): Uri? {
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, rootId)
        resolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getString(1) == FILE_NAME) {
                    return DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0))
                }
            }
        }
        return null
    }

    private fun merge(local: JSONObject, remote: JSONObject): JSONObject {
        val result = JSONObject(remote.toString())
        val localBooks = local.getJSONObject("books")
        val resultBooks = result.getJSONObject("books")
        val localReset = local.optJSONObject("resetAllVersion")
        val remoteReset = remote.optJSONObject("resetAllVersion")
        val reset = if (compare(localReset, remoteReset) > 0) localReset else remoteReset
        if (reset != null) result.put("resetAllVersion", reset)
        for (id in localBooks.keys()) {
            val incoming = localBooks.optJSONObject(id) ?: continue
            val existing = resultBooks.optJSONObject(id)
            if (existing == null) {
                resultBooks.put(id, JSONObject(incoming.toString()))
            } else if (listOf("libraryName", "relativePath", "format")
                    .all { existing.optString(it) == incoming.optString(it) } &&
                    existing.optLong("fileSize") == incoming.optLong("fileSize")) {
                for (fieldName in listOf("visual", "audio", "completion")) {
                    val a = existing.optJSONObject(fieldName)
                    val b = incoming.optJSONObject(fieldName)
                    if (compare(b?.optJSONObject("version"), a?.optJSONObject("version")) > 0) {
                        existing.put(fieldName, b)
                    }
                }
            }
        }
        if (reset != null) {
            val remove = mutableListOf<String>()
            for (id in resultBooks.keys()) {
                val record = resultBooks.optJSONObject(id) ?: continue
                for (fieldName in listOf("visual", "audio", "completion")) {
                    val version = record.optJSONObject(fieldName)?.optJSONObject("version")
                    if (version != null && compare(version, reset) <= 0) record.remove(fieldName)
                }
                if (listOf("visual", "audio", "completion").all { !record.has(it) }) remove.add(id)
            }
            remove.forEach(resultBooks::remove)
        }
        return result
    }

    private fun compare(a: JSONObject?, b: JSONObject?): Int {
        if (a == null) return if (b == null) 0 else -1
        if (b == null) return 1
        val time = a.optLong("changedAt").compareTo(b.optLong("changedAt"))
        if (time != 0) return time
        val sequence = a.optInt("sequence").compareTo(b.optInt("sequence"))
        if (sequence != 0) return sequence
        return a.optString("deviceID").compareTo(b.optString("deviceID"))
    }

    companion object { private const val FILE_NAME = "LibraryOn-progress.json" }
}
