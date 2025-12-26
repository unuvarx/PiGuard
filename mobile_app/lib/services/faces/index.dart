import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';


Future<String> _getBaseUrl() async {

  final ip = dotenv.env['IP_ADDRESS'] ?? '0.0.0.0';

  final base = "http://$ip:8001";
  print("Using API base: $base");
  return base;
}

Future<List<Map<String, dynamic>>> getFaces() async {
  final base = await _getBaseUrl();
  final uri = Uri.parse("$base/faces");

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

Future<List<Map<String, dynamic>>> getStrangers() async {
  final base = await _getBaseUrl();
  final uri = Uri.parse("$base/strangers");

  try {
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      print("GetStrangers başarılı: ${response.body}");
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      print("GetStrangers hata: ${response.statusCode}");
      print("GetStrangers hata mesajı: ${response.body}");
      return [];
    }
  } catch (e) {
    print("GetStrangers sırasında hata oluştu: $e");
    return [];
  }
}
