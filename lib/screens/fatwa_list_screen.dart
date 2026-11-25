import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'ai_chat_screen.dart';
import 'hadith_webview_screen.dart';

class FatwaListScreen extends StatefulWidget {
  const FatwaListScreen({super.key});

  @override
  State<FatwaListScreen> createState() => _FatwaListScreenState();
}

class _FatwaListScreenState extends State<FatwaListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final WebViewController _islamwebController;
  late final WebViewController _bekalIslamController;
  int _webProgress = 0;
  int _bekalProgress = 0;

  // Fatwa Indonesia (IslamHouse API v3)
  List<dynamic> _ihFatwas = [];
  List<dynamic> _filteredIhFatwas = [];
  bool _loadingIh = true;
  int _ihPage = 1;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _islamwebController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _webProgress = p);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.islamweb.net/ar/fatwa/'));
    _bekalIslamController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _bekalProgress = p);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://bekalislam.online/fatwa-ulama'));
    _loadIslamHouseFatwas(page: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIslamHouseFatwas({required int page}) async {
    setState(() => _loadingIh = true);
    try {
      final url = 'https://api3.islamhouse.com/v3/paV29H2Gm56kvLPy/main/fatwa/id/id/$page/20/json';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (decoded['data'] as List?) ?? [];
        if (mounted) {
          setState(() {
            _ihPage = page;
            _ihFatwas = data;
            _applyFilter(_searchCtrl.text);
            _loadingIh = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingIh = false);
  }

  void _applyFilter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredIhFatwas = _ihFatwas;
    } else {
      _filteredIhFatwas = _ihFatwas.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final desc = (item['description'] ?? '').toString().toLowerCase();
        return title.contains(query) || desc.contains(query);
      }).toList();
    }
  }

  String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  void _jumpToFatwaNumber() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Buka Nomor Fatwa IslamWeb', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Contoh: 12345',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
            onPressed: () {
              final numStr = ctrl.text.trim();
              if (numStr.isNotEmpty) {
                Navigator.pop(ctx);
                _tabController.animateTo(0);
                _islamwebController.loadRequest(Uri.parse('https://www.islamweb.net/ar/fatwa/$numStr'));
              }
            },
            child: const Text('Buka'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fatwa Ulama', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.hash, size: 19),
            tooltip: 'Buka Nomor Fatwa IslamWeb',
            onPressed: _jumpToFatwaNumber,
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Muat Ulang',
            onPressed: () {
              if (_tabController.index == 0) {
                _islamwebController.reload();
              } else if (_tabController.index == 1) {
                _loadIslamHouseFatwas(page: _ihPage);
              } else {
                _bekalIslamController.reload();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D7377),
          indicatorColor: const Color(0xFF0D7377),
          tabs: const [
            Tab(text: 'IslamWeb (AR)'),
            Tab(text: 'IslamHouse (ID)'),
            Tab(text: 'Bekal Islam'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: IslamWeb Live Portal
          Column(
            children: [
              if (_webProgress < 100)
                LinearProgressIndicator(
                  value: _webProgress / 100.0,
                  color: const Color(0xFF0D7377),
                  minHeight: 2.5,
                ),
              Container(
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, size: 18),
                      onPressed: () async {
                        if (await _islamwebController.canGoBack()) {
                          await _islamwebController.goBack();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.arrowRight, size: 18),
                      onPressed: () async {
                        if (await _islamwebController.canGoForward()) {
                          await _islamwebController.goForward();
                        }
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'islamweb.net/ar/fatwa',
                        style: TextStyle(fontSize: 12, color: Color(0xFF0D7377), fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _islamwebController.loadRequest(Uri.parse('https://www.islamweb.net/ar/fatwa/')),
                      icon: const Icon(LucideIcons.home, size: 14),
                      label: const Text('Beranda', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(child: WebViewWidget(controller: _islamwebController)),
            ],
          ),

          // Tab 2: Fatwa Indonesia (IslamHouse API v3)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Filter fatwa pada halaman ini...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(LucideIcons.search, size: 19),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => _applyFilter(v)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Halaman $_ihPage (IslamHouse)', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    Row(
                      children: [
                        if (_ihPage > 1)
                          TextButton(
                            onPressed: () => _loadIslamHouseFatwas(page: _ihPage - 1),
                            child: const Text('Sebelumnya', style: TextStyle(fontSize: 12)),
                          ),
                        TextButton(
                          onPressed: () => _loadIslamHouseFatwas(page: _ihPage + 1),
                          child: const Text('Berikutnya', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loadingIh
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
                    : _filteredIhFatwas.isEmpty
                        ? const Center(child: Text('Tidak ada fatwa ditemukan.'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            itemCount: _filteredIhFatwas.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, idx) {
                              final item = _filteredIhFatwas[idx] as Map<String, dynamic>;
                              final title = (item['title'] ?? '').toString();
                              final desc = (item['description'] ?? '').toString();
                              return ListTile(
                                title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                subtitle: desc.isNotEmpty
                                    ? Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600]))
                                    : null,
                                trailing: const Icon(LucideIcons.chevronRight, size: 17, color: Colors.grey),
                                onTap: () => _showFatwaDetailSheet(item),
                              );
                            },
                          ),
              ),
            ],
          ),

          // Tab 3: Bekal Islam Fatwa Ulama
          Column(
            children: [
              if (_bekalProgress < 100)
                LinearProgressIndicator(
                  value: _bekalProgress / 100.0,
                  color: const Color(0xFF0D7377),
                  minHeight: 2.5,
                ),
              Expanded(child: WebViewWidget(controller: _bekalIslamController)),
            ],
          ),
        ],
      ),
    );
  }

  void _showFatwaDetailSheet(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final fullText = _stripHtml((item['full_description'] ?? item['description'] ?? '').toString());
    final attachments = (item['attachments'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '$title\n\n$fullText'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fatwa tersalin')));
                  },
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  fullText,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: attachments.map((att) {
                  final ext = (att['extension_type'] ?? 'FILE').toString();
                  final url = (att['url'] ?? '').toString();
                  return ActionChip(
                    avatar: const Icon(LucideIcons.fileDown, size: 15),
                    label: Text('$ext (${att['size'] ?? ''})', style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      if (url.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => HadithWebViewScreen(url: url, title: title)),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
              icon: const Icon(LucideIcons.sparkles, size: 16, color: Color(0xFFD4A843)),
              label: const Text('Ringkas & Jelaskan Dalilnya dengan AI'),
              onPressed: () {
                final snippet = fullText.length > 2500 ? fullText.substring(0, 2500) : fullText;
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AIChatScreen(
                      initialPrompt: 'Ringkas dan jelaskan dalil-dalil dari fatwa "$title" berikut:\n\n$snippet',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
