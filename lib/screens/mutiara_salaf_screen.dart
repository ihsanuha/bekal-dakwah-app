import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'hadith_webview_screen.dart';

class MutiaraSalafScreen extends StatefulWidget {
  const MutiaraSalafScreen({super.key});

  @override
  State<MutiaraSalafScreen> createState() => _MutiaraSalafScreenState();
}

class _MutiaraSalafScreenState extends State<MutiaraSalafScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];
  final Set<int> _expandedIndices = {};
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('custom_mutiara_sheet_url');
    final cachedRaw = prefs.getString('cached_mutiara_items');
    if (cachedRaw != null && _items.isEmpty) {
      try {
        final List decoded = jsonDecode(cachedRaw);
        _items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _applyFilter(_searchCtrl.text);
        if (mounted) setState(() => _loading = false);
      } catch (_) {}
    }

    if (_items.isEmpty && mounted) {
      setState(() => _loading = true);
    }

    final fresh = await ApiService.getMutiaraList(sheetUrl: customUrl);
    if (!mounted) return;
    if (fresh.isNotEmpty) {
      _items = fresh;
      await prefs.setString('cached_mutiara_items', jsonEncode(fresh));
      _applyFilter(_searchCtrl.text);
    }
    setState(() => _loading = false);
  }

  void _applyFilter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      _filtered = _items;
    } else {
      _filtered = _items.where((it) {
        return (it['judul'] ?? '').toString().toLowerCase().contains(query) ||
            (it['konten_wa'] ?? '').toString().toLowerCase().contains(query) ||
            (it['sumber'] ?? '').toString().toLowerCase().contains(query);
      }).toList();
    }
  }

  Future<void> _showSheetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final ctrl = TextEditingController(text: prefs.getString('custom_mutiara_sheet_url') ?? '');
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Link Google Sheet Mutiara', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://docs.google.com/spreadsheets/d/...',
            labelText: 'URL Google Sheet (Anyone with link / Published CSV)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
            onPressed: () async {
              await prefs.setString('custom_mutiara_sheet_url', ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Simpan & Muat'),
          ),
        ],
      ),
    );
    if (saved == true) {
      _loadData();
    }
  }

  Widget _buildClickableText(String text, TextStyle baseStyle) {
    final urlRegex = RegExp(r'https?://[^\s\]\)]+');
    final matches = urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final m in matches) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start), style: baseStyle));
      }
      final url = m.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: baseStyle.copyWith(
            color: const Color(0xFF0D7377),
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HadithWebViewScreen(
                    url: url,
                    title: url.contains('shamela') ? 'Rujukan Shamela' : 'Rujukan Kitab',
                  ),
                ),
              );
            },
        ),
      );
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mutiara Ilmu', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, size: 19),
            tooltip: 'Atur Link Google Sheet',
            onPressed: _showSheetSettings,
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Perbarui dari Sheet',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari judul, isi mutiara, atau sumber...',
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _loading && _filtered.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
                  : _filtered.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Icon(LucideIcons.sparkles, size: 48, color: Colors.teal[200]),
                            const SizedBox(height: 12),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'Belum ada data Mutiara Ilmu.\nPastikan MUTIARA_SHEET_URL di Render atau Link Google Sheet di ikon pengaturan sudah diisi.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: _showSheetSettings,
                                icon: const Icon(LucideIcons.link, size: 16),
                                label: const Text('Masukkan Link Google Sheet'),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (_, idx) {
                            final item = _filtered[idx];
                            final itemKey = (item['id'] as int?) ?? idx;
                            final isExpanded = _expandedIndices.contains(itemKey);
                            final judul = (item['judul'] ?? '').toString();
                            final arab = (item['teks_arab'] ?? '').toString();
                            final kontenWa = (item['konten_wa'] ?? '').toString();
                            final sumber = (item['sumber'] ?? '').toString();
                            final tanggal = (item['tanggal'] ?? '').toString();

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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            judul.isNotEmpty ? judul : 'Mutiara Ilmu',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0D7377)),
                                          ),
                                        ),
                                        if (tanggal.isNotEmpty)
                                          Text(tanggal, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                      ],
                                    ),
                                    if (arab.isNotEmpty && arab != '-') ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        arab,
                                        maxLines: isExpanded ? null : 2,
                                        overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        textDirection: TextDirection.rtl,
                                        style: const TextStyle(
                                          fontFamily: 'ThmanyahText',
                                          fontSize: 18,
                                          height: 1.8,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    if (isExpanded)
                                      _buildClickableText(
                                        kontenWa,
                                        const TextStyle(fontSize: 13.5, height: 1.55, color: Colors.black87),
                                      )
                                    else
                                      Text(
                                        kontenWa,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13.5, height: 1.5, color: Colors.black87),
                                      ),
                                    if (sumber.isNotEmpty && isExpanded) ...[
                                      const SizedBox(height: 8),
                                      _buildClickableText(
                                        'Sumber: $sumber',
                                        TextStyle(fontSize: 11.5, color: Colors.grey[700], fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(0xFF0D7377),
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedIndices.remove(itemKey);
                                              } else {
                                                _expandedIndices.add(itemKey);
                                              }
                                            });
                                          },
                                          icon: Icon(isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 15),
                                          label: Text(
                                            isExpanded ? 'Tutup' : 'Baca selengkapnya',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0D7377),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          ),
                                          icon: const Icon(LucideIcons.copy, size: 15),
                                          label: const Text('Salin Siap WA', style: TextStyle(fontSize: 12)),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: kontenWa));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Konten Mutiara Ilmu disalin, siap tempel di WA')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
