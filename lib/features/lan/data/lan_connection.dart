import 'package:flutter/foundation.dart';
import '../domain/lan_protocol.dart';

abstract class LanConnection extends ChangeNotifier {
  Map<String, dynamic>? get snapshot;
  String get uid;
  String get status;
  int get clockOffsetMs;
  Future<bool> command(String action, Map<String, dynamic> payload);
  Future<void> reconnect();
  Future<void> suspend() async {}
  Future<void> close({bool leave = true});
}

abstract interface class LanHostedRoom {
  LanConnection get local;
  List<String> get addresses;
  int get port;
  String get room;
  LanInvitation invitation(String address);
  Future<void> start({String mode = 'classic'});
  Future<void> close();
}
