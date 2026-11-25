import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_service.dart';
import 'ai_chat_screen.dart';
import 'hadith_webview_screen.dart';

class TurathSearchScreen extends StatefulWidget {
  const TurathSearchScreen({super.key});

  @override
  State<TurathSearchScreen> createState() => _TurathSearchScreenState();
}

class _TurathSearchScreenState extends State<TurathSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String _activeQuery = '';
  int _totalCount = 0;
  int _currentPage = 1;
  List<dynamic> _results = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query, {int page = 1}) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _activeQuery = '';
        _totalCount = 0;
        _currentPage = 1;
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _activeQuery = q;
      _currentPage = page;
    });

    try {
      final data = await ApiService.searchTurath(q, page: page);
      if (!mounted) return;
      setState(() {
        _totalCount = (data['count'] as int?) ?? 0;
        _results = (data['data'] as List?) ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat hasil dari Turath: $e';
        _loading = false;
      });
    }
  }

  String _cleanHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _openWebTurath() {
    final url = _activeQuery.isNotEmpty
        ? 'https://app.turath.io/search?q=${Uri.encodeQueryComponent(_activeQuery)}'
        : 'https://app.turath.io/';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HadithWebViewScreen(
          url: url,
          title: 'Maktabah Turath',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maktabah Kitab Ulama', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Sumber: Turath.io', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.globe, size: 19),
            tooltip: 'Buka app.turath.io',
            onPressed: _openWebTurath,
          ),
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
                hintText: 'Cari kitab atau nash ulama (Arab)...',
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
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (val) => _performSearch(val),
            ),
          ),
          if (_activeQuery.isNotEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_totalCount hasil ditemukan (hal. $_currentPage)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0D7377), fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      if (_currentPage > 1)
                        TextButton(
                          onPressed: () => _performSearch(_activeQuery, page: _currentPage - 1),
                          child: const Text('Sebelumnya', style: TextStyle(fontSize: 12)),
                        ),
                      if (_results.length >= 10)
                        TextButton(
                          onPressed: () => _performSearch(_activeQuery, page: _currentPage + 1),
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
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        ),
                      )
                    : _activeQuery.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.library, size: 48, color: Colors.teal[200]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Cari ribuan kitab para ulama Ahlus Sunnah dari Maktabah Turath.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: _openWebTurath,
                                    icon: const Icon(LucideIcons.externalLink, size: 16),
                                    label: const Text('Jelajahi di app.turath.io'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _results.isEmpty
                            ? const Center(child: Text('Tidak ditemukan hasil untuk kata kunci tersebut.'))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                itemCount: _results.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final item = _results[idx] as Map<String, dynamic>;
                                  final rawMeta = item['meta'];
                                  Map<String, dynamic> meta = {};
                                  if (rawMeta is Map<String, dynamic>) {
                                    meta = rawMeta;
                                  } else if (rawMeta is String && rawMeta.isNotEmpty) {
                                    try {
                                      final decoded = jsonDecode(rawMeta);
                                      if (decoded is Map<String, dynamic>) meta = decoded;
                                    } catch (_) {}
                                  }
                                  final bookId = int.tryParse('${item['book_id'] ?? 0}') ?? 0;
                                  final pageId = int.tryParse('${meta['page_id'] ?? 1}') ?? 1;
                                  final bookName = (meta['book_name'] ?? 'Kitab #$bookId').toString();
                                  final authorName = (meta['author_name'] ?? '').toString();
                                  final vol = (meta['vol'] ?? '').toString();
                                  final page = (meta['page'] ?? '').toString();
                                  final snip = _cleanHtml((item['snip'] ?? item['text'] ?? '').toString());

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                    title: Text(
                                      bookName,
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(
                                        fontFamily: 'ThmanyahText',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D7377),
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (authorName.isNotEmpty)
                                          Text(
                                            '$authorName ${vol.isNotEmpty ? "• ج $vol ص $page" : ""}',
                                            textDirection: TextDirection.rtl,
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          snip,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          textDirection: TextDirection.rtl,
                                          style: const TextStyle(
                                            fontFamily: 'ThmanyahText',
                                            fontSize: 14,
                                            height: 1.6,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      if (bookId > 0) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TurathBookReaderScreen(
                                              bookId: bookId,
                                              initialPage: pageId,
                                              initialTitle: bookName,
                                            ),
                                          ),
                                        );
                                      }
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

class TurathBookReaderScreen extends StatefulWidget {
  final int bookId;
  final int initialPage;
  final String initialTitle;

  const TurathBookReaderScreen({
    super.key,
    required this.bookId,
    this.initialPage = 1,
    this.initialTitle = 'Baca Kitab',
  });

  @override
  State<TurathBookReaderScreen> createState() => _TurathBookReaderScreenState();
}

class _TurathBookReaderScreenState extends State<TurathBookReaderScreen> {
  late int _currentPg;
  bool _loadingPage = true;
  String? _error;
  String _bookName = '';
  String _authorName = '';
  String _vol = '';
  String _printedPage = '';
  String _pageText = '';
  List<dynamic> _headings = [];

  @override
  void initState() {
    super.initState();
    _currentPg = widget.initialPage;
    _bookName = widget.initialTitle;
    _loadBookMeta();
    _loadPage(_currentPg);
  }

  Future<void> _loadBookMeta() async {
    try {
      final data = await ApiService.getTurathBook(widget.bookId);
      if (!mounted) return;
      final meta = (data['meta'] as Map<String, dynamic>?) ?? {};
      final indexes = (data['indexes'] as Map<String, dynamic>?) ?? {};
      setState(() {
        _bookName = (meta['name'] ?? _bookName).toString();
        _headings = (indexes['headings'] as List?) ?? [];
      });
    } catch (_) {}
  }

  Future<void> _loadPage(int pg) async {
    if (pg < 1) return;
    setState(() {
      _loadingPage = true;
      _error = null;
      _currentPg = pg;
    });

    try {
      final data = await ApiService.getTurathPage(widget.bookId, pg);
      if (!mounted) return;
      final meta = (data['meta'] as Map<String, dynamic>?) ?? {};
      setState(() {
        _bookName = (meta['book_name'] ?? _bookName).toString();
        _authorName = (meta['author_name'] ?? '').toString();
        _vol = (meta['vol'] ?? '').toString();
        _printedPage = (meta['page'] ?? pg).toString();
        _pageText = (data['text'] ?? '').toString();
        _loadingPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat halaman: $e';
        _loadingPage = false;
      });
    }
  }

  void _openTocSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Daftar Isi Kitab', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const Divider(height: 1),
            Expanded(
              child: _headings.isEmpty
                  ? const Center(child: Text('Daftar isi tidak tersedia untuk kitab ini.'))
                  : ListView.separated(
                      controller: ctrl,
                      itemCount: _headings.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final h = _headings[i] as Map<String, dynamic>;
                        final title = (h['title'] ?? '').toString();
                        final page = (h['page'] as int?) ?? 1;
                        return ListTile(
                          title: Text(
                            title,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontFamily: 'ThmanyahText', fontSize: 15),
                          ),
                          leading: Text('ص $page', style: const TextStyle(fontSize: 12, color: Color(0xFF0D7377))),
                          onTap: () {
                            Navigator.pop(ctx);
                            _loadPage(page);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_bookName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            if (_authorName.isNotEmpty)
              Text(_authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.list, size: 20),
            tooltip: 'Daftar Isi',
            onPressed: _openTocSheet,
          ),
          IconButton(
            icon: const Icon(LucideIcons.globe, size: 19),
            tooltip: 'Buka di app.turath.io',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HadithWebViewScreen(
                    url: 'https://app.turath.io/book/${widget.bookId}?pg=$_currentPg',
                    title: _bookName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _loadingPage
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.teal.withOpacity(0.06),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _vol.isNotEmpty ? 'Juz $_vol • Hal. $_printedPage' : 'Hal. $_printedPage',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D7377)),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(LucideIcons.copy, size: 17),
                                tooltip: 'Salin Teks Halaman',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: '$_pageText\n\n[$_bookName, Juz $_vol, Hal. $_printedPage]'));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks halaman tersalin')));
                                },
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.sparkles, size: 17, color: Color(0xFFD4A843)),
                                tooltip: 'Terjemahkan & Jelaskan dengan AI',
                                onPressed: () {
                                  final snippet = _pageText.length > 2500 ? _pageText.substring(0, 2500) : _pageText;
                                  final prompt =
                                      'Terjemahkan dan jelaskan faedah ilmiah dari kutipan kitab "$_bookName" (Juz $_vol, Hal. $_printedPage) berikut menurut manhaj Ahlus Sunnah:\n\n$snippet';
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => AIChatScreen(initialPrompt: prompt)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          _pageText.isEmpty ? '(Halaman kosong)' : _pageText,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontFamily: 'ThmanyahText',
                            fontSize: 19,
                            height: 1.9,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _currentPg > 1 ? () => _loadPage(_currentPg - 1) : null,
                icon: const Icon(LucideIcons.chevronLeft, size: 16),
                label: const Text('Sebelumnya'),
              ),
              Text('Hal. $_currentPg', style: const TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _loadPage(_currentPg + 1),
                icon: const Icon(LucideIcons.chevronRight, size: 16),
                label: const Text('Berikutnya'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
