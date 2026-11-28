import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/quran_db_service.dart';
import '../widgets/ayah_action_sheet.dart';
import '../widgets/home_action_button.dart';
import 'ai_chat_screen.dart';
import 'quran_mushaf_screen.dart';

class QuranSurahDetailScreen extends StatefulWidget {
  final int chapterId;
  final String surahName;
  final String arabicName;
  final String indoName;
  final int? initialAyah;

  const QuranSurahDetailScreen({
    super.key,
    required this.chapterId,
    required this.surahName,
    required this.arabicName,
    this.indoName = '',
    this.initialAyah,
  });

  @override
  State<QuranSurahDetailScreen> createState() => _QuranSurahDetailScreenState();
}

class _QuranSurahDetailScreenState extends State<QuranSurahDetailScreen> {
  List<Map<String, dynamic>> _verses = [];
  bool _isLoading = true;
  double _arabicFontSize = 24.0;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  @override
  void initState() {
    super.initState();
    _loadVerses();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVerses() async {
    try {
      final list = await QuranDbService.getVerses(widget.chapterId);
      if (mounted) {
        for (final v in list) {
          _ayahKeys[v['ayah_number'] as int] = GlobalKey();
        }
        setState(() {
          _verses = list;
          _isLoading = false;
        });

        if (widget.initialAyah != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToAyah(widget.initialAyah!));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat ayat: $e')),
        );
      }
    }
  }

  Future<void> _scrollToAyah(int ayahNumber) async {
    final targetIdx = _verses.indexWhere((v) => v['ayah_number'] == ayahNumber);
    if (targetIdx == -1 || !_scrollController.hasClients) return;

    // Lakukan konvergensi beberapa langkah karena tinggi item ayat bervariasi
    double currentEstimate = (targetIdx * 230.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    for (int attempt = 0; attempt < 8; attempt++) {
      final existingCtx = _ayahKeys[ayahNumber]?.currentContext;
      if (existingCtx != null && existingCtx.mounted) {
        await Scrollable.ensureVisible(
          existingCtx,
          duration: const Duration(milliseconds: 280),
          alignment: 0.08,
        );
        return;
      }

      _scrollController.jumpTo(currentEstimate.clamp(0.0, _scrollController.position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final afterCtx = _ayahKeys[ayahNumber]?.currentContext;
      if (afterCtx != null && afterCtx.mounted) {
        await Scrollable.ensureVisible(
          afterCtx,
          duration: const Duration(milliseconds: 280),
          alignment: 0.08,
        );
        return;
      }

      // Cari indeks ayat yang sedang ter-render untuk koreksi arah scroll
      int? minMountedIdx;
      int? maxMountedIdx;
      for (int i = 0; i < _verses.length; i++) {
        final aNum = _verses[i]['ayah_number'] as int;
        if (_ayahKeys[aNum]?.currentContext != null) {
          minMountedIdx ??= i;
          maxMountedIdx = i;
        }
      }

      if (minMountedIdx != null && maxMountedIdx != null) {
        if (targetIdx < minMountedIdx) {
          final diff = minMountedIdx - targetIdx;
          currentEstimate -= (diff * 220.0).clamp(300.0, 4000.0);
        } else if (targetIdx > maxMountedIdx) {
          final diff = targetIdx - maxMountedIdx;
          currentEstimate += (diff * 220.0).clamp(300.0, 4000.0);
        }
      } else {
        currentEstimate += 600.0;
      }
    }
  }

  void _copyAyah(Map<String, dynamic> verse) {
    final ayahNum = verse['ayah_number'];
    final formatted = '${verse['text_uthmani']}\n\n"${verse['translation_id']}"\n(QS. ${widget.surahName}: $ayahNum)';
    Clipboard.setData(ClipboardData(text: formatted));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ayat $ayahNum (${widget.surahName}) tersalin ke clipboard')),
    );
  }

  void _openAyahSheet(Map<String, dynamic> verse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AyahActionSheet(
        surahId: widget.chapterId,
        ayahNumber: verse['ayah_number'] as int,
        pageNumber: verse['page'] as int,
        surahName: widget.surahName,
        surahArabic: widget.arabicName,
        textUthmani: (verse['text_uthmani'] ?? '').toString(),
        translationId: (verse['translation_id'] ?? '').toString(),
      ),
    );
  }

  void _switchToMushafMode() {
    int page = 1;
    if (_verses.isNotEmpty) {
      if (widget.initialAyah != null) {
        final target = _verses.firstWhere(
          (v) => v['ayah_number'] == widget.initialAyah,
          orElse: () => _verses.first,
        );
        page = (target['page'] as int?) ?? 1;
      } else {
        page = (_verses.first['page'] as int?) ?? 1;
      }
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuranMushafScreen(
          initialPage: page,
          highlightSurahId: widget.chapterId,
          highlightAyahNumber: widget.initialAyah,
        ),
      ),
    );
  }

  void _askAIAboutAyah(Map<String, dynamic> verse) {
    final ayahNum = verse['ayah_number'];
    final prompt =
        'Jelaskan tafsir ringkas dan faedah ilmiah dari QS. ${widget.surahName} (${widget.chapterId}) ayat $ayahNum menurut Tafsir Ibnu Katsir dan Tafsir As-Sa\'di:\n\n${verse['text_uthmani']}\n"${verse['translation_id']}"';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AIChatScreen(initialPrompt: prompt)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBismillahBanner = widget.chapterId != 1 && widget.chapterId != 9;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.surahName} ${widget.indoName.isNotEmpty ? "(${widget.indoName})" : ""}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              '${widget.arabicName} • ${_verses.length} Ayat (Mode Daftar)',
              style: GoogleFonts.amiri(fontSize: 13, color: const Color(0xFF0D7377)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bookOpen, size: 18),
            tooltip: 'Buka Mode Mushaf Madani',
            onPressed: _switchToMushafMode,
          ),
          IconButton(
            icon: const Icon(LucideIcons.zoomOut, size: 18),
            tooltip: 'Perkecil huruf Arab',
            onPressed: () => setState(() => _arabicFontSize = (_arabicFontSize - 2).clamp(18.0, 38.0)),
          ),
          IconButton(
            icon: const Icon(LucideIcons.zoomIn, size: 18),
            tooltip: 'Perbesar huruf Arab',
            onPressed: () => setState(() => _arabicFontSize = (_arabicFontSize + 2).clamp(18.0, 38.0)),
          ),
          const HomeActionButton(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: _verses.length + (showBismillahBanner ? 1 : 0),
              itemBuilder: (ctx, idx) {
                if (showBismillahBanner && idx == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7377).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.amiri(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0D7377)),
                    ),
                  );
                }

                final verseIdx = showBismillahBanner ? idx - 1 : idx;
                final verse = _verses[verseIdx];
                final ayahNum = verse['ayah_number'] as int;
                final isHighlighted = widget.initialAyah == ayahNum;

                return Container(
                  key: _ayahKeys[ayahNum],
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isHighlighted ? const Color(0xFFD4A843).withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isHighlighted ? const Color(0xFFD4A843) : Colors.grey[200]!,
                      width: isHighlighted ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFF0D7377).withValues(alpha: 0.1),
                            child: Text(
                              '$ayahNum',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D7377)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Juz ${verse['juz']} • Hal ${verse['page']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          const Spacer(),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            icon: const Icon(LucideIcons.bookOpenCheck, size: 17, color: Color(0xFF0D7377)),
                            tooltip: 'Baca Tafsir & Bookmark',
                            onPressed: () => _openAyahSheet(verse),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            icon: const Icon(LucideIcons.sparkles, size: 17, color: Color(0xFFD4A843)),
                            tooltip: 'Tanya Tafsir ke AI',
                            onPressed: () => _askAIAboutAyah(verse),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            icon: const Icon(LucideIcons.copy, size: 17, color: Colors.grey),
                            tooltip: 'Salin Ayat & Terjemah',
                            onPressed: () => _copyAyah(verse),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        verse['text_uthmani'] ?? '',
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.amiri(
                          fontSize: _arabicFontSize,
                          height: 2.1,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        verse['translation_id'] ?? '',
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
