import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class QuranListScreen extends StatefulWidget {
  const QuranListScreen({super.key});

  @override
  State<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends State<QuranListScreen> {
  List<dynamic> _surahList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSurah();
  }

  void _fetchSurah() async {
    final list = await ApiService.getSurahList();
    if (mounted) {
      setState(() {
        _surahList = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Al-Qur'anul Karim",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _surahList.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final surah = _surahList[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D7377).withOpacity(0.1),
                    child: Text(
                      '${surah['id']}',
                      style: const TextStyle(color: Color(0xFF0D7377), fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    surah['name_simple'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${surah['translated_name']?['name'] ?? ''} • ${surah['verses_count']} Ayat',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  trailing: Text(
                    surah['name_arabic'] ?? '',
                    style: GoogleFonts.amiri(fontSize: 20, color: const Color(0xFF0D7377)),
                  ),
                  onTap: () {
                    // Detail surah view
                  },
                );
              },
            ),
    );
  }
}
