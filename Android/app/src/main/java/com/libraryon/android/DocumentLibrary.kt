package com.libraryon.android

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.text.Normalizer
import java.util.ArrayDeque
import java.util.Locale

data class LibraryRoot(val uri: Uri, val name: String)

data class Book(
    val uri: Uri,
    val rootName: String,
    val relativePath: String,
    val title: String,
    val format: String,
    val size: Long
) {
    val portableId: String get() {
        val identity = listOf(rootName, relativePath).map {
            Normalizer.normalize(it, Normalizer.Form.NFC)
        } + listOf(format, size.toString())
        val bytes = MessageDigest.getInstance("SHA-256")
            .digest(identity.joinToString("\u0000").toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }
}

class DocumentLibrary(private val context: Context) {
    private val prefs = context.getSharedPreferences("library", Context.MODE_PRIVATE)
    private val resolver: ContentResolver get() = context.contentResolver

    fun roots(): List<LibraryRoot> {
        val saved = JSONArray(prefs.getString("roots", "[]"))
        return (0 until saved.length()).mapNotNull { index ->
            val value = saved.optJSONObject(index) ?: return@mapNotNull null
            val uri = value.optString("uri")
            val name = value.optString("name")
            if (uri.isBlank() || name.isBlank()) null else LibraryRoot(Uri.parse(uri), name)
        }
    }

    fun addRoot(uri: Uri): LibraryRoot {
        val name = queryName(DocumentsContract.buildDocumentUriUsingTree(
            uri, DocumentsContract.getTreeDocumentId(uri))) ?: "Pustaka"
        val root = LibraryRoot(uri, name)
        val roots = roots().filterNot { it.uri == uri } + root
        prefs.edit().putString("roots", JSONArray().apply {
            roots.forEach { put(JSONObject().put("uri", it.uri.toString()).put("name", it.name)) }
        }.toString()).putString("selectedRoot", uri.toString()).apply()
        return root
    }

    fun removeRoot(uri: Uri) {
        val roots = roots().filterNot { it.uri == uri }
        prefs.edit().putString("roots", JSONArray().apply {
            roots.forEach { put(JSONObject().put("uri", it.uri.toString()).put("name", it.name)) }
        }.toString()).apply()
    }

    var selectedRoot: String?
        get() = prefs.getString("selectedRoot", null)
        set(value) { prefs.edit().putString("selectedRoot", value).apply() }

    fun queryName(uri: Uri): String? = resolver.query(uri,
        arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { cursor ->
        if (cursor.moveToFirst()) cursor.getString(0) else null
    }

    /** Scans a SAF tree without relying on filesystem paths or provider-specific APIs. */
    fun scan(root: LibraryRoot): List<Book> {
        data class Folder(val documentId: String, val relativePath: String, val depth: Int)
        val pending = ArrayDeque<Folder>()
        pending.add(Folder(DocumentsContract.getTreeDocumentId(root.uri), "", 0))
        val books = mutableListOf<Book>()
        var visited = 0
        while (pending.isNotEmpty() && visited < 100_000) {
            val folder = pending.removeFirst()
            if (folder.depth > 32) continue
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(root.uri, folder.documentId)
            resolver.query(children, arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE
            ), null, null, null)?.use { cursor ->
                while (cursor.moveToNext() && visited < 100_000) {
                    visited++
                    val id = cursor.getString(0) ?: continue
                    val name = cursor.getString(1) ?: continue
                    val mime = cursor.getString(2) ?: ""
                    if (name == "." || name == ".." || name.contains('/')) continue
                    val path = if (folder.relativePath.isEmpty()) name else "${folder.relativePath}/$name"
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        pending.add(Folder(id, path, folder.depth + 1))
                    } else {
                        val format = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
                        if (format !in supportedFormats) continue
                        val uri = DocumentsContract.buildDocumentUriUsingTree(root.uri, id)
                        val size = if (cursor.isNull(3)) -1 else cursor.getLong(3)
                        books.add(Book(uri, root.name, path, name.substringBeforeLast('.'), format, size))
                    }
                }
            }
        }
        return books.sortedWith(compareBy({ it.relativePath.lowercase(Locale.ROOT) }))
    }

    companion object {
        val supportedFormats = setOf("pdf", "epub", "txt", "docx", "mp4", "m4v", "mov", "webm")
    }
}
