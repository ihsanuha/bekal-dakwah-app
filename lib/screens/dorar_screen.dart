import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_service.dart';
import '../widgets/home_action_button.dart';
import 'ai_chat_screen.dart';
import 'hadith_webview_screen.dart';

class DorarEncyclopediaScreen extends StatefulWidget {
  const DorarEncyclopediaScreen({super.key});

  @override
  State<DorarEncyclopediaScreen> createState() => _DorarEncyclopediaScreenState();
}

class _DorarEncyclopediaScreenState extends State<DorarEncyclopediaScreen> {
  static const List<Map<String, String>> _categories = [
    {'id': 'hadith', 'label': 'Hadits (الموسوعة الحديثية)'},
    {'id': 'tafseer', 'label': 'Tafsir'},
    {'id': 'aqeeda', 'label': 'Aqidah'},
    {'id': 'feqhia', 'label': 'Fiqih'},
    {'id': 'alakhlaq', 'label': 'Akhlak'},
    {'id': 'aadab', 'label': 'Adab'},
    {'id': 'history', 'label': 'Sejarah'},
  ];

  String _selectedCat = 'hadith';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = false;
  bool _configured = true;
  String? _error;
  String? _pendingDetail;
  String? _webFallbackUrl;
  String _activeQuery = '';
  List<dynamic> _results = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _pendingDetail = null;
      _activeQuery = q;
      _results = [];
    });

    try {
      final res = await ApiService.searchDorar(query: q, category: _selectedCat);
      if (!mounted) return;
      final isConf = res['configured'] == true;
      List<dynamic> list = [];
      if (isConf) {
        if (res['results'] is List) {
          list = res['results'] as List;
        } else if (res['data'] is Map && res['data']['data'] is List) {
          list = res['data']['data'] as List;
        } else if (res['data'] is List) {
          list = res['data'] as List;
        }
      }
      setState(() {
        _configured = isConf;
        _pendingDetail = res['detail']?.toString();
        _webFallbackUrl = res['web_url']?.toString();
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data dari Ad-Durar As-Saniyyah: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ensiklopedia Dorar', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Sumber: الدرر السنية (dorar.net)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.globe, size: 19),
            tooltip: 'Buka dorar.net',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HadithWebViewScreen(
                    url: 'https://dorar.net/',
                    title: 'الدرر السنية (dorar.net)',
                  ),
                ),
              );
            },
          ),
          const HomeActionButton(),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final sel = _selectedCat == cat['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        cat['label']!,
                        style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                      ),
                      selected: sel,
                      selectedColor: const Color(0xFF0D7377),
                      onSelected: (_) {
                        setState(() => _selectedCat = cat['id']!);
                        if (_activeQuery.isNotEmpty) {
                          _performSearch(_activeQuery);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari di Ensiklopedia الدرر السنية (Arab)...',
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
                          setState(() {
                            _activeQuery = '';
                            _results = [];
                            _error = null;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _performSearch,
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
                    : !_configured
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.keyRound, size: 46, color: Colors.amber[700]),
                                  const SizedBox(height: 12),
                                  Text(
                                    _pendingDetail ?? 'Ensiklopedia ini menunggu persetujuan DORAR_API_KEY resmi.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13.5, height: 1.5),
                                  ),
                                  const SizedBox(height: 14),
                                  if (_webFallbackUrl != null)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
                                      icon: const Icon(LucideIcons.externalLink, size: 16),
                                      label: const Text('Buka Pencarian di dorar.net'),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => HadithWebViewScreen(
                                              url: _webFallbackUrl!,
                                              title: 'الدرر السنية (dorar.net)',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          )
                        : _activeQuery.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Ketik kata kunci bahasa Arab untuk mencari di Ensiklopedia الدرر السنية.\n\nTab Hadits sudah aktif langsung; 6 ensiklopedia lainnya aktif otomatis begitu DORAR_API_KEY dimasukkan di Render.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5),
                                  ),
                                ),
                              )
                            : _results.isEmpty
                                ? const Center(child: Text('Tidak ditemukan hasil untuk kata kunci tersebut.'))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _results.length,
                                    itemBuilder: (_, idx) => _buildResultCard(_results[idx] as Map<String, dynamic>),
                                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    final matan = (item['matan'] ?? item['hadith'] ?? item['text'] ?? item['title'] ?? '').toString();
    final rawi = (item['rawi'] ?? '').toString();
    final muhaddits = (item['muhaddits'] ?? '').toString();
    final source = (item['source'] ?? '').toString();
    final pageOrNum = (item['page_or_num'] ?? '').toString();
    final grade = (item['grade'] ?? item['khulasa'] ?? '').toString();
    final url = (item['url'] ?? 'https://dorar.net/').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.7,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              matan,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'ThmanyahText', fontSize: 18, height: 1.85, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            if (grade.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D7377).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'خلاصة حكم المحدث: $grade',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0D7377)),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                if (rawi.isNotEmpty) Text('الراوي: $rawi', style: TextStyle(fontSize: 11.5, color: Colors.grey[700])),
                if (muhaddits.isNotEmpty) Text('المحدث: $muhaddits', style: TextStyle(fontSize: 11.5, color: Colors.grey[700])),
                if (source.isNotEmpty) Text('المصدر: $source ($pageOrNum)', style: TextStyle(fontSize: 11.5, color: Colors.grey[700])),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF0D7377), padding: EdgeInsets.zero),
                  icon: const Icon(LucideIcons.externalLink, size: 14),
                  label: const Text('الدرر السنية (Sumber)', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HadithWebViewScreen(url: url, title: 'الدرر السنية'),
                      ),
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.copy, size: 17, color: Colors.grey),
                  tooltip: 'Salin Lengkap',
                  onPressed: () {
                    final formatted = '$matan\n\nخلاصة حكم المحدث: $grade\nالمحدث: $muhaddits | المصدر: $source ($pageOrNum)\nSumber: الدرر السنية ($url)';
                    Clipboard.setData(ClipboardData(text: formatted));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks beserta hukum & sumber disalin')));
                  },
                ),
                IconButton(
                  icon: const Icon(LucideIcons.sparkles, size: 17, color: Color(0xFFD4A843)),
                  tooltip: 'Terjemahkan & Jelaskan dengan AI',
                  onPressed: () {
                    final prompt = 'Terjemahkan dan jelaskan faedah ilmiah dari nash berikut (sumber: الدرر السنية):\n\n$matan\nHukum Muhaddits: $grade\nSumber: $source ($pageOrNum)';
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
    );
  }
}
