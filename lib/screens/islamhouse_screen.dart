import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'hadith_webview_screen.dart';

class IslamHouseScreen extends StatefulWidget {
  const IslamHouseScreen({super.key});

  @override
  State<IslamHouseScreen> createState() => _IslamHouseScreenState();
}

class _IslamHouseScreenState extends State<IslamHouseScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _lang = 'id'; // 'id' atau 'ar'
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _isGlobalSearch = false;
  List<dynamic> _items = [];
  final Map<String, List<dynamic>> _globalCache = {};
  String _filterQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _types = ['books', 'articles', 'audios'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _searchCtrl.clear();
        _filterQuery = '';
        _loadItems(page: 1);
      }
    });
    _loadItems(page: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems({required int page}) async {
    setState(() {
      _loading = true;
      _isGlobalSearch = false;
    });
    final type = _types[_tabController.index];
    try {
      final url = 'https://api3.islamhouse.com/v3/paV29H2Gm56kvLPy/main/$type/$_lang/$_lang/$page/50/json';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final links = (decoded['links'] as Map<String, dynamic>?) ?? {};
        if (mounted) {
          setState(() {
            _page = page;
            _totalPages = (links['pages_number'] as int?) ?? 10;
            _items = (decoded['data'] as List?) ?? [];
            _loading = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _searchAllPages(String q) async {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      _loadItems(page: 1);
      return;
    }

    setState(() {
      _loading = true;
      _isGlobalSearch = true;
      _filterQuery = query;
    });

    final type = _types[_tabController.index];
    final cacheKey = '${type}_$_lang';
    if (!_globalCache.containsKey(cacheKey)) {
      final pagesToFetch = _totalPages.clamp(1, 10);
      final futures = List.generate(pagesToFetch, (i) async {
        final p = i + 1;
        try {
          final url = 'https://api3.islamhouse.com/v3/paV29H2Gm56kvLPy/main/$type/$_lang/$_lang/$p/50/json';
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
          if (res.statusCode == 200) {
            final d = jsonDecode(res.body) as Map<String, dynamic>;
            return (d['data'] as List?) ?? [];
          }
        } catch (_) {}
        return <dynamic>[];
      });
      final results = await Future.wait(futures);
      _globalCache[cacheKey] = results.expand((e) => e).toList();
    }

    if (mounted) {
      setState(() {
        _items = _globalCache[cacheKey] ?? [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterQuery.isEmpty
        ? _items
        : _items.where((it) {
            final t = (it['title'] ?? '').toString().toLowerCase();
            final d = (it['description'] ?? '').toString().toLowerCase();
            return t.contains(_filterQuery) || d.contains(_filterQuery);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pustaka IslamHouse', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Buku, Artikel & Audio Kajian', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _lang = _lang == 'id' ? 'ar' : 'id');
              _searchCtrl.clear();
              _filterQuery = '';
              _loadItems(page: 1);
            },
            child: Text(
              _lang == 'id' ? 'ID' : 'AR',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D7377)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D7377),
          indicatorColor: const Color(0xFF0D7377),
          tabs: const [
            Tab(text: 'Buku / PDF'),
            Tab(text: 'Artikel'),
            Tab(text: 'Audio Kajian'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari judul di seluruh database (tekan Enter)...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: IconButton(
                  icon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF0D7377)),
                  onPressed: () => _searchAllPages(_searchCtrl.text),
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 17),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filterQuery = '';
                          _loadItems(page: 1);
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                if (v.trim().isEmpty && _isGlobalSearch) {
                  _filterQuery = '';
                  _loadItems(page: 1);
                } else {
                  setState(() => _filterQuery = v.trim().toLowerCase());
                }
              },
              onSubmitted: _searchAllPages,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isGlobalSearch
                      ? '${filtered.length} hasil dari ${_items.length} item (${_lang.toUpperCase()})'
                      : 'Halaman $_page / $_totalPages • ${_lang.toUpperCase()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                if (!_isGlobalSearch)
                  Row(
                    children: [
                      if (_page > 1)
                        TextButton(
                          onPressed: () => _loadItems(page: _page - 1),
                          child: const Text('Sebelumnya', style: TextStyle(fontSize: 12)),
                        ),
                      if (_page < _totalPages)
                        TextButton(
                          onPressed: () => _loadItems(page: _page + 1),
                          child: const Text('Berikutnya', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
                : filtered.isEmpty
                    ? const Center(child: Text('Belum ada item ditemukan.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final item = filtered[idx] as Map<String, dynamic>;
                          final title = (item['title'] ?? '').toString();
                          final desc = (item['description'] ?? '').toString();
                          final attachments = (item['attachments'] as List?) ?? [];

                          return ListTile(
                            title: Text(
                              title,
                              textDirection: _lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (desc.isNotEmpty)
                                  Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                if (attachments.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${attachments.length} lampiran (${attachments.map((a) => a['extension_type']).join(', ')})',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF0D7377), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () => _openDetailSheet(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _openDetailSheet(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final desc = (item['description'] ?? '').toString();
    final fullDesc = (item['full_description'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final attachments = (item['attachments'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (desc.isNotEmpty || fullDesc.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Text(fullDesc.isNotEmpty ? fullDesc : desc, style: const TextStyle(fontSize: 13, height: 1.5)),
                ),
              ),
            const SizedBox(height: 12),
            if (attachments.isNotEmpty) ...[
              const Text('Buka / Unduh Lampiran:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...attachments.map((att) {
                final url = (att['url'] ?? '').toString();
                final ext = (att['extension_type'] ?? 'FILE').toString();
                final size = (att['size'] ?? '').toString();
                return ListTile(
                  dense: true,
                  leading: const Icon(LucideIcons.fileDown, color: Color(0xFF0D7377)),
                  title: Text('$ext • $size'),
                  subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                  onTap: () {
                    if (url.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => HadithWebViewScreen(url: url, title: title)),
                      );
                    }
                  },
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
