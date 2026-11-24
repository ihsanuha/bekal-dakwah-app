import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_service.dart';

class FatwaListScreen extends StatefulWidget {
  const FatwaListScreen({super.key});

  @override
  State<FatwaListScreen> createState() => _FatwaListScreenState();
}

class _FatwaListScreenState extends State<FatwaListScreen> {
  List<dynamic> _fatwas = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'Semua';

  final List<String> _categories = [
    'Semua',
    'Shalat',
    'Aqidah',
    'Muamalah',
    'Adab',
    'Sosial',
  ];

  @override
  void initState() {
    super.initState();
    _loadFatwas();
  }

  void _loadFatwas({String? query, String? category}) async {
    setState(() => _isLoading = true);
    final cat = (category ?? _selectedCategory) == 'Semua' ? null : (category ?? _selectedCategory);
    final list = await ApiService.getFatwaList(query: query);
    if (mounted) {
      setState(() {
        if (cat != null) {
          _fatwas = list.where((f) => (f['category'] ?? '').toString().toLowerCase().contains(cat.toLowerCase())).toList();
        } else {
          _fatwas = list;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Database Fatwa Ulama', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari fatwa: shalat, musik, jimat, bank...',
                prefixIcon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF0D7377)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadFatwas();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (val) => _loadFatwas(query: val),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D7377),
                    backgroundColor: Colors.grey[100],
                    showCheckmark: false,
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                      _loadFatwas(query: _searchCtrl.text, category: cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
                : _fatwas.isEmpty
                    ? const Center(child: Text('Fatwa tidak ditemukan'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _fatwas.length,
                        itemBuilder: (context, index) {
                          final item = _fatwas[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF0D7377),
                                child: Icon(LucideIcons.scale, color: Colors.white, size: 18),
                              ),
                              title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('${item['scholar']} • ${item['category']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text('Pertanyaan:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[900])),
                                      const SizedBox(height: 4),
                                      Text(item['question'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
                                      const SizedBox(height: 12),
                                      Text('Jawaban & Dalil:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900])),
                                      const SizedBox(height: 4),
                                      Text(item['answer'] ?? '', style: const TextStyle(fontSize: 13, height: 1.5)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.bookOpen, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text('Rujukan: ${item['source']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
