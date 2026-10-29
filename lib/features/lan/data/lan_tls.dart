import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

/// Per-room identity. Never persisted or used by the online HTTP client.
Map<String, String> generateLanIdentity() {
  final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  final privateKey = pair.privateKey as RSAPrivateKey;
  final csr = X509Utils.generateRsaCsrPem(
    {'CN': 'Halabessa local room'},
    privateKey,
    pair.publicKey as RSAPublicKey,
  );
  final certificate = X509Utils.generateSelfSignedCertificate(
    privateKey,
    csr,
    7,
    notBefore: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
  );
  return {
    'certificate': certificate,
    'key': CryptoUtils.encodeRSAPrivateKeyToPem(privateKey),
  };
}

class LanTlsIdentity {
  LanTlsIdentity(Map<String, String> pem) {
    final certificate = pem['certificate']!;
    final base64 = certificate
        .split('\n')
        .where((line) => !line.startsWith('-----'))
        .join()
        .replaceAll(RegExp(r'\s'), '');
    fingerprint = sha256.convert(base64Decode(base64)).toString();
    context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(Uint8List.fromList(utf8.encode(certificate)))
      ..usePrivateKeyBytes(Uint8List.fromList(utf8.encode(pem['key']!)));
  }
  late final SecurityContext context;
  late final String fingerprint;
}
