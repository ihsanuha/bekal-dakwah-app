import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class HadithCategoriesScreen extends StatefulWidget {
  const HadithCategoriesScreen({super.key});

  @override
  State<HadithCategoriesScreen> createState() => _HadithCategoriesScreenState();
}

class _HadithCategoriesScreenState extends State<HadithCategoriesScreen> {
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() async {
    final list = await ApiService.getHadithCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ensiklopedia Hadits & Takhrij', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFD4A843).withOpacity(0.15),
                      child: const Icon(Icons.menu_book, color: Color(0xFFD4A843)),
                    ),
                    title: Text(cat['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${cat['hadeeths_count']} Hadits Terverifikasi', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HadithListScreen(categoryId: int.parse(cat['id']), categoryTitle: cat['title']),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class HadithListScreen extends StatefulWidget {
  final int categoryId;
  final String categoryTitle;

  const HadithListScreen({super.key, required this.categoryId, required this.categoryTitle});

  @override
  State<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<HadithListScreen> {
  List<dynamic> _hadiths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHadiths();
  }

  void _loadHadiths() async {
    final list = await ApiService.getHadithList(widget.categoryId);
    if (mounted) {
      setState(() {
        _hadiths = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _hadiths.length,
              separatorBuilder: (ctx, i) => const Divider(),
              itemBuilder: (context, index) {
                final item = _hadiths[index];
                return ListTile(
                  title: Text(
                    item['title'] ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HadithDetailScreen(hadithId: int.parse(item['id'])),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class HadithDetailScreen extends StatefulWidget {
  final int hadithId;
  const HadithDetailScreen({super.key, required this.hadithId});

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  void _loadDetail() async {
    final res = await ApiService.getHadithDetail(widget.hadithId);
    if (mounted) {
      setState(() {
        _detail = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail & Takhrij Hadits', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : _detail == null
              ? const Center(child: Text('Hadits tidak ditemukan'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Badge Derajat / Takhrij
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Text(
                          'Derajat Hadits: ${_detail!['grade'] ?? 'Shahih'} • ${_detail!['attribution'] ?? ''}',
                          style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Matan Arab
                      Text(
                        _detail!['hadeeth_ar'] ?? '',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.amiri(fontSize: 22, height: 2.2, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),

                      // Terjemahan & Sanad
                      Text(
                        _detail!['hadeeth'] ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),

                      // Penjelasan / Syarah Singkat
                      if (_detail!['explanation'] != null) ...[
                        const Divider(),
                        Text(
                          'Penjelasan & Faedah Hadits:',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0D7377)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _detail!['explanation'],
                          style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey[800]),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
