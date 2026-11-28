import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/home_action_button.dart';

class PdfReaderScreen extends StatefulWidget {
  final String filePath;
  final String title;
  final int initialPage;

  const PdfReaderScreen({
    super.key,
    required this.filePath,
    required this.title,
    this.initialPage = 1,
  });

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late PdfControllerPinch _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage < 1 ? 1 : widget.initialPage;
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
      initialPage: _currentPage,
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _saveProgress(int page, int total) async {
    if (total <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('pustaka_pdf_progress');
    final Map<String, dynamic> map = raw != null ? Map<String, dynamic>.from(jsonDecode(raw)) : {};
    map[widget.filePath] = {
      'lastPage': page,
      'totalPages': total,
      'percent': ((page / total) * 100).round().clamp(0, 100),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString('pustaka_pdf_progress', jsonEncode(map));
  }

  void _showJumpToPage() {
    final ctrl = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lompat ke Halaman (1 - $_totalPages)', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Nomor Halaman'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
            onPressed: () {
              final target = int.tryParse(ctrl.text.trim());
              if (target != null && target >= 1 && (_totalPages == 0 || target <= _totalPages)) {
                Navigator.pop(ctx);
                _pdfController.jumpToPage(target);
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
    final pct = _totalPages > 0 ? ((_currentPage / _totalPages) * 100).round().clamp(0, 100) : 0;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(
              _totalPages > 0 ? 'Hal. $_currentPage / $_totalPages ($pct%)' : 'Memuat PDF...',
              style: const TextStyle(fontSize: 11, color: Color(0xFF0D7377), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.hash, size: 19),
            tooltip: 'Lompat ke Halaman',
            onPressed: _totalPages > 0 ? _showJumpToPage : null,
          ),
          const HomeActionButton(),
        ],
      ),
      body: Column(
        children: [
          if (_totalPages > 0)
            LinearProgressIndicator(
              value: (_currentPage / _totalPages).clamp(0.0, 1.0),
              minHeight: 3.5,
              color: const Color(0xFF0D7377),
              backgroundColor: Colors.grey[200],
            ),
          Expanded(
            child: PdfViewPinch(
              controller: _pdfController,
              onDocumentLoaded: (doc) {
                if (mounted) {
                  setState(() => _totalPages = doc.pagesCount);
                  _saveProgress(_currentPage, doc.pagesCount);
                }
              },
              onPageChanged: (page) {
                if (mounted) {
                  setState(() => _currentPage = page);
                  _saveProgress(page, _totalPages);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
