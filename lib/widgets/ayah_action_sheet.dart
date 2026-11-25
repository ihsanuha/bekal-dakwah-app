import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/quran_db_service.dart';
import '../screens/ai_chat_screen.dart';

class AyahActionSheet extends StatefulWidget {
  final int surahId;
  final int ayahNumber;
  final int pageNumber;
  final String surahName;
  final String surahArabic;
  final String textUthmani;
  final String translationId;
  final VoidCallback? onBookmarkChanged;

  const AyahActionSheet({
    super.key,
    required this.surahId,
    required this.ayahNumber,
    required this.pageNumber,
    required this.surahName,
    required this.surahArabic,
    required this.textUthmani,
    required this.translationId,
    this.onBookmarkChanged,
  });

  @override
  State<AyahActionSheet> createState() => _AyahActionSheetState();
}

class _AyahActionSheetState extends State<AyahActionSheet> {
  bool _isBookmarked = false;
  bool _showTafsir = false;
  String _selectedTafsirId = 'kemenag_id';
  String _tafsirContent = '';
  bool _loadingTafsir = false;

  final Map<String, String> _tafsirOptions = const {
    'kemenag_id': 'Kemenag (ID)',
    '91': "As-Sa'di (AR)",
    '14': 'Ibnu Katsir (AR)',
    '94': 'Al-Baghawi (AR)',
  };

  @override
  void initState() {
    super.initState();
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    final res = await QuranDbService.isBookmarked(widget.surahId, widget.ayahNumber);
    if (mounted) {
      setState(() => _isBookmarked = res);
    }
  }

  Future<void> _toggleBookmark() async {
    final added = await QuranDbService.toggleBookmark(
      widget.surahId,
      widget.ayahNumber,
      widget.pageNumber,
    );
    if (mounted) {
      setState(() => _isBookmarked = added);
      widget.onBookmarkChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added ? 'Ayat ditambahkan ke Bookmark' : 'Ayat dihapus dari Bookmark'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadTafsir(String tafsirId) async {
    setState(() {
      _showTafsir = true;
      _selectedTafsirId = tafsirId;
      _loadingTafsir = true;
    });
    final text = await QuranDbService.getTafsir(tafsirId, widget.surahId, widget.ayahNumber);
    if (mounted && _selectedTafsirId == tafsirId) {
      setState(() {
        _tafsirContent = text;
        _loadingTafsir = false;
      });
    }
  }

  void _copyDalil() {
    final formatted =
        '${widget.textUthmani}\n\n"${widget.translationId}"\n(QS. ${widget.surahName}: ${widget.ayahNumber})';
    Clipboard.setData(ClipboardData(text: formatted));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dalil QS. ${widget.surahName}: ${widget.ayahNumber} tersalin')),
    );
  }

  void _askAI({bool translateTafsir = false}) {
    final prompt = translateTafsir && _tafsirContent.isNotEmpty
        ? 'Terjemahkan dan ringkaskan tafsir berikut ke dalam bahasa Indonesia yang mudah dipahami untuk materi kajian Ustadz (QS. ${widget.surahName}: ${widget.ayahNumber}):\n\n${_tafsirContent.length > 2500 ? _tafsirContent.substring(0, 2500) : _tafsirContent}'
        : 'Jelaskan tafsir dan faedah ilmiah dari QS. ${widget.surahName} (${widget.surahId}) ayat ${widget.ayahNumber} menurut Tafsir Ibnu Katsir dan Tafsir As-Sa\'di:\n\n${widget.textUthmani}\n"${widget.translationId}"';
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AIChatScreen(initialPrompt: prompt)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7377).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'QS. ${widget.surahName}: ${widget.ayahNumber}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D7377),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Hal ${widget.pageNumber}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    LucideIcons.bookmark,
                    size: 20,
                    color: _isBookmarked ? const Color(0xFFD4A843) : Colors.grey,
                  ),
                  tooltip: 'Bookmark Ayat',
                  onPressed: _toggleBookmark,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.copy, size: 19, color: Colors.grey),
                  tooltip: 'Salin Dalil',
                  onPressed: _copyDalil,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    widget.textUthmani,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.amiri(fontSize: 22, height: 2.0, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    widget.translationId,
                    style: const TextStyle(fontSize: 13.5, height: 1.55, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D7377),
                            side: const BorderSide(color: Color(0xFF0D7377)),
                          ),
                          icon: const Icon(LucideIcons.bookOpenCheck, size: 16),
                          label: Text(_showTafsir ? 'Tutup Tafsir' : 'Baca Tafsir'),
                          onPressed: () {
                            if (_showTafsir) {
                              setState(() => _showTafsir = false);
                            } else {
                              _loadTafsir(_selectedTafsirId);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D7377),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(LucideIcons.sparkles, size: 16, color: Color(0xFFD4A843)),
                          label: const Text('Tanya AI'),
                          onPressed: () => _askAI(),
                        ),
                      ),
                    ],
                  ),

                  // Panel Tafsir (persis kebutuhan studi Ustadz)
                  if (_showTafsir) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    Text(
                      'Kitab Tafsir (Tersimpan Offline Setelah Dibuka)',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0D7377)),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tafsirOptions.entries.map((entry) {
                          final selected = _selectedTafsirId == entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                entry.value,
                                style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.black87),
                              ),
                              selected: selected,
                              selectedColor: const Color(0xFF0D7377),
                              showCheckmark: false,
                              onSelected: (_) => _loadTafsir(entry.key),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingTafsir)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF0D7377))),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: SelectableText(
                          _tafsirContent,
                          textAlign: _selectedTafsirId == 'kemenag_id' ? TextAlign.left : TextAlign.right,
                          textDirection: _selectedTafsirId == 'kemenag_id' ? TextDirection.ltr : TextDirection.rtl,
                          style: _selectedTafsirId == 'kemenag_id'
                              ? const TextStyle(fontSize: 13.5, height: 1.6, color: Colors.black87)
                              : GoogleFonts.amiri(fontSize: 19, height: 1.9, color: Colors.black87),
                        ),
                      ),
                      if (_selectedTafsirId != 'kemenag_id' && _tafsirContent.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(LucideIcons.languages, size: 16),
                            label: const Text('Terjemahkan & Ringkas Tafsir dengan AI'),
                            onPressed: () => _askAI(translateTafsir: true),
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
