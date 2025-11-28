import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<Map<String, dynamic>>> getFaces() async {
  final uri = Uri.parse("http://100.80.70.109:8001/faces");

  try {
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      print("GetFaces başarılı: ${response.body}");
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      print("GetFaces hata: ${response.statusCode}");
      print("GetFaces hata mesajı: ${response.body}");
      print("GetFaces hata mesajı: ${response}");
      return [];
    }
  } catch (e) {
    print("GetFaces sırasında hata oluştu: $e");
    return [];
  }
}
