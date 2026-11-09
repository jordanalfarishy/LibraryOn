package com.libraryon.android

import android.content.ContentResolver
import android.net.Uri
import android.text.Html
import android.util.Xml
import org.xmlpull.v1.XmlPullParser
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.nio.charset.Charset
import java.util.zip.ZipInputStream

data class Chapter(val title: String, val text: String)
data class BookContent(val chapters: List<Chapter>)

object BookReaders {
    fun load(resolver: ContentResolver, uri: Uri, format: String): BookContent {
        val stream = resolver.openInputStream(uri) ?: error("Berkas belum tersedia")
        return stream.use { input -> when (format) {
            "txt" -> BookContent(listOf(Chapter("Teks", decodeText(readLimited(input, 20_000_000)))))
            "docx" -> docx(input)
            "epub" -> epub(input)
            else -> error("Format belum didukung")
        } }
    }

    private fun docx(input: InputStream): BookContent {
        val entries = unzip(input)
        val xml = entries["word/document.xml"] ?: error("DOCX tidak memiliki document.xml")
        val parser = Xml.newPullParser().apply { setInput(ByteArrayInputStream(xml), "UTF-8") }
        val result = StringBuilder()
        var inText = false
        while (parser.eventType != XmlPullParser.END_DOCUMENT) {
            when (parser.eventType) {
                XmlPullParser.START_TAG -> when (parser.name.substringAfter(':')) {
                    "t" -> inText = true
                    "tab" -> result.append('\t')
                    "br" -> result.append('\n')
                }
                XmlPullParser.TEXT -> if (inText) result.append(parser.text)
                XmlPullParser.END_TAG -> when (parser.name.substringAfter(':')) {
                    "t" -> inText = false
                    "p" -> result.append("\n\n")
                }
            }
            parser.next()
        }
        return BookContent(listOf(Chapter("Dokumen", result.toString().trim())))
    }

    private fun epub(input: InputStream): BookContent {
        val entries = unzip(input)
        val container = entries["META-INF/container.xml"] ?: error("EPUB tidak memiliki container.xml")
        var opfPath: String? = null
        val containerParser = Xml.newPullParser().apply { setInput(ByteArrayInputStream(container), "UTF-8") }
        while (containerParser.eventType != XmlPullParser.END_DOCUMENT) {
            if (containerParser.eventType == XmlPullParser.START_TAG &&
                containerParser.name.substringAfter(':') == "rootfile") {
                opfPath = containerParser.getAttributeValue(null, "full-path")
                break
            }
            containerParser.next()
        }
        val packagePath = safePath("", opfPath ?: error("EPUB tidak memiliki OPF"))
        val packageXml = entries[packagePath] ?: error("EPUB tidak memiliki OPF")
        val base = packagePath.substringBeforeLast('/', "")
        val manifest = mutableMapOf<String, String>()
        val spine = mutableListOf<String>()
        val titles = mutableMapOf<String, String>()
        val parser = Xml.newPullParser().apply { setInput(ByteArrayInputStream(packageXml), "UTF-8") }
        var inTitle = false
        var bookTitle = "Buku"
        while (parser.eventType != XmlPullParser.END_DOCUMENT) {
            when (parser.eventType) {
                XmlPullParser.START_TAG -> when (parser.name.substringAfter(':')) {
                    "item" -> {
                        val id = parser.getAttributeValue(null, "id")
                        val href = parser.getAttributeValue(null, "href")
                        val media = parser.getAttributeValue(null, "media-type") ?: ""
                        if (id != null && href != null && media.contains("html")) manifest[id] = href
                    }
                    "itemref" -> parser.getAttributeValue(null, "idref")?.let(spine::add)
                    "title" -> inTitle = true
                }
                XmlPullParser.TEXT -> if (inTitle) bookTitle = parser.text
                XmlPullParser.END_TAG -> if (parser.name.substringAfter(':') == "title") inTitle = false
            }
            parser.next()
        }
        val chapters = spine.mapNotNull { id ->
            val href = manifest[id] ?: return@mapNotNull null
            val path = safePath(base, href.substringBefore('#'))
            val bytes = entries[path] ?: return@mapNotNull null
            val html = String(bytes, Charsets.UTF_8)
                .replace(Regex("(?is)<(script|style|head)\\b[^>]*>.*?</\\1>"), "")
            val text = Html.fromHtml(html, Html.FROM_HTML_MODE_COMPACT).toString().trim()
            if (text.isBlank()) return@mapNotNull null
            Chapter("Bab ${titles.size + 1}", text).also { titles[id] = it.title }
        }
        require(chapters.isNotEmpty()) { "EPUB tidak memiliki bab teks yang dapat dibaca" }
        return BookContent(chapters.ifEmpty { listOf(Chapter(bookTitle, "")) })
    }

    private fun unzip(input: InputStream): Map<String, ByteArray> {
        val result = mutableMapOf<String, ByteArray>()
        var total = 0L
        ZipInputStream(input).use { zip ->
            var entry = zip.nextEntry
            var count = 0
            while (entry != null && count < 2000) {
                count++
                if (!entry.isDirectory && !entry.name.startsWith("/") &&
                    !entry.name.split('/').contains("..")) {
                    val extension = entry.name.substringAfterLast('.', "").lowercase()
                    if (extension in setOf("xml", "opf", "xhtml", "html", "htm")) {
                        val bytes = readLimited(zip, 10_000_000)
                        total += bytes.size
                        require(total <= 40_000_000) { "Arsip terlalu besar" }
                        result[entry.name] = bytes
                    }
                }
                zip.closeEntry()
                entry = zip.nextEntry
            }
        }
        return result
    }

    private fun safePath(base: String, href: String): String {
        val components = mutableListOf<String>()
        for (component in (if (base.isBlank()) href else "$base/$href").split('/')) {
            when (component) {
                "", "." -> Unit
                ".." -> { require(components.isNotEmpty()) { "Path EPUB tidak valid" }; components.removeAt(components.lastIndex) }
                else -> components.add(Uri.decode(component))
            }
        }
        return components.joinToString("/")
    }

    private fun readLimited(input: InputStream, max: Int): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            require(output.size() + count <= max) { "Berkas terlalu besar untuk pembaca teks" }
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    private fun decodeText(bytes: ByteArray): String = when {
        bytes.size >= 2 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xFE.toByte() ->
            String(bytes, 2, bytes.size - 2, Charset.forName("UTF-16LE"))
        bytes.size >= 2 && bytes[0] == 0xFE.toByte() && bytes[1] == 0xFF.toByte() ->
            String(bytes, 2, bytes.size - 2, Charset.forName("UTF-16BE"))
        bytes.size >= 3 && bytes[0] == 0xEF.toByte() && bytes[1] == 0xBB.toByte() && bytes[2] == 0xBF.toByte() ->
            String(bytes, 3, bytes.size - 3, Charsets.UTF_8)
        else -> String(bytes, Charsets.UTF_8)
    }
}
