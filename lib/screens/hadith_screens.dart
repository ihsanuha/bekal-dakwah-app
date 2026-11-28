import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/home_action_button.dart';
import '../services/api_service.dart';
import 'ai_chat_screen.dart';
import 'hadith_webview_screen.dart';

class HadithSearchScreen extends StatefulWidget {
  const HadithSearchScreen({super.key});

  @override
  State<HadithSearchScreen> createState() => _HadithSearchScreenState();
}

class _HadithSearchScreenState extends State<HadithSearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _savedHadiths = [];
  List<Map<String, dynamic>> _books = [];
  List<String> _recentQueries = [];

  bool _isSearching = false;
  bool _loadingBooks = false;
  String? _errorMsg;
  String _activeQuery = '';
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLocalData();
    _loadBooks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSaved = prefs.getString('saved_hdith_items');
    final rawQueries = prefs.getStringList('hdith_recent_queries') ?? [];
    if (mounted) {
      setState(() {
        _recentQueries = rawQueries;
        if (rawSaved != null) {
          final List decoded = jsonDecode(rawSaved);
          _savedHadiths = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      });
    }
  }

  Future<void> _loadBooks() async {
    setState(() => _loadingBooks = true);
    final list = await ApiService.getHdithComBooks();
    if (mounted) {
      setState(() {
        _books = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingBooks = false;
      });
    }
  }

  Future<void> _performSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _activeQuery = '';
        _results = [];
        _errorMsg = null;
      });
      return;
    }

    setState(() {
      _activeQuery = q;
      _isSearching = true;
      _errorMsg = null;
    });

    try {
      final data = await ApiService.searchHdithCom(q);
      final rawList = (data['results'] as List?) ?? [];
      final parsed = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final prefs = await SharedPreferences.getInstance();
      final updatedQueries = [q, ..._recentQueries.where((x) => x != q)].take(10).toList();
      await prefs.setStringList('hdith_recent_queries', updatedQueries);

      if (mounted && _activeQuery == q) {
        setState(() {
          _results = parsed;
          _totalCount = (data['count'] as int?) ?? parsed.length;
          _recentQueries = updatedQueries;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMsg = 'Gagal mencari di hdith.com. Periksa koneksi internet Anda.\n($e)';
        });
      }
    }
  }

  Future<void> _toggleSaveHadith(Map<String, dynamic> item) async {
    final key = '${item['entry_id']}_${item['book_id']}_${item['text']}';
    final exists = _savedHadiths.any((s) => '${s['entry_id']}_${s['book_id']}_${s['text']}' == key);
    setState(() {
      if (exists) {
        _savedHadiths.removeWhere((s) => '${s['entry_id']}_${s['book_id']}_${s['text']}' == key);
      } else {
        _savedHadiths.insert(0, item);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_hdith_items', jsonEncode(_savedHadiths));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exists ? 'Hadits dihapus dari tersimpan' : 'Hadits disimpan untuk akses offline'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool _isSaved(Map<String, dynamic> item) {
    final key = '${item['entry_id']}_${item['book_id']}_${item['text']}';
    return _savedHadiths.any((s) => '${s['entry_id']}_${s['book_id']}_${s['text']}' == key);
  }

  String _cleanText(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\w\u0600-\u06FF_]+["\x27]?<'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _buildHadithWebUrl(Map<String, dynamic> item) {
    final bookId = item['book_id'];
    final entryId = item['entry_id'];
    if (bookId != null && entryId != null) {
      return 'https://hdith.com/encyclopedia/book/b-$bookId/h/$entryId';
    }
    return 'https://hdith.com/encyclopedia/s?q=${Uri.encodeQueryComponent(_activeQuery)}';
  }

  List<TextSpan> _buildHighlightedSpans(String rawHtml, TextStyle normal, TextStyle highlight) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'<mark>(.*?)</mark>', dotAll: true);
    int lastEnd = 0;

    for (final m in regex.allMatches(rawHtml)) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: _cleanText(rawHtml.substring(lastEnd, m.start)), style: normal));
      }
      spans.add(TextSpan(text: _cleanText(m.group(1) ?? ''), style: highlight));
      lastEnd = m.end;
    }
    if (lastEnd < rawHtml.length) {
      spans.add(TextSpan(text: _cleanText(rawHtml.substring(lastEnd)), style: normal));
    }
    return spans;
  }

  void _openDetailSheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HadithDetailSheet(
        item: item,
        cleanText: _cleanText((item['text'] ?? '').toString()),
        webUrl: _buildHadithWebUrl(item),
        initiallySaved: _isSaved(item),
        onToggleSave: () => _toggleSaveHadith(item),
      ),
    );
  }

  void _openFullWebSearch() {
    final url = _activeQuery.isNotEmpty
        ? 'https://hdith.com/encyclopedia/s?q=${Uri.encodeQueryComponent(_activeQuery)}'
        : 'https://hdith.com/encyclopedia';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HadithWebViewScreen(
          url: url,
          title: _activeQuery.isNotEmpty ? 'hdith.com: $_activeQuery' : 'Ensiklopedia hdith.com',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearchMode = _activeQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hadits & Takhrij (hdith.com)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('612.548 Hadits • 245 Kitab', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.globe, size: 19),
            tooltip: 'Buka Halaman Lengkap di hdith.com',
            onPressed: _openFullWebSearch,
          ),
          const HomeActionButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Ketik kata kunci matan hadits (Arab)...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: IconButton(
                  icon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF0D7377)),
                  onPressed: () => _performSearch(_searchCtrl.text),
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onSubmitted: _performSearch,
              onChanged: (val) {
                if (val.isEmpty && _activeQuery.isNotEmpty) {
                  _performSearch('');
                } else {
                  setState(() {});
                }
              },
            ),
          ),

          if (isSearchMode) ...[
            if (!_isSearching && _results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Total ditemukan: $_totalCount hasil (menampilkan ${_results.length})',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _openFullWebSearch,
                      child: const Text(
                        'Buka di Web hdith.com →',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF0D7377), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Expanded(child: _buildSearchResults()),
          ] else ...[
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0D7377),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF0D7377),
              tabs: [
                Tab(text: 'Tersimpan (${_savedHadiths.length})'),
                Tab(text: 'Kitab (${_books.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSavedAndRecentTab(),
                  _buildBooksTab(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)));
    }
    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.wifiOff, size: 36, color: Colors.grey),
              const SizedBox(height: 10),
              Text(_errorMsg!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
                onPressed: () => _performSearch(_activeQuery),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text('Tidak ada hadits ditemukan.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (ctx, idx) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (ctx, idx) => _buildCompactHadithRow(_results[idx]),
    );
  }

  Widget _buildCompactHadithRow(Map<String, dynamic> item) {
    final rawText = (item['text'] ?? '').toString();
    final book = (item['book'] ?? '').toString();
    final chapter = (item['chapter'] ?? '').toString();
    final numbering = (item['numbering'] ?? '').toString().trim();

    const normalStyle = TextStyle(
      fontFamily: 'ThmanyahText',
      fontSize: 17,
      height: 1.7,
      color: Colors.black87,
    );
    final highlightStyle = TextStyle(
      fontFamily: 'ThmanyahText',
      fontSize: 17,
      height: 1.7,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF0D7377),
      backgroundColor: const Color(0xFFD4A843).withValues(alpha: 0.3),
    );

    return InkWell(
      onTap: () => _openDetailSheet(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RichText(
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(children: _buildHighlightedSpans(rawText, normalStyle, highlightStyle)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.bookOpen, size: 13, color: Color(0xFF0D7377)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '$book${numbering.isNotEmpty ? " (No. $numbering)" : ""}${chapter.isNotEmpty && chapter != "—" ? " • $chapter" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 15, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAndRecentTab() {
    return ListView(
      children: [
        if (_recentQueries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text('Riwayat Pencarian', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 0,
              children: _recentQueries.map((q) {
                return ActionChip(
                  label: Text(
                    q,
                    style: const TextStyle(fontFamily: 'ThmanyahText', fontSize: 15, color: Color(0xFF0D7377)),
                  ),
                  backgroundColor: const Color(0xFF0D7377).withValues(alpha: 0.07),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _searchCtrl.text = q;
                    _performSearch(q);
                  },
                );
              }).toList(),
            ),
          ),
          const Divider(height: 16),
        ],
        if (_savedHadiths.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                'Ketik kata Arab di kolom pencarian atas untuk mencari hadits di hdith.com.\nHadits yang Anda simpan akan muncul di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ..._savedHadiths.map((item) => Column(
                children: [
                  _buildCompactHadithRow(item),
                  Divider(height: 1, color: Colors.grey[200]),
                ],
              )),
      ],
    );
  }

  Widget _buildBooksTab() {
    if (_loadingBooks) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)));
    }
    if (_books.isEmpty) {
      return const Center(child: Text('Daftar kitab belum termuat (periksa koneksi internet).', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      itemCount: _books.length,
      separatorBuilder: (ctx, idx) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (ctx, idx) {
        final b = _books[idx];
        return ListTile(
          dense: true,
          title: Text(
            (b['title'] ?? '').toString(),
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'ThmanyahText', fontSize: 17, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${b['author'] ?? ''} (${b['era'] ?? ''}) • ${b['section'] ?? ''}',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          trailing: Text(
            '${b['count'] ?? ''} hadits',
            style: const TextStyle(fontSize: 11, color: Color(0xFF0D7377), fontWeight: FontWeight.w600),
          ),
          onTap: () {
            final slug = (b['slug'] ?? '').toString();
            if (slug.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HadithWebViewScreen(
                    url: 'https://hdith.com/encyclopedia/book/$slug',
                    title: (b['title'] ?? 'Kitab Hadits').toString(),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _HadithDetailSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final String cleanText;
  final String webUrl;
  final bool initiallySaved;
  final VoidCallback onToggleSave;

  const _HadithDetailSheet({
    required this.item,
    required this.cleanText,
    required this.webUrl,
    required this.initiallySaved,
    required this.onToggleSave,
  });

  @override
  State<_HadithDetailSheet> createState() => _HadithDetailSheetState();
}

class _HadithDetailSheetState extends State<_HadithDetailSheet> {
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.initiallySaved;
  }

  @override
  Widget build(BuildContext context) {
    final book = (widget.item['book'] ?? '-').toString();
    final chapter = (widget.item['chapter'] ?? '-').toString();
    final numbering = (widget.item['numbering'] ?? '-').toString().trim();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book,
                        style: const TextStyle(fontFamily: 'ThmanyahText', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D7377)),
                      ),
                      Text(
                        '${numbering.isNotEmpty ? "No. $numbering • " : ""}$chapter',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.bookmark, size: 19, color: _saved ? const Color(0xFFD4A843) : Colors.grey),
                  tooltip: 'Simpan Offline',
                  onPressed: () {
                    widget.onToggleSave();
                    setState(() => _saved = !_saved);
                  },
                ),
                IconButton(
                  icon: const Icon(LucideIcons.copy, size: 18, color: Colors.grey),
                  tooltip: 'Salin Hadits',
                  onPressed: () {
                    final formatted = '${widget.cleanText}\n\nSumber: $book (No. $numbering)\nBab: $chapter';
                    Clipboard.setData(ClipboardData(text: formatted));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hadits tersalin')));
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    widget.cleanText,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'ThmanyahText',
                      fontSize: 20,
                      height: 1.9,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Tombol Utama: Buka Halaman Lengkap di hdith.com (Silsilah Isnad, Syarah, Takhrij, Syawahid)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7377),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(LucideIcons.externalLink, size: 17, color: Color(0xFFD4A843)),
                    label: const Text('Buka Halaman Lengkap di hdith.com'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HadithWebViewScreen(
                            url: widget.webUrl,
                            title: '$book ${numbering.isNotEmpty ? "#$numbering" : ""}',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D7377),
                      side: const BorderSide(color: Color(0xFF0D7377)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(LucideIcons.languages, size: 17),
                    label: const Text('Terjemahkan & Jelaskan Syarah dengan AI'),
                    onPressed: () {
                      final prompt =
                          'Terjemahkan hadits berikut ke dalam bahasa Indonesia dan jelaskan takhrij/derajat serta faedah ilmiahnya menurut ulama Ahlus Sunnah:\n\nMatan: ${widget.cleanText}\nKitab: $book (No. $numbering)\nBab: $chapter';
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AIChatScreen(initialPrompt: prompt)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
