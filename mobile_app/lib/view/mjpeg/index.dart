import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_model/mjpeg/index_vm.dart';

class MjpegViewer extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const MjpegViewer({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MjpegViewModel>(
      create: (_) => MjpegViewModel(url),
      child: Consumer<MjpegViewModel>(
        builder: (context, vm, _) {
          if (vm.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.error) {
            return Center(
                child: Text('Canlı yayın alınamadı',
                    style: TextStyle(color: Colors.red[700])));
          }
          return vm.frame != null
              ? Image.memory(vm.frame!, gaplessPlayback: true, fit: fit)
              : const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
