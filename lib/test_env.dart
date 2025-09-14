import 'package:flutter/material.dart';
import 'config/env_config.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  // Load environment
  await EnvConfig.load();

  // Check Speechify configuration
  final speechifyKey = EnvConfig.speechifyApiKey;

  // Check if it's reading from .env properly
  if (speechifyKey == 'your_speechify_api_key_here' ||
      speechifyKey == 'YOUR_SPEECHIFY_API_KEY_HERE') {
  } else {
  }

  // Print full status
  EnvConfig.printConfigurationStatus();


  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('Check console output'),
      ),
    ),
  ));
}