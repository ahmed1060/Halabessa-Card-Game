import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../game/presentation/widgets/table_style.dart';

class LanQrScanner extends StatefulWidget {
  const LanQrScanner({super.key});
  @override
  State<LanQrScanner> createState() => _LanQrScannerState();
}

class _LanQrScannerState extends State<LanQrScanner>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    autoStart: false,
    formats: [BarcodeFormat.qrCode],
  );
  bool _finished = false, _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted || _finished) return;
    try {
      await _camera.start();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_camera.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TableStyle.ink,
    appBar: AppBar(title: Text('lan_scan'.tr())),
    body: _failed
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('lan_camera_help'.tr(), style: TableStyle.label),
            ),
          )
        : MobileScanner(
            controller: _camera,
            onDetect: (capture) {
              if (_finished || !mounted) return;
              final values = capture.barcodes
                  .map((b) => b.rawValue)
                  .whereType<String>()
                  .where((s) => s.startsWith('halabessa-lan:'));
              if (values.isEmpty) return;
              _finished = true;
              unawaited(_camera.stop());
              Navigator.pop(context, values.first);
            },
          ),
  );
}
