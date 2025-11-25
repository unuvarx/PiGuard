import 'package:http/http.dart' as http;
import 'dart:io';

Future<void> uploadImages(String name, List<String> imagePaths) async {
  final uri = Uri.parse("http://100.80.70.109:8001/upload_face");

  final request = http.MultipartRequest('POST', uri);

  request.fields['name'] = name;

  for (int i = 0; i < imagePaths.length; i++) {
    final file = await http.MultipartFile.fromPath('image$i', imagePaths[i]);
    request.files.add(file);
  }

  try {
    final response = await request.send();

    if (response.statusCode == 200) {
      print("Yüz fotoğrafları başarıyla yüklendi!");
    } else {
      print("Yükleme hatası: ${response.statusCode}");
    }
  } catch (e) {
    print("Fotoğraf yükleme sırasında hata oluştu: $e");
  }
}
