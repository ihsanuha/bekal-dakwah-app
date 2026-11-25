import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/quran_db_service.dart';
import 'quran_mushaf_screen.dart';
import 'quran_surah_detail_screen.dart';

class QuranListScreen extends StatefulWidget {
  const QuranListScreen({super.key});

  @override
  State<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends State<QuranListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _allSurah = [];
  List<Map<String, dynamic>> _juzList = [];
  List<Map<String, dynamic>> _bookmarks = [];
  List<Map<String, dynamic>> _filteredSurah = [];
  List<Map<String, dynamic>> _verseResults = [];

  bool _isLoadingData = true;
  bool _isSearching = false;
  bool _preferMushafMode = false;
  int _lastMushafPage = 1;
  int _downloadedPagesCount = 0;

  String _currentQuery = '';
  Timer? _debounce;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final results = await Future.wait([
        QuranDbService.getSurahs(),
        QuranDbService.getJuzList(),
        QuranDbService.getBookmarks(),
        QuranDbService.getMushafDownloadStatus(),
      ]);

      if (mounted) {
        final status = results[3] as Map<String, dynamic>;
        setState(() {
          _allSurah = results[0] as List<Map<String, dynamic>>;
          _filteredSurah = _allSurah;
          _juzList = results[1] as List<Map<String, dynamic>>;
          _bookmarks = results[2] as List<Map<String, dynamic>>;
          _lastMushafPage = prefs.getInt('last_mushaf_page') ?? 1;
          _preferMushafMode = prefs.getBool('prefer_mushaf_mode') ?? false;
          _downloadedPagesCount = (status['downloaded_pages'] as int?) ?? 0;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat database Al-Qur\'an: $e')),
        );
      }
    }
  }

  Future<void> _refreshBookmarksAndStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bm = await QuranDbService.getBookmarks();
    final status = await QuranDbService.getMushafDownloadStatus();
    if (mounted) {
      setState(() {
        _bookmarks = bm;
        _lastMushafPage = prefs.getInt('last_mushaf_page') ?? 1;
        _downloadedPagesCount = (status['downloaded_pages'] as int?) ?? 0;
      });
    }
  }

  Future<void> _togglePreferredMode() async {
    final next = !_preferMushafMode;
    setState(() => _preferMushafMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prefer_mushaf_mode', next);
  }

  void _openLocation({
    required int page,
    required int surahId,
    required String surahName,
    required String surahArabic,
    String surahIndo = '',
    int? ayahNumber,
    bool? forceMushaf,
  }) async {
    final useMushaf = forceMushaf ?? _preferMushafMode;
    if (useMushaf) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuranMushafScreen(
            initialPage: page,
            highlightSurahId: surahId,
            highlightAyahNumber: ayahNumber,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuranSurahDetailScreen(
            chapterId: surahId,
            surahName: surahName,
            arabicName: surahArabic,
            indoName: surahIndo,
            initialAyah: ayahNumber,
          ),
        ),
      );
    }
    _refreshBookmarksAndStatus();
  }

  void _showMushafDownloadManager() {
    showDialog(
      context: context,
      builder: (ctx) => _MushafDownloadDialog(
        onFinished: _refreshBookmarksAndStatus,
      ),
    );
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
              _preferMushafMode ? 'Default: Mode Mushaf Madani' : 'Default: Mode Daftar Terjemah',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_preferMushafMode ? LucideIcons.bookOpen : LucideIcons.list, size: 19),
            tooltip: _preferMushafMode ? 'Ganti Default ke Mode Daftar' : 'Ganti Default ke Mode Mushaf',
            onPressed: _togglePreferredMode,
          ),
          IconButton(
            icon: Icon(
              _downloadedPagesCount >= 604 ? LucideIcons.checkCircle2 : LucideIcons.downloadCloud,
              size: 19,
              color: _downloadedPagesCount >= 604 ? Colors.green[700] : const Color(0xFF0D7377),
            ),
            tooltip: 'Unduh Mushaf Madani Offline (604 Hal)',
            onPressed: _showMushafDownloadManager,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
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

          // Resume Banner when not searching
          if (!isQueryMode && !_isLoadingData)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openLocation(
                  page: _lastMushafPage,
                  surahId: 1,
                  surahName: '',
                  surahArabic: '',
                  forceMushaf: true,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7377).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.bookOpen, size: 18, color: Color(0xFF0D7377)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Lanjutkan Mushaf Madani • Halaman $_lastMushafPage',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D7377)),
                        ),
                      ),
                      Text(
                        '$_downloadedPagesCount/604 hal',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF0D7377)),
                    ],
                  ),
                ),
              ),
            ),

          if (!isQueryMode)
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0D7377),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF0D7377),
              tabs: const [
                Tab(text: 'Surah (114)'),
                Tab(text: 'Juz (30)'),
                Tab(text: 'Bookmark'),
              ],
            ),

          Expanded(
            child: _isLoadingData
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
                : isQueryMode
                    ? _buildSearchResultsView()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSurahListView(_allSurah),
                          _buildJuzListView(),
                          _buildBookmarkListView(),
                        ],
                      ),
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
        final startPage = (surah['start_page'] as int?) ?? 1;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF0D7377).withValues(alpha: 0.1),
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
            '${surah['name_indo'] ?? ''} • ${surah['verses_count']} Ayat • Hal $startPage',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          trailing: Text(
            surah['name_arabic'] ?? '',
            style: GoogleFonts.amiri(fontSize: 20, color: const Color(0xFF0D7377)),
          ),
          onTap: () => _openLocation(
            page: startPage,
            surahId: surah['id'] as int,
            surahName: (surah['name_simple'] ?? '').toString(),
            surahArabic: (surah['name_arabic'] ?? '').toString(),
            surahIndo: (surah['name_indo'] ?? '').toString(),
          ),
        );
      },
    );
  }

  Widget _buildJuzListView() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _juzList.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final j = _juzList[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFD4A843).withValues(alpha: 0.15),
            child: Text(
              '${j['juz']}',
              style: const TextStyle(color: Color(0xFFD4A843), fontWeight: FontWeight.bold),
            ),
          ),
          title: Text('Juz ${j['juz']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            'Mulai: QS. ${j['surah_name_simple']}: ${j['ayah_number']} • Hal ${j['page']}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
          onTap: () => _openLocation(
            page: j['page'] as int,
            surahId: j['surah_id'] as int,
            surahName: (j['surah_name_simple'] ?? '').toString(),
            surahArabic: (j['surah_name_arabic'] ?? '').toString(),
            surahIndo: (j['surah_name_indo'] ?? '').toString(),
            ayahNumber: j['ayah_number'] as int,
          ),
        );
      },
    );
  }

  Widget _buildBookmarkListView() {
    if (_bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(LucideIcons.bookmark, size: 42, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Belum ada ayat yang ditandai.\nKetuk ayat di Mode Mushaf atau Mode Daftar untuk mem-bookmark.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _bookmarks.length,
      itemBuilder: (ctx, i) {
        final b = _bookmarks[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0.5,
          child: ListTile(
            title: Text(
              'QS. ${b['surah_name_simple']}: ${b['ayah_number']} (Hal ${b['page_number']})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0D7377)),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                Text(
                  b['text_uthmani'] ?? '',
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.amiri(fontSize: 18, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  b['translation_id'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            onTap: () => _openLocation(
              page: b['page_number'] as int,
              surahId: b['surah_id'] as int,
              surahName: (b['surah_name_simple'] ?? '').toString(),
              surahArabic: (b['surah_name_arabic'] ?? '').toString(),
              ayahNumber: b['ayah_number'] as int,
            ),
          ),
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
                    backgroundColor: const Color(0xFF0D7377).withValues(alpha: 0.1),
                    child: Text('${surah['id']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
                  ),
                  title: Text('${surah['name_simple']} (${surah['name_indo']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(surah['name_arabic'] ?? '', style: GoogleFonts.amiri(fontSize: 18, color: const Color(0xFF0D7377))),
                  onTap: () => _openLocation(
                    page: (surah['start_page'] as int?) ?? 1,
                    surahId: surah['id'] as int,
                    surahName: (surah['name_simple'] ?? '').toString(),
                    surahArabic: (surah['name_arabic'] ?? '').toString(),
                    surahIndo: (surah['name_indo'] ?? '').toString(),
                  ),
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
                onTap: () => _openLocation(
                  page: v['page'] as int,
                  surahId: v['surah_id'] as int,
                  surahName: (v['surah_name_simple'] ?? '').toString(),
                  surahArabic: (v['surah_name_arabic'] ?? '').toString(),
                  surahIndo: (v['surah_name_indo'] ?? '').toString(),
                  ayahNumber: v['ayah_number'] as int,
                ),
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
                              color: const Color(0xFF0D7377).withValues(alpha: 0.1),
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
                            icon: const Icon(LucideIcons.bookOpen, size: 16, color: Color(0xFFD4A843)),
                            tooltip: 'Buka di Mushaf Madani',
                            onPressed: () => _openLocation(
                              page: v['page'] as int,
                              surahId: v['surah_id'] as int,
                              surahName: (v['surah_name_simple'] ?? '').toString(),
                              surahArabic: (v['surah_name_arabic'] ?? '').toString(),
                              surahIndo: (v['surah_name_indo'] ?? '').toString(),
                              ayahNumber: v['ayah_number'] as int,
                              forceMushaf: true,
                            ),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            icon: const Icon(LucideIcons.list, size: 16, color: Color(0xFF0D7377)),
                            tooltip: 'Buka di Mode Daftar',
                            onPressed: () => _openLocation(
                              page: v['page'] as int,
                              surahId: v['surah_id'] as int,
                              surahName: (v['surah_name_simple'] ?? '').toString(),
                              surahArabic: (v['surah_name_arabic'] ?? '').toString(),
                              surahIndo: (v['surah_name_indo'] ?? '').toString(),
                              ayahNumber: v['ayah_number'] as int,
                              forceMushaf: false,
                            ),
                          ),
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
                              backgroundColor: const Color(0xFFD4A843).withValues(alpha: 0.35),
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
                              backgroundColor: const Color(0xFFD4A843).withValues(alpha: 0.35),
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

class _MushafDownloadDialog extends StatefulWidget {
  final VoidCallback onFinished;
  const _MushafDownloadDialog({required this.onFinished});

  @override
  State<_MushafDownloadDialog> createState() => _MushafDownloadDialogState();
}

class _MushafDownloadDialogState extends State<_MushafDownloadDialog> {
  Timer? _poller;
  int _downloadedPages = 0;
  bool _isDownloading = false;
  int _progress = 0;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _pollStatus();
    _poller = Timer.periodic(const Duration(milliseconds: 600), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _pollStatus() async {
    final s = await QuranDbService.getMushafDownloadStatus();
    if (!mounted) return;
    final wasDownloading = _isDownloading;
    final nowDownloading = (s['is_downloading'] as bool?) ?? false;
    setState(() {
      _downloadedPages = (s['downloaded_pages'] as int?) ?? 0;
      _isDownloading = nowDownloading;
      _progress = (s['progress_percent'] as int?) ?? 0;
      _statusText = (s['status_text'] ?? '').toString();
    });
    if (wasDownloading && !nowDownloading) {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mushaf Madani Offline', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Halaman tersimpan di HP: $_downloadedPages / 604 halaman.\n\n'
            'Halaman yang sudah dibuka otomatis tersimpan di HP, atau Anda bisa mengunduh seluruh 604 halaman sekaligus (~77 MB) agar 100% offline.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          if (_isDownloading || _statusText.isNotEmpty) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: _isDownloading ? _progress / 100.0 : (_downloadedPages >= 604 ? 1.0 : null),
              color: const Color(0xFF0D7377),
            ),
            const SizedBox(height: 8),
            Text(
              _statusText.isNotEmpty ? '$_statusText ($_progress%)' : '',
              style: const TextStyle(fontSize: 12, color: Color(0xFF0D7377), fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
      actions: [
        if (_downloadedPages > 0 && !_isDownloading)
          TextButton(
            onPressed: () async {
              await QuranDbService.clearMushafCache();
              await _pollStatus();
              widget.onFinished();
            },
            child: const Text('Hapus Cache', style: TextStyle(color: Colors.red)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        if (!_isDownloading && _downloadedPages < 604)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
            icon: const Icon(LucideIcons.download, size: 16),
            label: const Text('Unduh 604 Hal'),
            onPressed: () async {
              await QuranDbService.startDownloadAllMushafPages();
              _pollStatus();
            },
          ),
      ],
    );
  }
}
