package com.bekaldakwah.bekal_dakwah_app.quran

/**
 * Adapted from quran/quran_android (GPL-3.0)
 * https://github.com/quran/quran_android/blob/main/common/search/src/main/java/com/quran/common/search/arabic/ArabicCharacterHelper.kt
 */
object ArabicCharacterHelper {
    private const val BANNED_CHARS = "[()]"
    private val lookupTable = hashMapOf(
        // given: ا -> match: آ أ إ ا ى ٱ
        "\u0627" to "\u0622\u0623\u0625\u0627\u0649\u0671",
        // given: و -> match: و ؤ
        "\u0648" to "\u0648\u0624",
        // given: أ -> match: أ ء ؤ ئ ا
        "\u0623" to "\u0621\u0623\u0624\u0626\u0627",
        // given: ء -> match: ء أ ؤ ئ ا
        "\u0621" to "\u0621\u0623\u0624\u0626\u0627",
        // given: ت -> match: ت ة
        "\u062a" to "\u062a\u0629",
        // given: ة -> match: ة ت ه
        "\u0629" to "\u0629\u062a\u0647",
        // given: ه -> match: ه ة
        "\u0647" to "\u0647\u0629",
        // given: ى -> match: ى ي
        "\u0649" to "\u0649\u064a",
        // given: ي -> match: ي ى ئ
        "\u064a" to "\u064a\u0649\u0626",
        // given: ئ -> match: ئ ى ي
        "\u0626" to "\u0626\u0649\u064a"
    )

    fun generateRegex(query: String): String {
        val regexBuilder = StringBuilder()
        for (ch in query.toCharArray()) {
            val mapped = lookupTable[ch.toString()]
            if (mapped != null) {
                regexBuilder.append("[")
                regexBuilder.append(mapped)
                regexBuilder.append("]")
            } else if (!BANNED_CHARS.contains(ch)) {
                regexBuilder.append(Regex.escape(ch.toString()))
            }
        }
        return regexBuilder.toString()
    }
}
