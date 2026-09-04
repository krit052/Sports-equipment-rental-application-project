import 'package:flutter_dotenv/flutter_dotenv.dart';

String get defaultIp => dotenv.env['DEFAULT_IP'] ?? '172.27.8.16';
String get defaultPort => dotenv.env['PORT'] ?? '3000';
String get scheme => dotenv.env['SCHEME'] ?? 'http';

String get baseUrl => '$scheme://$defaultIp:$defaultPort';
Uri get baseUri => Uri.parse(baseUrl);