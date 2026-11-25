package com.bekaldakwah.bekal_dakwah_app.quran

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import io.flutter.FlutterInjector
import java.io.File
import java.io.FileOutputStream

/**
 * Native SQLite Quran & Search Engine powered by quran_android Arabic search logic (GPL-3.0).
 */
class QuranNativeEngine(private val context: Context) {

    private var db: SQLiteDatabase? = null

    @Synchronized
    private fun getDatabase(): SQLiteDatabase {
        db?.let {
            if (it.isOpen) return it
        }

        val dbFile = context.getDatabasePath(DB_NAME)
        val versionPrefs = context.getSharedPreferences("quran_engine_prefs", Context.MODE_PRIVATE)
        val installedVersion = versionPrefs.getInt("db_version", 0)

        if (!dbFile.exists() || installedVersion < DB_VERSION) {
            dbFile.parentFile?.mkdirs()
            val assetKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/db/quran_id.db")
            context.assets.open(assetKey).use { input ->
                FileOutputStream(dbFile).use { output ->
                    val buffer = ByteArray(8192)
                    var read: Int
                    while (input.read(buffer).also { read = it } != -1) {
                        output.write(buffer, 0, read)
                    }
                    output.flush()
                }
            }
            versionPrefs.edit().putInt("db_version", DB_VERSION).apply()
        }

        val opened = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
        db = opened
        return opened
    }

    fun getSurahs(): List<Map<String, Any>> {
        val database = getDatabase()
        val list = mutableListOf<Map<String, Any>>()
        database.rawQuery(
            "SELECT id, name_arabic, name_simple, name_indo, revelation_type, verses_count FROM surahs ORDER BY id ASC",
            null
        ).use { cursor ->
            while (cursor.moveToNext()) {
                list.add(
                    mapOf(
                        "id" to cursor.getInt(0),
                        "name_arabic" to cursor.getString(1),
                        "name_simple" to cursor.getString(2),
                        "name_indo" to cursor.getString(3),
                        "revelation_type" to cursor.getString(4),
                        "verses_count" to cursor.getInt(5)
                    )
                )
            }
        }
        return list
    }

    fun getVerses(surahId: Int): List<Map<String, Any>> {
        val database = getDatabase()
        val list = mutableListOf<Map<String, Any>>()
        database.rawQuery(
            """
            SELECT ayah_number, juz, page, text_uthmani, text_imlaei, translation_id
            FROM verses
            WHERE surah_id = ?
            ORDER BY ayah_number ASC
            """.trimIndent(),
            arrayOf(surahId.toString())
        ).use { cursor ->
            while (cursor.moveToNext()) {
                list.add(
                    mapOf(
                        "surah_id" to surahId,
                        "ayah_number" to cursor.getInt(0),
                        "juz" to cursor.getInt(1),
                        "page" to cursor.getInt(2),
                        "text_uthmani" to cursor.getString(3),
                        "text_imlaei" to cursor.getString(4),
                        "translation_id" to cursor.getString(5)
                    )
                )
            }
        }
        return list
    }

    fun searchVerses(rawQuery: String, limit: Int = 100): List<Map<String, Any>> {
        val query = rawQuery.trim()
        if (query.isEmpty()) return emptyList()

        val database = getDatabase()
        val results = mutableListOf<Map<String, Any>>()

        // 1. Cek jika user mengetik referensi langsung seperti "2:255" atau "66:8"
        val refMatch = "^(\\d{1,3})[:\\s](\\d{1,3})$".toRegex().find(query)
        if (refMatch != null) {
            val surahId = refMatch.groupValues[1].toIntOrNull()
            val ayahNum = refMatch.groupValues[2].toIntOrNull()
            if (surahId != null && ayahNum != null) {
                database.rawQuery(
                    """
                    SELECT v.surah_id, v.ayah_number, s.name_simple, s.name_arabic, s.name_indo,
                           v.text_uthmani, v.text_imlaei, v.translation_id, v.juz, v.page
                    FROM verses v
                    JOIN surahs s ON s.id = v.surah_id
                    WHERE v.surah_id = ? AND v.ayah_number = ?
                    """.trimIndent(),
                    arrayOf(surahId.toString(), ayahNum.toString())
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        results.add(
                            mapOf(
                                "surah_id" to cursor.getInt(0),
                                "ayah_number" to cursor.getInt(1),
                                "surah_name_simple" to cursor.getString(2),
                                "surah_name_arabic" to cursor.getString(3),
                                "surah_name_indo" to cursor.getString(4),
                                "text_uthmani" to cursor.getString(5),
                                "text_imlaei_highlighted" to cursor.getString(6),
                                "translation_highlighted" to cursor.getString(7),
                                "translation_id" to cursor.getString(7),
                                "juz" to cursor.getInt(8),
                                "page" to cursor.getInt(9),
                                "is_arabic_match" to true
                            )
                        )
                    }
                }
                if (results.isNotEmpty()) return results
            }
        }

        val isArabic = SearchTextUtil.isRtl(query)
        if (isArabic) {
            val cleanQuery = SearchTextUtil.asSearchableString(query, isRtlText = true)
            val strippedQuery = SearchTextUtil.stripTashkeel(query)
            if (cleanQuery.isEmpty()) return emptyList()

            // Gunakan ArabicCharacterHelper dari quran_android untuk highlight di text_imlaei
            val regexStr = ArabicCharacterHelper.generateRegex(strippedQuery)
            val highlightRegex = try {
                if (regexStr.isNotEmpty()) Regex(regexStr) else null
            } catch (_: Exception) {
                null
            }

            // Support multi-kata Arab (AND) maupun frasa persis
            val words = cleanQuery.split(" ").filter { it.isNotEmpty() }
            val whereClauses = words.joinToString(" AND ") { "v.text_searchable LIKE ?" }
            val args = words.map { "%$it%" }.toTypedArray() + arrayOf(limit.toString())

            database.rawQuery(
                """
                SELECT v.surah_id, v.ayah_number, s.name_simple, s.name_arabic, s.name_indo,
                       v.text_uthmani, v.text_imlaei, v.translation_id, v.juz, v.page
                FROM verses v
                JOIN surahs s ON s.id = v.surah_id
                WHERE $whereClauses
                ORDER BY v.surah_id ASC, v.ayah_number ASC
                LIMIT ?
                """.trimIndent(),
                args
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    val imlaei = cursor.getString(6)
                    var highlightedImlaei = if (highlightRegex != null) {
                        highlightRegex.replace(imlaei) { "[[MATCH]]${it.value}[[/MATCH]]" }
                    } else {
                        imlaei
                    }
                    // Jika frasa tidak ter-highlight utuh, highlight per-kata dari query
                    if (!highlightedImlaei.contains("[[MATCH]]") && words.size > 1) {
                        for (w in words) {
                            val wRegexStr = ArabicCharacterHelper.generateRegex(w)
                            if (wRegexStr.isNotEmpty()) {
                                highlightedImlaei = try {
                                    Regex(wRegexStr).replace(highlightedImlaei) { "[[MATCH]]${it.value}[[/MATCH]]" }
                                } catch (_: Exception) {
                                    highlightedImlaei
                                }
                            }
                        }
                    }

                    val trans = cursor.getString(7)
                    results.add(
                        mapOf(
                            "surah_id" to cursor.getInt(0),
                            "ayah_number" to cursor.getInt(1),
                            "surah_name_simple" to cursor.getString(2),
                            "surah_name_arabic" to cursor.getString(3),
                            "surah_name_indo" to cursor.getString(4),
                            "text_uthmani" to cursor.getString(5),
                            "text_imlaei_highlighted" to highlightedImlaei,
                            "translation_highlighted" to trans,
                            "translation_id" to trans,
                            "juz" to cursor.getInt(8),
                            "page" to cursor.getInt(9),
                            "is_arabic_match" to true
                        )
                    )
                }
            }
        } else {
            // Pencarian Bahasa Indonesia di terjemahan Kemenag (multi-word AND)
            val cleanLatin = SearchTextUtil.asSearchableString(query, isRtlText = false)
            val words = cleanLatin.split(" ").filter { it.isNotEmpty() }
            if (words.isEmpty()) return emptyList()

            val whereClauses = words.joinToString(" AND ") { "LOWER(v.translation_id) LIKE ?" }
            val args = words.map { "%$it%" }.toTypedArray() + arrayOf(limit.toString())

            database.rawQuery(
                """
                SELECT v.surah_id, v.ayah_number, s.name_simple, s.name_arabic, s.name_indo,
                       v.text_uthmani, v.text_imlaei, v.translation_id, v.juz, v.page
                FROM verses v
                JOIN surahs s ON s.id = v.surah_id
                WHERE $whereClauses
                ORDER BY v.surah_id ASC, v.ayah_number ASC
                LIMIT ?
                """.trimIndent(),
                args
            ).use { cursor ->
                while (cursor.moveToNext()) {
                    val imlaei = cursor.getString(6)
                    val trans = cursor.getString(7)
                    var highlightedTrans = trans
                    for (w in words) {
                        highlightedTrans = Regex(Regex.escape(w), RegexOption.IGNORE_CASE)
                            .replace(highlightedTrans) { "[[MATCH]]${it.value}[[/MATCH]]" }
                    }
                    results.add(
                        mapOf(
                            "surah_id" to cursor.getInt(0),
                            "ayah_number" to cursor.getInt(1),
                            "surah_name_simple" to cursor.getString(2),
                            "surah_name_arabic" to cursor.getString(3),
                            "surah_name_indo" to cursor.getString(4),
                            "text_uthmani" to cursor.getString(5),
                            "text_imlaei_highlighted" to imlaei,
                            "translation_highlighted" to highlightedTrans,
                            "translation_id" to trans,
                            "juz" to cursor.getInt(8),
                            "page" to cursor.getInt(9),
                            "is_arabic_match" to false
                        )
                    )
                }
            }
        }

        return results
    }

    companion object {
        private const val DB_NAME = "quran_id.db"
        private const val DB_VERSION = 1
    }
}
