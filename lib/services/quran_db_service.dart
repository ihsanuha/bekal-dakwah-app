import 'package:flutter/services.dart';

class QuranDbService {
  static const MethodChannel _channel = MethodChannel('com.bekaldakwah/quran_engine');

  static Future<List<Map<String, dynamic>>> getSurahs() async {
    final List<dynamic>? res = await _channel.invokeMethod<List<dynamic>>('getSurahs');
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

  static Future<List<Map<String, dynamic>>> searchVerses(String query, {int limit = 100}) async {
    if (query.trim().isEmpty) return [];
    final List<dynamic>? res = await _channel.invokeMethod<List<dynamic>>(
      'searchVerses',
      {'query': query, 'limit': limit},
    );
    if (res == null) return [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
