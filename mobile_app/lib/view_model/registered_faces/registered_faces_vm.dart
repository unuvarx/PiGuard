import 'package:flutter/material.dart';
import 'package:mobile_app/services/faces/index.dart';

class RegisteredFacesViewModel extends ChangeNotifier {
  bool isLoading = false;
  List<Map<String, dynamic>> faces = [];

  DateTime? _lastLoadedAt;

  Future<void> loadFaces() async {
    final now = DateTime.now();
    if (_lastLoadedAt != null && now.difference(_lastLoadedAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastLoadedAt = now;

    if (isLoading) return;

    isLoading = true;
    notifyListeners();

    try {
      faces = await getFaces();
    } catch (e) {
      // Hata durumunda boş bırak veya logla
      faces = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
