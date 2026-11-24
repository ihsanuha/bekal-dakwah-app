import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/quran_list_screen.dart';
import 'screens/hadith_screens.dart';
import 'screens/fatwa_list_screen.dart';
import 'screens/material_editor_screen.dart';
import 'screens/dakwah_schedule_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const BekalDakwahApp());
}

class BekalDakwahApp extends StatelessWidget {
  const BekalDakwahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bekal Dakwah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D7377),
          primary: const Color(0xFF0D7377),
          secondary: const Color(0xFFD4A843),
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    QuranListScreen(),
    AIChatScreen(),
    MaterialEditorScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: "Al-Qur'an"),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Asisten AI'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'Editor'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _prayerData;
  bool _loadingPrayer = true;

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
  }

  void _loadPrayerTimes() async {
    final data = await ApiService.getPrayerTimes();
    if (mounted) {
      setState(() {
        _prayerData = data;
        _loadingPrayer = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timings = _prayerData?['timings'];
    final hijri = _prayerData?['date']?['hijri'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🕌 ', style: TextStyle(fontSize: 22)),
            Text(
              'Bekal Dakwah',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D7377),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.account_circle_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Salam & Penanggalan Hijriyah
            Text(
              "Assalamu'alaikum, Ustadz",
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              hijri != null
                  ? '${hijri['day']} ${hijri['month']?['en']} ${hijri['year']} H'
                  : 'Pusat Bantuan & Referensi Ilmiah Ahlus Sunnah',
              style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),

            // Card Jadwal Shalat
            if (!_loadingPrayer && timings != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _prayerItem('Shubuh', timings['Fajr']),
                    _prayerItem('Dzuhur', timings['Dhuhr']),
                    _prayerItem('Ashar', timings['Asr']),
                    _prayerItem('Maghrib', timings['Maghrib']),
                    _prayerItem('Isya', timings['Isha']),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Banner AI Assistant
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0D7377), Color(0xFF148F94)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFFD4A843), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Asisten AI Dakwah (Manhaj Salaf)',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Siapkan khutbah, susun materi kajian, atau carikan dalil shahih untuk menjawab pertanyaan jamaah dengan cepat dan amanah.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4A843),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen()));
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Mulai Tanya AI', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Akses Cepat Fitur Lengkap
            Text(
              'Akses Cepat',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildMenuCard(Icons.menu_book_rounded, "Al-Qur'an\n& Tafsir", Colors.teal, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranListScreen()));
                }),
                _buildMenuCard(Icons.auto_awesome, 'Tanya\nAI Dakwah', const Color(0xFFD4A843), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen()));
                }),
                _buildMenuCard(Icons.format_quote_rounded, 'Hadits &\nTakhrij', Colors.amber[800]!, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HadithCategoriesScreen()));
                }),
                _buildMenuCard(Icons.gavel_rounded, 'Database\nFatwa', Colors.indigo, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FatwaListScreen()));
                }),
                _buildMenuCard(Icons.edit_note_rounded, 'Editor\nMateri', Colors.green[700]!, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialEditorScreen()));
                }),
                _buildMenuCard(Icons.calendar_month_rounded, 'Jadwal\nKajian', Colors.purple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DakwahScheduleScreen()));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _prayerItem(String name, String? time) {
    return Column(
      children: [
        Text(name, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(time ?? '--:--', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D7377))),
      ],
    );
  }

  Widget _buildMenuCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
