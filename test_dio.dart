import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
  
  print('Base URL: ${dio.options.baseUrl}');
  
  final path1 = '/users/me';
  final uri1 = dio.options.baseUrl + path1;
  print('Manual concat /users/me: $uri1');
  
  // Dio uses Uri.resolveUri or similar
  final base = Uri.parse(dio.options.baseUrl);
  final resolved = base.resolve(path1);
  print('Resolved /users/me: $resolved');
  
  final path2 = 'users/me';
  final resolved2 = base.resolve(path2);
  print('Resolved users/me: $resolved2');
}
