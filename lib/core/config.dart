class AppConfig {
  // Base URL Backend Production di Render
  static const String baseUrl = 'https://bekal-dakwah-backend.onrender.com/api/v1';

  // Endpoints
  static const String quranSurah = '$baseUrl/quran/surah';
  static String quranVerses(int chapterId) => '$baseUrl/quran/surah/$chapterId/verses';
  static const String prayerTimes = '$baseUrl/prayer-times/today';
  static const String aiChat = '$baseUrl/ai/chat';
  static const String maktabahSearch = '$baseUrl/maktabah/search';
  static const String hadithCategories = '$baseUrl/hadith/categories';
  static const String hadithList = '$baseUrl/hadith/list';
  static String hadithDetail(int id) => '$baseUrl/hadith/detail/$id';
  static const String fatwaList = '$baseUrl/fatwa/list';
}
