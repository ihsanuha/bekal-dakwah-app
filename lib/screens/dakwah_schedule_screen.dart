import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DakwahScheduleScreen extends StatefulWidget {
  const DakwahScheduleScreen({super.key});

  @override
  State<DakwahScheduleScreen> createState() => _DakwahScheduleScreenState();
}

class _DakwahScheduleScreenState extends State<DakwahScheduleScreen> {
  final List<Map<String, String>> _schedules = [
    {
      'title': 'Kajian Kitab At-Tauhid',
      'location': 'Masjid Al-Ikhlas, Kebayoran',
      'time': 'Ahad, Ba\'da Maghrib',
      'status': 'Rutin Mingguan',
    },
    {
      'title': 'Syarah Riyadhus Shalihin',
      'location': 'Masjid As-Sunnah, Bintaro',
      'time': 'Rabu, Ba\'da Isya',
      'status': 'Rutin Mingguan',
    },
    {
      'title': 'Khutbah Jum\'at: Adab Penuntut Ilmu',
      'location': 'Masjid Agung Al-Falah',
      'time': 'Jum\'at, 11:45 WIB',
      'status': 'Terjadwal',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jadwal Dakwah & Kajian', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D7377),
        foregroundColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tambah jadwal baru')));
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Jadwal'),
      ),
      body: ListView.builder(
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
                child: const Icon(Icons.mosque, color: Color(0xFF0D7377)),
              ),
              title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(item['location'] ?? '', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(item['time'] ?? '', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    ],
                  ),
                ],
              ),
              trailing: Chip(
                label: Text(item['status'] ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF0D7377))),
                backgroundColor: const Color(0xFF0D7377).withOpacity(0.08),
                side: BorderSide.none,
              ),
            ),
          );
        },
      ),
    );
  }
}
