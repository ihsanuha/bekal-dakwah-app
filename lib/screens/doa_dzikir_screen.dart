import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DoaDzikirScreen extends StatefulWidget {
  const DoaDzikirScreen({super.key});

  @override
  State<DoaDzikirScreen> createState() => _DoaDzikirScreenState();
}

class _DoaDzikirScreenState extends State<DoaDzikirScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;

  List<Map<String, dynamic>> _pagi = [];
  List<Map<String, dynamic>> _petang = [];
  List<Map<String, dynamic>> _hisnulGroups = [];
  List<Map<String, dynamic>> _filteredHisnul = [];

  final Map<String, int> _counters = {};
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAssets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final rawDzikir = await rootBundle.loadString('assets/data/dzikir_pagi_petang.json');
      final rawHisnul = await rootBundle.loadString('assets/data/hisnul_muslim_id.json');

      final dzikirMap = jsonDecode(rawDzikir) as Map<String, dynamic>;
      final hisnulList = (jsonDecode(rawHisnul) as List).map((e) => Map<String, dynamic>.from(e)).toList();

      if (!mounted) return;
      setState(() {
        _pagi = ((dzikirMap['pagi'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        _petang = ((dzikirMap['petang'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        _hisnulGroups = hisnulList;
        _filteredHisnul = hisnulList;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data doa/dzikir: $e')));
      }
    }
  }

  void _filterHisnul(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredHisnul = _hisnulGroups;
      } else {
        _filteredHisnul = _hisnulGroups.where((g) {
          final title = (g['title'] ?? '').toString().toLowerCase();
          if (title.contains(query)) return true;
          final duas = (g['duas'] as List?) ?? [];
          return duas.any((d) =>
              (d['translation'] ?? '').toString().toLowerCase().contains(query) ||
              (d['arab'] ?? '').toString().contains(query));
        }).toList();
      }
    });
  }

  void _incrementCounter(String key, int target) {
    final current = _counters[key] ?? 0;
    if (current < target) {
      HapticFeedback.lightImpact();
      setState(() => _counters[key] = current + 1);
    }
  }

  void _resetCounter(String key) {
    setState(() => _counters[key] = 0);
  }

  void _resetAllCounters() {
    setState(() => _counters.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua hitungan dzikir direset ke 0')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doa & Dzikir Shahih', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Dzikir Pagi Petang & Hisnul Muslim', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCcw, size: 19),
            tooltip: 'Reset Semua Hitungan Dzikir',
            onPressed: _resetAllCounters,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D7377),
          indicatorColor: const Color(0xFF0D7377),
          tabs: const [
            Tab(text: 'Dzikir Pagi'),
            Tab(text: 'Dzikir Petang'),
            Tab(text: 'Doa Harian'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDzikirList(_pagi, prefix: 'pagi'),
                _buildDzikirList(_petang, prefix: 'petang'),
                _buildHisnulTab(),
              ],
            ),
    );
  }

  Widget _buildDzikirList(List<Map<String, dynamic>> items, {required String prefix}) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, idx) {
        final item = items[idx];
        final key = '${prefix}_${item['id'] ?? idx}';
        final target = int.tryParse('${item['ulang'] ?? 1}') ?? 1;
        final count = _counters[key] ?? 0;
        final done = count >= target;
        final dalil = (item['dalil'] ?? '').toString().trim();
        final latin = (item['latin'] ?? '').toString().trim();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0.6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: done ? const Color(0xFF0D7377) : Colors.grey[200]!,
              width: done ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: done ? const Color(0xFF0D7377) : Colors.teal.withValues(alpha: 0.12),
                      child: done
                          ? const Icon(Icons.check, size: 15, color: Colors.white)
                          : Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (item['judul'] ?? '').toString(),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A843).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Dibaca ${target}x',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8C6812)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  (item['arab'] ?? '').toString(),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: 'ThmanyahText',
                    fontSize: 21,
                    height: 1.9,
                    color: Colors.black87,
                  ),
                ),
                if (latin.isNotEmpty && latin != 'null') ...[
                  const SizedBox(height: 8),
                  Text(
                    latin,
                    style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: Colors.teal[800]),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  (item['arti'] ?? '').toString(),
                  style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey[800]),
                ),
                if (dalil.isNotEmpty && dalil != 'null') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sumber / Faedah: $dalil',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: target > 0 ? (count / target).clamp(0.0, 1.0) : 1.0,
                  backgroundColor: Colors.grey[200],
                  color: const Color(0xFF0D7377),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: done ? Colors.green[700] : const Color(0xFF0D7377),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _incrementCounter(key, target),
                        icon: Icon(done ? Icons.check_circle_outline : LucideIcons.hand, size: 17),
                        label: Text(
                          done ? 'Selesai ($count / $target)' : 'Hitung ($count / $target)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(LucideIcons.rotateCcw, size: 18),
                      tooltip: 'Reset hitungan',
                      onPressed: count > 0 ? () => _resetCounter(key) : null,
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.copy, size: 18),
                      tooltip: 'Salin',
                      onPressed: () {
                        final text = '${item['judul']}\n\n${item['arab']}\n\n${item['arti']}\n($dalil)';
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dzikir disalin')));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHisnulTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari doa sehari-hari (Hisnul Muslim)...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 17),
                      onPressed: () {
                        _searchCtrl.clear();
                        _filterHisnul('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: _filterHisnul,
          ),
        ),
        Expanded(
          child: _filteredHisnul.isEmpty
              ? const Center(child: Text('Doa tidak ditemukan.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: _filteredHisnul.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final group = _filteredHisnul[idx];
                    final duas = (group['duas'] as List?) ?? [];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFF0D7377).withValues(alpha: 0.1),
                        child: Text(
                          '${group['id'] ?? idx + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D7377)),
                        ),
                      ),
                      title: Text(
                        (group['title'] ?? '').toString(),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${duas.length} bacaan doa shahih', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      trailing: const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _HisnulDetailScreen(group: group),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _HisnulDetailScreen extends StatelessWidget {
  final Map<String, dynamic> group;
  const _HisnulDetailScreen({required this.group});

  @override
  Widget build(BuildContext context) {
    final duas = (group['duas'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (group['title'] ?? 'Doa Hisnul Muslim').toString(),
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: duas.length,
        itemBuilder: (_, idx) {
          final d = duas[idx] as Map<String, dynamic>;
          final arab = (d['arab'] ?? '').toString();
          final trans = (d['translation'] ?? '').toString();
          final ref = (d['reference'] ?? '').toString();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0.6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bacaan #${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
                      IconButton(
                        icon: const Icon(LucideIcons.copy, size: 17, color: Colors.grey),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '$arab\n\n$trans\n($ref)'));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doa disalin')));
                        },
                      ),
                    ],
                  ),
                  SelectableText(
                    arab,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'ThmanyahText',
                      fontSize: 21,
                      height: 1.9,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(trans, style: TextStyle(fontSize: 13.5, height: 1.5, color: Colors.grey[850])),
                  if (ref.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Sumber: $ref', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
