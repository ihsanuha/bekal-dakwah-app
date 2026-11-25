import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/quran_db_service.dart';
import '../widgets/ayah_action_sheet.dart';
import 'quran_surah_detail_screen.dart';

class QuranMushafScreen extends StatefulWidget {
  final int initialPage;
  final int? highlightSurahId;
  final int? highlightAyahNumber;

  const QuranMushafScreen({
    super.key,
    required this.initialPage,
    this.highlightSurahId,
    this.highlightAyahNumber,
  });

  @override
  State<QuranMushafScreen> createState() => _QuranMushafScreenState();
}

class _QuranMushafScreenState extends State<QuranMushafScreen> {
  static const int totalPages = 604;
  late PageController _pageController;
  late int _currentPage;
  bool _nightMode = false;
  bool _showControls = true;

  // Data halaman aktif untuk AppBar
  Map<String, dynamic> _currentPageMeta = {};
  int? _selectedSurahId;
  int? _selectedAyahNumber;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, totalPages);
    _selectedSurahId = widget.highlightSurahId;
    _selectedAyahNumber = widget.highlightAyahNumber;
    _pageController = PageController(initialPage: _currentPage - 1);
    _loadPrefsAndMeta(_currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefsAndMeta(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_mushaf_page', page);
    final night = prefs.getBool('mushaf_night_mode') ?? false;
    final meta = await QuranDbService.getPageData(page);
    if (mounted) {
      setState(() {
        _nightMode = night;
        _currentPageMeta = meta;
      });
    }
    // Preload halaman sekitar secara senyap agar geser halaman mulus
    for (final adj in [page - 1, page + 1]) {
      if (adj >= 1 && adj <= totalPages) {
        QuranDbService.ensureMushafPage(adj).catchError((_) => '');
      }
    }
  }

  Future<void> _toggleNightMode() async {
    final next = !_nightMode;
    setState(() => _nightMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mushaf_night_mode', next);
  }

  void _showJumpToPageDialog() {
    final ctrl = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lompat ke Halaman (1 - 604)', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nomor Halaman Mushaf Madani',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
            onPressed: () {
              final target = int.tryParse(ctrl.text.trim());
              if (target != null && target >= 1 && target <= totalPages) {
                Navigator.pop(ctx);
                _pageController.jumpToPage(target - 1);
              }
            },
            child: const Text('Buka'),
          ),
        ],
      ),
    );
  }

  void _switchToListMode() {
    final surahId = (_currentPageMeta['surah_id'] as int?) ?? 1;
    final surahName = (_currentPageMeta['surah_name_simple'] ?? 'Al-Fatihah').toString();
    final surahArabic = (_currentPageMeta['surah_name_arabic'] ?? '').toString();
    final surahIndo = (_currentPageMeta['surah_name_indo'] ?? '').toString();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuranSurahDetailScreen(
          chapterId: surahId,
          surahName: surahName,
          arabicName: surahArabic,
          indoName: surahIndo,
          initialAyah: _selectedSurahId == surahId ? _selectedAyahNumber : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surahName = (_currentPageMeta['surah_name_simple'] ?? '').toString();
    final juz = _currentPageMeta['juz'] ?? '';
    final bgColor = _nightMode ? const Color(0xFF121212) : const Color(0xFFFAF6EB);
    final textColor = _nightMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _showControls
          ? AppBar(
              backgroundColor: _nightMode ? const Color(0xFF1E1E1E) : Colors.white,
              foregroundColor: textColor,
              elevation: 0.5,
              title: InkWell(
                onTap: _showJumpToPageDialog,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surahName.isNotEmpty ? 'QS. $surahName' : 'Mushaf Madani',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Juz $juz • Halaman $_currentPage / $totalPages (Ketuk lompat)',
                      style: TextStyle(fontSize: 11, color: _nightMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(_nightMode ? LucideIcons.sun : LucideIcons.moon, size: 19),
                  tooltip: _nightMode ? 'Mode Terang' : 'Mode Malam',
                  onPressed: _toggleNightMode,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.list, size: 19),
                  tooltip: 'Buka Mode Daftar & Terjemah',
                  onPressed: _switchToListMode,
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          reverse: true, // RTL seperti Mushaf asli (Halaman 1 di kanan, geser ke kiri ke halaman 2)
          itemCount: totalPages,
          onPageChanged: (index) {
            final newPage = index + 1;
            setState(() {
              _currentPage = newPage;
              _selectedSurahId = null;
              _selectedAyahNumber = null;
            });
            _loadPrefsAndMeta(newPage);
          },
          itemBuilder: (context, index) {
            final pageNum = index + 1;
            return _MushafPageView(
              pageNumber: pageNum,
              nightMode: _nightMode,
              selectedSurahId: _currentPage == pageNum ? _selectedSurahId : null,
              selectedAyahNumber: _currentPage == pageNum ? _selectedAyahNumber : null,
              onToggleControls: () => setState(() => _showControls = !_showControls),
              onAyahSelected: (surahId, ayahNum) {
                setState(() {
                  _selectedSurahId = surahId;
                  _selectedAyahNumber = ayahNum;
                });
              },
            );
          },
        ),
      ),
    );
  }
}

class _MushafPageView extends StatefulWidget {
  final int pageNumber;
  final bool nightMode;
  final int? selectedSurahId;
  final int? selectedAyahNumber;
  final VoidCallback onToggleControls;
  final void Function(int surahId, int ayahNumber) onAyahSelected;

  const _MushafPageView({
    required this.pageNumber,
    required this.nightMode,
    required this.selectedSurahId,
    required this.selectedAyahNumber,
    required this.onToggleControls,
    required this.onAyahSelected,
  });

  @override
  State<_MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<_MushafPageView> {
  static const double imgWidth = 1260.0;
  static const double imgHeight = 2038.0;

  String? _localImagePath;
  String? _errorMsg;
  List<Map<String, dynamic>> _bounds = [];

  // Color matrix untuk membalik warna (Night Mode persis quran_android)
  static const ColorFilter _nightColorFilter = ColorFilter.matrix(<double>[
    -1, 0, 0, 0, 255,
    0, -1, 0, 0, 255,
    0, 0, -1, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    try {
      final results = await Future.wait([
        QuranDbService.ensureMushafPage(widget.pageNumber),
        QuranDbService.getPageData(widget.pageNumber),
      ]);
      if (mounted) {
        final path = results[0] as String;
        final pageData = results[1] as Map<String, dynamic>;
        final rawBounds = (pageData['bounds'] as List?) ?? [];
        setState(() {
          _localImagePath = path;
          _bounds = rawBounds.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _errorMsg = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Halaman belum terunduh.\nPeriksa internet untuk mengunduh halaman ${widget.pageNumber}.\n($e)');
      }
    }
  }

  void _handleTap(Offset localPosition, Rect renderedRect) async {
    if (!renderedRect.contains(localPosition)) {
      widget.onToggleControls();
      return;
    }

    // Konversi koordinat tap layar ke koordinat asli 1260 x 2038 gambar Madani
    final scaleX = imgWidth / renderedRect.width;
    final scaleY = imgHeight / renderedRect.height;
    final imgX = (localPosition.dx - renderedRect.left) * scaleX;
    final imgY = (localPosition.dy - renderedRect.top) * scaleY;

    Map<String, dynamic>? hit;
    for (final b in _bounds) {
      final minX = (b['min_x'] as int).toDouble();
      final maxX = (b['max_x'] as int).toDouble();
      final minY = (b['min_y'] as int).toDouble();
      final maxY = (b['max_y'] as int).toDouble();
      // Tambah toleransi tap 16px di gambar asli agar jari mudah mengetuk ayat
      if (imgX >= minX - 16 && imgX <= maxX + 16 && imgY >= minY - 16 && imgY <= maxY + 16) {
        hit = b;
        break;
      }
    }

    if (hit == null) {
      widget.onToggleControls();
      return;
    }

    final surahId = hit['surah_id'] as int;
    final ayahNum = hit['ayah_number'] as int;
    widget.onAyahSelected(surahId, ayahNum);

    final verse = await QuranDbService.getVerseDetail(surahId, ayahNum);
    if (!mounted || verse == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AyahActionSheet(
        surahId: surahId,
        ayahNumber: ayahNum,
        pageNumber: widget.pageNumber,
        surahName: (verse['surah_name_simple'] ?? '').toString(),
        surahArabic: (verse['surah_name_arabic'] ?? '').toString(),
        textUthmani: (verse['text_uthmani'] ?? '').toString(),
        translationId: (verse['translation_id'] ?? '').toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.wifiOff, size: 42, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                style: TextStyle(color: widget.nightMode ? Colors.white70 : Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Coba Unduh Lagi'),
                onPressed: () {
                  setState(() => _errorMsg = null);
                  _loadPage();
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_localImagePath == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF0D7377)),
            const SizedBox(height: 12),
            Text(
              'Memuat Halaman ${widget.pageNumber}...',
              style: TextStyle(fontSize: 12, color: widget.nightMode ? Colors.white70 : Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;
        final imgAspect = imgWidth / imgHeight;
        final boxAspect = boxW / boxH;

        late final Rect renderedRect;
        if (boxAspect > imgAspect) {
          final h = boxH;
          final w = h * imgAspect;
          final dx = (boxW - w) / 2;
          renderedRect = Rect.fromLTWH(dx, 0, w, h);
        } else {
          final w = boxW;
          final h = w / imgAspect;
          final dy = (boxH - h) / 2;
          renderedRect = Rect.fromLTWH(0, dy, w, h);
        }

        Widget imgWidget = Image.file(
          File(_localImagePath!),
          width: renderedRect.width,
          height: renderedRect.height,
          fit: BoxFit.fill,
        );

        if (widget.nightMode) {
          imgWidget = ColorFiltered(colorFilter: _nightColorFilter, child: imgWidget);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details.localPosition, renderedRect),
          child: Stack(
            children: [
              Positioned.fromRect(rect: renderedRect, child: imgWidget),
              if (widget.selectedSurahId != null && widget.selectedAyahNumber != null)
                Positioned.fromRect(
                  rect: renderedRect,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _AyahHighlightPainter(
                        bounds: _bounds,
                        selectedSurahId: widget.selectedSurahId!,
                        selectedAyahNumber: widget.selectedAyahNumber!,
                        imgWidth: imgWidth,
                        imgHeight: imgHeight,
                        nightMode: widget.nightMode,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AyahHighlightPainter extends CustomPainter {
  final List<Map<String, dynamic>> bounds;
  final int selectedSurahId;
  final int selectedAyahNumber;
  final double imgWidth;
  final double imgHeight;
  final bool nightMode;

  _AyahHighlightPainter({
    required this.bounds,
    required this.selectedSurahId,
    required this.selectedAyahNumber,
    required this.imgWidth,
    required this.imgHeight,
    required this.nightMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imgWidth;
    final scaleY = size.height / imgHeight;

    final paint = Paint()
      ..color = nightMode
          ? const Color(0xFFD4A843).withValues(alpha: 0.35)
          : const Color(0xFF0D7377).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    for (final b in bounds) {
      if (b['surah_id'] == selectedSurahId && b['ayah_number'] == selectedAyahNumber) {
        final rect = Rect.fromLTRB(
          (b['min_x'] as int) * scaleX,
          (b['min_y'] as int) * scaleY,
          (b['max_x'] as int) * scaleX,
          (b['max_y'] as int) * scaleY,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AyahHighlightPainter oldDelegate) {
    return oldDelegate.selectedSurahId != selectedSurahId ||
        oldDelegate.selectedAyahNumber != selectedAyahNumber ||
        oldDelegate.nightMode != nightMode;
  }
}
