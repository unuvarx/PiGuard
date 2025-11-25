import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MjpegViewModel with ChangeNotifier {
  final String url;
  Uint8List? frame;
  bool loading = true;
  bool error = false;

  http.Client? _client;
  StreamSubscription<List<int>>? _sub;
  List<int> _buffer = [];

  static const List<int> _soi = [0xFF, 0xD8];
  static const List<int> _eoi = [0xFF, 0xD9];
  static const int _maxBuffer = 5 * 1024 * 1024; // 5 MB

  MjpegViewModel(this.url) {
    start();
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

  Future<void> start() async {
    stop(); // varsa önceki kaynakları temizle
    _client = http.Client();
    _buffer = [];
    loading = true;
    error = false;
    notifyListeners();

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await _client!.send(request);

      _sub = response.stream.listen((chunk) {
        _buffer.addAll(chunk);

        // buffer çok büyürse eski kısımları at (memory leak önleme)
        if (_buffer.length > _maxBuffer) {
          _buffer = _buffer.sublist(_buffer.length - 1024 * 1024); // son 1MB'ı tut
        }

        while (true) {
          final int start = _indexOfSequence(_buffer, _soi);
          if (start == -1) break;
          final int end = _indexOfSequence(_buffer, _eoi, start + 2);
          if (end == -1) break;

          final frameBytes = Uint8List.fromList(_buffer.sublist(start, end + 2));

          // frame güncelle
          frame = frameBytes;
          loading = false;
          error = false;
          notifyListeners();

          // tüketilen kısmı buffer'dan çıkar
          _buffer = _buffer.sublist(end + 2);
        }
      }, onDone: () {
        stop();
      }, onError: (err) {
        stop();
        error = true;
        loading = false;
        notifyListeners();
      }, cancelOnError: true);
    } catch (e) {
      stop();
      error = true;
      loading = false;
      notifyListeners();
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    try {
      _client?.close();
    } catch (_) {}
    _client = null;
    _buffer.clear();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}