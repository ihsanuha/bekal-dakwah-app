import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

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
          'fileName': null,
        },
        {
          'id': '2',
          'title': 'Kajian Kitab Tauhid: Bab Takut Kepada Syirik',
          'category': 'Kajian Rutin',
          'date': '18 Nov 2026',
          'content': 'Penjelasan matan Kitab At-Tauhid karya Syaikh Muhammad bin Abdul Wahhab rahimahullah.\n\nDalil firman Allah Ta\'ala:\nإِنَّ اللَّهَ لَا يَغْفِرُ أَن يُشْرَكَ بِهِ وَيَغْفِرُ مَا دُونَ ذَٰلِكَ لِمَن يَشَاءُ\n(QS. An-Nisa: 48)',
          'fileName': null,
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

  void _pickAndUploadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _showAddDialog(
          initialTitle: file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
          fileName: file.name,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih file: $e')));
    }
  }

  void _showAddDialog({String? initialTitle, String? fileName}) {
    final titleCtrl = TextEditingController(text: initialTitle);
    final categoryCtrl = TextEditingController(text: 'Materi Kajian');
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(fileName != null ? 'Upload Berkas Materi' : 'Tambah Materi Baru', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fileName != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.fileText, color: Color(0xFF0D7377), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(fileName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Judul Materi / Tema', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Kategori (Khutbah / Kajian / Dauroh)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Ringkasan / Teks Dalil Utama', border: OutlineInputBorder()),
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
                _materials.insert(0, {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'title': titleCtrl.text.trim(),
                  'category': categoryCtrl.text.trim(),
                  'date': 'Hari ini',
                  'content': contentCtrl.text.trim(),
                  'fileName': fileName,
                });
              });
              _saveToPrefs();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Materi berhasil ditambahkan ke database')));
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
            icon: const Icon(LucideIcons.uploadCloud),
            tooltip: 'Upload File Materi (PDF/DOC)',
            onPressed: _pickAndUploadDocument,
          ),
          IconButton(
            icon: const Icon(LucideIcons.plusCircle),
            tooltip: 'Tulis Materi Baru',
            onPressed: () => _showAddDialog(),
          ),
        ],
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
                        icon: const Icon(LucideIcons.uploadCloud, size: 18),
                        label: const Text('Upload Berkas Materi'),
                        onPressed: _pickAndUploadDocument,
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
                          child: Icon(
                            item['fileName'] != null ? LucideIcons.fileText : LucideIcons.bookOpen,
                            color: const Color(0xFF0D7377),
                            size: 20,
                          ),
                        ),
                        title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('${item['category']} • ${item['date']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                            if (item['fileName'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text('Lampiran: ${item['fileName']}', style: const TextStyle(fontSize: 11, color: Colors.teal)),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                          onPressed: () => _deleteMaterial(item['id']),
                        ),
                        onTap: () {
                          // Buka kembali materi kajian
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
              Chip(
                label: Text(item['category'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF0D7377))),
                backgroundColor: const Color(0xFF0D7377).withOpacity(0.08),
                side: BorderSide.none,
              ),
              const SizedBox(height: 12),
              Text(
                item['content'] != null && item['content'].toString().isNotEmpty
                    ? item['content']
                    : '(Berkas dokumen terlampir: ${item['fileName']})',
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
