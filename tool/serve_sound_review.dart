// Local review artifacts only; never deploys or writes application settings.
import 'dart:io';

Future<void> main() async {
  final workspace = File.fromUri(Platform.script).parent.parent;
  final root = Directory.fromUri(
    workspace.uri.resolve('build/sound-options-2026-10-24/'),
  );
  if (!root.existsSync()) {
    throw StateError('Generate sound review artifacts first.');
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 9114);
  stdout.writeln('Sound choices: http://127.0.0.1:9114/');
  await for (final request in server) {
    try {
      final path = request.uri.path == '/'
          ? 'index.html'
          : request.uri.path.substring(1);
      final file = File.fromUri(root.uri.resolve(path));
      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response.statusCode = 405;
      } else if (request.uri.pathSegments.any(
            (s) => s == '..' || s.contains('\\'),
          ) ||
          !file.uri.toString().startsWith(root.uri.toString())) {
        request.response.statusCode = 403;
      } else if (!file.existsSync()) {
        request.response.statusCode = 404;
      } else {
        final mime = switch (path.split('.').last) {
          'html' => 'text/html; charset=utf-8',
          'js' => 'application/javascript; charset=utf-8',
          'css' => 'text/css; charset=utf-8',
          'json' => 'application/json; charset=utf-8',
          'wav' => 'audio/wav',
          'png' => 'image/png',
          _ => 'application/octet-stream',
        };
        request.response.headers.set('Content-Type', mime);
        request.response.headers.set('Cache-Control', 'no-store');
        request.response.headers.set('X-Content-Type-Options', 'nosniff');
        request.response.contentLength = await file.length();
        if (request.method == 'GET') {
          await request.response.addStream(file.openRead());
        }
      }
    } catch (_) {
      if (!request.response.headers.chunkedTransferEncoding) {
        request.response.statusCode = 500;
      }
    }
    await request.response.close();
  }
}
