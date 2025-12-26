import 'package:flutter/foundation.dart';
import '../../services/faces/index.dart' as faces_service;
import 'dart:async';

class StrangersViewModel extends ChangeNotifier {
  List<Map<String, dynamic>> strangers = [];
  bool isLoading = false;
  DateTime? _lastFetch;
  final Duration _throttle = const Duration(seconds: 2);

  Future<void> loadStrangers({bool force = false}) async {
    if (isLoading) return;
    final now = DateTime.now();
    if (!force && _lastFetch != null && now.difference(_lastFetch!) < _throttle) {
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      final data = await faces_service.getStrangers();
      strangers = data;
      _lastFetch = DateTime.now();
    } catch (e) {
      print("loadStrangers hata: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadStrangers(force: true);
  }
}

