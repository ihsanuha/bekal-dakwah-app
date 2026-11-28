import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../widgets/home_action_button.dart';

class DakwahScheduleScreen extends StatefulWidget {
  const DakwahScheduleScreen({super.key});

  @override
  State<DakwahScheduleScreen> createState() => _DakwahScheduleScreenState();
}

class _DakwahScheduleScreenState extends State<DakwahScheduleScreen> {
  static const List<String> _pasaranNames = ['Legi', 'Pahing', 'Pon', 'Wage', 'Kliwon'];
  static const List<String> _pasaranShort = ['Lg', 'Ph', 'Pn', 'Wg', 'Kl'];
  static const List<String> _dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jum\'at', 'Sabtu', 'Ahad'];

  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  late DateTime _focusedMonth;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadSchedules();
  }

  /// Anchor historis: 17 Agustus 1945 adalah Jum'at Legi (index 0)
  static int _pasaranIndex(DateTime date) {
    final anchor = DateTime.utc(1945, 8, 17);
    final target = DateTime.utc(date.year, date.month, date.day);
    final diff = target.difference(anchor).inDays;
    return ((diff % 5) + 5) % 5;
  }

  static String getPasaran(DateTime date) => _pasaranNames[_pasaranIndex(date)];
  static String getPasaranShort(DateTime date) => _pasaranShort[_pasaranIndex(date)];
  static String getDayAndPasaran(DateTime date) => '${_dayNames[date.weekday - 1]} ${getPasaran(date)}';

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  bool _occursOnDate(Map<String, dynamic> item, DateTime day) {
    final anchorStr = (item['date'] ?? '').toString();
    final anchor = DateTime.tryParse(anchorStr);
    if (anchor == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final a = DateTime(anchor.year, anchor.month, anchor.day);
    if (d.isBefore(a)) return false;

    final repeat = (item['repeatType'] ?? 'none').toString();
    switch (repeat) {
      case 'weekly':
        return d.weekday == a.weekday;
      case 'pasaran_35':
        return d.weekday == a.weekday && _pasaranIndex(d) == _pasaranIndex(a);
      case 'monthly':
        return d.day == a.day;
      case 'monthly_nth_weekday':
        if (d.weekday != a.weekday) return false;
        final weekOfMonth = ((d.day - 1) ~/ 7) + 1;
        final weeks = ((item['repeatWeeks'] as List?) ?? []).map((e) => int.tryParse('$e') ?? 0).toList();
        return weeks.contains(weekOfMonth);
      default:
        return d.year == a.year && d.month == a.month && d.day == a.day;
    }
  }

  DateTime? _nextOccurrence(Map<String, dynamic> item) {
    final anchor = DateTime.tryParse((item['date'] ?? '').toString());
    if (anchor == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final repeat = (item['repeatType'] ?? 'none').toString();
    if (repeat == 'none') return anchor;

    for (int offset = 0; offset <= 366; offset++) {
      final candidate = today.add(Duration(days: offset));
      if (_occursOnDate(item, candidate)) return candidate;
    }
    return anchor;
  }

  String _repeatLabel(String? repeatType, DateTime? anchor, {List<dynamic>? repeatWeeks}) {
    switch (repeatType) {
      case 'weekly':
        return anchor != null ? 'Berulang tiap ${_dayNames[anchor.weekday - 1]}' : 'Rutin Mingguan';
      case 'pasaran_35':
        return anchor != null ? 'Berulang tiap ${getDayAndPasaran(anchor)} (35 hr)' : 'Selapanan (35 hari)';
      case 'monthly':
        return anchor != null ? 'Berulang tiap tanggal ${anchor.day}' : 'Rutin Bulanan';
      case 'monthly_nth_weekday':
        final weeksStr = (repeatWeeks ?? []).join(', ');
        final dayStr = anchor != null ? _dayNames[anchor.weekday - 1] : 'Hari';
        return 'Tiap $dayStr pekan ke-$weeksStr';
      default:
        return 'Sekali saja';
    }
  }

  Future<void> _loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final cleanedOnce = prefs.getBool('schedules_cleared_v1') ?? false;
    if (!cleanedOnce) {
      await prefs.setString('saved_dakwah_schedules', jsonEncode([]));
      await prefs.setBool('schedules_cleared_v1', true);
      if (mounted) {
        setState(() {
          _schedules = [];
          _isLoading = false;
        });
      }
      return;
    }

    final raw = prefs.getString('saved_dakwah_schedules');
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() {
        _schedules = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _schedules = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_dakwah_schedules', jsonEncode(_schedules));
  }

  int _notifIdFor(String idStr) => idStr.hashCode & 0x7fffffff;

  Future<void> _syncNotification(Map<String, dynamic> item) async {
    final id = _notifIdFor(item['id'].toString());
    final enabled = item['notifyEnabled'] == true;
    final dateStr = (item['date'] ?? '').toString();
    if (!enabled || dateStr.isEmpty) {
      await NotificationService.cancelReminder(id);
      return;
    }

    final parsedDate = _nextOccurrence(item);
    if (parsedDate == null) return;

    final daysBefore = (item['notifyDaysBefore'] as int?) ?? 1;
    final hour = (item['notifyHour'] as int?) ?? 7;
    final minute = (item['notifyMinute'] as int?) ?? 0;

    final targetDate = parsedDate.subtract(Duration(days: daysBefore));
    final scheduledTime = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);

    if (scheduledTime.isAfter(DateTime.now())) {
      final pasaran = getDayAndPasaran(parsedDate);
      final hLabel = daysBefore == 0 ? 'Hari Ini' : 'H-$daysBefore';
      await NotificationService.scheduleKajianReminder(
        id: id,
        title: 'Pengingat ($hLabel): ${item['title']}',
        body: '$pasaran (${DateFormat('dd MMM yyyy').format(parsedDate)}) • ${item['clock'] ?? ''} • ${item['location'] ?? ''}',
        scheduledTime: scheduledTime,
      );
    }
  }

  void _showScheduleDialog({Map<String, dynamic>? existingSchedule, int? index}) {
    final titleCtrl = TextEditingController(text: existingSchedule?['title']);
    final locationCtrl = TextEditingController(text: existingSchedule?['location']);
    final statusCtrl = TextEditingController(text: existingSchedule?['status'] ?? 'Khutbah Jum\'at');

    DateTime pickedDate = DateTime.tryParse((existingSchedule?['date'] ?? '').toString()) ?? _selectedDate;
    final clockParts = (existingSchedule?['clock'] ?? '11:45').toString().split(':');
    TimeOfDay pickedTime = TimeOfDay(
      hour: int.tryParse(clockParts.isNotEmpty ? clockParts[0] : '11') ?? 11,
      minute: int.tryParse(clockParts.length > 1 ? clockParts[1] : '45') ?? 45,
    );

    bool notifyEnabled = existingSchedule?['notifyEnabled'] == true;
    int notifyDaysBefore = (existingSchedule?['notifyDaysBefore'] as int?) ?? 1;
    String repeatType = (existingSchedule?['repeatType'] ?? 'none').toString();
    final Set<int> repeatWeeks = ((existingSchedule?['repeatWeeks'] as List?) ?? [((pickedDate.day - 1) ~/ 7) + 1])
        .map((e) => int.tryParse('$e') ?? 1)
        .toSet();
    final customDaysCtrl = TextEditingController(text: '$notifyDaysBefore');
    TimeOfDay notifyTime = TimeOfDay(
      hour: (existingSchedule?['notifyHour'] as int?) ?? 7,
      minute: (existingSchedule?['notifyMinute'] as int?) ?? 0,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existingSchedule == null ? 'Tambah Jadwal Dakwah' : 'Edit Jadwal Dakwah',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Kajian / Khutbah', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'Lokasi / Masjid', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: statusCtrl,
                  decoration: const InputDecoration(labelText: 'Kategori (Khutbah Jum\'at / Kajian Rutin / Dauroh)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.calendar, size: 16),
                  label: Text('${getDayAndPasaran(pickedDate)}, ${DateFormat('dd MMM yyyy').format(pickedDate)}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: pickedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (d != null) setDialogState(() => pickedDate = d);
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.clock, size: 16),
                  label: Text('Jam Acara: ${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')} WIB'),
                  onPressed: () async {
                    final t = await showTimePicker(context: ctx, initialTime: pickedTime);
                    if (t != null) setDialogState(() => pickedTime = t);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: repeatType,
                  decoration: const InputDecoration(
                    labelText: 'Pengulangan Jadwal',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: 'none', child: Text('Sekali saja')),
                    DropdownMenuItem(value: 'weekly', child: Text('Setiap ${_dayNames[pickedDate.weekday - 1]} (Mingguan)')),
                    DropdownMenuItem(value: 'monthly_nth_weekday', child: Text('${_dayNames[pickedDate.weekday - 1]} Pekan Tertentu (1-5)')),
                    DropdownMenuItem(value: 'pasaran_35', child: Text('Setiap ${getDayAndPasaran(pickedDate)} (Selapanan 35 hr)')),
                    DropdownMenuItem(value: 'monthly', child: Text('Setiap Tanggal ${pickedDate.day} (Bulanan)')),
                  ],
                  onChanged: (v) => setDialogState(() => repeatType = v ?? 'none'),
                ),
                if (repeatType == 'monthly_nth_weekday') ...[
                  const SizedBox(height: 8),
                  const Text('Pilih Pekan ke-berapa dalam bulan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [1, 2, 3, 4, 5].map((w) {
                      final sel = repeatWeeks.contains(w);
                      return FilterChip(
                        label: Text('Pekan $w', style: const TextStyle(fontSize: 11)),
                        selected: sel,
                        onSelected: (checked) {
                          setDialogState(() {
                            if (checked) {
                              repeatWeeks.add(w);
                            } else if (repeatWeeks.length > 1) {
                              repeatWeeks.remove(w);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const Divider(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktifkan Notifikasi Pengingat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: notifyEnabled,
                  onChanged: (v) => setDialogState(() => notifyEnabled = v),
                ),
                if (notifyEnabled) ...[
                  Row(
                    children: [
                      const Expanded(child: Text('Ingatkan berapa hari sebelum Hari H:', style: TextStyle(fontSize: 12))),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: customDaysCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            suffixText: 'hr',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v.trim());
                            if (parsed != null && parsed >= 0) {
                              notifyDaysBefore = parsed;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [0, 1, 2, 3, 7].map((d) {
                      return ChoiceChip(
                        label: Text(d == 0 ? 'Hari H' : 'H-$d', style: const TextStyle(fontSize: 11)),
                        selected: notifyDaysBefore == d,
                        onSelected: (_) {
                          setDialogState(() {
                            notifyDaysBefore = d;
                            customDaysCtrl.text = '$d';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(LucideIcons.bellRing, size: 15),
                    label: Text('Jam Notif: ${notifyTime.hour.toString().padLeft(2, '0')}:${notifyTime.minute.toString().padLeft(2, '0')}'),
                    onPressed: () async {
                      final t = await showTimePicker(context: ctx, initialTime: notifyTime);
                      if (t != null) setDialogState(() => notifyTime = t);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7377), foregroundColor: Colors.white),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final clockStr = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                final daysBeforeVal = int.tryParse(customDaysCtrl.text.trim()) ?? notifyDaysBefore;
                final newItem = <String, dynamic>{
                  'id': existingSchedule?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  'title': titleCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'date': _dateKey(pickedDate),
                  'clock': clockStr,
                  'time': '${getDayAndPasaran(pickedDate)}, $clockStr WIB',
                  'status': statusCtrl.text.trim(),
                  'repeatType': repeatType,
                  'repeatWeeks': (repeatWeeks.toList()..sort()),
                  'notifyEnabled': notifyEnabled,
                  'notifyDaysBefore': daysBeforeVal < 0 ? 0 : daysBeforeVal,
                  'notifyHour': notifyTime.hour,
                  'notifyMinute': notifyTime.minute,
                };

                setState(() {
                  if (existingSchedule == null) {
                    _schedules.insert(0, newItem);
                  } else if (index != null) {
                    _schedules[index] = newItem;
                  }
                  _selectedDate = pickedDate;
                  _focusedMonth = DateTime(pickedDate.year, pickedDate.month, 1);
                });
                await _saveSchedules();
                await _syncNotification(newItem);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted && notifyEnabled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Pengingat dijadwalkan ${daysBeforeVal == 0 ? "pada Hari H" : "H-$daysBeforeVal"}')),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSchedule(int index) async {
    if (index < 0 || index >= _schedules.length) return;
    final item = _schedules[index];
    setState(() => _schedules.removeAt(index));
    await _saveSchedules();
    try {
      await NotificationService.cancelReminder(_notifIdFor(item['id'].toString()));
    } catch (_) {}
  }

  Future<void> _clearAllSchedules() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bersihkan Semua Jadwal?'),
        content: const Text('Semua jadwal kajian dan khutbah akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final item in _schedules) {
      try {
        await NotificationService.cancelReminder(_notifIdFor(item['id'].toString()));
      } catch (_) {}
    }
    setState(() => _schedules.clear());
    await _saveSchedules();
  }

  List<DateTime> _buildCalendarDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1; // Senin = 1
    final list = <DateTime>[];
    for (int i = leadingBlanks; i > 0; i--) {
      list.add(firstDay.subtract(Duration(days: i)));
    }
    for (int d = 1; d <= daysInMonth; d++) {
      list.add(DateTime(month.year, month.month, d));
    }
    while (list.length % 7 != 0) {
      list.add(list.last.add(const Duration(days: 1)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final calendarDays = _buildCalendarDays(_focusedMonth);
    final selectedKey = _dateKey(_selectedDate);
    final selectedSchedules = _schedules.where((s) => _occursOnDate(s, _selectedDate)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Jadwal & Kalender Jawa', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (_schedules.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 19, color: Colors.red),
              tooltip: 'Bersihkan Semua Jadwal',
              onPressed: _clearAllSchedules,
            ),
          IconButton(
            icon: const Icon(LucideIcons.calendarCheck, size: 20),
            tooltip: 'Hari Ini',
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _focusedMonth = DateTime(now.year, now.month, 1);
                _selectedDate = DateTime(now.year, now.month, now.day);
              });
            },
          ),
          const HomeActionButton(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D7377)))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 84),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Bulan + Navigasi
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.chevronLeft),
                          onPressed: () => setState(() {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                          }),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_focusedMonth),
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0D7377)),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.chevronRight),
                          onPressed: () => setState(() {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                          }),
                        ),
                      ],
                    ),
                  ),

                  // Nama Hari
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Ahd'].map((d) {
                        final isJum = d == 'Jum';
                        return Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isJum ? const Color(0xFF0D7377) : Colors.grey[700],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Grid Kalender + Pasaran Jawa
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: calendarDays.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 0.92,
                      ),
                      itemBuilder: (_, idx) {
                        final day = calendarDays[idx];
                        final inMonth = day.month == _focusedMonth.month;
                        final key = _dateKey(day);
                        final isSelected = key == selectedKey;
                        final hasEvent = _schedules.any((s) => _occursOnDate(s, day));
                        final isFriday = day.weekday == DateTime.friday;

                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() => _selectedDate = day),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0D7377)
                                  : (isFriday && inMonth ? const Color(0xFF0D7377).withValues(alpha: 0.06) : Colors.transparent),
                              borderRadius: BorderRadius.circular(8),
                              border: hasEvent && !isSelected
                                  ? Border.all(color: const Color(0xFFD4A843), width: 1.3)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : (inMonth ? (isFriday ? const Color(0xFF0D7377) : Colors.black87) : Colors.grey[400]),
                                  ),
                                ),
                                Text(
                                  getPasaranShort(day),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: isSelected
                                        ? Colors.amber[200]
                                        : (inMonth ? Colors.grey[600] : Colors.grey[400]),
                                  ),
                                ),
                                if (hasEvent)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.amber[300] : const Color(0xFFD4A843),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Info Tanggal Terpilih (Lengkap dengan Pasaran Jawa)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7377).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              getDayAndPasaran(_selectedDate),
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0D7377)),
                            ),
                            Text(
                              DateFormat('dd MMMM yyyy').format(_selectedDate),
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D7377),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(LucideIcons.plus, size: 15),
                          label: const Text('Jadwalkan', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showScheduleDialog(),
                        ),
                      ],
                    ),
                  ),

                  if (selectedSchedules.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'Jadwal pada ${getDayAndPasaran(_selectedDate)}',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...selectedSchedules.map((item) => _buildScheduleCard(item, _schedules.indexOf(item))),
                  ],

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'Semua Jadwal (${_schedules.length})',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_schedules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Belum ada jadwal kajian atau khutbah.')),
                    )
                  else
                    ...List.generate(_schedules.length, (i) => _buildScheduleCard(_schedules[i], i)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D7377),
        foregroundColor: Colors.white,
        onPressed: () => _showScheduleDialog(),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Tambah Jadwal'),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> item, int index) {
    final notifyOn = item['notifyEnabled'] == true;
    final daysBefore = (item['notifyDaysBefore'] as int?) ?? 1;
    final dateStr = (item['date'] ?? '').toString();
    final parsed = DateTime.tryParse(dateStr);
    final jawaLabel = parsed != null ? '${getDayAndPasaran(parsed)} (${DateFormat('dd MMM').format(parsed)})' : (item['time'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      elevation: 0.6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(
          (item['title'] ?? '').toString(),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.calendar, size: 13, color: Color(0xFF0D7377)),
                const SizedBox(width: 5),
                Expanded(child: Text('$jawaLabel • ${item['clock'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
            if ((item['repeatType'] ?? 'none') != 'none') ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(LucideIcons.repeat, size: 12, color: Colors.purple),
                  const SizedBox(width: 5),
                  Text(
                    _repeatLabel(item['repeatType']?.toString(), parsed, repeatWeeks: item['repeatWeeks'] as List?),
                    style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            if ((item['location'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, size: 13, color: Colors.grey),
                  const SizedBox(width: 5),
                  Expanded(child: Text(item['location'].toString(), style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                ],
              ),
            ],
            if (notifyOn) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.bellRing, size: 12, color: Color(0xFFD4A843)),
                  const SizedBox(width: 4),
                  Text(
                    'Pengingat: ${daysBefore == 0 ? "Hari H" : "H-$daysBefore"} jam ${(item['notifyHour'] ?? 7).toString().padLeft(2, '0')}:${(item['notifyMinute'] ?? 0).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9C761F), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _showScheduleDialog(existingSchedule: item, index: index);
            if (v == 'delete') _deleteSchedule(index);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}
