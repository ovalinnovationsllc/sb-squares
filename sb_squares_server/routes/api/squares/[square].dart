import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';

final Map<String, String> _squares = <String, String>{};

Response onRequest(RequestContext context, String square) {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getSquare(context, square);
    case HttpMethod.delete:
      return _removeSquare(context, square);
    default:
      return Response(statusCode: 405);
  }
}

Response _getSquare(RequestContext context, String square) {
  if (_squares.containsKey(square)) {
    return Response.json(
      body: {
        'square': square,
        'playerName': _squares[square],
      },
    );
  }
  
  return Response.json(
    statusCode: 404,
    body: {'error': 'Square not found'},
  );
}

Response _removeSquare(RequestContext context, String square) {
  if (_squares.containsKey(square)) {
    final playerName = _squares.remove(square);
    return Response.json(
      body: {
        'success': true,
        'message': 'Square $square removed',
        'playerName': playerName,
      },
    );
  }
  
  return Response.json(
    statusCode: 404,
    body: {'error': 'Square not found'},
  );
}