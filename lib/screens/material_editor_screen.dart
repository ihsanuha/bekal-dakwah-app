import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

class MaterialEditorScreen extends StatefulWidget {
  final String? targetDirectory;
  final String? existingFilePath;
  final String? initialTitle;
  final String? initialContent;

  const MaterialEditorScreen({
    super.key,
    this.targetDirectory,
    this.existingFilePath,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<MaterialEditorScreen> createState() => _MaterialEditorScreenState();
}

class _MaterialEditorScreenState extends State<MaterialEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    String defaultTitle = widget.initialTitle ?? '';
    if (defaultTitle.isEmpty && widget.existingFilePath != null) {
      defaultTitle = p.basenameWithoutExtension(widget.existingFilePath!);
    }
    if (defaultTitle.isEmpty) {
      defaultTitle = 'Catatan Kajian Baru';
    }

    _titleCtrl = TextEditingController(text: defaultTitle);
    _contentCtrl = TextEditingController(text: widget.initialContent ?? '');

    if (widget.existingFilePath != null && widget.initialContent == null) {
      _loadFromFile();
    }
  }

  Future<void> _loadFromFile() async {
    try {
      final file = File(widget.existingFilePath!);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (mounted) {
          setState(() => _contentCtrl.text = content);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  String _sanitizeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'materi_${DateTime.now().millisecondsSinceEpoch}' : cleaned;
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);
    try {
      final safeTitle = _sanitizeFileName(_titleCtrl.text);
      String targetPath;
      if (widget.existingFilePath != null) {
        final parentDir = p.dirname(widget.existingFilePath!);
        final ext = p.extension(widget.existingFilePath!).isNotEmpty
            ? p.extension(widget.existingFilePath!)
            : '.txt';
        targetPath = p.join(parentDir, '$safeTitle$ext');
        if (targetPath != widget.existingFilePath) {
          final oldFile = File(widget.existingFilePath!);
          if (await oldFile.exists()) {
            await oldFile.rename(targetPath);
          }
        }
      } else if (widget.targetDirectory != null) {
        targetPath = p.join(widget.targetDirectory!, '$safeTitle.txt');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Materi siap disalin (tidak ada folder tujuan)')),
          );
        }
        setState(() => _saving = false);
        return;
      }

      await File(targetPath).writeAsString(_contentCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tersimpan: ${p.basename(targetPath)}')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _insertTemplateKhutbah() {
    const template = '''إِنَّ الْحَمْدَ لِلَّهِ نَحْمَدُهُ وَنَسْتَعِينُهُ وَنَسْتَغْفِرُهُ...

Ikhwatal Iman rahimakumullah,
Marilah kita senantiasa meningkatkan ketakwaan kepada Allah Ta'ala dengan sebenar-benar takwa.

Poin Pembahasan:
1. 
2. 
3. ''';
    _contentCtrl.text = '${_contentCtrl.text}\n$template'.trimLeft();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editor Materi', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Salin Teks',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '${_titleCtrl.text}\n\n${_contentCtrl.text}'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks materi disalin')));
            },
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded),
            tooltip: 'Simpan ke Folder',
            onPressed: _saving ? null : _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Nama File / Judul Materi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Template Khutbah'),
                  onPressed: _insertTemplateKhutbah,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 14, height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'Tuliskan draf materi kajian, khutbah, atau kultum di sini...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
