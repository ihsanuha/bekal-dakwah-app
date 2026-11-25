package com.bekaldakwah.bekal_dakwah_app

import com.bekaldakwah.bekal_dakwah_app.quran.QuranNativeEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bekaldakwah/quran_engine"
    private val executor = Executors.newCachedThreadPool()
    private lateinit var quranEngine: QuranNativeEngine

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        quranEngine = QuranNativeEngine(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSurahs" -> executor.execute {
                    try {
                        val data = quranEngine.getSurahs()
                        runOnUiThread { result.success(data) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("DB_ERROR", e.message, null) }
                    }
                }
                "getJuzList" -> executor.execute {
                    try {
                        val data = quranEngine.getJuzList()
                        runOnUiThread { result.success(data) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("DB_ERROR", e.message, null) }
                    }
                }
                "getVerses" -> {
                    val surahId = call.argument<Int>("surahId") ?: 1
                    executor.execute {
                        try {
                            val data = quranEngine.getVerses(surahId)
                            runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DB_ERROR", e.message, null) }
                        }
                    }
                }
                "getPageData" -> {
                    val pageNumber = call.argument<Int>("pageNumber") ?: 1
                    executor.execute {
                        try {
                            val data = quranEngine.getPageData(pageNumber)
                            runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DB_ERROR", e.message, null) }
                        }
                    }
                }
                "getVerseDetail" -> {
                    val surahId = call.argument<Int>("surahId") ?: 1
                    val ayahNumber = call.argument<Int>("ayahNumber") ?: 1
                    executor.execute {
                        try {
                            val data = quranEngine.getVerseDetail(surahId, ayahNumber)
                            runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DB_ERROR", e.message, null) }
                        }
                    }
                }
                "searchVerses" -> {
                    val query = call.argument<String>("query") ?: ""
                    val limit = call.argument<Int>("limit") ?: 100
                    executor.execute {
                        try {
                            val data = quranEngine.searchVerses(query, limit)
                            runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SEARCH_ERROR", e.message, null) }
                        }
                    }
                }
                "ensureMushafPage" -> {
                    val pageNumber = call.argument<Int>("pageNumber") ?: 1
                    executor.execute {
                        try {
                            val path = quranEngine.ensureMushafPage(pageNumber)
                            runOnUiThread { result.success(path) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("MUSHAF_ERROR", e.message, null) }
                        }
                    }
                }
                "getMushafDownloadStatus" -> executor.execute {
                    try {
                        val status = quranEngine.getMushafDownloadStatus()
                        runOnUiThread { result.success(status) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("MUSHAF_ERROR", e.message, null) }
                    }
                }
                "startDownloadAllMushafPages" -> {
                    quranEngine.startDownloadAllMushafPages()
                    result.success(true)
                }
                "clearMushafCache" -> executor.execute {
                    val ok = quranEngine.clearMushafCache()
                    runOnUiThread { result.success(ok) }
                }
                "toggleBookmark" -> {
                    val surahId = call.argument<Int>("surahId") ?: 1
                    val ayahNumber = call.argument<Int>("ayahNumber") ?: 1
                    val pageNumber = call.argument<Int>("pageNumber") ?: 1
                    executor.execute {
                        val added = quranEngine.toggleBookmark(surahId, ayahNumber, pageNumber)
                        runOnUiThread { result.success(added) }
                    }
                }
                "isBookmarked" -> {
                    val surahId = call.argument<Int>("surahId") ?: 1
                    val ayahNumber = call.argument<Int>("ayahNumber") ?: 1
                    executor.execute {
                        val res = quranEngine.isBookmarked(surahId, ayahNumber)
                        runOnUiThread { result.success(res) }
                    }
                }
                "getBookmarks" -> executor.execute {
                    val list = quranEngine.getBookmarks()
                    runOnUiThread { result.success(list) }
                }
                "getCachedTafsir" -> {
                    val tafsirId = call.argument<String>("tafsirId") ?: ""
                    val surahId = call.argument<Int>("surahId") ?: 1
                    val ayahNumber = call.argument<Int>("ayahNumber") ?: 1
                    executor.execute {
                        val text = quranEngine.getCachedTafsir(tafsirId, surahId, ayahNumber)
                        runOnUiThread { result.success(text) }
                    }
                }
                "saveCachedTafsir" -> {
                    val tafsirId = call.argument<String>("tafsirId") ?: ""
                    val surahId = call.argument<Int>("surahId") ?: 1
                    val ayahNumber = call.argument<Int>("ayahNumber") ?: 1
                    val content = call.argument<String>("content") ?: ""
                    executor.execute {
                        quranEngine.saveCachedTafsir(tafsirId, surahId, ayahNumber, content)
                        runOnUiThread { result.success(true) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }
}
