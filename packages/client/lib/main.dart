import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'src/app.dart';
import 'src/services/research_api.dart';

void main() {
  final host = !kIsWeb && Platform.isAndroid ? '10.0.2.2' : 'localhost';
  final api = ResearchApi(
    baseUrl: Uri.parse('http://$host:8080'),
    client: http.Client(),
  );
  runApp(ResearchApp(api: api));
}
