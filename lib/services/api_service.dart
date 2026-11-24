import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class ApiService {
  /// Ambil jadwal shalat & kalender hijriyah hari ini
  static Future<Map<String, dynamic>?> getPrayerTimes({String city = "Jakarta"}) async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.prayerTimes}?city=$city'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('[ApiService] Error getPrayerTimes: $e');
    }
    return null;
  }

  /// Ambil daftar 114 surah
  static Future<List<dynamic>> getSurahList() async {
    try {
      final res = await http.get(Uri.parse(AppConfig.quranSurah));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('[ApiService] Error getSurahList: $e');
    }
    return [];
  }

  /// Ambil ayat-ayat surah
  static Future<List<dynamic>> getSurahVerses(int chapterId) async {
    try {
      final res = await http.get(Uri.parse(AppConfig.quranVerses(chapterId)));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['verses'] ?? [];
      }
    } catch (e) {
      print('[ApiService] Error getSurahVerses: $e');
    }
    return [];
  }

  /// Chat dengan AI Asisten Manhaj Salaf
  static Future<String> askAI(String question, {bool searchReference = true}) async {
    try {
      final res = await http.post(
        Uri.parse(AppConfig.aiChat),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': [
            {'role': 'user', 'content': question}
          ],
          'search_reference': searchReference
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['error'] == true) {
          return 'Mohon maaf: ${data['detail']}';
        }
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content'] ?? 'Tidak ada jawaban.';
        }
      }
    } catch (e) {
      return 'Gagal menghubungi server: $e';
    }
    return 'Terjadi kendala pada server.';
  }

  /// Hadits Categories
  static Future<List<dynamic>> getHadithCategories() async {
    try {
      final res = await http.get(Uri.parse(AppConfig.hadithCategories));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('[ApiService] Error getHadithCategories: $e');
    }
    return [];
  }

  /// Hadits List by Category
  static Future<List<dynamic>> getHadithList(int categoryId) async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.hadithList}?category_id=$categoryId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['data'] ?? [];
      }
    } catch (e) {
      print('[ApiService] Error getHadithList: $e');
    }
    return [];
  }

  /// Hadits Detail (Matan, Takhrij, Syarah)
  static Future<Map<String, dynamic>?> getHadithDetail(int hadithId) async {
    try {
      final res = await http.get(Uri.parse(AppConfig.hadithDetail(hadithId)));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('[ApiService] Error getHadithDetail: $e');
    }
    return null;
  }

  /// Fatwa List
  static Future<List<dynamic>> getFatwaList({String? query}) async {
    try {
      String url = AppConfig.fatwaList;
      if (query != null && query.isNotEmpty) {
        url += '?q=$query';
      }
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['data'] ?? [];
      }
    } catch (e) {
      print('[ApiService] Error getFatwaList: $e');
    }
    return [];
  }
}
