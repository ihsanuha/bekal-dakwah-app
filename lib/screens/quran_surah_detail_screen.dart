import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class QuranSurahDetailScreen extends StatefulWidget {
  final int chapterId;
  final String surahName;
  final String arabicName;

  const QuranSurahDetailScreen({
    super.key,
    required this.chapterId,
    required this.surahName,
    required this.arabicName,
  });

  @override
  State<QuranSurahDetailScreen> createState() => _QuranSurahDetailScreenState();
}

class _QuranSurahDetailScreenState extends State<QuranSurahDetailScreen> {
  List<dynamic> _verses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVerses();
  }

  void _loadVerses() async {
    final list = await ApiService.getSurahVerses(widget.chapterId);
    if (mounted) {
      setState(() {
        _verses = list;
        _isLoading = false;
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
            Text(widget.surahName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.arabicName, style: GoogleFonts.amiri(fontSize: 14, color: const Color(0xFF0D7377))),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _verses.length,
              separatorBuilder: (ctx, i) => const Divider(height: 32),
              itemBuilder: (ctx, i) {
                final verse = _verses[i];
                final verseNumber = verse['verse_number'];
                final textUthmani = verse['text_uthmani'] ?? '';
                final translations = verse['translations'] as List?;
                final translationText = translations != null && translations.isNotEmpty
                    ? translations[0]['text']
                    : '';

                // Hapus tag HTML seperti <sup ...> jika ada
                final cleanTranslation = translationText.replaceAll(RegExp(r'<[^>]*>'), '');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF0D7377).withOpacity(0.1),
                          child: Text(
                            '$verseNumber',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D7377)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ayat $verseNumber tersalin')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      textUthmani,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.amiri(
                        fontSize: 24,
                        height: 2.2,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cleanTranslation,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
