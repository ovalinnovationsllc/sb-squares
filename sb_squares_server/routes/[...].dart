import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context, String path) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  
  // Default to index.html for root path
  final filePath = path.isEmpty || path == '/' 
    ? 'public/index.html' 
    : 'public/$path';
  
  final file = File(filePath);
  
  if (await file.exists()) {
    final contentType = _getContentType(filePath);
    
    if (contentType.startsWith('text/') || 
        contentType == 'application/javascript' || 
        contentType == 'application/json') {
      return Response(
        body: await file.readAsString(),
        headers: {'Content-Type': contentType},
      );
    } else {
      return Response.bytes(
        body: await file.readAsBytes(),
        headers: {'Content-Type': contentType},
      );
    }
  }
  
  // For client-side routing, return index.html for any non-existent path
  final indexFile = File('public/index.html');
  if (await indexFile.exists()) {
    return Response(
      body: await indexFile.readAsString(),
      headers: {'Content-Type': 'text/html'},
    );
  }
  
  return Response(statusCode: 404, body: 'Not found');
}

String _getContentType(String path) {
  if (path.endsWith('.html')) return 'text/html';
  if (path.endsWith('.css')) return 'text/css';
  if (path.endsWith('.js')) return 'application/javascript';
  if (path.endsWith('.json')) return 'application/json';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.ico')) return 'image/x-icon';
  if (path.endsWith('.woff2')) return 'font/woff2';
  if (path.endsWith('.woff')) return 'font/woff';
  if (path.endsWith('.ttf')) return 'font/ttf';
  if (path.endsWith('.otf')) return 'font/otf';
  if (path.endsWith('.wasm')) return 'application/wasm';
  return 'application/octet-stream';
}