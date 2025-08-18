import 'dart:math';
import 'package:dart_frog/dart_frog.dart';

List<int> _awayNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
List<int> _homeNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

Response onRequest(RequestContext context) {
  switch (context.request.method) {
    case HttpMethod.post:
      return _shuffleNumbers(context);
    case HttpMethod.get:
      return _getNumbers(context);
    default:
      return Response(statusCode: 405);
  }
}

Response _shuffleNumbers(RequestContext context) {
  final random = Random();
  
  _awayNumbers.shuffle(random);
  _homeNumbers.shuffle(random);
  
  return Response.json(
    body: {
      'success': true,
      'awayNumbers': _awayNumbers,
      'homeNumbers': _homeNumbers,
      'message': 'Numbers shuffled successfully',
    },
  );
}

Response _getNumbers(RequestContext context) {
  return Response.json(
    body: {
      'awayNumbers': _awayNumbers,
      'homeNumbers': _homeNumbers,
    },
  );
}