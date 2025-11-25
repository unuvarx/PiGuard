import 'package:flutter/material.dart';
import 'package:mobile_app/view_model/face_registration/face_registration_vm.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

class FaceRegistration extends StatelessWidget {
  const FaceRegistration({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FaceRegistrationViewModel(),
      builder: (context, _) {
        final vm = context.watch<FaceRegistrationViewModel>();

        if (vm.controller == null || !vm.controller!.value.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (vm.statusMessage != null && !vm.dialogShown) {
          vm.dialogShown = true;
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
                  vm.statusMessage!,
                  style: const TextStyle(fontSize: 18),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      vm.clearStatusMessage(); // UI'ı başa döndür
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
              CameraPreview(vm.controller!),
              Center(
                child: Container(
                  width: 280,
                  height: 380,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: vm.frameColor, width: 6),
                    borderRadius: BorderRadius.circular(200),
                  ),
                ),
              ),
              if (vm.currentStep < vm.steps.length)
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
                      "Turn your head:\n${vm.steps[vm.currentStep]}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (vm.currentStep < vm.steps.length)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: vm.isPoseValid && !vm.isBusy ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !vm.isPoseValid || vm.isBusy,
                        child: ElevatedButton.icon(
                          onPressed: () => vm.takePicture(),
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
