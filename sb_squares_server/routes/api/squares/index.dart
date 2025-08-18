import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';

final Map<String, String> _squares = <String, String>{};
final List<int> _awayNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
final List<int> _homeNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _getSquares(context);
    case HttpMethod.post:
      return await _selectSquare(context);
    case HttpMethod.delete:
      return _clearSquares(context);
    default:
      return Response(statusCode: 405);
  }
}

Response _getSquares(RequestContext context) {
  return Response.json(
    body: {
      'squares': _squares,
      'awayNumbers': _awayNumbers,
      'homeNumbers': _homeNumbers,
    },
  );
}

Future<Response> _selectSquare(RequestContext context) async {
  try {
    final body = await context.request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;
    
    final row = data['row'] as int?;
    final col = data['col'] as int?;
    final playerName = data['playerName'] as String?;
    
    if (row == null || col == null || playerName == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Missing required fields: row, col, playerName'},
      );
    }
    
    if (row < 0 || row > 9 || col < 0 || col > 9) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Row and column must be between 0 and 9'},
      );
    }
    
    final key = '$row-$col';
    
    if (_squares.containsKey(key)) {
      return Response.json(
        statusCode: 409,
        body: {'error': 'Square already taken'},
      );
    }
    
    _squares[key] = playerName;
    
    return Response.json(
      body: {
        'success': true,
        'square': {'row': row, 'col': col, 'playerName': playerName},
        'totalSelected': _squares.length,
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Invalid JSON body'},
    );
  }
}

Response _clearSquares(RequestContext context) {
  _squares.clear();
  
  return Response.json(
    body: {
      'success': true,
      'message': 'All squares cleared',
    },
  );
}