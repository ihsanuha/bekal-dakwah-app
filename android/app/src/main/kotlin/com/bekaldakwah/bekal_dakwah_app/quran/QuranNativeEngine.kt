package com.bekaldakwah.bekal_dakwah_app.quran

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import io.flutter.FlutterInjector
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream

/**
 * Native SQLite Quran, Mushaf Page Manager & Arabic Search Engine.
 * Search logic adapted from quran/quran_android (GPL-3.0).
 */
class QuranNativeEngine(private val context: Context) {

    private var db: SQLiteDatabase? = null
    private var userDb: SQLiteDatabase? = null

    @Volatile
    var isDownloadingPack = false
        private set

    @Volatile
    var downloadProgressPercent = 0
        private set

    @Volatile
    var downloadStatusText = ""
        private set

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

    @Synchronized
    private fun getUserDatabase(): SQLiteDatabase {
        userDb?.let {
            if (it.isOpen) return it
        }
        val dbFile = context.getDatabasePath(USER_DB_NAME)
        dbFile.parentFile?.mkdirs()
        val opened = SQLiteDatabase.openOrCreateDatabase(dbFile, null)
        opened.execSQL(
            """
            CREATE TABLE IF NOT EXISTS bookmarks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                surah_id INTEGER NOT NULL,
                ayah_number INTEGER NOT NULL,
                page_number INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                UNIQUE(surah_id, ayah_number)
            )
            """.trimIndent()
        )
        opened.execSQL(
            """
            CREATE TABLE IF NOT EXISTS tafsir_cache (
                tafsir_id TEXT NOT NULL,
                surah_id INTEGER NOT NULL,
                ayah_number INTEGER NOT NULL,
                content TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (tafsir_id, surah_id, ayah_number)
            )
            """.trimIndent()
        )
        userDb = opened
        return opened
    }

    fun getMushafDir(): File {
        val dir = File(context.filesDir, "mushaf_madani_1260")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    fun getMushafPageFile(pageNumber: Int): File {
        val padded = pageNumber.toString().padStart(3, '0')
        return File(getMushafDir(), "page$padded.png")
    }

    /**
     * Memastikan gambar halaman Mushaf tersedia secara lokal di HP.
     * Jika belum ada, unduh dari files.quran.app lalu simpan permanen di filesDir.
     */
    fun ensureMushafPage(pageNumber: Int): String {
        val file = getMushafPageFile(pageNumber)
        if (file.exists() && file.length() > 1000) {
            return file.absolutePath
        }
        val padded = pageNumber.toString().padStart(3, '0')
        val urlStr = "https://files.quran.app/hafs/madani/width_1260/page$padded.png"
        val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 15000
            readTimeout = 20000
            setRequestProperty("User-Agent", "BekalDakwah/1.0")
        }
        val tmpFile = File(getMushafDir(), "page$padded.tmp")
        conn.inputStream.use { input ->
            FileOutputStream(tmpFile).use { output ->
                val buffer = ByteArray(8192)
                var read: Int
                while (input.read(buffer).also { read = it } != -1) {
                    output.write(buffer, 0, read)
                }
                output.flush()
            }
        }
        if (tmpFile.exists() && tmpFile.length() > 1000) {
            if (file.exists()) file.delete()
            tmpFile.renameTo(file)
            return file.absolutePath
        }
        throw IllegalStateException("Gagal mengunduh halaman Mushaf $pageNumber")
    }

    fun getMushafDownloadStatus(): Map<String, Any> {
        val dir = getMushafDir()
        val count = dir.listFiles { _, name ->
            name.startsWith("page") && name.endsWith(".png")
        }?.size ?: 0
        return mapOf(
            "downloaded_pages" to count,
            "total_pages" to 604,
            "is_downloading" to isDownloadingPack,
            "progress_percent" to downloadProgressPercent,
            "status_text" to downloadStatusText
        )
    }

    fun startDownloadAllMushafPages() {
        if (isDownloadingPack) return
        isDownloadingPack = true
        downloadProgressPercent = 0
        downloadStatusText = "Menghubungkan ke server Mushaf Madani..."

        Thread {
            val zipFile = File(context.cacheDir, "images_1260.zip")
            try {
                val url = URL("https://files.quran.app/hafs/madani/zips/images_1260.zip")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = 20000
                    readTimeout = 60000
                    setRequestProperty("User-Agent", "BekalDakwah/1.0")
                }
                val totalSize = conn.contentLength.toLong().coerceAtLeast(1L)
                var downloaded = 0L

                conn.inputStream.use { input ->
                    FileOutputStream(zipFile).use { output ->
                        val buffer = ByteArray(16384)
                        var read: Int
                        while (input.read(buffer).also { read = it } != -1) {
                            output.write(buffer, 0, read)
                            downloaded += read
                            downloadProgressPercent = ((downloaded * 85) / totalSize).toInt().coerceIn(1, 85)
                            val mbDone = String.format("%.1f", downloaded / (1024.0 * 1024.0))
                            val mbTotal = String.format("%.1f", totalSize / (1024.0 * 1024.0))
                            downloadStatusText = "Mengunduh Mushaf ($mbDone / $mbTotal MB)..."
                        }
                        output.flush()
                    }
                }

                downloadStatusText = "Mengekstrak 604 halaman ke penyimpanan HP..."
                val destDir = getMushafDir()
                val canonicalDest = destDir.canonicalPath
                var extractedCount = 0

                ZipInputStream(BufferedInputStream(zipFile.inputStream())).use { zis ->
                    var entry = zis.nextEntry
                    while (entry != null) {
                        if (!entry.isDirectory) {
                            val fileName = File(entry.name).name
                            if (fileName.startsWith("page") && fileName.endsWith(".png")) {
                                val outFile = File(destDir, fileName)
                                if (outFile.canonicalPath.startsWith(canonicalDest + File.separator)) {
                                    FileOutputStream(outFile).use { out ->
                                        val buffer = ByteArray(8192)
                                        var len: Int
                                        while (zis.read(buffer).also { len = it } != -1) {
                                            out.write(buffer, 0, len)
                                        }
                                    }
                                    extractedCount++
                                    downloadProgressPercent = 85 + ((extractedCount * 15) / 604).coerceIn(0, 15)
                                }
                            }
                        }
                        zis.closeEntry()
                        entry = zis.nextEntry
                    }
                }
                downloadProgressPercent = 100
                downloadStatusText = "Selesai! 604 halaman siap dibaca offline."
            } catch (e: Exception) {
                downloadStatusText = "Gagal mengunduh: ${e.message}"
            } finally {
                if (zipFile.exists()) zipFile.delete()
                isDownloadingPack = false
            }
        }.start()
    }

    fun clearMushafCache(): Boolean {
        val dir = getMushafDir()
        dir.listFiles()?.forEach { it.delete() }
        return true
    }

    fun getSurahs(): List<Map<String, Any>> {
        val database = getDatabase()
        val list = mutableListOf<Map<String, Any>>()
        database.rawQuery(
            "SELECT id, name_arabic, name_simple, name_indo, revelation_type, verses_count, start_page FROM surahs ORDER BY id ASC",
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
                        "verses_count" to cursor.getInt(5),
                        "start_page" to cursor.getInt(6)
                    )
                )
            }
        }
        return list
    }

    fun getJuzList(): List<Map<String, Any>> {
        val database = getDatabase()
        val list = mutableListOf<Map<String, Any>>()
        database.rawQuery(
            """
            SELECT v.juz, v.surah_id, v.ayah_number, v.page, s.name_simple, s.name_arabic, s.name_indo
            FROM verses v
            JOIN surahs s ON s.id = v.surah_id
            WHERE v.id IN (
                SELECT MIN(id) FROM verses GROUP BY juz
            )
            ORDER BY v.juz ASC
            """.trimIndent(),
            null
        ).use { cursor ->
            while (cursor.moveToNext()) {
                list.add(
                    mapOf(
                        "juz" to cursor.getInt(0),
                        "surah_id" to cursor.getInt(1),
                        "ayah_number" to cursor.getInt(2),
                        "page" to cursor.getInt(3),
                        "surah_name_simple" to cursor.getString(4),
                        "surah_name_arabic" to cursor.getString(5),
                        "surah_name_indo" to cursor.getString(6)
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

    fun getPageData(pageNumber: Int): Map<String, Any> {
        val database = getDatabase()
        val bounds = mutableListOf<Map<String, Any>>()
        val verses = mutableListOf<Map<String, Any>>()
        var primarySurahId = 1
        var primarySurahName = ""
        var primarySurahArabic = ""
        var primarySurahIndo = ""
        var primaryJuz = 1

        database.rawQuery(
            """
            SELECT line_number, surah_id, ayah_number, min_x, max_x, min_y, max_y
            FROM ayah_bounds
            WHERE page_number = ?
            ORDER BY line_number ASC, min_x DESC
            """.trimIndent(),
            arrayOf(pageNumber.toString())
        ).use { cursor ->
            while (cursor.moveToNext()) {
                bounds.add(
                    mapOf(
                        "line_number" to cursor.getInt(0),
                        "surah_id" to cursor.getInt(1),
                        "ayah_number" to cursor.getInt(2),
                        "min_x" to cursor.getInt(3),
                        "max_x" to cursor.getInt(4),
                        "min_y" to cursor.getInt(5),
                        "max_y" to cursor.getInt(6)
                    )
                )
            }
        }

        database.rawQuery(
            """
            SELECT v.surah_id, v.ayah_number, v.juz, v.text_uthmani, v.translation_id,
                   s.name_simple, s.name_arabic, s.name_indo
            FROM verses v
            JOIN surahs s ON s.id = v.surah_id
            WHERE v.page = ?
            ORDER BY v.surah_id ASC, v.ayah_number ASC
            """.trimIndent(),
            arrayOf(pageNumber.toString())
        ).use { cursor ->
            var first = true
            while (cursor.moveToNext()) {
                if (first) {
                    primarySurahId = cursor.getInt(0)
                    primaryJuz = cursor.getInt(2)
                    primarySurahName = cursor.getString(5)
                    primarySurahArabic = cursor.getString(6)
                    primarySurahIndo = cursor.getString(7)
                    first = false
                }
                verses.add(
                    mapOf(
                        "surah_id" to cursor.getInt(0),
                        "ayah_number" to cursor.getInt(1),
                        "juz" to cursor.getInt(2),
                        "text_uthmani" to cursor.getString(3),
                        "translation_id" to cursor.getString(4),
                        "surah_name_simple" to cursor.getString(5),
                        "surah_name_arabic" to cursor.getString(6),
                        "surah_name_indo" to cursor.getString(7)
                    )
                )
            }
        }

        // Fallback info jika halaman kosong dari query verses (misal lanjutan ayat)
        if (primarySurahName.isEmpty() && bounds.isNotEmpty()) {
            val firstBoundSurah = bounds[0]["surah_id"] as Int
            database.rawQuery(
                "SELECT name_simple, name_arabic, name_indo FROM surahs WHERE id = ?",
                arrayOf(firstBoundSurah.toString())
            ).use { c ->
                if (c.moveToFirst()) {
                    primarySurahId = firstBoundSurah
                    primarySurahName = c.getString(0)
                    primarySurahArabic = c.getString(1)
                    primarySurahIndo = c.getString(2)
                }
            }
        }

        return mapOf(
            "page_number" to pageNumber,
            "surah_id" to primarySurahId,
            "surah_name_simple" to primarySurahName,
            "surah_name_arabic" to primarySurahArabic,
            "surah_name_indo" to primarySurahIndo,
            "juz" to primaryJuz,
            "bounds" to bounds,
            "verses" to verses
        )
    }

    fun getVerseDetail(surahId: Int, ayahNumber: Int): Map<String, Any>? {
        val database = getDatabase()
        database.rawQuery(
            """
            SELECT v.surah_id, v.ayah_number, v.juz, v.page, v.text_uthmani, v.translation_id,
                   s.name_simple, s.name_arabic, s.name_indo
            FROM verses v
            JOIN surahs s ON s.id = v.surah_id
            WHERE v.surah_id = ? AND v.ayah_number = ?
            """.trimIndent(),
            arrayOf(surahId.toString(), ayahNumber.toString())
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                return mapOf(
                    "surah_id" to cursor.getInt(0),
                    "ayah_number" to cursor.getInt(1),
                    "juz" to cursor.getInt(2),
                    "page" to cursor.getInt(3),
                    "text_uthmani" to cursor.getString(4),
                    "translation_id" to cursor.getString(5),
                    "surah_name_simple" to cursor.getString(6),
                    "surah_name_arabic" to cursor.getString(7),
                    "surah_name_indo" to cursor.getString(8)
                )
            }
        }
        return null
    }

    fun searchVerses(rawQuery: String, limit: Int = 100): List<Map<String, Any>> {
        val query = rawQuery.trim()
        if (query.isEmpty()) return emptyList()

        val database = getDatabase()
        val results = mutableListOf<Map<String, Any>>()

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

            val regexStr = ArabicCharacterHelper.generateRegex(strippedQuery)
            val highlightRegex = try {
                if (regexStr.isNotEmpty()) Regex(regexStr) else null
            } catch (_: Exception) {
                null
            }

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

    // --- Bookmarks & Tafsir Cache ---

    fun toggleBookmark(surahId: Int, ayahNumber: Int, pageNumber: Int): Boolean {
        val udb = getUserDatabase()
        val exists = isBookmarked(surahId, ayahNumber)
        if (exists) {
            udb.delete("bookmarks", "surah_id = ? AND ayah_number = ?", arrayOf(surahId.toString(), ayahNumber.toString()))
            return false
        } else {
            udb.execSQL(
                "INSERT OR REPLACE INTO bookmarks (surah_id, ayah_number, page_number, created_at) VALUES (?, ?, ?, ?)",
                arrayOf(surahId, ayahNumber, pageNumber, System.currentTimeMillis())
            )
            return true
        }
    }

    fun isBookmarked(surahId: Int, ayahNumber: Int): Boolean {
        val udb = getUserDatabase()
        udb.rawQuery(
            "SELECT 1 FROM bookmarks WHERE surah_id = ? AND ayah_number = ?",
            arrayOf(surahId.toString(), ayahNumber.toString())
        ).use { cursor ->
            return cursor.moveToFirst()
        }
    }

    fun getBookmarks(): List<Map<String, Any>> {
        val udb = getUserDatabase()
        val qdb = getDatabase()
        val list = mutableListOf<Map<String, Any>>()
        udb.rawQuery("SELECT surah_id, ayah_number, page_number, created_at FROM bookmarks ORDER BY created_at DESC", null).use { cursor ->
            while (cursor.moveToNext()) {
                val sid = cursor.getInt(0)
                val ano = cursor.getInt(1)
                val pno = cursor.getInt(2)
                val created = cursor.getLong(3)
                var textU = ""
                var trans = ""
                var sName = ""
                var sArabic = ""
                qdb.rawQuery(
                    """
                    SELECT v.text_uthmani, v.translation_id, s.name_simple, s.name_arabic
                    FROM verses v JOIN surahs s ON s.id = v.surah_id
                    WHERE v.surah_id = ? AND v.ayah_number = ?
                    """.trimIndent(),
                    arrayOf(sid.toString(), ano.toString())
                ).use { qc ->
                    if (qc.moveToFirst()) {
                        textU = qc.getString(0)
                        trans = qc.getString(1)
                        sName = qc.getString(2)
                        sArabic = qc.getString(3)
                    }
                }
                list.add(
                    mapOf(
                        "surah_id" to sid,
                        "ayah_number" to ano,
                        "page_number" to pno,
                        "created_at" to created,
                        "text_uthmani" to textU,
                        "translation_id" to trans,
                        "surah_name_simple" to sName,
                        "surah_name_arabic" to sArabic
                    )
                )
            }
        }
        return list
    }

    fun getCachedTafsir(tafsirId: String, surahId: Int, ayahNumber: Int): String? {
        val udb = getUserDatabase()
        udb.rawQuery(
            "SELECT content FROM tafsir_cache WHERE tafsir_id = ? AND surah_id = ? AND ayah_number = ?",
            arrayOf(tafsirId, surahId.toString(), ayahNumber.toString())
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getString(0)
            }
        }
        return null
    }

    fun saveCachedTafsir(tafsirId: String, surahId: Int, ayahNumber: Int, content: String) {
        val udb = getUserDatabase()
        udb.execSQL(
            "INSERT OR REPLACE INTO tafsir_cache (tafsir_id, surah_id, ayah_number, content, updated_at) VALUES (?, ?, ?, ?, ?)",
            arrayOf(tafsirId, surahId, ayahNumber, content, System.currentTimeMillis())
        )
    }

    companion object {
        private const val DB_NAME = "quran_id.db"
        private const val DB_VERSION = 2
        private const val USER_DB_NAME = "user_quran.db"
    }
}
