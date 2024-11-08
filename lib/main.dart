import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'screens/screens.dart';

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensure the framework is initialized
  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
  } catch (e) {
    exit(1); // Exit if .env file cannot be loaded
  }
  // Access your API key from the environment variables
  final apiKey = dotenv.env['GEMINI_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    exit(1); // Exit if API_KEY is not found
  }
  // Initialize the GenerativeModel
  GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  // Run the app
  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Market Wizard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
