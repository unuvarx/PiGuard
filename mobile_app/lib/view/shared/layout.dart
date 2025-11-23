import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/view_model/shared/layout_vm.dart';
import 'package:mobile_app/view/home/index.dart';
import 'package:mobile_app/view/live_camera/index.dart';
import 'package:mobile_app/view/strangers/strangers.dart';
import 'package:mobile_app/view/face_registration/index.dart';
import 'package:mobile_app/view/registered_faces/index.dart';

class Layout extends StatefulWidget {
  const Layout({super.key}); // body kaldırıldı, Layout sabit kalacak

  @override
  State<Layout> createState() => _Layout();
}

class _Layout extends State<Layout> {
  @override
  Widget build(BuildContext context) {
    return Consumer<LayoutViewModel>(
      builder: (context, vm, _) {
        // Sayfaları bir kere tanımlayıp IndexedStack ile göstermek, layout'ın yeniden oluşturulmasını engeller ve her sayfanın state'ini korur.
        final pages = <Widget>[
          const HomeIndex(),
          const LiveCamera(),
          const Strangers(),
          const FaceRegistration(),
          const RegiteredFaces(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('PiGuard', style: TextStyle(color: Colors.white)),
            centerTitle: true,
            backgroundColor: Colors.indigo,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          drawer: Drawer(
            backgroundColor: Colors.indigo,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  height: 200,
                  color: Colors.indigo,
                  padding: const EdgeInsets.only(left: 16, top: 12, bottom: 0),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Guard Bar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                // Her ListTile bir Container ile sarıldı; 1px beyaz border eklendi.
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.home, color: Colors.white),
                    title: const Text('Home', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      vm.selectedIndex = 0;
                      Navigator.pop(context);
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.video_camera_back, color: Colors.white),
                    title: const Text('Live Camera Stream', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      vm.selectedIndex = 1;
                      Navigator.pop(context);
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.security, color: Colors.white),
                    title: const Text('Strangers', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      vm.selectedIndex = 2;
                      Navigator.pop(context);
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.add_reaction, color: Colors.white),
                    title: const Text('Face Registration', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      vm.selectedIndex = 3;
                      Navigator.pop(context);
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.face, color: Colors.white),
                    title: const Text('Registered Faces', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      vm.selectedIndex = 4;
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
          // IndexedStack ile sayfalar arasında geçiş yapılıyor; Layout sabit kalır, her sayfanın state'i korunur.
          body: IndexedStack(index: vm.selectedIndex, children: pages),
        );
      },
    );
  }
}
