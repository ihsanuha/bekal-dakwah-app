import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'ai_chat_screen.dart';

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
  String _degreeFilter = 'Semua'; // 'Semua', 'Shahih', 'Dhaif'
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
      _degreeFilter = 'Semua';
    });

    try {
      final data = await ApiService.searchHdithCom(q);
      final rawList = (data['results'] as List?) ?? [];
      final parsed = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Simpan riwayat query
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
    final key = '${item['text']}_${item['source']}_${item['page']}';
    final exists = _savedHadiths.any((s) => '${s['text']}_${s['source']}_${s['page']}' == key);
    setState(() {
      if (exists) {
        _savedHadiths.removeWhere((s) => '${s['text']}_${s['source']}_${s['page']}' == key);
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
    final key = '${item['text']}_${item['source']}_${item['page']}';
    return _savedHadiths.any((s) => '${s['text']}_${s['source']}_${s['page']}' == key);
  }

  /// Klasifikasi derajat hadits dari field `degree` & `degree_cat` di hdith.com
  _DegreeBadge _classifyDegree(Map<String, dynamic> item) {
    final deg = (item['degree'] ?? '').toString();
    final cat = item['degree_cat'];

    if (deg.contains('صحيح') || deg.contains('متفق عليه') || deg.contains('أخرجه البخاري') || deg.contains('أخرجه مسلم')) {
      return _DegreeBadge('Shahih', Colors.green[700]!);
    }
    if (deg.contains('حسن') || deg.contains('جيد') || deg.contains('لا بأس به') || deg.contains('ثابت')) {
      return _DegreeBadge('Hasan/Kuat', Colors.teal[700]!);
    }
    if (cat == 0 ||
        deg.contains('ضعيف') ||
        deg.contains('موضوع') ||
        deg.contains('منكر') ||
        deg.contains('متروك') ||
        deg.contains('باطل') ||
        deg.contains('غير محفوظ') ||
        deg.contains('لا أصل')) {
      return _DegreeBadge('Lemah/Cacat', Colors.red[700]!);
    }
    return _DegreeBadge('Perlu Telaah', Colors.amber[800]!);
  }

  List<Map<String, dynamic>> get _filteredResults {
    if (_degreeFilter == 'Semua') return _results;
    return _results.where((item) {
      final badge = _classifyDegree(item);
      if (_degreeFilter == 'Shahih') {
        return badge.label == 'Shahih' || badge.label == 'Hasan/Kuat';
      }
      return badge.label == 'Lemah/Cacat';
    }).toList();
  }

  void _openDetailSheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HadithDetailSheet(
        item: item,
        badge: _classifyDegree(item),
        initiallySaved: _isSaved(item),
        onToggleSave: () => _toggleSaveHadith(item),
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
      ),
      body: Column(
        children: [
          // Search Bar Fokus Utama
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
            // Filter derajat ringkas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  for (final f in ['Semua', 'Shahih', 'Dhaif'])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          f == 'Dhaif' ? "Dha'if/Lemah" : f,
                          style: TextStyle(fontSize: 11.5, color: _degreeFilter == f ? Colors.white : Colors.black87),
                        ),
                        selected: _degreeFilter == f,
                        selectedColor: const Color(0xFF0D7377),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _degreeFilter = f),
                      ),
                    ),
                  const Spacer(),
                  if (!_isSearching && _results.isNotEmpty)
                    Text(
                      '${_filteredResults.length} / $_totalCount',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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

    final list = _filteredResults;
    if (list.isEmpty) {
      return const Center(
        child: Text('Tidak ada hadits yang cocok dengan filter ini.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (ctx, idx) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (ctx, idx) => _buildCompactHadithRow(list[idx]),
    );
  }

  /// Baris ringkas (padat & cepat dipindai, memuat 6-8 hadits per layar)
  Widget _buildCompactHadithRow(Map<String, dynamic> item) {
    final badge = _classifyDegree(item);
    final rawi = (item['rawi'] ?? '').toString();
    final source = (item['source'] ?? '').toString();
    final muhaddith = (item['muhaddith'] ?? '').toString();

    return InkWell(
      onTap: () => _openDetailSheet(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              (item['text'] ?? '').toString(),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.amiri(fontSize: 18, height: 1.65, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: badge.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  badge.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badge.color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$source • $muhaddith${rawi.isNotEmpty ? " • $rawi" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
                  label: Text(q, style: GoogleFonts.amiri(fontSize: 14, color: const Color(0xFF0D7377))),
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
                'Ketik kata Arab di kolom pencarian atas untuk mencari hadits & takhrij di hdith.com.\nHadits yang Anda simpan akan muncul di sini.',
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
            style: GoogleFonts.amiri(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${b['author'] ?? ''} (${b['era'] ?? ''}) • ${b['section'] ?? ''}',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          trailing: Text(
            '${b['count'] ?? ''} hadits',
            style: const TextStyle(fontSize: 11, color: Color(0xFF0D7377), fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}

class _DegreeBadge {
  final String label;
  final Color color;
  _DegreeBadge(this.label, this.color);
}

class _HadithDetailSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final _DegreeBadge badge;
  final bool initiallySaved;
  final VoidCallback onToggleSave;

  const _HadithDetailSheet({
    required this.item,
    required this.badge,
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
    final text = (widget.item['text'] ?? '').toString();
    final rawi = (widget.item['rawi'] ?? '-').toString();
    final muhaddith = (widget.item['muhaddith'] ?? '-').toString();
    final source = (widget.item['source'] ?? '-').toString();
    final page = (widget.item['page'] ?? '-').toString();
    final degree = (widget.item['degree'] ?? '-').toString();

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.badge.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.badge.label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.badge.color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$source ($page)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
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
                  tooltip: 'Salin Hadits & Takhrij',
                  onPressed: () {
                    final formatted = '$text\n\nPerawi: $rawi\nSumber: $source ($page)\nHukum ($muhaddith): $degree';
                    Clipboard.setData(ClipboardData(text: formatted));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hadits & takhrij tersalin')));
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
                    text,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.amiri(fontSize: 21, height: 1.95, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _metaRow('Perawi', rawi),
                        _metaRow('Muhaddits', muhaddith),
                        _metaRow('Kitab & Hal', '$source ($page)'),
                        _metaRow('Takhrij / Hukum', degree),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7377),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(LucideIcons.languages, size: 17, color: Color(0xFFD4A843)),
                    label: const Text('Terjemahkan & Jelaskan Syarah dengan AI'),
                    onPressed: () {
                      final prompt =
                          'Terjemahkan hadits berikut ke dalam bahasa Indonesia dan jelaskan syarah serta faedah ilmiahnya menurut ulama Ahlus Sunnah:\n\nMatan: $text\nPerawi: $rawi\nKitab: $source ($page)\nHukum ($muhaddith): $degree';
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

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: value.contains(RegExp(r'[\u0600-\u06FF]')) ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
