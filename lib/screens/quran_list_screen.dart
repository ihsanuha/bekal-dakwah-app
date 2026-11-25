import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/quran_db_service.dart';
import 'quran_surah_detail_screen.dart';

class QuranListScreen extends StatefulWidget {
  const QuranListScreen({super.key});

  @override
  State<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends State<QuranListScreen> {
  List<Map<String, dynamic>> _allSurah = [];
  List<Map<String, dynamic>> _filteredSurah = [];
  List<Map<String, dynamic>> _verseResults = [];
  bool _isLoadingSurah = true;
  bool _isSearching = false;
  String _currentQuery = '';
  Timer? _debounce;
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _quickQueries = [
    'توبة',
    'الرحمن',
    'لا تقنطوا',
    'الربا',
    '2:255',
    'ikhlas',
  ];

  @override
  void initState() {
    super.initState();
    _loadSurahs();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    try {
      final list = await QuranDbService.getSurahs();
      if (mounted) {
        setState(() {
          _allSurah = list;
          _filteredSurah = list;
          _isLoadingSurah = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSurah = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat database Al-Qur\'an: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String raw) {
    final query = raw.trim();
    _debounce?.cancel();

    setState(() {
      _currentQuery = query;
      if (query.isEmpty) {
        _filteredSurah = _allSurah;
        _verseResults = [];
        _isSearching = false;
      } else {
        final qLower = query.toLowerCase();
        _filteredSurah = _allSurah.where((s) {
          final simple = (s['name_simple'] ?? '').toString().toLowerCase();
          final arabic = (s['name_arabic'] ?? '').toString();
          final indo = (s['name_indo'] ?? '').toString().toLowerCase();
          final idStr = (s['id'] ?? '').toString();
          return simple.contains(qLower) || arabic.contains(query) || indo.contains(qLower) || idStr == query;
        }).toList();
      }
    });

    if (query.isNotEmpty) {
      setState(() => _isSearching = true);
      _debounce = Timer(const Duration(milliseconds: 120), () async {
        try {
          final matches = await QuranDbService.searchVerses(query, limit: 120);
          if (mounted && _currentQuery == query) {
            setState(() {
              _verseResults = matches;
              _isSearching = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isSearching = false);
          }
        }
      });
    }
  }

  List<TextSpan> _buildHighlightedSpans(String text, TextStyle normalStyle, TextStyle highlightStyle) {
    const startTag = '[[MATCH]]';
    const endTag = '[[/MATCH]]';
    final spans = <TextSpan>[];
    int idx = 0;

    while (idx < text.length) {
      final start = text.indexOf(startTag, idx);
      if (start == -1) {
        spans.add(TextSpan(text: text.substring(idx), style: normalStyle));
        break;
      }
      if (start > idx) {
        spans.add(TextSpan(text: text.substring(idx, start), style: normalStyle));
      }
      final matchStart = start + startTag.length;
      final end = text.indexOf(endTag, matchStart);
      if (end == -1) {
        spans.add(TextSpan(text: text.substring(matchStart), style: normalStyle));
        break;
      }
      spans.add(TextSpan(text: text.substring(matchStart, end), style: highlightStyle));
      idx = end + endTag.length;
    }
    return spans;
  }

  void _copyDalil(Map<String, dynamic> verse) {
    final text = '${verse['text_uthmani']}\n\n"${verse['translation_id']}"\n(QS. ${verse['surah_name_simple']}: ${verse['ayah_number']})';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dalil QS. ${verse['surah_name_simple']}: ${verse['ayah_number']} tersalin')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isQueryMode = _currentQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Al-Qur'anul Karim",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              'Offline 30 Juz • Pencarian Arab Instan',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Ketik kata Arab (توبة), arti, atau 2:255...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF0D7377)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Quick Search Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _quickQueries.length,
              separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final q = _quickQueries[i];
                return ActionChip(
                  label: Text(
                    q,
                    style: q.contains(RegExp(r'[\u0600-\u06FF]'))
                        ? GoogleFonts.amiri(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0D7377))
                        : const TextStyle(fontSize: 12, color: Color(0xFF0D7377)),
                  ),
                  backgroundColor: const Color(0xFF0D7377).withOpacity(0.08),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onPressed: () {
                    _searchCtrl.text = q;
                    _searchCtrl.selection = TextSelection.fromPosition(TextPosition(offset: q.length));
                    _onSearchChanged(q);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: _isLoadingSurah
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
                : isQueryMode
                    ? _buildSearchResultsView()
                    : _buildSurahListView(_allSurah),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahListView(List<Map<String, dynamic>> surahs) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: surahs.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final surah = surahs[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF0D7377).withOpacity(0.1),
            child: Text(
              '${surah['id']}',
              style: const TextStyle(color: Color(0xFF0D7377), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          title: Text(
            surah['name_simple'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${surah['name_indo'] ?? ''} • ${surah['revelation_type'] ?? ''} • ${surah['verses_count']} Ayat',
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
                  chapterId: surah['id'] as int,
                  surahName: surah['name_simple'] ?? '',
                  arabicName: surah['name_arabic'] ?? '',
                  indoName: surah['name_indo'] ?? '',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResultsView() {
    if (_isSearching && _verseResults.isEmpty && _filteredSurah.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)));
    }

    if (_filteredSurah.isEmpty && _verseResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.searchX, size: 42, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Tidak ditemukan ayat atau surah untuk "$_currentQuery"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_filteredSurah.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'Surah yang Cocok (${_filteredSurah.length})',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0D7377)),
            ),
          ),
          ..._filteredSurah.take(5).map((surah) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0.5,
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF0D7377).withOpacity(0.1),
                    child: Text('${surah['id']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
                  ),
                  title: Text('${surah['name_simple']} (${surah['name_indo']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(surah['name_arabic'] ?? '', style: GoogleFonts.amiri(fontSize: 18, color: const Color(0xFF0D7377))),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuranSurahDetailScreen(
                          chapterId: surah['id'] as int,
                          surahName: surah['name_simple'] ?? '',
                          arabicName: surah['name_arabic'] ?? '',
                          indoName: surah['name_indo'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
              )),
          const SizedBox(height: 8),
        ],

        if (_verseResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hasil Pencarian Ayat (${_verseResults.length}${_verseResults.length == 120 ? '+' : ''})',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0D7377)),
                ),
                if (_isSearching)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          ..._verseResults.map((v) {
            final isArabicMatch = v['is_arabic_match'] == true;
            final arabicHighlighted = (v['text_imlaei_highlighted'] ?? v['text_uthmani'] ?? '').toString();
            final transHighlighted = (v['translation_highlighted'] ?? v['translation_id'] ?? '').toString();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0.6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuranSurahDetailScreen(
                        chapterId: v['surah_id'] as int,
                        surahName: v['surah_name_simple'] ?? '',
                        arabicName: v['surah_name_arabic'] ?? '',
                        indoName: v['surah_name_indo'] ?? '',
                        initialAyah: v['ayah_number'] as int,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D7377).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'QS. ${v['surah_name_simple']}: ${v['ayah_number']}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D7377)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Juz ${v['juz']} • Hal ${v['page']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          const Spacer(),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            icon: const Icon(LucideIcons.copy, size: 16, color: Colors.grey),
                            tooltip: 'Salin Dalil',
                            onPressed: () => _copyDalil(v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        text: TextSpan(
                          children: _buildHighlightedSpans(
                            isArabicMatch ? arabicHighlighted : (v['text_uthmani'] ?? '').toString(),
                            GoogleFonts.amiri(fontSize: 21, height: 1.9, color: Colors.black87),
                            GoogleFonts.amiri(
                              fontSize: 21,
                              height: 1.9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D7377),
                              backgroundColor: const Color(0xFFD4A843).withOpacity(0.35),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        textAlign: TextAlign.left,
                        text: TextSpan(
                          children: _buildHighlightedSpans(
                            transHighlighted,
                            TextStyle(fontSize: 13, height: 1.5, color: Colors.grey[800]),
                            TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              backgroundColor: const Color(0xFFD4A843).withOpacity(0.35),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
