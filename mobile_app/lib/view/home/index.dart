import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/view_model/shared/layout_vm.dart';

class HomeIndex extends StatefulWidget {
  const HomeIndex({super.key});

  @override
  State<HomeIndex> createState() => _HomeIndexState();
}

class _HomeIndexState extends State<HomeIndex> {
  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<LayoutViewModel>(context);
    return Center(
      child: Text("Ana sayfa"),
    );
  }
}
