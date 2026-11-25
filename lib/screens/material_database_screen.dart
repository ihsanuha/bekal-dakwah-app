import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MaterialDatabaseScreen extends StatefulWidget {
  const MaterialDatabaseScreen({super.key});

  @override
  State<MaterialDatabaseScreen> createState() => _MaterialDatabaseScreenState();
}

class _MaterialDatabaseScreenState extends State<MaterialDatabaseScreen> {
  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedMaterials();
  }

  void _loadSavedMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_dakwah_materials');
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() {
        _materials = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } else {
      // Default seed materi awal
      _materials = [
        {
          'id': '1',
          'title': 'Khutbah Jum\'at: Hakikat Ikhlas dan Bahaya Riya\'',
          'category': 'Khutbah',
          'date': '21 Nov 2026',
          'content': 'Ikhwatal Iman rahimakumullah,\nMarilah kita senantiasa meningkatkan ketakwaan kepada Allah Ta\'ala...\n\nDalil:\nوَمَا أُمِرُوا إِلَّا لِيَعْبُدُوا اللَّهَ مُخْلِصِينَ لَهُ الدِّينَ\n"Padahal mereka tidak disuruh kecuali supaya menyembah Allah dengan memurnikan ketaatan..." (QS. Al-Bayyinah: 5)',
          'sourceName': 'Buku Panduan Khutbah',
        },
        {
          'id': '2',
          'title': 'Kajian Kitab Tauhid: Bab Takut Kepada Syirik',
          'category': 'Kajian Rutin',
          'date': '18 Nov 2026',
          'content': 'Penjelasan matan Kitab At-Tauhid karya Syaikh Muhammad bin Abdul Wahhab rahimahullah.\n\nDalil firman Allah Ta\'ala:\nإِنَّ اللَّهَ لَا يَغْفِرُ أَن يُشْرَكَ بِهِ وَيَغْفِرُ مَا دُونَ ذَٰلِكَ لِمَن يَشَاءُ\n(QS. An-Nisa: 48)',
          'sourceName': 'Syarah Kitab Tauhid',
        }
      ];
      _saveToPrefs();
      setState(() => _isLoading = false);
    }
  }

  void _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_dakwah_materials', jsonEncode(_materials));
  }

  void _showAddDialog({Map<String, dynamic>? existingMaterial, int? index}) {
    final titleCtrl = TextEditingController(text: existingMaterial?['title']);
    final categoryCtrl = TextEditingController(text: existingMaterial?['category'] ?? 'Materi Kajian');
    final sourceCtrl = TextEditingController(text: existingMaterial?['sourceName'] ?? 'Catatan / Kitab Rujukan');
    final contentCtrl = TextEditingController(text: existingMaterial?['content']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existingMaterial == null ? 'Tambah Materi Kajian' : 'Edit Materi Kajian',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Judul Materi / Tema Kajian', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Kategori (Khutbah / Kajian Rutin / Dauroh)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sourceCtrl,
                decoration: const InputDecoration(labelText: 'Sumber / Kitab Rujukan', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Isi Materi, Dalil, & Poin Kajian',
                  hintText: 'Tempelkan atau ketikkan materi dakwah yang akan dikaji...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              setState(() {
                if (existingMaterial == null) {
                  _materials.insert(0, {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'title': titleCtrl.text.trim(),
                    'category': categoryCtrl.text.trim(),
                    'sourceName': sourceCtrl.text.trim(),
                    'date': 'Hari ini',
                    'content': contentCtrl.text.trim(),
                  });
                } else if (index != null) {
                  _materials[index] = {
                    'id': existingMaterial['id'],
                    'title': titleCtrl.text.trim(),
                    'category': categoryCtrl.text.trim(),
                    'sourceName': sourceCtrl.text.trim(),
                    'date': existingMaterial['date'] ?? 'Hari ini',
                    'content': contentCtrl.text.trim(),
                  };
                }
              });
              _saveToPrefs();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(existingMaterial == null ? 'Materi berhasil disimpan' : 'Materi berhasil diperbarui')),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _deleteMaterial(String id) {
    setState(() {
      _materials.removeWhere((m) => m['id'] == id);
    });
    _saveToPrefs();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Materi dihapus')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Database Materi Kajian', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plusCircle),
            tooltip: 'Tambah / Simpan Materi Baru',
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D7377),
        foregroundColor: Colors.white,
        onPressed: () => _showAddDialog(),
        icon: const Icon(LucideIcons.filePlus),
        label: const Text('Input Materi Baru'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : _materials.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.folderOpen, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Belum ada materi kajian tersimpan', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
                        icon: const Icon(LucideIcons.plusCircle, size: 18),
                        label: const Text('Tambah Materi Baru'),
                        onPressed: () => _showAddDialog(),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _materials.length,
                  itemBuilder: (context, index) {
                    final item = _materials[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF0D7377).withOpacity(0.12),
                          child: const Icon(LucideIcons.bookOpen, color: Color(0xFF0D7377), size: 20),
                        ),
                        title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('${item['category']} • ${item['date']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                            if (item['sourceName'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text('Rujukan: ${item['sourceName']}', style: const TextStyle(fontSize: 11, color: Colors.teal)),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          icon: const Icon(LucideIcons.moreVertical, size: 18),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(LucideIcons.pencil, size: 16), SizedBox(width: 8), Text('Edit')])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 16, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                          ],
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showAddDialog(existingMaterial: item, index: index);
                            } else if (val == 'delete') {
                              _deleteMaterial(item['id']);
                            }
                          },
                        ),
                        onTap: () {
                          _showViewMaterialDialog(item);
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showViewMaterialDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['title'] ?? '', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(item['category'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF0D7377))),
                    backgroundColor: const Color(0xFF0D7377).withOpacity(0.08),
                    side: BorderSide.none,
                  ),
                  const SizedBox(width: 8),
                  if (item['sourceName'] != null)
                    Expanded(
                      child: Text(
                        'Rujukan: ${item['sourceName']}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),
              SelectableText(
                item['content'] ?? '',
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }
}
