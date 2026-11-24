import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_service.dart';
import 'quran_surah_detail_screen.dart';

class QuranListScreen extends StatefulWidget {
  const QuranListScreen({super.key});

  @override
  State<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends State<QuranListScreen> {
  List<dynamic> _allSurah = [];
  List<dynamic> _filteredSurah = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSurah();
  }

  void _fetchSurah() async {
    final list = await ApiService.getSurahList();
    if (mounted) {
      setState(() {
        _allSurah = list;
        _filteredSurah = list;
        _isLoading = false;
      });
    }
  }

  void _filterSurah(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredSurah = _allSurah);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredSurah = _allSurah.where((s) {
        final nameSimple = (s['name_simple'] ?? '').toString().toLowerCase();
        final nameArabic = (s['name_arabic'] ?? '').toString();
        final translatedName = (s['translated_name']?['name'] ?? '').toString().toLowerCase();
        final idStr = (s['id'] ?? '').toString();
        return nameSimple.contains(q) || nameArabic.contains(q) || translatedName.contains(q) || idStr == q;
      }).toList();
    });
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari surah (misal: Al-Baqarah, Yasin, Juz, No)...',
                prefixIcon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF0D7377)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filterSurah('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _filterSurah,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
                : _filteredSurah.isEmpty
                    ? const Center(child: Text('Surah tidak ditemukan'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredSurah.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final surah = _filteredSurah[i];
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QuranSurahDetailScreen(
                                    chapterId: surah['id'],
                                    surahName: surah['name_simple'] ?? '',
                                    arabicName: surah['name_arabic'] ?? '',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
