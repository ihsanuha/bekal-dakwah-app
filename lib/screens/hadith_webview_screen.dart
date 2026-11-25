import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HadithWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const HadithWebViewScreen({
    super.key,
    required this.url,
    this.title = 'Detail Hadits (hdith.com)',
  });

  @override
  State<HadithWebViewScreen> createState() => _HadithWebViewScreenState();
}

class _HadithWebViewScreenState extends State<HadithWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (_) {
            _controller.runJavaScript('''
              (function() {
                var vp = document.querySelector('meta[name="viewport"]');
                if (vp) {
                  vp.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes');
                }
              })();
            ''');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 18),
              tooltip: 'Kembali',
              onPressed: () async {
                if (await _controller.canGoBack()) {
                  await _controller.goBack();
                }
              },
            ),
            IconButton(
              icon: const Icon(LucideIcons.arrowRight, size: 18),
              tooltip: 'Maju',
              onPressed: () async {
                if (await _controller.canGoForward()) {
                  await _controller.goForward();
                }
              },
            ),
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              tooltip: 'Muat Ulang',
              onPressed: () => _controller.reload(),
            ),
            IconButton(
              icon: const Icon(LucideIcons.copy, size: 17),
              tooltip: 'Salin URL',
              onPressed: () async {
                final currentUrl = await _controller.currentUrl() ?? widget.url;
                await Clipboard.setData(ClipboardData(text: currentUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tautan halaman tersalin')),
                  );
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
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
