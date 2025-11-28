import 'package:flutter/material.dart';
import 'package:mobile_app/services/faces/index.dart';

class RegisteredFacesViewModel extends ChangeNotifier {
  bool isLoading = false;
  List<Map<String, dynamic>> faces = [];

  Future<void> loadFaces() async {
    isLoading = true;
    notifyListeners();

    faces = await getFaces();

    isLoading = false;
    notifyListeners();
  }
}
