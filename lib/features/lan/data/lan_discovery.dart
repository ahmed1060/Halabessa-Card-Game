import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import '../domain/lan_protocol.dart';

/// NSD advertisements carry no invitation secret or private resume credential.
class LanDiscovery extends ChangeNotifier {
  nsd.Discovery? _discovery;
  nsd.Registration? _registration;
  bool _disposed = false, failed = false;
  int _epoch = 0;
  List<nsd.Service> get rooms => _discovery?.services.toList() ?? [];
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> browse() async {
    if (_disposed || _discovery != null) return;
    final epoch = _epoch;
    try {
      final discovery = await nsd.startDiscovery(
        lanServiceType,
        ipLookupType: nsd.IpLookupType.v4,
      );
      if (_disposed || epoch != _epoch) {
        await nsd.stopDiscovery(discovery);
        return;
      }
      _discovery = discovery;
      discovery.addListener(_changed);
      failed = false;
      _changed();
    } catch (_) {
      failed = true;
      _changed();
    }
  }

  Future<void> advertise(int port, String name) async {
    final epoch = _epoch;
    try {
      final registration = await nsd.register(
        nsd.Service(
          name:
              'Halabessa ${String.fromCharCodes(lanName(name).runes.take(10))}',
          type: lanServiceType,
          port: port,
        ),
      );
      if (_disposed || epoch != _epoch) {
        await nsd.unregister(registration);
        return;
      }
      _registration = registration;
    } catch (_) {
      failed = true;
      _changed();
    }
  }

  Future<void> stop() async {
    _epoch++;
    final discovery = _discovery, registration = _registration;
    _discovery = null;
    _registration = null;
    discovery?.removeListener(_changed);
    try {
      if (discovery != null) await nsd.stopDiscovery(discovery);
    } catch (_) {}
    try {
      if (registration != null) await nsd.unregister(registration);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    unawaitedStop();
    super.dispose();
  }

  void unawaitedStop() {
    stop();
  }
}
