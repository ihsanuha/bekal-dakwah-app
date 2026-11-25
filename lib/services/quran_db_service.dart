import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class QuranDbService {
  static const MethodChannel _channel = MethodChannel('com.bekaldakwah/quran_engine');

  static Future<List<Map<String, dynamic>>> getSurahs() async {
    final List<dynamic>? res = await _channel.invokeMethod<List<dynamic>>('getSurahs');
    if (res == null) return [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> getJuzList() async {
    final List<dynamic>? res = await _channel.invokeMethod<List<dynamic>>('getJuzList');
    if (res == null) return [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> getVerses(int surahId) async {
    final List<dynamic>? res = await _channel.invokeMethod<List<dynamic>>(
      'getVerses',
      {'surahId': surahId},
    );
    if (res == null) return [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> getPageData(int pageNumber) async {
    final Map<dynamic, dynamic>? res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getPageData',
      {'pageNumber': pageNumber},
    );
    if (res == null) return {};
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, dynamic>?> getVerseDetail(int surahId, int ayahNumber) async {
    final Map<dynamic, dynamic>? res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getVerseDetail',
      {'surahId': surahId, 'ayahNumber': ayahNumber},
    );
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  static Future<List<Map<String, dynamic>>> searchVerses(String query, {int limit = 100}) async {
    if (query.trim().isEmpty) return [];
    final List<dynamic>? res = await _channel.invokeMethod<List<dynamic>>(
      'searchVerses',
      {'query': query, 'limit': limit},
    );
    if (res == null) return [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<String> ensureMushafPage(int pageNumber) async {
    final String? path = await _channel.invokeMethod<String>(
      'ensureMushafPage',
      {'pageNumber': pageNumber},
    );
    if (path == null || path.isEmpty) {
      throw Exception('Path halaman Mushaf kosong');
    }
    return path;
  }

  static Future<Map<String, dynamic>> getMushafDownloadStatus() async {
    final Map<dynamic, dynamic>? res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getMushafDownloadStatus');
    if (res == null) return {};
    return Map<String, dynamic>.from(res);
  }

  static Future<void> startDownloadAllMushafPages() async {
    await _channel.invokeMethod('startDownloadAllMushafPages');
  }

  static Future<void> clearMushafCache() async {
    await _channel.invokeMethod('clearMushafCache');
  }

  static Future<bool> toggleBookmark(int surahId, int ayahNumber, int pageNumber) async {
    final bool? res = await _channel.invokeMethod<bool>(
      'toggleBookmark',
      {'surahId': surahId, 'ayahNumber': ayahNumber, 'pageNumber': pageNumber},
    );
    return res ?? false;
  }

  static Future<bool> isBookmarked(int surahId, int ayahNumber) async {
    final bool? res = await _channel.invokeMethod<bool>(
      'isBookmarked',
      {'surahId': surahId, 'ayahNumber': ayahNumber},
    );
    return res ?? false;
  }

  static Future<List<Map<String, dynamic>>> getBookmarks() async {
    final List<dynamic>? res = await _channel.invokeMethod<List<dynamic>>('getBookmarks');
    if (res == null) return [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Ambil Tafsir (dengan cache SQLite lokal agar tersedia offline setelah dibuka sekali)
  /// tafsirId: 'kemenag_id', '91' (As-Sa'di AR), '14' (Ibnu Katsir AR), '94' (Al-Baghawi AR)
  static Future<String> getTafsir(String tafsirId, int surahId, int ayahNumber) async {
    // 1. Cek cache SQLite lokal terlebih dahulu
    final String? cached = await _channel.invokeMethod<String>(
      'getCachedTafsir',
      {'tafsirId': tafsirId, 'surahId': surahId, 'ayahNumber': ayahNumber},
    );
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    // 2. Fetch dari API sumber terpercaya
    try {
      String fetchedText = '';
      if (tafsirId == 'kemenag_id') {
        final res = await http.get(
          Uri.parse('https://equran.id/api/v2/tafsir/$surahId'),
          headers: {'User-Agent': 'BekalDakwah/1.0'},
        ).timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final List tafsirList = data['data']?['tafsir'] ?? [];
          for (final t in tafsirList) {
            final tAyah = t['ayat'];
            final tText = (t['teks'] ?? '').toString().trim();
            if (tAyah is int && tText.isNotEmpty) {
              // Cache sekalian seluruh ayat surah ini agar instan saat geser ayat berikutnya!
              await _channel.invokeMethod('saveCachedTafsir', {
                'tafsirId': tafsirId,
                'surahId': surahId,
                'ayahNumber': tAyah,
                'content': tText,
              });
              if (tAyah == ayahNumber) {
                fetchedText = tText;
              }
            }
          }
        }
      } else {
        // Quran.com API v4 (91 = As-Sa'di, 14 = Ibnu Katsir, 94 = Al-Baghawi)
        final res = await http.get(
          Uri.parse('https://api.quran.com/api/v4/tafsirs/$tafsirId/by_ayah/$surahId:$ayahNumber'),
          headers: {'User-Agent': 'BekalDakwah/1.0'},
        ).timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final rawHtml = (data['tafsir']?['text'] ?? '').toString();
          fetchedText = _cleanHtml(rawHtml);
          if (fetchedText.isNotEmpty) {
            await _channel.invokeMethod('saveCachedTafsir', {
              'tafsirId': tafsirId,
              'surahId': surahId,
              'ayahNumber': ayahNumber,
              'content': fetchedText,
            });
          }
        }
      }

      if (fetchedText.isNotEmpty) return fetchedText;
      return 'Tafsir tidak ditemukan untuk ayat ini.';
    } catch (e) {
      return 'Gagal mengambil tafsir (periksa koneksi internet Anda): $e';
    }
  }

  static String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
