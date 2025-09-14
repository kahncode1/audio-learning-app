import 'package:flutter/material.dart';
import '../config/env_config.dart';
import '../services/speechify_service.dart';

class TestSpeechifyScreen extends StatefulWidget {
  const TestSpeechifyScreen({super.key});

  @override
  State<TestSpeechifyScreen> createState() => _TestSpeechifyScreenState();
}

class _TestSpeechifyScreenState extends State<TestSpeechifyScreen> {
  String _status = 'Checking configuration...';
  final SpeechifyService _speechifyService = SpeechifyService();

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  Future<void> _checkConfiguration() async {
    setState(() {
      _status = 'Loading environment...';
    });

    // Configuration is already loaded in main.dart
    final apiKey = EnvConfig.speechifyApiKey;
    final isConfigured = EnvConfig.isSpeechifyConfigured;

    setState(() {
      if (isConfigured) {
        _status = '''
✅ Speechify API Key Loaded Successfully!

API Key: ${apiKey.substring(0, 20)}...
Environment: ${EnvConfig.environment}
Base URL: ${EnvConfig.speechifyBaseUrl}

Ready to test audio generation!
        ''';
      } else {
        _status = '''
❌ Speechify API Key Not Configured

Current value: $apiKey

Please update your .env file with your actual API key.
        ''';
      }
    });
  }

  Future<void> _testSpeechifyAPI() async {
    setState(() {
      _status = 'Testing Speechify API...';
    });

    try {
      // Test with a simple text
      const testText = 'Hello! This is a test of the Speechify text-to-speech API.';

      setState(() {
        _status = 'Generating audio stream...';
      });

      final streamUrl = await _speechifyService.generateAudioStream(
        content: testText,
      );

      setState(() {
        _status = '''
✅ Speechify API Test Successful!

Generated stream URL:
${streamUrl.substring(0, 50)}...

API is working correctly!
        ''';
      });
    } catch (e) {
      setState(() {
        _status = '''
❌ Speechify API Test Failed

Error: $e

Please check:
1. Your API key is valid
2. You have sufficient API quota
3. Your internet connection
        ''';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Speechify Configuration'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuration Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (EnvConfig.isSpeechifyConfigured) ...[
              Center(
                child: ElevatedButton.icon(
                  onPressed: _testSpeechifyAPI,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Test Speechify API'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Click to test if the API can generate audio',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This screen verifies that your Speechify API key is properly loaded from the .env file.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}