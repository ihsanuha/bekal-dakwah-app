import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
                      child: const Icon(LucideIcons.bookMarked, color: Color(0xFFD4A843), size: 20),
                    ),
                    title: Text(cat['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${cat['hadeeths_count']} Hadits Terverifikasi', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
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
  List<dynamic> _filteredHadiths = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _lastPage = 1;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialHadiths();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _lastPage && _searchCtrl.text.isEmpty) {
        _loadMoreHadiths();
      }
    }
  }

  void _loadInitialHadiths() async {
    final result = await ApiService.getHadithListPaginated(widget.categoryId, page: 1, perPage: 30);
    if (mounted) {
      setState(() {
        _hadiths = result['data'] ?? [];
        _filteredHadiths = _hadiths;
        _lastPage = int.tryParse(result['meta']?['last_page']?.toString() ?? '1') ?? 1;
        _isLoading = false;
      });
    }
  }

  void _loadMoreHadiths() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;
    final result = await ApiService.getHadithListPaginated(widget.categoryId, page: nextPage, perPage: 30);
    if (mounted) {
      final newItems = result['data'] as List? ?? [];
      setState(() {
        _currentPage = nextPage;
        _hadiths.addAll(newItems);
        _filteredHadiths = _hadiths;
        _isLoadingMore = false;
      });
    }
  }

  void _filterHadiths(String q) {
    if (q.trim().isEmpty) {
      setState(() => _filteredHadiths = _hadiths);
      return;
    }
    final query = q.toLowerCase();
    setState(() {
      _filteredHadiths = _hadiths.where((h) {
        final title = (h['title'] ?? '').toString().toLowerCase();
        return title.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari matan / kata kunci hadits...',
                prefixIcon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF0D7377)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filterHadiths('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _filterHadiths,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
                : _filteredHadiths.isEmpty
                    ? const Center(child: Text('Hadits tidak ditemukan'))
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredHadiths.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (ctx, i) => const Divider(),
                        itemBuilder: (context, index) {
                          if (index == _filteredHadiths.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D7377)),
                                ),
                              ),
                            );
                          }
                          final item = _filteredHadiths[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF0D7377).withOpacity(0.1),
                              child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
                            ),
                            title: Text(
                              item['title'] ?? '',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            trailing: const Icon(LucideIcons.chevronRight, size: 18),
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
          ),
        ],
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Derajat Hadits: ${_detail!['grade'] ?? 'Shahih'} • ${_detail!['attribution'] ?? ''}',
                                style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Matan Arab
                      Text(
                        _detail!['hadeeth_ar'] ?? '',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.amiri(fontSize: 23, height: 2.2, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 18),

                      // Terjemahan & Sanad
                      Text(
                        _detail!['hadeeth'] ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),

                      // Penjelasan / Syarah Singkat
                      if (_detail!['explanation'] != null) ...[
                        const Divider(),
                        Row(
                          children: [
                            const Icon(LucideIcons.sparkles, color: Color(0xFF0D7377), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Penjelasan & Faedah Hadits:',
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0D7377)),
                            ),
                          ],
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
