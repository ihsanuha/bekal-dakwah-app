import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/home_action_button.dart';
import 'material_editor_screen.dart';

class MaterialDatabaseScreen extends StatefulWidget {
  const MaterialDatabaseScreen({super.key});

  @override
  State<MaterialDatabaseScreen> createState() => _MaterialDatabaseScreenState();
}

class _MaterialDatabaseScreenState extends State<MaterialDatabaseScreen> {
  Directory? _rootDir;
  Directory? _currentDir;
  List<FileSystemEntity> _entities = [];
  bool _loading = true;
  String _searchQuery = '';
  bool _searchAllSubfolders = false;
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
    final root = Directory(p.join(appDir.path, 'materi_dakwah'));
    if (!await root.exists()) {
      await root.create(recursive: true);
      await Directory(p.join(root.path, "Khutbah Jum'at")).create(recursive: true);
      await Directory(p.join(root.path, 'Kajian Rutin')).create(recursive: true);
      await _migrateLegacyNotes(root);
    }

    _rootDir = root;
    _currentDir = root;
    await _refreshDirectory();
  }

  Future<void> _migrateLegacyNotes(Directory root) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('saved_dakwah_materials');
      if (raw == null || raw.isEmpty) return;
      final List decoded = jsonDecode(raw);
      for (final item in decoded) {
        if (item is Map) {
          final title = (item['title'] ?? 'Catatan').toString().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
          final cat = (item['category'] ?? '').toString().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
          final content = (item['content'] ?? '').toString();
          final targetFolder = cat.isNotEmpty ? Directory(p.join(root.path, cat)) : root;
          if (!await targetFolder.exists()) await targetFolder.create(recursive: true);
          final file = File(p.join(targetFolder.path, '$title.txt'));
          if (!await file.exists()) {
            await file.writeAsString(content);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshDirectory() async {
    if (_currentDir == null || _rootDir == null) return;
    setState(() => _loading = true);

    List<FileSystemEntity> list;
    if (_searchQuery.isNotEmpty && _searchAllSubfolders) {
      list = _rootDir!.listSync(recursive: true, followLinks: false);
    } else {
      list = _currentDir!.listSync(followLinks: false);
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) => p.basename(e.path).toLowerCase().contains(q)).toList();
    }

    list.sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;
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

  Future<void> _createFolder() async {
    if (_currentDir == null) return;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Folder Baru'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Misal: Kitab Tauhid / PDF 2026'),
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
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
    }
    await _refreshDirectory();
  }

  Future<void> _uploadFiles() async {
    if (_currentDir == null) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    int copiedCount = 0;
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
      copiedCount++;
    }

    await _refreshDirectory();
    if (mounted && copiedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$copiedCount file berhasil ditambahkan ke folder ini')),
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

    final ext = p.extension(entity.path).toLowerCase();
    if (ext == '.txt' || ext == '.md') {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MaterialEditorScreen(existingFilePath: entity.path),
        ),
      );
      if (changed == true) {
        await _refreshDirectory();
      }
      return;
    }

    final res = await OpenFilex.open(entity.path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat membuka file (${res.message}). Pastikan ada aplikasi pembaca $ext di HP.')),
      );
    }
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
        if (entity is Directory && (p.equals(e.path, entity.path) || p.isWithin(entity.path, e.path))) {
          continue;
        }
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
            child: Text('Pindahkan ke Folder', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: folders.length,
              itemBuilder: (_, i) {
                final dir = folders[i];
                final rel = p.equals(dir.path, _rootDir!.path)
                    ? 'Materi (Root)'
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item berhasil dipindahkan')),
      );
    }
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final name = p.basename(entity.path);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Item?'),
        content: Text('Yakin ingin menghapus "$name"${entity is Directory ? " beserta seluruh isinya" : ""}?'),
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

  IconData _iconForEntity(FileSystemEntity entity) {
    if (entity is Directory) return LucideIcons.folder;
    final ext = p.extension(entity.path).toLowerCase();
    if (ext == '.pdf') return LucideIcons.fileText;
    if (ext == '.doc' || ext == '.docx') return LucideIcons.fileType;
    if (ext == '.txt' || ext == '.md') return LucideIcons.stickyNote;
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') return LucideIcons.image;
    if (ext == '.mp3' || ext == '.m4a' || ext == '.wav') return LucideIcons.music;
    return LucideIcons.file;
  }

  Color _colorForEntity(FileSystemEntity entity) {
    if (entity is Directory) return Colors.amber[700]!;
    final ext = p.extension(entity.path).toLowerCase();
    if (ext == '.pdf') return Colors.red[600]!;
    if (ext == '.doc' || ext == '.docx') return Colors.blue[700]!;
    if (ext == '.txt' || ext == '.md') return const Color(0xFF0D7377);
    if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp') return Colors.purple[600]!;
    if (ext == '.mp3' || ext == '.m4a' || ext == '.wav') return Colors.orange[700]!;
    return Colors.grey[700]!;
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
          title: Text('Explorer Materi Dakwah', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.folderPlus, size: 20),
              tooltip: 'Folder Baru',
              onPressed: _createFolder,
            ),
            IconButton(
              icon: const Icon(LucideIcons.upload, size: 20),
              tooltip: 'Upload File (PDF, DOCX, dll.)',
              onPressed: _uploadFiles,
            ),
            const HomeActionButton(),
          ],
        ),
        body: Column(
          children: [
            // Breadcrumb bar ala Windows Explorer
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
                        tooltip: 'Naik satu folder',
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
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            i == 0 ? 'Materi' : p.basename(crumbs[i].path),
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

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Cari file / folder...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                  _refreshDirectory();
                                },
                              )
                            : null,
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
                    selected: _searchAllSubfolders,
                    onSelected: (v) {
                      _searchAllSubfolders = v;
                      _refreshDirectory();
                    },
                  ),
                ],
              ),
            ),

            // Explorer File & Folder List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
                  : _entities.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.folderOpen, size: 52, color: Colors.grey[350]),
                                const SizedBox(height: 10),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Tidak ada file/folder yang cocok.'
                                      : 'Folder ini masih kosong.\nUpload PDF/DOCX atau buat catatan baru.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ],
                            ),
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
                            final subtitleText = isDir
                                ? 'Folder • $modified'
                                : '${_formatSize(stat.size)} • $modified';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _colorForEntity(entity).withValues(alpha: 0.12),
                                child: Icon(_iconForEntity(entity), color: _colorForEntity(entity), size: 20),
                              ),
                              title: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                _searchAllSubfolders && _searchQuery.isNotEmpty && _rootDir != null
                                    ? p.relative(p.dirname(entity.path), from: _rootDir!.path)
                                    : subtitleText,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.small(
              heroTag: 'upload_file',
              backgroundColor: const Color(0xFFD4A843),
              foregroundColor: Colors.black87,
              tooltip: 'Upload PDF / DOCX / File',
              onPressed: _uploadFiles,
              child: const Icon(LucideIcons.upload, size: 18),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.extended(
              heroTag: 'new_note',
              backgroundColor: const Color(0xFF0D7377),
              foregroundColor: Colors.white,
              onPressed: () async {
                if (_currentDir == null) return;
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MaterialEditorScreen(targetDirectory: _currentDir!.path),
                  ),
                );
                if (changed == true) {
                  await _refreshDirectory();
                }
              },
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Catatan Baru'),
            ),
          ],
        ),
      ),
    );
  }
}
