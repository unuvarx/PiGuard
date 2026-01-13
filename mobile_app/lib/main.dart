import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_app/view/shared/layout.dart';
import 'package:mobile_app/view_model/registered_faces/registered_faces_vm.dart';
import 'package:mobile_app/view_model/shared/layout_vm.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile_app/services/notifications/index.dart' as notifications;

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

// Global navigator key, bildirimleri göstermek için kullanılacak
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = new MyHttpOverrides();
  await dotenv.load(fileName: "assets/.env");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (BuildContext context) => LayoutViewModel(),
        ),
        ChangeNotifierProvider(
          create: (BuildContext context) => RegisteredFacesViewModel(),
        ),
      ],
      child: UnuvarMobilya(),
    ),
  );

  // Uygulama başlatıldıktan sonra websocket bildirim servisini başlat
  await notifications.startNotifications(navigatorKey: navigatorKey);
}

class UnuvarMobilya extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Poppins'),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      navigatorKey: navigatorKey, // burada veriyoruz
      home: const Layout(),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
