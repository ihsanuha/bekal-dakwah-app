import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Tombol cepat untuk langsung kembali ke halaman Beranda aplikasi
class HomeActionButton extends StatelessWidget {
  final Color? color;
  const HomeActionButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(LucideIcons.home, size: 19, color: color),
      tooltip: 'Kembali ke Home Aplikasi',
      onPressed: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }
}
