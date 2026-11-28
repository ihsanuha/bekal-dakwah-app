import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/quran_list_screen.dart';
import 'screens/hadith_screens.dart';
import 'screens/hadith_webview_screen.dart';
import 'screens/turath_screens.dart';
import 'screens/fatwa_list_screen.dart';
import 'screens/material_database_screen.dart';
import 'screens/dakwah_schedule_screen.dart';
import 'screens/doa_dzikir_screen.dart';
import 'screens/islamhouse_screen.dart';
import 'screens/portal_hub_screen.dart';
import 'screens/mutiara_salaf_screen.dart';
import 'screens/pustaka_ilmu_screen.dart';
import 'screens/dorar_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
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
    MaterialDatabaseScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.home, size: 20),
            selectedIcon: Icon(LucideIcons.home, color: Color(0xFF0D7377), size: 20),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.bookOpen, size: 20),
            selectedIcon: Icon(LucideIcons.bookOpen, color: Color(0xFF0D7377), size: 20),
            label: "Al-Qur'an",
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.sparkles, size: 20),
            selectedIcon: Icon(LucideIcons.sparkles, color: Color(0xFF0D7377), size: 20),
            label: 'Asisten AI',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.folder, size: 20),
            selectedIcon: Icon(LucideIcons.folder, color: Color(0xFF0D7377), size: 20),
            label: 'Materi',
          ),
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _prayerData;
  bool _loadingPrayer = true;
  String _locationLabel = 'Jakarta (Default)';
  Map<String, dynamic>? _latestMutiara;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrayerTimes();
    _loadLatestMutiara();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLatestMutiara();
    }
  }

  Future<void> _loadLatestMutiara() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('custom_mutiara_sheet_url');
    final cachedRaw = prefs.getString('cached_mutiara_items');
    if (cachedRaw != null) {
      try {
        final List decoded = jsonDecode(cachedRaw);
        if (decoded.isNotEmpty && mounted) {
          setState(() => _latestMutiara = Map<String, dynamic>.from(decoded.first));
        }
      } catch (_) {}
    }

    final fresh = await ApiService.getMutiaraList(sheetUrl: customUrl);
    if (fresh.isNotEmpty) {
      await prefs.setString('cached_mutiara_items', jsonEncode(fresh));
      final latest = fresh.first;
      final latestKey = '${latest['tanggal']}_${latest['judul']}';
      final lastNotifiedKey = prefs.getString('last_notified_mutiara_key');
      if (lastNotifiedKey != null && lastNotifiedKey != latestKey) {
        await NotificationService.showMutiaraNotification(
          title: 'Mutiara Ilmu Baru: ${latest['judul'] ?? 'Update'}',
          body: (latest['konten_wa'] ?? '').toString(),
        );
      }
      await prefs.setString('last_notified_mutiara_key', latestKey);
      if (mounted) {
        setState(() => _latestMutiara = latest);
      }
    }
  }

  Future<void> _loadPrayerTimes({bool forceGpsRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    double? lat = prefs.getDouble('last_lat');
    double? lon = prefs.getDouble('last_lon');

    if (lat != null && lon != null && !forceGpsRefresh) {
      final cachedLat = lat;
      final cachedLon = lon;
      final cachedData = await ApiService.getPrayerTimes(lat: cachedLat, lon: cachedLon);
      if (mounted && cachedData != null) {
        setState(() {
          _prayerData = cachedData;
          _locationLabel = 'GPS (${cachedLat.toStringAsFixed(3)}, ${cachedLon.toStringAsFixed(3)})';
          _loadingPrayer = false;
        });
      }
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
          );
          lat = pos.latitude;
          lon = pos.longitude;
          await prefs.setDouble('last_lat', lat);
          await prefs.setDouble('last_lon', lon);
        }
      }
    } catch (_) {}

    final data = await ApiService.getPrayerTimes(lat: lat, lon: lon);
    if (mounted) {
      setState(() {
        _prayerData = data;
        _locationLabel = (lat != null && lon != null)
            ? 'GPS (${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)})'
            : 'Jakarta (Default)';
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
            const Icon(LucideIcons.landmark, color: Color(0xFF0D7377), size: 22),
            const SizedBox(width: 8),
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
          IconButton(icon: const Icon(LucideIcons.bell, size: 20), onPressed: () {}),
          IconButton(
            icon: const Icon(LucideIcons.info, size: 20),
            tooltip: 'Tentang & Lisensi Open Source',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Bekal Dakwah (GPL-3.0)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  content: const Text(
                    'Aplikasi pusat bantuan dakwah khusus Android, 100% gratis & non-komersial di bawah lisensi GNU GPL-3.0.\n\n'
                    'Atribusi Sumber Terbuka:\n'
                    '• Mushaf Madani, ayahinfo, & Mesin Pencari Arab diadaptasi dari quran/quran_android (GPL-3.0) & files.quran.app\n'
                    '• Teks Al-Qur\'an & Terjemah Kemenag (Tanzil / AlQuran Cloud)\n'
                    '• Tafsir Ibnu Katsir, As-Sa\'di, Al-Baghawi (Quran.com API) & Tafsir Kemenag (equran.id)\n'
                    '• Ensiklopedia Hadits & Takhrij (hdith.com)\n'
                    '• Maktabah Kitab Ulama (turath.io)\n'
                    '• Konsultasi Syariah (konsultasisyariah.com)\n'
                    '• Doa & Dzikir Shahih (Hisnul Muslim & Dzikir Pagi Petang)\n'
                    '• Fatwa IslamWeb, IslamHouse & Bekal Islam\n'
                    '• Portal Riset: Tafsir.app, Tafsir.one, Takw.in, Hifdh.app, Bahith.app, Sunnah.one\n'
                    '• Ensiklopedia Ad-Durar As-Saniyyah (dorar.net)',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadPrayerTimes(),
            _loadLatestMutiara(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                  : 'Pusat Referensi Ilmiah & Alat Bantu Dakwah',
              style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),

            // Card Jadwal Shalat (Presisi GPS)
            if (!_loadingPrayer && timings != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.mapPin, size: 13, color: Color(0xFF0D7377)),
                            const SizedBox(width: 4),
                            Text(
                              _locationLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _loadPrayerTimes(forceGpsRefresh: true),
                          child: const Row(
                            children: [
                              Icon(LucideIcons.locateFixed, size: 13, color: Color(0xFF0D7377)),
                              SizedBox(width: 3),
                              Text('Perbarui GPS', style: TextStyle(fontSize: 11, color: Color(0xFF0D7377), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _prayerItem('Shubuh', timings['Fajr']),
                        _prayerItem('Dzuhur', timings['Dhuhr']),
                        _prayerItem('Ashar', timings['Asr']),
                        _prayerItem('Maghrib', timings['Maghrib']),
                        _prayerItem('Isya', timings['Isha']),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Kartu Mutiara Ilmu (Sinkron otomatis dengan Google Sheet)
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.sparkles, color: Color(0xFFD4A843), size: 19),
                          const SizedBox(width: 8),
                          Text(
                            'Mutiara Ilmu',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(right: 8),
                            icon: const Icon(LucideIcons.refreshCw, color: Colors.white70, size: 15),
                            tooltip: 'Perbarui Mutiara Ilmu',
                            onPressed: _loadLatestMutiara,
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.amber[200],
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 28),
                            ),
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const MutiaraSalafScreen()));
                              _loadLatestMutiara();
                            },
                            child: const Text('Lihat Semua →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_latestMutiara != null) ...[
                    Text(
                      (_latestMutiara!['judul'] ?? 'Mutiara Ilmu Terbaru').toString(),
                      style: GoogleFonts.poppins(color: Colors.amber[200], fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    if ((_latestMutiara!['teks_arab'] ?? '').toString().isNotEmpty && _latestMutiara!['teks_arab'] != '-') ...[
                      const SizedBox(height: 6),
                      Text(
                        _latestMutiara!['teks_arab'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontFamily: 'ThmanyahText', color: Colors.white, fontSize: 16, height: 1.7),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      (_latestMutiara!['konten_wa'] ?? '').toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            (_latestMutiara!['sumber'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4A843),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: (_latestMutiara!['konten_wa'] ?? '').toString()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Mutiara Ilmu disalin, siap tempel di WA')),
                            );
                          },
                          icon: const Icon(LucideIcons.copy, size: 14),
                          label: const Text('Salin WA', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'Belum tersambung ke Google Sheet Mutiara Ilmu. Ketuk "Lihat Semua" untuk mengatur link Sheet atau refresh.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
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
                _buildMenuCard(LucideIcons.bookOpen, "Al-Qur'an\n& Tafsir", Colors.teal, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranListScreen()));
                }),
                _buildMenuCard(LucideIcons.sparkles, 'Tanya\nAI Dakwah', const Color(0xFFD4A843), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen()));
                }),
                _buildMenuCard(LucideIcons.scrollText, 'Hadits &\nTakhrij', Colors.amber[800]!, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HadithSearchScreen()));
                }),
                _buildMenuCard(LucideIcons.library, 'Maktabah\nTurath', Colors.brown[600]!, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TurathSearchScreen()));
                }),
                _buildMenuCard(LucideIcons.scale, 'Database\nFatwa', Colors.indigo, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FatwaListScreen()));
                }),
                _buildMenuCard(LucideIcons.messageCircle, 'Konsultasi\nSyariah', Colors.cyan[700]!, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HadithWebViewScreen(
                        url: 'https://konsultasisyariah.com/',
                        title: 'Konsultasi Syariah',
                      ),
                    ),
                  );
                }),
                _buildMenuCard(LucideIcons.folderArchive, 'Database\nMateri', Colors.green[700]!, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialDatabaseScreen()));
                }),
                _buildMenuCard(LucideIcons.calendar, 'Jadwal\nKajian', Colors.purple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DakwahScheduleScreen()));
                }),
                _buildMenuCard(LucideIcons.heartHandshake, 'Doa &\nDzikir', Colors.pink[600]!, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DoaDzikirScreen()));
                }),
                _buildMenuCard(LucideIcons.bookMarked, 'Pustaka\nIslamHouse', Colors.deepOrange[600]!, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const IslamHouseScreen()));
                }),
                _buildMenuCard(LucideIcons.compass, 'Portal Riset\nIlmiah', Colors.blueGrey[700]!, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PortalHubScreen()));
                }),
                _buildMenuCard(LucideIcons.bookOpenCheck, 'Pustaka\nIlmu (PDF)', Colors.teal[800]!, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PustakaIlmuScreen()));
                }),
                _buildMenuCard(LucideIcons.searchCheck, 'Ensiklopedia\nDorar', const Color(0xFF0D7377), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DorarEncyclopediaScreen()));
                }),
              ],
            ),
          ],
        ),
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
                child: Icon(icon, color: color, size: 20),
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
