import '../domain/lan_protocol.dart';
import 'lan_connection.dart';

Future<LanHostedRoom> hostLanRoom(
  LanGameDriver driver,
  String name, {
  bool loopbackForTesting = false,
}) async => throw UnsupportedError('lan_mobile_only');
Future<LanConnection> joinLanRoom(
  LanInvitation invitation,
  String name, {
  bool loopbackForTesting = false,
}) async => throw UnsupportedError('lan_mobile_only');
