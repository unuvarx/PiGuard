import 'package:flutter/material.dart';

class LayoutViewModel with ChangeNotifier {
  var _selectedIndex = 0;

  get selectedIndex => _selectedIndex;

  set selectedIndex(value) {
    _selectedIndex = value;
    notifyListeners();
  }
}