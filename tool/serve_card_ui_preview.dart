// Local QA host only. No deployment or remote network binding.
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final workspace = File.fromUri(Platform.script).parent.parent;
  final root = Directory.fromUri(
    workspace.uri.resolve(
      arguments.isEmpty
          ? 'build/card-ui-refinements-web/'
          : '${arguments.first}/',
    ),
  );
  if (!root.uri.toString().startsWith(workspace.uri.toString())) {
    throw ArgumentError('Preview root must remain inside the workspace');
  }
  if (!root.existsSync()) throw StateError('Build the local preview first.');
  final port = arguments.length < 2 ? 9113 : int.parse(arguments[1]);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln(
    'Local refinement preview: http://127.0.0.1:$port/play.html?renderer=flutter#/game',
  );
  await for (final request in server) {
    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response.statusCode = 405;
      } else if (request.uri.pathSegments.any(
        (s) => s == '..' || s.contains('\\'),
      )) {
        request.response.statusCode = 403;
      } else {
        final path = request.uri.path == '/'
            ? 'index.html'
            : request.uri.path.substring(1);
        final file = File.fromUri(root.uri.resolve(path));
        if (!file.uri.toString().startsWith(root.uri.toString()) ||
            !file.existsSync()) {
          request.response.statusCode = 404;
        } else {
          final extension = path.split('.').last;
          final mime = switch (extension) {
            'html' => 'text/html',
            'js' => 'application/javascript',
            'json' => 'application/json',
            'css' => 'text/css',
            'png' => 'image/png',
            'jpg' || 'jpeg' => 'image/jpeg',
            'svg' => 'image/svg+xml',
            'wasm' => 'application/wasm',
            'woff2' => 'font/woff2',
            'wav' => 'audio/wav',
            _ => 'application/octet-stream',
          };
          request.response.headers.set('Content-Type', mime);
          request.response.headers.set('Cache-Control', 'no-store');
          request.response.contentLength = await file.length();
          if (path.contains('audio/defaults/')) {
            stdout.writeln('Selected audio requested: $path');
          }
          if (request.method == 'GET') {
            await request.response.addStream(file.openRead());
          }
        }
      }
    } catch (_) {
      request.response.statusCode = 500;
    }
    await request.response.close();
  }
}
