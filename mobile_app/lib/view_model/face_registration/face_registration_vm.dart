import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile_app/services/uploadImages/index.dart';

class FaceRegistrationViewModel extends ChangeNotifier {
  CameraController? controller;
  List<CameraDescription>? cameras;

  bool isDetecting = false;
  bool isBusy = false;
  bool isPoseValid = false;
  String? statusMessage;
  bool dialogShown = false;
  final List<String> steps = ["FRONT", "RIGHT ->", "<- LEFT"];
  int currentStep = 0;

  Color frameColor = Colors.red;
  List<String> capturedImages = [];

  late FaceDetector faceDetector;

  bool _streaming = false;

  FaceRegistrationViewModel() {
    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        enableContours: false,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    initCamera();
  }

  @override
  void dispose() {
    stopImageStream();
    controller?.dispose();
    faceDetector.close();
    super.dispose();
  }

  Future<void> initCamera() async {
    cameras = await availableCameras();
    final front = cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await controller!.initialize();

    notifyListeners();
  }

  Future<void> startImageStream() async {
    if (controller == null || !controller!.value.isInitialized || _streaming) return;
    try {
      _streaming = true;
      controller!.startImageStream((image) {
        if (!isDetecting && !isBusy) {
          isDetecting = true;
          processCameraImage(image);
        }
      });
    } catch (e) {
      _streaming = false;
    }
  }

  Future<void> stopImageStream() async {
    if (!_streaming || controller == null) return;
    try {
      await controller!.stopImageStream();
    } catch (_) {
      // bazı platformlarda desteklenmeyebilir
    } finally {
      _streaming = false;
      isDetecting = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    final rotation =
    InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        (Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21);

    if (image.planes.isEmpty) return null;

    final bytes = _concatenatePlanes(image.planes);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> processCameraImage(CameraImage image) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        isDetecting = false;
        return;
      }

      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        frameColor = Colors.red;
        isPoseValid = false;
        notifyListeners();
        isDetecting = false;
        return;
      }

      final face = faces.first;
      final rotY = face.headEulerAngleY ?? 0;
      final rotX = face.headEulerAngleX ?? 0;

      final correct = _checkPose(rotX, rotY);

      frameColor = correct ? Colors.green : Colors.red;
      isPoseValid = correct;
      notifyListeners();
    } catch (_) {} finally {
      isDetecting = false;
    }
  }

  bool _checkPose(double rotX, double rotY) {
    if (currentStep >= steps.length) return false;

    switch (steps[currentStep]) {
      case "FRONT":
        return rotY.abs() < 10 && rotX.abs() < 10;
      case "RIGHT ->":
        return rotY > 25;
      case "<- LEFT":
        return rotY < -25;
    }
    return false;
  }

  Future<void> takePicture() async {
    if (controller == null || !controller!.value.isInitialized || isBusy) return;

    isBusy = true;
    notifyListeners();

    try {
      final XFile file = await controller!.takePicture();
      final dir = await getTemporaryDirectory();

      final newFile = File(
        "${dir.path}/${steps[currentStep]}_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      await newFile.writeAsBytes(await file.readAsBytes());
      capturedImages.add(newFile.path);

      currentStep++;
      frameColor = Colors.red;
      isPoseValid = false;

      notifyListeners();

      // Son adımda 3 fotoğrafı upload et
      if (currentStep >= steps.length) {
        try {
          await uploadImages("user", capturedImages);
          statusMessage = "Face registration successful!";
        } catch (e) {
          statusMessage = "Face registration failed: $e";
        }
        notifyListeners();
      }

    } catch (_) {} finally {
      isBusy = false;
      notifyListeners();
    }
  }
  void clearStatusMessage() {
    statusMessage = null;
    dialogShown = false;
    currentStep = 0;
    capturedImages.clear();
    frameColor = Colors.red;
    isPoseValid = false;
    notifyListeners();
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final buffer = WriteBuffer();
    for (final p in planes) {
      buffer.putUint8List(p.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }
}
