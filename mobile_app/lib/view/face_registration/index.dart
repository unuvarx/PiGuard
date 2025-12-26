import 'package:flutter/material.dart';
import 'package:mobile_app/view_model/face_registration/face_registration_vm.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:mobile_app/main.dart'; // routeObserver

class FaceRegistration extends StatefulWidget {
  const FaceRegistration({super.key});

  @override
  State<FaceRegistration> createState() => _FaceRegistrationState();
}

class _FaceRegistrationState extends State<FaceRegistration> with RouteAware, WidgetsBindingObserver {
  late final FaceRegistrationViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = FaceRegistrationViewModel();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
    // if page already visible at first build, başlat (post-frame)
    if (route?.isCurrent ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        vm.startImageStream();
      });
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    vm.dispose();
    super.dispose();
  }

  // RouteAware callbacks
  @override
  void didPush() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.startImageStream();
    });
  }

  @override
  void didPopNext() {
    // geri dönüldüğünde görünür oldu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.startImageStream();
    });
  }

  @override
  void didPushNext() {
    // başka sayfa üstüne geldi -> durdur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.stopImageStream();
    });
  }

  @override
  void didPop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.stopImageStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FaceRegistrationViewModel>.value(
      value: vm,
      builder: (context, _) {
        final vmWatch = context.watch<FaceRegistrationViewModel>();

        if (vmWatch.controller == null || !vmWatch.controller!.value.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (vmWatch.statusMessage != null && !vmWatch.dialogShown) {
          vmWatch.dialogShown = true;
          Future.microtask(() {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.white,
                title: Row(
                  children: const [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 10),
                    Text("Message"),
                  ],
                ),
                content: Text(
                  vmWatch.statusMessage!,
                  style: const TextStyle(fontSize: 18),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      vmWatch.clearStatusMessage(); // UI'ı başa döndür
                    },
                    child: const Text(
                      "Ok",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            );
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Face Registration")),
          body: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(vmWatch.controller!),
              Center(
                child: Container(
                  width: 280,
                  height: 380,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: vmWatch.frameColor, width: 6),
                    borderRadius: BorderRadius.circular(200),
                  ),
                ),
              ),
              if (vmWatch.currentStep < vmWatch.steps.length)
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Turn your head:\n${vmWatch.steps[vmWatch.currentStep]}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (vmWatch.currentStep < vmWatch.steps.length)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: vmWatch.isPoseValid && !vmWatch.isBusy ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !vmWatch.isPoseValid || vmWatch.isBusy,
                        child: ElevatedButton.icon(
                          onPressed: () => vmWatch.takePicture(),
                          icon: const Icon(Icons.camera_alt, size: 30),
                          label: const Text(
                            "Capture",
                            style: TextStyle(fontSize: 20),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
