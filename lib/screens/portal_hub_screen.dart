import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PortalHubScreen extends StatefulWidget {
  final int initialIndex;
  const PortalHubScreen({super.key, this.initialIndex = 0});

  @override
  State<PortalHubScreen> createState() => _PortalHubScreenState();
}

class _PortalHubScreenState extends State<PortalHubScreen> {
  static const List<Map<String, String>> _portals = [
    {'name': 'Tafsir.app', 'desc': 'Al-Bahits Al-Qur\'ani', 'url': 'https://tafsir.app/'},
    {'name': 'Takw.in', 'desc': 'Takwin Ar-Rasikhin', 'url': 'https://takw.in/'},
    {'name': 'Hifdh.app', 'desc': 'Hafalan & Muroja\'ah', 'url': 'https://hifdh.app/'},
    {'name': 'Bahith.app', 'desc': 'Pencari Ilmiah', 'url': 'https://bahith.app/'},
    {'name': 'Sunnah.one', 'desc': 'Al-Bahits Al-Haditsi', 'url': 'https://sunnah.one/'},
    {'name': 'Faidah.app', 'desc': 'Fawaid Ulama', 'url': 'https://faidah.app/'},
  ];

  late int _selectedIndex;
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _portals.length - 1);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        ),
      )
      ..loadRequest(Uri.parse(_portals[_selectedIndex]['url']!));
  }

  void _selectPortal(int idx) {
    setState(() {
      _selectedIndex = idx;
      _progress = 0;
    });
    _controller.loadRequest(Uri.parse(_portals[idx]['url']!));
  }

  @override
  Widget build(BuildContext context) {
    final current = _portals[_selectedIndex];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Portal Riset Ilmiah', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${current['name']} • ${current['desc']}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 18),
              onPressed: () async {
                if (await _controller.canGoBack()) await _controller.goBack();
              },
            ),
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              onPressed: () => _controller.reload(),
            ),
            IconButton(
              icon: const Icon(LucideIcons.home, size: 18),
              onPressed: () => _controller.loadRequest(Uri.parse(current['url']!)),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_portals.length, (i) {
                    final selected = i == _selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          _portals[i]['name']!,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.black87),
                        ),
                        selected: selected,
                        selectedColor: const Color(0xFF0D7377),
                        onSelected: (_) => _selectPortal(i),
                      ),
                    );
                  }),
                ),
              ),
            ),
            if (_progress < 100)
              LinearProgressIndicator(
                value: _progress / 100.0,
                color: const Color(0xFF0D7377),
                minHeight: 2.5,
              ),
            Expanded(
              child: WebViewWidget(
                controller: _controller,
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
