package com.bekaldakwah.bekal_dakwah_app

import com.bekaldakwah.bekal_dakwah_app.quran.QuranNativeEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bekaldakwah/quran_engine"
    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var quranEngine: QuranNativeEngine

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        quranEngine = QuranNativeEngine(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSurahs" -> {
                    executor.execute {
                        try {
                            val data = quranEngine.getSurahs()
                            runOnUiThread { result.success(data) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DB_ERROR", e.message, null) }
                        }
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
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }
}
