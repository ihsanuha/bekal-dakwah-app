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
  bool _loading = true;
  List<dynamic> _items = [];
  String _filterQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _types = ['books', 'articles', 'audios'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
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
    setState(() => _loading = true);
    final type = _types[_tabController.index];
    try {
      final url = 'https://api3.islamhouse.com/v3/paV29H2Gm56kvLPy/main/$type/$_lang/$_lang/$page/20/json';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _page = page;
            _items = (decoded['data'] as List?) ?? [];
            _loading = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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
              decoration: InputDecoration(
                hintText: 'Filter judul pada halaman ini...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _filterQuery = v.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Halaman $_page • Bahasa: ${_lang.toUpperCase()}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                Row(
                  children: [
                    if (_page > 1)
                      TextButton(
                        onPressed: () => _loadItems(page: _page - 1),
                        child: const Text('Sebelumnya', style: TextStyle(fontSize: 12)),
                      ),
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
                    ? const Center(child: Text('Belum ada item pada halaman ini.'))
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
