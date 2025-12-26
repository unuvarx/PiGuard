import 'package:flutter/material.dart';
import 'package:mobile_app/view_model/registered_faces/registered_faces_vm.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/main.dart';

class RegisteredFaces extends StatefulWidget {
  const RegisteredFaces({super.key});

  @override
  State<RegisteredFaces> createState() => _RegisteredFacesState();
}

class _RegisteredFacesState extends State<RegisteredFaces> with RouteAware {
  RegisteredFacesViewModel? vm;
  bool _subscribed = false;
  DateTime? _lastLoadAttempt;

  void _tryScheduleLoad() {
    final now = DateTime.now();
    // Aynı işlem kısa sürede tekrar tetiklenmesin
    if (_lastLoadAttempt != null &&
        now.difference(_lastLoadAttempt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastLoadAttempt = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      vm?.loadFaces();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    vm ??= Provider.of<RegisteredFacesViewModel>(context, listen: false);
    final route = ModalRoute.of(context);
    // subscribe işlemi sadece bir kez yapılır ve ilk görünürlük burada ele alınır
    if (route != null && !_subscribed) {
      routeObserver.subscribe(this, route);
      _subscribed = true;
      // Eğer ilk açılışta görünürse hemen yükle (post-frame)
      if (route.isCurrent) {
        _tryScheduleLoad();
      }
    }
  }

  @override
  void dispose() {
    if (_subscribed) {
      routeObserver.unsubscribe(this);
      _subscribed = false;
    }
    super.dispose();
  }

  @override
  void didPush() {
    _tryScheduleLoad();
  }

  @override
  void didPopNext() {
    _tryScheduleLoad();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tanımlı Yüzler")),
      body: Consumer<RegisteredFacesViewModel>(
        builder: (context, vmWatch, child) {
          if (vmWatch.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vmWatch.faces.isEmpty) {
            return const Center(child: Text("Kayıtlı yüz bulunamadı"));
          }

          return ListView.builder(
            itemCount: vmWatch.faces.length,
            itemBuilder: (context, index) {
              final face = vmWatch.faces[index];

              final List images = face["images"] ?? [];

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(face["name"] ?? "İsim yok"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ID: ${face["id"].toString()}"),
                      const SizedBox(height: 5),
                      if (images.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: images.map((imgUrl) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: Image.network(
                                  imgUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      else
                        const Icon(Icons.person, size: 60),
                    ],
                  ),

                ),
              );
            },
          );
        },
      ),
    );
  }
}
