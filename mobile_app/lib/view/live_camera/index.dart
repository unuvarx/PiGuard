import 'package:flutter/material.dart';
import '../mjpeg/index.dart';
import 'package:mobile_app/main.dart';

class LiveCamera extends StatefulWidget {
  const LiveCamera({super.key});

  @override
  State<LiveCamera> createState() => _LiveCameraState();
}

class _LiveCameraState extends State<LiveCamera> with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _blinkController;
  late final Animation<double> _opacityAnim;
  bool _isActive = false;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
    _isActive = route?.isCurrent ?? false;
    if (_isActive) _blinkController.repeat(reverse: true);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _blinkController.dispose();
    super.dispose();
  }

  @override
  void didPush() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setActive(true);
    });
  }

  @override
  void didPopNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setActive(true);
    });
  }

  @override
  void didPushNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setActive(false);
    });
  }

  @override
  void didPop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setActive(false);
    });
  }

  void _setActive(bool v) {
    if (_isActive == v) return;
    setState(() {
      _isActive = v;
      if (_isActive) {
        _blinkController.repeat(reverse: true);
      } else {
        _blinkController.stop();
      }
    });
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
      body: _isActive
          ? const MjpegViewer(
              url: "http://100.80.70.109:8000/video",
              fit: BoxFit.contain,
            )
          : const Center(child: Text("Live kamera pasif durumda.")),
    );
  }
}
