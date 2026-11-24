import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MaterialEditorScreen extends StatefulWidget {
  const MaterialEditorScreen({super.key});

  @override
  State<MaterialEditorScreen> createState() => _MaterialEditorScreenState();
}

class _MaterialEditorScreenState extends State<MaterialEditorScreen> {
  final TextEditingController _titleCtrl = TextEditingController(text: 'Khutbah Jum\'at: Menjaga Keikhlasan dalam Beramal');
  final TextEditingController _contentCtrl = TextEditingController(
    text: '''إِنَّ الْحَمْدَ لِلَّهِ نَحْمَدُهُ وَنَسْتَعِيْنُهُ وَنَسْتَغْفِرُهُ...

Ikhwatal Iman rahimakumullah,
Marilah kita senantiasa meningkatkan ketakwaan kepada Allah Ta'ala dengan sebenar-benar takwa.

Dalil Utama:
وَمَا أُمِرُوا إِلَّا لِيَعْبُدُوا اللَّهَ مُخْلِصِينَ لَهُ الدِّينَ حُنَفَاءَ
"Padahal mereka tidak disuruh kecuali supaya menyembah Allah dengan memurnikan ketaatan kepada-Nya dalam (menjalankan) agama yang lurus..." (QS. Al-Bayyinah: 5)

Poin-poin Pembahasan:
1. Hakikat Ikhlas menurut para Salafus Shalih
2. Bahaya Riya' dan Sum'ah yang merusak pahala amal
3. Doa berlindung dari syirik kecil (riya')''',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editor Materi Kajian & Khutbah', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks materi siap dibagikan')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Materi berhasil disimpan')));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Judul Kajian / Khutbah',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Template Khutbah'),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.format_quote, size: 16),
                  label: const Text('Sisipkan Ayat'),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 14, height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'Tuliskan draf materi kajian, khutbah, atau kultum di sini...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
