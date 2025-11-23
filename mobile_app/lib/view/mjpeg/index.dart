import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Tek satırda kullanabileceğiniz MJPEG widget
class MjpegViewer extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const MjpegViewer({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer> {
  Uint8List? _frame;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  // basit yardımcı: bir dizi içinde bir desenin başlangıç indeksini bul
  int _indexOfSequence(List<int> data, List<int> pattern, [int start = 0]) {
    final int dataLen = data.length;
    final int patLen = pattern.length;
    if (patLen == 0 || dataLen < patLen) return -1;
    for (int i = start; i <= dataLen - patLen; i++) {
      bool match = true;
      for (int j = 0; j < patLen; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  void _startStream() async {
    final client = http.Client();
    List<int> buffer = [];

    try {
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await client.send(request);

      const List<int> soi = [0xFF, 0xD8];
      const List<int> eoi = [0xFF, 0xD9];

      response.stream.listen((chunk) {
        // eklenen veriyi buffer'a ekle
        buffer.addAll(chunk);

        // buffer çok büyürse eski kısımları at (memory leak önleme)
        const int maxBuffer = 5 * 1024 * 1024; // 5 MB
        if (buffer.length > maxBuffer) {
          buffer = buffer.sublist(buffer.length - 1024 * 1024); // son 1MB'ı tut
        }

        while (true) {
          // SOI'yi ara
          final int start = _indexOfSequence(buffer, soi);
          if (start == -1) {
            // henüz JPEG başlangıcı yok, bekle
            break;
          }

          // EOI'yi SOI sonrası ara
          final int end = _indexOfSequence(buffer, eoi, start + 2);
          if (end == -1) {
            // henüz tüm frame gelmedi
            break;
          }

          // frame baştan son (EOI dahil) alınır
          final frame = Uint8List.fromList(buffer.sublist(start, end + 2));

          // setState sadece mounted ise
          if (mounted) {
            try {
              setState(() {
                _frame = frame;
                _loading = false;
                _error = false;
              });
            } catch (_) {}
          }

          // tüketilen kısmı buffer'dan çıkar
          buffer = buffer.sublist(end + 2);
        }
      }, onDone: () {
        client.close();
      }, onError: (err) {
        client.close();
        if (mounted) {
          setState(() {
            _error = true;
            _loading = false;
          });
        }
      }, cancelOnError: true);
    } catch (e) {
      client.close();
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return Center(child: Text('Canlı yayın alınamadı', style: TextStyle(color: Colors.red[700])));
    }
    return _frame != null
        ? Image.memory(_frame!, gaplessPlayback: true, fit: widget.fit)
        : const Center(child: CircularProgressIndicator());
  }
}
