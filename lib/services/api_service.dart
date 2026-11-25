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
    } catch (_) {}
    return null;
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

  /// Cari Hadits dari Ensiklopedia hdith.com (/encyclopedia/s?q=...)
  static Future<Map<String, dynamic>> searchHdithCom(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return {'count': 0, 'results': []};

    final uri = Uri.parse('https://hdith.com/encyclopedia/s?q=${Uri.encodeQueryComponent(cleanQuery)}');
    final res = await http.get(
      uri,
      headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 13) BekalDakwah/1.0'},
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode == 200) {
      final props = _extractInertiaProps(res.body);
      return {
        'count': props['count'] ?? 0,
        'results': (props['results'] as List?) ?? [],
      };
    }
    throw Exception('HTTP ${res.statusCode} dari hdith.com');
  }

  /// Ambil daftar kitab hadits dari ensiklopedia hdith.com
  static Future<List<dynamic>> getHdithComBooks() async {
    try {
      final res = await http.get(
        Uri.parse('https://hdith.com/encyclopedia/books'),
        headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 13) BekalDakwah/1.0'},
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final props = _extractInertiaProps(res.body);
        return (props['books'] as List?) ?? [];
      }
    } catch (_) {}
    return [];
  }

  static Map<String, dynamic> _extractInertiaProps(String htmlBody) {
    final regex = RegExp(r'<script[^>]*type=["\x27]application/json["\x27][^>]*>(.*?)</script>', dotAll: true);
    final match = regex.firstMatch(htmlBody);
    if (match != null) {
      final decoded = jsonDecode(match.group(1)!);
      if (decoded is Map<String, dynamic>) {
        return (decoded['props'] as Map<String, dynamic>?) ?? {};
      }
    }
    return {};
  }

  /// Fatwa List
  static Future<List<dynamic>> getFatwaList({String? query}) async {
    try {
      String url = AppConfig.fatwaList;
      if (query != null && query.isNotEmpty) {
        url += '?q=${Uri.encodeQueryComponent(query)}';
      }
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }
}
