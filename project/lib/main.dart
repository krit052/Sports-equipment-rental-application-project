import 'package:flutter/material.dart';
import 'package:flutter_application_1/welcome/welcome.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MaterialApp(home: Welcome()));
}