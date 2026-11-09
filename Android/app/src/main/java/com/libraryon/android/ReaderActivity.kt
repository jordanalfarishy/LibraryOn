package com.libraryon.android

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.os.ParcelFileDescriptor
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.text.SpannableString
import android.text.style.BackgroundColorSpan
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.widget.ImageView
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.text.BreakIterator
import java.util.Locale
import java.util.concurrent.Executors

class ReaderActivity : Activity() {
    private lateinit var book: Book
    private val progress by lazy { ProgressRepository(this) }
    private val worker = Executors.newSingleThreadExecutor()
    private lateinit var scroll: ScrollView
    private lateinit var pageImage: ImageView
    private lateinit var imagePan: HorizontalScrollView
    private lateinit var body: TextView
    private lateinit var position: TextView
    private lateinit var backButton: TextView
    private lateinit var nextButton: TextView
    private lateinit var playButton: TextView
    private lateinit var languageButton: TextView
    private var content: BookContent? = null
    private var chapterIndex = 0
    private var pageIndex = 0
    private var pageCount = 0
    private var descriptor: ParcelFileDescriptor? = null
    private var renderer: PdfRenderer? = null
    private var bitmap: Bitmap? = null
    private var zoom = 1
    private var renderGeneration = 0
    private var sentences = emptyList<IntRange>()
    private var sentenceIndex = 0
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var playing = false
    private var speechLanguage = Locale.forLanguageTag("id-ID")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent.getStringExtra("uri") ?: run { finish(); return }
        book = Book(Uri.parse(uri), intent.getStringExtra("rootName") ?: "Pustaka",
            intent.getStringExtra("relativePath") ?: "", intent.getStringExtra("title") ?: "Buku",
            intent.getStringExtra("format") ?: "txt", intent.getLongExtra("size", -1))
        buildScreen()
        if (book.format == "pdf") openPdf() else openText()
    }

    private fun buildScreen() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Ui.background)
            setOnApplyWindowInsetsListener { view, insets ->
                val top = if (Build.VERSION.SDK_INT >= 30) {
                    insets.getInsets(WindowInsets.Type.statusBars()).top
                } else insets.systemWindowInsetTop
                val bottom = if (Build.VERSION.SDK_INT >= 30) {
                    insets.getInsets(WindowInsets.Type.navigationBars()).bottom
                } else insets.systemWindowInsetBottom
                view.setPadding(0, top, 0, bottom)
                insets
            }
        }
        val toolbar = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(10))
        }
        toolbar.addView(Ui.button(this, "‹ Pustaka").apply { setOnClickListener { finish() } })
        val titleBlock = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), 0, dp(10), 0)
        }
        titleBlock.addView(Ui.text(this, book.title, 16f, Ui.ink, true).apply { maxLines = 1 })
        titleBlock.addView(Ui.text(this, book.format.uppercase(), 11f, Ui.muted))
        toolbar.addView(titleBlock, LinearLayout.LayoutParams(0, -2, 1f))
        if (book.format == "pdf") {
            toolbar.addView(Ui.button(this, "1×").apply {
                contentDescription = "Perbesar halaman PDF"
                setOnClickListener {
                    zoom = if (zoom == 3) 1 else zoom + 1
                    text = "${zoom}×"
                    renderPage(updateProgress = false)
                }
            }, LinearLayout.LayoutParams(-2, -2).apply { rightMargin = dp(8) })
        }
        toolbar.addView(Ui.button(this, "✓").apply {
            contentDescription = "Tandai selesai"
            setOnClickListener {
                progress.markFinished(book, true)
                Toast.makeText(this@ReaderActivity, "Ditandai selesai", Toast.LENGTH_SHORT).show()
            }
        })
        root.addView(toolbar)

        position = Ui.text(this, "Memuat buku…", 13f, Ui.muted).apply {
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(10), dp(12), dp(10))
        }
        root.addView(position)
        scroll = ScrollView(this).apply {
            isFillViewport = true
            background = Ui.rounded(Color.WHITE, dp(18).toFloat())
        }
        pageImage = ImageView(this).apply {
            scaleType = ImageView.ScaleType.FIT_XY
            visibility = View.GONE
        }
        imagePan = HorizontalScrollView(this).apply {
            isFillViewport = true
            visibility = View.GONE
        }
        imagePan.addView(pageImage, FrameLayout.LayoutParams(-1, -2))
        body = Ui.text(this, "", 18f).apply {
            setTextIsSelectable(true)
            setLineSpacing(dp(5).toFloat(), 1.1f)
            setPadding(dp(22), dp(22), dp(22), dp(44))
        }
        val contentFrame = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        contentFrame.addView(imagePan, LinearLayout.LayoutParams(-1, -2))
        contentFrame.addView(body, LinearLayout.LayoutParams(-1, -2))
        scroll.addView(contentFrame)
        root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f).apply {
            leftMargin = dp(10); rightMargin = dp(10)
        })

        val controls = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
        backButton = Ui.button(this, "‹ Sebelumnya").apply { setOnClickListener { move(-1) } }
        nextButton = Ui.button(this, "Berikutnya ›").apply { setOnClickListener { move(1) } }
        controls.addView(backButton, LinearLayout.LayoutParams(0, -2, 1f))
        controls.addView(nextButton, LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(8) })
        root.addView(controls)
        if (book.format != "pdf") {
            val audioRow = LinearLayout(this).apply {
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(12), 0, dp(12), dp(14))
            }
            languageButton = Ui.button(this, "Suara: ID").apply { setOnClickListener { toggleLanguage() } }
            playButton = Ui.button(this, "▶ Dengarkan", true).apply { setOnClickListener { togglePlayback() } }
            audioRow.addView(languageButton, LinearLayout.LayoutParams(0, -2, 1f))
            audioRow.addView(playButton, LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(8) })
            root.addView(audioRow)
            tts = TextToSpeech(this) { result ->
                runOnUiThread {
                    ttsReady = result == TextToSpeech.SUCCESS
                    if (!ttsReady) position.text = "Suara perangkat tidak tersedia"
                    else tts?.setLanguage(speechLanguage)
                }
            }.also { engine ->
                engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) = Unit
                    override fun onError(utteranceId: String?) = Unit
                    override fun onDone(utteranceId: String?) {
                        runOnUiThread {
                            if (!playing) return@runOnUiThread
                            sentenceIndex++
                            if (sentenceIndex >= sentences.size) {
                                playing = false
                                playButton.text = "▶ Dengarkan"
                                progress.saveAudio(book, 0, chapterIndex)
                            } else speakCurrent()
                        }
                    }
                })
            }
        }
        setContentView(root)
    }

    private fun openPdf() {
        body.visibility = View.GONE
        imagePan.visibility = View.VISIBLE
        pageImage.visibility = View.VISIBLE
        worker.execute {
            try {
                val fd = contentResolver.openFileDescriptor(book.uri, "r") ?: error("PDF belum tersedia")
                val pdf = PdfRenderer(fd)
                descriptor = fd
                renderer = pdf
                val count = pdf.pageCount
                runOnUiThread {
                    pageCount = count
                    pageIndex = progress.visualPage(book).coerceIn(0, (count - 1).coerceAtLeast(0))
                    renderPage()
                }
            } catch (error: Exception) {
                runOnUiThread { position.text = "PDF tidak dapat dibuka: ${error.message}" }
            }
        }
    }

    private fun renderPage(updateProgress: Boolean = true) {
        val pdf = renderer ?: return
        val requested = pageIndex
        val generation = ++renderGeneration
        position.text = "Halaman ${requested + 1} dari $pageCount · PDF visual"
        backButton.isEnabled = requested > 0
        nextButton.isEnabled = requested < pageCount - 1
        if (updateProgress) progress.saveVisual(book, pdfPage = requested)
        worker.execute {
            try {
                val page = pdf.openPage(requested)
                val displayWidth = (resources.displayMetrics.widthPixels - dp(20)) * zoom
                val displayHeight = (page.height.toDouble() * displayWidth / page.width)
                    .toInt().coerceAtLeast(1)
                val width = displayWidth.coerceAtMost(2400)
                val height = (page.height.toDouble() * width / page.width)
                    .toInt().coerceIn(1, 4000)
                val next = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                next.eraseColor(Color.WHITE)
                page.render(next, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                page.close()
                runOnUiThread {
                    if (generation != renderGeneration || isFinishing) next.recycle()
                    else {
                        pageImage.setImageBitmap(next)
                        pageImage.layoutParams = FrameLayout.LayoutParams(displayWidth, displayHeight)
                        imagePan.scrollTo(0, 0)
                        bitmap?.recycle()
                        bitmap = next
                        scroll.scrollTo(0, 0)
                    }
                }
            } catch (error: Exception) {
                runOnUiThread { position.text = "Halaman tidak dapat ditampilkan: ${error.message}" }
            }
        }
    }

    private fun openText() {
        worker.execute {
            val result = runCatching { BookReaders.load(contentResolver, book.uri, book.format) }
            runOnUiThread {
                result.onSuccess {
                    content = it
                    chapterIndex = progress.epubChapter(book).coerceIn(0, it.chapters.lastIndex)
                    showChapter()
                }.onFailure { position.text = "Buku tidak dapat dibuka: ${it.message}" }
            }
        }
    }

    private fun showChapter() {
        val chapters = content?.chapters ?: return
        stopPlayback()
        val chapter = chapters[chapterIndex]
        body.text = chapter.text
        position.text = if (book.format == "epub") "Bab ${chapterIndex + 1} dari ${chapters.size}" else book.title
        backButton.isEnabled = chapterIndex > 0
        nextButton.isEnabled = chapterIndex < chapters.lastIndex
        progress.saveVisual(book, epubChapter = chapterIndex)
        sentenceIndex = if (progress.audioChapter(book) == chapterIndex) {
            progress.audioSentence(book).coerceAtLeast(0)
        } else 0
        sentences = splitSentences(chapter.text)
        if (sentenceIndex >= sentences.size) sentenceIndex = 0
        scroll.scrollTo(0, 0)
    }

    private fun move(delta: Int) {
        if (book.format == "pdf") {
            val candidate = pageIndex + delta
            if (candidate in 0 until pageCount) { pageIndex = candidate; renderPage() }
        } else {
            val chapters = content?.chapters ?: return
            val candidate = chapterIndex + delta
            if (candidate in chapters.indices) { chapterIndex = candidate; showChapter() }
        }
    }

    private fun togglePlayback() {
        if (playing) { stopPlayback(); return }
        if (!ttsReady) {
            Toast.makeText(this, "Menyiapkan suara perangkat…", Toast.LENGTH_SHORT).show()
            return
        }
        if (sentences.isEmpty()) return
        playing = true
        playButton.text = "■ Jeda"
        speakCurrent()
    }

    private fun speakCurrent() {
        val text = content?.chapters?.get(chapterIndex)?.text ?: return
        val range = sentences.getOrNull(sentenceIndex) ?: return
        progress.saveAudio(book, sentenceIndex, chapterIndex)
        highlight(text, range)
        tts?.speak(text.substring(range.first, range.last + 1), TextToSpeech.QUEUE_FLUSH,
            Bundle(), "sentence-$chapterIndex-$sentenceIndex")
    }

    private fun highlight(text: String, range: IntRange) {
        val styled = SpannableString(text)
        styled.setSpan(BackgroundColorSpan(Ui.accentPale), range.first, range.last + 1, 0)
        body.text = styled
        body.post {
            val line = body.layout?.getLineForOffset(range.first) ?: return@post
            scroll.smoothScrollTo(0, (body.top + body.layout.getLineTop(line) - dp(24)).coerceAtLeast(0))
        }
    }

    private fun toggleLanguage() {
        stopPlayback()
        speechLanguage = if (speechLanguage.language == "id") Locale.ENGLISH else Locale.forLanguageTag("id-ID")
        languageButton.text = if (speechLanguage.language == "id") "Suara: ID" else "Voice: EN"
        val result = tts?.setLanguage(speechLanguage)
        if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
            Toast.makeText(this, "Bahasa suara belum terpasang di perangkat", Toast.LENGTH_LONG).show()
        }
    }

    private fun stopPlayback() {
        playing = false
        tts?.stop()
        if (::playButton.isInitialized) playButton.text = "▶ Dengarkan"
    }

    private fun splitSentences(text: String): List<IntRange> {
        val iterator = BreakIterator.getSentenceInstance(Locale.ROOT)
        iterator.setText(text)
        val result = mutableListOf<IntRange>()
        var start = iterator.first()
        var end = iterator.next()
        while (end != BreakIterator.DONE) {
            val first = (start until end).firstOrNull { !text[it].isWhitespace() }
            val last = (end - 1 downTo start).firstOrNull { !text[it].isWhitespace() }
            if (first != null && last != null) result.add(first..last)
            start = end
            end = iterator.next()
        }
        return result
    }

    override fun onStop() {
        super.onStop()
        stopPlayback()
    }

    override fun onDestroy() {
        super.onDestroy()
        renderGeneration++
        tts?.shutdown()
        pageImage.setImageDrawable(null)
        bitmap?.recycle()
        worker.execute { renderer?.close(); descriptor?.close() }
        worker.shutdown()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
