package com.bekaldakwah.bekal_dakwah_app.quran

import java.text.Normalizer

/**
 * Adapted from quran/quran_android (GPL-3.0)
 * https://github.com/quran/quran_android/blob/main/common/search/src/main/java/com/quran/common/search/SearchTextUtil.kt
 */
object SearchTextUtil {
    private val nonSpacingCombiningCharactersRegex = "\\p{Mn}+".toRegex()
    private val charactersToReplaceRegex = "['`]".toRegex()

    // Hilangkan harakat, tanwin, syaddah, sukun, madd, waqaf, tatweel
    private val tashkeelRegex = "[\\u0610-\\u061A\\u064B-\\u065F\\u0670\\u06D6-\\u06ED\\u0640]".toRegex()

    // Normalisasi variasi huruf Arab agar cocok dengan kolom text_searchable
    private val alifReplacementsRegex = "[\\u0622\\u0623\\u0625\\u0671]".toRegex() // آ أ إ ٱ -> ا
    private val wawReplacementsRegex = "\\u0624".toRegex() // ؤ -> و
    private val yaaReplacementsRegex = "[\\u0649\\u0626]".toRegex() // ى ئ -> ي
    private val taaReplacementsRegex = "\\u0629".toRegex() // ة -> ه

    fun stripTashkeel(string: String): String {
        return string.replace(tashkeelRegex, "").replace("\\s+".toRegex(), " ").trim()
    }

    fun asSearchableString(string: String, isRtlText: Boolean): String {
        return if (isRtlText) {
            string
                .replace(tashkeelRegex, "")
                .replace(alifReplacementsRegex, "\u0627")
                .replace(wawReplacementsRegex, "\u0648")
                .replace(yaaReplacementsRegex, "\u064a")
                .replace(taaReplacementsRegex, "\u0647")
                .replace("\\s+".toRegex(), " ")
                .trim()
        } else {
            val normalizedString = Normalizer.normalize(string, Normalizer.Form.NFKD)
            normalizedString
                .replace(nonSpacingCombiningCharactersRegex, "")
                .replace(charactersToReplaceRegex, "")
                .lowercase()
                .trim()
        }
    }

    fun isRtl(s: String): Boolean {
        for (character in s.toCharArray()) {
            val directionality = Character.getDirectionality(character).toInt()
            if (directionality == Character.DIRECTIONALITY_RIGHT_TO_LEFT.toInt() ||
                directionality == Character.DIRECTIONALITY_RIGHT_TO_LEFT_ARABIC.toInt()
            ) {
                return true
            } else if (directionality == Character.DIRECTIONALITY_LEFT_TO_RIGHT.toInt()) {
                return false
            }
        }
        return false
    }
}
