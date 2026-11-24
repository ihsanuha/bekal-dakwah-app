import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DakwahScheduleScreen extends StatefulWidget {
  const DakwahScheduleScreen({super.key});

  @override
  State<DakwahScheduleScreen> createState() => _DakwahScheduleScreenState();
}

class _DakwahScheduleScreenState extends State<DakwahScheduleScreen> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  void _loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_dakwah_schedules');
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() {
        _schedules = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } else {
      _schedules = [
        {
          'id': '1',
          'title': 'Kajian Kitab At-Tauhid',
          'location': 'Masjid Al-Ikhlas, Kebayoran',
          'time': 'Ahad, Ba\'da Maghrib',
          'status': 'Rutin Mingguan',
        },
        {
          'id': '2',
          'title': 'Syarah Riyadhus Shalihin',
          'location': 'Masjid As-Sunnah, Bintaro',
          'time': 'Rabu, Ba\'da Isya',
          'status': 'Rutin Mingguan',
        },
        {
          'id': '3',
          'title': 'Khutbah Jum\'at: Adab Penuntut Ilmu',
          'location': 'Masjid Agung Al-Falah',
          'time': 'Jum\'at, 11:45 WIB',
          'status': 'Terjadwal',
        },
      ];
      _saveSchedules();
      setState(() => _isLoading = false);
    }
  }

  void _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_dakwah_schedules', jsonEncode(_schedules));
  }

  void _showScheduleDialog({Map<String, dynamic>? existingSchedule, int? index}) {
    final titleCtrl = TextEditingController(text: existingSchedule?['title']);
    final locationCtrl = TextEditingController(text: existingSchedule?['location']);
    final timeCtrl = TextEditingController(text: existingSchedule?['time']);
    final statusCtrl = TextEditingController(text: existingSchedule?['status'] ?? 'Rutin Mingguan');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existingSchedule == null ? 'Tambah Jadwal Kajian' : 'Edit Jadwal Kajian',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Nama Kajian / Kitab', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: 'Lokasi / Masjid', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(labelText: 'Hari & Waktu (misal: Ahad, Ba\'da Ashar)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: statusCtrl,
                decoration: const InputDecoration(labelText: 'Status (Rutin / Terjadwal / Dauroh)', border: OutlineInputBorder()),
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
                if (existingSchedule == null) {
                  // Create
                  _schedules.insert(0, {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'title': titleCtrl.text.trim(),
                    'location': locationCtrl.text.trim(),
                    'time': timeCtrl.text.trim(),
                    'status': statusCtrl.text.trim(),
                  });
                } else if (index != null) {
                  // Update
                  _schedules[index] = {
                    'id': existingSchedule['id'],
                    'title': titleCtrl.text.trim(),
                    'location': locationCtrl.text.trim(),
                    'time': timeCtrl.text.trim(),
                    'status': statusCtrl.text.trim(),
                  };
                }
              });
              _saveSchedules();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(existingSchedule == null ? 'Jadwal berhasil ditambahkan' : 'Jadwal berhasil diperbarui')),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _deleteSchedule(int index) {
    setState(() {
      _schedules.removeAt(index);
    });
    _saveSchedules();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jadwal dihapus')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jadwal Dakwah & Kajian', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D7377),
        foregroundColor: Colors.white,
        onPressed: () => _showScheduleDialog(),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Tambah Jadwal'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : _schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.calendarX, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Belum ada jadwal kajian', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
                        icon: const Icon(LucideIcons.plus),
                        label: const Text('Tambah Jadwal Baru'),
                        onPressed: () => _showScheduleDialog(),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _schedules.length,
                  itemBuilder: (context, index) {
                    final item = _schedules[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF0D7377).withOpacity(0.12),
                          child: const Icon(LucideIcons.calendarDays, color: Color(0xFF0D7377), size: 20),
                        ),
                        title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(child: Text(item['location'] ?? '', style: TextStyle(color: Colors.grey[700], fontSize: 12))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(LucideIcons.clock, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(child: Text(item['time'] ?? '', style: TextStyle(color: Colors.grey[700], fontSize: 12))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Chip(
                              label: Text(item['status'] ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF0D7377))),
                              backgroundColor: const Color(0xFF0D7377).withOpacity(0.08),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
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
                              _showScheduleDialog(existingSchedule: item, index: index);
                            } else if (val == 'delete') {
                              _deleteSchedule(index);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
