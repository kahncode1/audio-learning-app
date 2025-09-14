import 'package:flutter/material.dart';
import 'config/env_config.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('\n=== Testing Environment Configuration ===\n');

  // Load environment
  await EnvConfig.load();

  // Check Speechify configuration
  final speechifyKey = EnvConfig.speechifyApiKey;
  print('Speechify API Key loaded: ${speechifyKey.substring(0, 10)}...');
  print('Is Speechify configured: ${EnvConfig.isSpeechifyConfigured}');

  // Check if it's reading from .env properly
  if (speechifyKey == 'your_speechify_api_key_here' ||
      speechifyKey == 'YOUR_SPEECHIFY_API_KEY_HERE') {
    print('❌ Still using placeholder - .env file may not be loaded correctly');
    print('   Make sure .env file is in the project root');
  } else {
    print('✅ Speechify API key loaded from .env successfully!');
    print('   Key starts with: ${speechifyKey.substring(0, 20)}...');
  }

  // Print full status
  EnvConfig.printConfigurationStatus();

  print('\n=== Test Complete ===\n');

  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('Check console output'),
      ),
    ),
  ));
}