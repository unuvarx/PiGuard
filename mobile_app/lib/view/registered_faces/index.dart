import 'package:flutter/material.dart';
import 'package:mobile_app/view_model/registered_faces/registered_faces_vm.dart';
import 'package:provider/provider.dart';

class RegisteredFaces extends StatefulWidget {
  const RegisteredFaces({super.key});

  @override
  State<RegisteredFaces> createState() => _RegisteredFacesState();
}

class _RegisteredFacesState extends State<RegisteredFaces> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => Provider.of<RegisteredFacesViewModel>(
        context,
        listen: false,
      ).loadFaces(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tanımlı Yüzler")),
      body: Consumer<RegisteredFacesViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.faces.isEmpty) {
            return const Center(child: Text("Kayıtlı yüz bulunamadı"));
          }

          return ListView.builder(
            itemCount: vm.faces.length,
            itemBuilder: (context, index) {
              final face = vm.faces[index];

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
