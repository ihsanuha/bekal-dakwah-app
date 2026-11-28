import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class ApiService {
  /// Ambil jadwal shalat & kalender hijriyah hari ini (presisi GPS jika lat/lon tersedia)
  static Future<Map<String, dynamic>?> getPrayerTimes({
    String city = "Jakarta",
    double? lat,
    double? lon,
  }) async {
    try {
      final uri = (lat != null && lon != null)
          ? Uri.parse('${AppConfig.prayerTimes}?lat=$lat&lon=$lon&method=20')
          : Uri.parse('${AppConfig.prayerTimes}?city=$city');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    // Fallback langsung ke Aladhan API jika backend sedang cold start
    if (lat != null && lon != null) {
      try {
        final direct = await http
            .get(Uri.parse('https://api.aladhan.com/v1/timings?latitude=$lat&longitude=$lon&method=20'))
            .timeout(const Duration(seconds: 12));
        if (direct.statusCode == 200) {
          final data = (jsonDecode(direct.body)['data'] as Map<String, dynamic>?) ?? {};
          return {
            'timings': data['timings'] ?? {},
            'date': data['date'] ?? {},
            'meta': data['meta'] ?? {},
          };
        }
      } catch (_) {}
    }
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

  /// Cari kitab & nash ulama di Maktabah Turath melalui backend (memakai TURATH_API_KEY)
  static Future<Map<String, dynamic>> searchTurath(String query, {int page = 1}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return {'count': 0, 'data': []};
    final uri = Uri.parse('${AppConfig.turathSearch}?q=${Uri.encodeQueryComponent(cleanQuery)}&page=$page');
    final res = await http.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${res.statusCode} dari Turath');
  }

  /// Ambil metadata & daftar isi kitab Turath
  static Future<Map<String, dynamic>> getTurathBook(int bookId) async {
    final res = await http.get(Uri.parse(AppConfig.turathBook(bookId))).timeout(const Duration(seconds: 25));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${res.statusCode} saat mengambil detail kitab');
  }

  /// Ambil isi halaman tertentu dari kitab Turath
  static Future<Map<String, dynamic>> getTurathPage(int bookId, int pg) async {
    final res = await http.get(Uri.parse(AppConfig.turathPage(bookId, pg))).timeout(const Duration(seconds: 25));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${res.statusCode} saat mengambil halaman kitab');
  }

  /// Ambil daftar Mutiara Ilmu dari Google Sheet (langsung CSV jika sheetUrl diisi agar super cepat, atau via backend)
  static Future<List<Map<String, dynamic>>> getMutiaraList({String? sheetUrl}) async {
    final trimmed = sheetUrl?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      final directItems = await _fetchMutiaraCsvDirect(trimmed);
      if (directItems.isNotEmpty) return directItems;
    }

    try {
      String url = AppConfig.mutiaraList;
      if (trimmed.isNotEmpty) {
        url += '?sheet_url=${Uri.encodeQueryComponent(trimmed)}';
      }
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (decoded['data'] as List?) ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> _fetchMutiaraCsvDirect(String rawUrl) async {
    try {
      String csvUrl = rawUrl;
      if (!rawUrl.contains('output=csv') && !rawUrl.contains('format=csv')) {
        final m = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(rawUrl);
        if (m != null) {
          final gidMatch = RegExp(r'gid=(\d+)').firstMatch(rawUrl);
          final gidPart = gidMatch != null ? '&gid=${gidMatch.group(1)}' : '';
          csvUrl = 'https://docs.google.com/spreadsheets/d/${m.group(1)}/export?format=csv$gidPart';
        }
      }
      final sep = csvUrl.contains('?') ? '&' : '?';
      final bustedUrl = '$csvUrl${sep}_ts=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http.get(
        Uri.parse(bustedUrl),
        headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final text = utf8.decode(res.bodyBytes, allowMalformed: true);
      final rows = _parseCsv(text);
      if (rows.length < 2) return [];

      final headers = rows.first.map((h) => h.trim().toLowerCase()).toList();
      final items = <Map<String, dynamic>>[];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final map = <String, String>{};
        for (int c = 0; c < headers.length && c < row.length; c++) {
          map[headers[c]] = row[c].trim();
        }
        final status = (map['status'] ?? 'Tayang').toLowerCase();
        final judul = map['judul'] ?? '';
        final kontenWa = map['konten siap wa'] ?? map['mutiara / intisari'] ?? map['intisari'] ?? '';
        if (judul.isEmpty && kontenWa.isEmpty) continue;
        if (status.isNotEmpty && !['tayang', 'publish', 'published', 'aktif', 'ya'].contains(status)) continue;

        items.add({
          'id': i,
          'tanggal': map['tanggal'] ?? '',
          'judul': judul,
          'teks_arab': map['teks arab'] ?? '',
          'konten_wa': kontenWa,
          'sumber': map['sumber (turath/shamela)'] ?? map['sumber'] ?? '',
          'path_file': map['path file word'] ?? map['file pdf'] ?? '',
          'status': map['status'] ?? 'Tayang',
        });
      }
      return items.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  /// Cari pada 7 Ensiklopedia Ad-Durar As-Saniyyah via backend
  static Future<Map<String, dynamic>> searchDorar({
    required String query,
    String category = 'hadith',
    int page = 1,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.dorarSearch}?q=${Uri.encodeQueryComponent(query.trim())}&category=$category&page=$page',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${res.statusCode} dari Dorar API');
  }

  static List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    var currentField = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            currentField.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          currentField.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          currentRow.add(currentField.toString());
          currentField = StringBuffer();
        } else if (ch == '\r') {
          continue;
        } else if (ch == '\n') {
          currentRow.add(currentField.toString());
          rows.add(currentRow);
          currentRow = <String>[];
          currentField = StringBuffer();
        } else {
          currentField.write(ch);
        }
      }
    }
    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString());
      rows.add(currentRow);
    }
    return rows;
  }
}
