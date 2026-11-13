import 'package:flutter/material.dart';

import 'screens/research_screen.dart';
import 'services/research_api.dart';

class ResearchApp extends StatelessWidget {
  final ResearchApi api;

  const ResearchApp({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bookstore Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: ResearchScreen(api: api),
    );
  }
}
