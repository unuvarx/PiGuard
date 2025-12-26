import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_app/view/shared/layout.dart';
import 'package:mobile_app/view_model/registered_faces/registered_faces_vm.dart';
import 'package:mobile_app/view_model/shared/layout_vm.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

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
}

class UnuvarMobilya extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Poppins'),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
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
