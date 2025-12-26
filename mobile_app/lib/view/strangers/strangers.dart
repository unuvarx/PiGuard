import 'package:flutter/material.dart';
import '../../view_model/strangers/strangers_vm.dart';

class Strangers extends StatefulWidget {
  const Strangers({super.key});

  @override
  State<Strangers> createState() => _StrangersState();
}

class _StrangersState extends State<Strangers> {
  final StrangersViewModel _vm = StrangersViewModel();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_loaded) {
        _vm.addListener(_onVmChanged);
        _vm.loadStrangers();
        _loaded = true;
      }
    });
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {
      // viewmodel değiştiğinde UI güncellenecek
    });
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await _vm.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final items = _vm.strangers;
    return Scaffold(
      appBar: AppBar(title: const Text("Yabancılar")),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _vm.isLoading && items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? ListView(
                    // RefreshIndicator için ListView olmalı
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text("Hiç yabancı bulunamadı.")),
                    ],
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final s = items[index];
                      final imageUrl = s['image'] as String?;
                      final metadata = s['metadata'] ?? '';
                      final addedAt = s['added_at'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 3x daha büyük önizleme (56 -> 168)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 168,
                                height: 168,
                                child: imageUrl != null
                                    ? Image.network(
                                        imageUrl,
                                        width: 168,
                                        height: 168,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                                      )
                                    : const Icon(Icons.person, size: 48),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("ID: ${s['id']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  if (metadata != null) Text(metadata.toString()),
                                  if (addedAt != null) Text(addedAt.toString(), style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
