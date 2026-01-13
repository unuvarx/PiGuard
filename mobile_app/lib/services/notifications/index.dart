import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

WebSocketChannel? _channel;
final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
bool _notificationsInitialized = false;

Future<void> _initLocalNotifications() async {
  if (_notificationsInitialized) return;

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  final InitializationSettings initSettings =
      InitializationSettings(android: androidInit, iOS: iosInit);

  await _flutterLocalNotificationsPlugin.initialize(initSettings,
      // payload ile tıklama işlemi yakalanabilir
      onDidReceiveNotificationResponse: (response) {
    // İstenirse burada notification tıklama davranışı ele alınabilir
    print('Bildirim tıklandı payload: ${response.payload}');
  });

  // Android kanal (high importance) oluştur
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'pi_guard_channel',
    'PiGuard Notifications',
    description: 'PiGuard uygulama bildirimleri',
    importance: Importance.high,
  );

  await _flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Android (API 33+) için runtime izni iste (plugin destekliyorsa)
  try {
    final androidImpl = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      // requestPermission() var ise çağır (plugin sürümüne bağlı)
      await androidImpl.requestPermission();
    }
  } catch (e) {
    print('Bildirim izni istenirken hata: $e');
  }

  _notificationsInitialized = true;
}

Future<void> _showNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  await _initLocalNotifications();

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'pi_guard_channel',
    'PiGuard Notifications',
    channelDescription: 'PiGuard uygulama bildirimleri',
    importance: Importance.high,
    priority: Priority.high,
    ticker: 'ticker',
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

  final NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails, iOS: iosDetails);

  await _flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    platformDetails,
    payload: payload,
  );
}

Future<void> startNotifications({required GlobalKey<NavigatorState> navigatorKey}) async {
  final ip = dotenv.env['IP_ADDRESS'] ?? 'PI_IP';
  final uri = Uri.parse('ws://$ip:8000/ws/notifications');

  try {
    // Eğer açık bir kanal varsa kapat
    await _channel?.sink.close();
  } catch (_) {}

  _channel = WebSocketChannel.connect(uri);

  _channel!.stream.listen((message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'stranger_detected') {
        print("YABANCI TESPİT EDİLDİ!");

        // Artık AlertDialog yerine sistem bildirimi göster
        final title = 'Yabancı Tespit Edildi';
        final body = 'Yeni bir yabancı kişi tespit edildi.';
        _showNotification(title: title, body: body, payload: jsonEncode(data));
      } else {
        // Diğer mesaj tipleri için istenirse burada işlem eklenebilir
        print("WS mesajı: $data");
      }
    } catch (e) {
      print("WebSocket mesajı işlenirken hata: $e");
    }
  }, onError: (error) {
    print("WebSocket hata: $error");
  }, onDone: () {
    print("WebSocket bağlantısı kapandı.");
  });
}

Future<void> stopNotifications() async {
  try {
    await _channel?.sink.close();
  } catch (e) {
    print("WebSocket kapatılırken hata: $e");
  } finally {
    _channel = null;
  }
}
