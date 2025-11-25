import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

class FaceRegistration extends StatefulWidget {
  const FaceRegistration({super.key});

  @override
  State<FaceRegistration> createState() => _FaceRegistrationState();
}

class _FaceRegistrationState extends State<FaceRegistration> {
  CameraController? _controller;
  List<CameraDescription>? cameras;

  bool isDetecting = false;
  bool isBusy = false;

  // YENİ: Pozisyonun doğru olup olmadığını tutan değişken
  bool isPoseValid = false;

  final List<String> steps = ["ÖN", "SOL", "SAĞ"];
  int currentStep = 0;

  Color frameColor = Colors.red;
  List<String> capturedImages = [];

  late final FaceDetector faceDetector;

  @override
  void initState() {
    super.initState();
    faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        enableContours: false,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    faceDetector.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    cameras = await availableCameras();
    final front = cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
    );

    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();

    if (!mounted) return;

    _controller!.startImageStream((image) {
      if (!isDetecting && !isBusy) {
        isDetecting = true;
        _processCameraImage(image);
      }
    });

    setState(() {});
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = cameras!.firstWhere(
          (element) => element.lensDirection == CameraLensDirection.front,
    );

    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final finalFormat = format ??
        (Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21);

    if (image.planes.isEmpty) return null;

    final bytes = _concatenatePlanes(image.planes);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: finalFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        isDetecting = false;
        return;
      }

      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
            frameColor = Colors.red;
            isPoseValid = false; // Yüz yoksa buton gizlensin
          });
        }
        isDetecting = false;
        return;
      }

      final face = faces.first;
      final rotY = face.headEulerAngleY ?? 0;
      final rotX = face.headEulerAngleX ?? 0;

      bool correct = _checkPose(rotX, rotY);

      if (mounted) {
        setState(() {
          frameColor = correct ? Colors.green : Colors.red;
          isPoseValid = correct; // Poz doğruysa butonu göster
        });
      }

      // ESKİ KOD BURADA FOTOĞRAF ÇEKİYORDU, ARTIK ÇEKMİYOR.
      // Sadece durumu güncelledik.

    } catch (e) {
      print("MLKit Hatası: $e");
    } finally {
      isDetecting = false;
    }
  }

  bool _checkPose(double rotX, double rotY) {
    if (currentStep >= steps.length) return false;

    switch (steps[currentStep]) {
      case "ÖN":
        return rotY.abs() < 10 && rotX.abs() < 10;
      case "SOL":
        return rotY > 25;
      case "SAĞ":
        return rotY < -25;
    }
    return false;
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || isBusy) return;

    setState(() {
      isBusy = true; // Butona tekrar basılmasını engelle
    });

    try {
      final XFile file = await _controller!.takePicture();
      final dir = await getTemporaryDirectory();
      final newFile = File("${dir.path}/${steps[currentStep]}_${DateTime.now().millisecondsSinceEpoch}.jpg");

      await newFile.writeAsBytes(await file.readAsBytes());
      capturedImages.add(newFile.path);

      if (mounted) {
        setState(() {
          currentStep++;
          frameColor = Colors.red;
          isPoseValid = false; // Yeni adıma geçince buton kaybolsun
        });
      }

      if (currentStep >= steps.length) {
        print("TÜM ADIMLAR TAMAMLANDI!");
      }

    } catch (e) {
      print("Fotoğraf çekme hatası: $e");
    } finally {
      // İşlem bitince kilidi aç
      if (mounted) setState(() => isBusy = false);
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer buffer = WriteBuffer();
    for (var p in planes) {
      buffer.putUint8List(p.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (currentStep >= steps.length) {
      return Scaffold(
        appBar: AppBar(title: const Text("Tamamlandı")),
        body: Center(child: Text("Kayıt Başarılı!\n${capturedImages.length} fotoğraf alındı.", textAlign: TextAlign.center)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Yüz Kaydı")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // Rehber Çerçeve
          Center(
            child: Container(
              width: 280,
              height: 380,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                    color: frameColor,
                    width: 6
                ),
                borderRadius: BorderRadius.circular(200),
              ),
            ),
          ),

          // Üst Bilgi
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.black54,
              child: Text(
                "Lütfen başınızı çevirin:\n${steps[currentStep]}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),

          // --- FOTOĞRAF ÇEK BUTONU ---
          // Sadece poz geçerliyse (isPoseValid == true) ve meşgul değilse görünür.
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isPoseValid && !isBusy ? 1.0 : 0.0, // Poz doğru değilse görünmez
                child: IgnorePointer(
                  ignoring: !isPoseValid || isBusy, // Görünmezken tıklanmasın
                  child: ElevatedButton.icon(
                    onPressed: _takePicture,
                    icon: const Icon(Icons.camera_alt, size: 30),
                    label: const Text("FOTOĞRAFI ÇEK", style: TextStyle(fontSize: 20)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)
                        )
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}