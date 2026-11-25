class AppConfig {
  // Base URL Backend Production di Render
  static const String baseUrl = 'https://bekal-dakwah-backend.onrender.com/api/v1';

  // Endpoints
  static const String quranSurah = '$baseUrl/quran/surah';
  static String quranVerses(int chapterId) => '$baseUrl/quran/surah/$chapterId/verses';
  static const String prayerTimes = '$baseUrl/prayer-times/today';
  static const String aiChat = '$baseUrl/ai/chat';
  static const String maktabahSearch = '$baseUrl/maktabah/search';
  static const String hadithSearch = '$baseUrl/hadith/search';
  static const String hadithBooks = '$baseUrl/hadith/books';
  static const String fatwaList = '$baseUrl/fatwa/list';
  static const String turathSearch = '$baseUrl/turath/search';
  static String turathBook(int bookId) => '$baseUrl/turath/book/$bookId';
  static String turathPage(int bookId, int pg) => '$baseUrl/turath/page?book_id=$bookId&pg=$pg';
  static const String mutiaraList = '$baseUrl/mutiara/list';
}
