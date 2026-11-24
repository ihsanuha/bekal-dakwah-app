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
}
