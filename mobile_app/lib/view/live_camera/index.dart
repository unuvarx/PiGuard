import 'package:flutter/material.dart';
import '../mjpeg/index.dart';

class LiveCamera extends StatefulWidget {
  const LiveCamera({super.key});

  @override
  State<LiveCamera> createState() => _LiveCameraState();
}

class _LiveCameraState extends State<LiveCamera> with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.2).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _blinkController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Live Camera"),
            const SizedBox(width: 10),
            FadeTransition(
              opacity: _opacityAnim,
              child: const Icon(Icons.radio_button_checked, color: Colors.red),
            ),
          ],
        ),
      ),
      body: const MjpegViewer(
        url: "http://100.80.70.109:8000/video",
        fit: BoxFit.contain,
      ),
    );
  }
}
