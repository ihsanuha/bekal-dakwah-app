import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/home_action_button.dart';
import 'pdf_reader_screen.dart';

class PustakaIlmuScreen extends StatefulWidget {
  const PustakaIlmuScreen({super.key});

  @override
  State<PustakaIlmuScreen> createState() => _PustakaIlmuScreenState();
}

class _PustakaIlmuScreenState extends State<PustakaIlmuScreen> {
  Directory? _rootDir;
  Directory? _currentDir;
  List<FileSystemEntity> _entities = [];
  Map<String, Map<String, dynamic>> _progressMap = {};
  bool _loading = true;
  String _searchQuery = '';
  bool _searchAll = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initExplorer();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initExplorer() async {
    final appDir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(appDir.path, 'pustaka_ilmu'));
    if (!await root.exists()) {
      await root.create(recursive: true);
      for (final cat in ['Aqidah', 'Fiqih', 'Tafsir', 'Hadits', 'Umum']) {
        await Directory(p.join(root.path, cat)).create(recursive: true);
      }
    }
    _rootDir = root;
    _currentDir = root;
    await _refreshDirectory();
  }

  Future<void> _loadProgressMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('pustaka_pdf_progress');
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _progressMap = decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
    } else {
      _progressMap = {};
    }
  }

  Future<void> _refreshDirectory() async {
    if (_currentDir == null || _rootDir == null) return;
    setState(() => _loading = true);
    await _loadProgressMap();

    List<FileSystemEntity> list = _searchQuery.isNotEmpty && _searchAll
        ? _rootDir!.listSync(recursive: true, followLinks: false)
        : _currentDir!.listSync(followLinks: false);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) => p.basename(e.path).toLowerCase().contains(q)).toList();
    }

    list.sort((a, b) {
      final aDir = a is Directory;
      final bDir = b is Directory;
      if (aDir && !bDir) return -1;
      if (!aDir && bDir) return 1;
      return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
    });

    if (mounted) {
      setState(() {
        _entities = list;
        _loading = false;
      });
    }
  }

  List<Directory> _getBreadcrumbs() {
    if (_rootDir == null || _currentDir == null) return [];
    final crumbs = <Directory>[];
    Directory cursor = _currentDir!;
    while (true) {
      crumbs.insert(0, cursor);
      if (p.equals(cursor.path, _rootDir!.path)) break;
      final parent = cursor.parent;
      if (p.equals(parent.path, cursor.path)) break;
      cursor = parent;
    }
    return crumbs;
  }

  Future<void> _createCategoryFolder() async {
    if (_currentDir == null) return;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategori / Folder Baru'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Misal: Ushul Fiqih / Sirah'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Buat')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final newDir = Directory(p.join(_currentDir!.path, safeName));
    if (!await newDir.exists()) await newDir.create(recursive: true);
    await _refreshDirectory();
  }

  Future<void> _uploadPdfs() async {
    if (_currentDir == null) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    int count = 0;
    for (final picked in result.files) {
      if (picked.path == null) continue;
      final src = File(picked.path!);
      if (!await src.exists()) continue;

      String destPath = p.join(_currentDir!.path, picked.name);
      if (await File(destPath).exists()) {
        final base = p.basenameWithoutExtension(picked.name);
        final ext = p.extension(picked.name);
        destPath = p.join(_currentDir!.path, '${base}_${DateTime.now().millisecondsSinceEpoch}$ext');
      }
      await src.copy(destPath);
      count++;
    }
    await _refreshDirectory();
    if (mounted && count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count file PDF berhasil ditambahkan ke Pustaka Ilmu')),
      );
    }
  }

  Future<void> _openEntity(FileSystemEntity entity) async {
    if (entity is Directory) {
      _currentDir = entity;
      _searchCtrl.clear();
      _searchQuery = '';
      await _refreshDirectory();
      return;
    }

    final prog = _progressMap[entity.path];
    final lastPage = (prog?['lastPage'] as int?) ?? 1;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfReaderScreen(
          filePath: entity.path,
          title: p.basenameWithoutExtension(entity.path),
          initialPage: lastPage,
        ),
      ),
    );
    await _refreshDirectory();
  }

  Future<void> _renameEntity(FileSystemEntity entity) async {
    final oldName = p.basename(entity.path);
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Nama'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    final safeName = newName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final newPath = p.join(p.dirname(entity.path), safeName);
    await entity.rename(newPath);
    await _refreshDirectory();
  }

  Future<void> _moveEntity(FileSystemEntity entity) async {
    if (_rootDir == null) return;
    final folders = <Directory>[_rootDir!];
    for (final e in _rootDir!.listSync(recursive: true, followLinks: false)) {
      if (e is Directory) {
        if (entity is Directory && (p.equals(e.path, entity.path) || p.isWithin(entity.path, e.path))) continue;
        folders.add(e);
      }
    }

    final targetDir = await showModalBottomSheet<Directory>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('Pindahkan ke Kategori / Folder', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: folders.length,
              itemBuilder: (_, i) {
                final dir = folders[i];
                final rel = p.equals(dir.path, _rootDir!.path)
                    ? 'Pustaka Ilmu (Root)'
                    : p.relative(dir.path, from: _rootDir!.path);
                return ListTile(
                  leading: const Icon(LucideIcons.folder, color: Colors.amber),
                  title: Text(rel),
                  onTap: () => Navigator.pop(ctx, dir),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (targetDir == null) return;
    final destPath = p.join(targetDir.path, p.basename(entity.path));
    if (p.equals(destPath, entity.path)) return;
    await entity.rename(destPath);
    await _refreshDirectory();
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final name = p.basename(entity.path);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Item?'),
        content: Text('Hapus "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await entity.delete(recursive: true);
      await _refreshDirectory();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final crumbs = _getBreadcrumbs();
    final isAtRoot = _rootDir != null && _currentDir != null && p.equals(_rootDir!.path, _currentDir!.path);

    return PopScope(
      canPop: isAtRoot,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!isAtRoot && _currentDir != null) {
          _currentDir = _currentDir!.parent;
          await _refreshDirectory();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Pustaka Ilmu (PDF)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.folderPlus, size: 20),
              tooltip: 'Kategori / Folder Baru',
              onPressed: _createCategoryFolder,
            ),
            IconButton(
              icon: const Icon(LucideIcons.upload, size: 20),
              tooltip: 'Upload PDF',
              onPressed: _uploadPdfs,
            ),
            const HomeActionButton(),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.grey[100],
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (!isAtRoot)
                      IconButton(
                        icon: const Icon(LucideIcons.arrowUp, size: 17),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () async {
                          _currentDir = _currentDir!.parent;
                          await _refreshDirectory();
                        },
                      ),
                    for (int i = 0; i < crumbs.length; i++) ...[
                      if (i > 0) const Icon(LucideIcons.chevronRight, size: 15, color: Colors.grey),
                      InkWell(
                        onTap: () async {
                          _currentDir = crumbs[i];
                          await _refreshDirectory();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            i == 0 ? 'Pustaka Ilmu' : p.basename(crumbs[i].path),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: i == crumbs.length - 1 ? FontWeight.bold : FontWeight.w500,
                              color: i == crumbs.length - 1 ? const Color(0xFF0D7377) : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Cari kitab PDF atau kategori...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) {
                        _searchQuery = v.trim();
                        _refreshDirectory();
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Semua', style: TextStyle(fontSize: 11)),
                    selected: _searchAll,
                    onSelected: (v) {
                      _searchAll = v;
                      _refreshDirectory();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
                  : _entities.isEmpty
                      ? Center(
                          child: Text(
                            'Folder kosong. Tekan tombol Upload PDF untuk menambah kitab belajar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          itemCount: _entities.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final entity = _entities[idx];
                            final name = p.basename(entity.path);
                            final isDir = entity is Directory;
                            final stat = entity.statSync();
                            final modified = DateFormat('dd MMM yyyy').format(stat.modified);
                            final prog = !isDir ? _progressMap[entity.path] : null;
                            final lastPage = (prog?['lastPage'] as int?) ?? 0;
                            final totalPages = (prog?['totalPages'] as int?) ?? 0;
                            final percent = (prog?['percent'] as int?) ?? 0;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (isDir ? Colors.amber[700]! : Colors.red[600]!).withValues(alpha: 0.12),
                                child: Icon(
                                  isDir ? LucideIcons.folder : LucideIcons.fileText,
                                  color: isDir ? Colors.amber[700]! : Colors.red[600]!,
                                  size: 20,
                                ),
                              ),
                              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isDir
                                        ? 'Kategori • $modified'
                                        : '${_formatSize(stat.size)}${totalPages > 0 ? " • Hal. $lastPage/$totalPages ($percent%)" : " • Belum dibaca"}',
                                    style: TextStyle(fontSize: 11, color: totalPages > 0 ? const Color(0xFF0D7377) : Colors.grey[600]),
                                  ),
                                  if (!isDir && totalPages > 0) ...[
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: (lastPage / totalPages).clamp(0.0, 1.0),
                                      minHeight: 4,
                                      borderRadius: BorderRadius.circular(4),
                                      color: const Color(0xFF0D7377),
                                      backgroundColor: Colors.grey[200],
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () => _openEntity(entity),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'open') _openEntity(entity);
                                  if (action == 'rename') _renameEntity(entity);
                                  if (action == 'move') _moveEntity(entity);
                                  if (action == 'delete') _deleteEntity(entity);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'open', child: Text('Buka')),
                                  PopupMenuItem(value: 'rename', child: Text('Ganti Nama')),
                                  PopupMenuItem(value: 'move', child: Text('Pindahkan ke...')),
                                  PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF0D7377),
          foregroundColor: Colors.white,
          onPressed: _uploadPdfs,
          icon: const Icon(LucideIcons.upload),
          label: const Text('Upload PDF'),
        ),
      ),
    );
  }
}
