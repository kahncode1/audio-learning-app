import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'config/env_config.dart';
import 'config/app_config.dart';

/// Test Speechify API connection and configuration
Future<void> testSpeechifyApiConnection() async {
  debugPrint('\n=== Testing Speechify API Connection ===\n');

  // Step 1: Load environment variables
  await EnvConfig.load();

  // Step 2: Check if API key is loaded
  final apiKey = AppConfig.speechifyApiKey;
  final baseUrl = AppConfig.speechifyBaseUrl;

  debugPrint('API Key loaded: ${apiKey.substring(0, 10)}...${apiKey.substring(apiKey.length - 4)}');
  debugPrint('API Key length: ${apiKey.length} characters');
  debugPrint('Base URL: $baseUrl');
  debugPrint('Is configured: ${EnvConfig.isSpeechifyConfigured}');

  if (!EnvConfig.isSpeechifyConfigured) {
    debugPrint('❌ Speechify API key not configured properly!');
    return;
  }

  // Step 3: Test actual API connection
  final dio = Dio();

  try {
    debugPrint('\n📡 Testing API connection...');

    // Test with a simple text-to-speech request
    final response = await dio.post(
      '$baseUrl/v1/audio/speech',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status != null,
      ),
      data: {
        'input': 'Hello, this is a test.',
        'voice': 'henry',  // Try a standard voice
        'model': 'speechify',
      },
    );

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response headers: ${response.headers.map}');

    if (response.statusCode == 200) {
      debugPrint('✅ API connection successful!');
      debugPrint('Response type: ${response.data.runtimeType}');

      // Check if we got audio data
      if (response.data is List<int>) {
        debugPrint('Audio data received: ${(response.data as List).length} bytes');
      } else if (response.data is Map) {
        debugPrint('Response data: ${response.data}');
      }
    } else if (response.statusCode == 401) {
      debugPrint('❌ Authentication failed - API key may be invalid');
      debugPrint('Response: ${response.data}');
    } else if (response.statusCode == 404) {
      debugPrint('⚠️ Endpoint not found - may need to check API documentation');
      debugPrint('Response: ${response.data}');
    } else {
      debugPrint('⚠️ Unexpected status code: ${response.statusCode}');
      debugPrint('Response: ${response.data}');
    }

  } on DioException catch (e) {
    debugPrint('❌ API request failed: ${e.type}');
    debugPrint('Error message: ${e.message}');

    if (e.response != null) {
      debugPrint('Response status: ${e.response?.statusCode}');
      debugPrint('Response data: ${e.response?.data}');

      // Check specific error codes
      if (e.response?.statusCode == 401) {
        debugPrint('\n⚠️ Authentication Error - Possible issues:');
        debugPrint('1. API key is invalid or expired');
        debugPrint('2. API key format is incorrect');
        debugPrint('3. Authorization header format is wrong');
      } else if (e.response?.statusCode == 403) {
        debugPrint('\n⚠️ Permission Error - API key may not have required permissions');
      } else if (e.response?.statusCode == 429) {
        debugPrint('\n⚠️ Rate Limit Error - Too many requests');
      }
    } else {
      debugPrint('\n⚠️ Network Error - Possible issues:');
      debugPrint('1. No internet connection');
      debugPrint('2. API endpoint is incorrect');
      debugPrint('3. SSL/TLS issues');
    }
  } catch (e) {
    debugPrint('❌ Unexpected error: $e');
  }

  debugPrint('\n=== Test Complete ===\n');
}

/// Alternative test with OpenAI-compatible endpoint
Future<void> testSpeechifyOpenAIEndpoint() async {
  debugPrint('\n=== Testing Speechify OpenAI-Compatible Endpoint ===\n');

  await EnvConfig.load();
  final apiKey = AppConfig.speechifyApiKey;

  if (!EnvConfig.isSpeechifyConfigured) {
    debugPrint('❌ Speechify API key not configured!');
    return;
  }

  final dio = Dio();

  try {
    // Try OpenAI-compatible endpoint
    final response = await dio.post(
      'https://api.openai.com/v1/audio/speech',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'OpenAI-Organization': 'speechify',  // Indicate Speechify usage
        },
        responseType: ResponseType.bytes,
        validateStatus: (status) => status != null,
      ),
      data: {
        'model': 'tts-1',
        'input': 'Hello, this is a test of the Speechify API.',
        'voice': 'alloy',
        'response_format': 'mp3',
      },
    );

    debugPrint('Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      debugPrint('✅ OpenAI endpoint successful!');
      final audioBytes = response.data as List<int>;
      debugPrint('Audio data received: ${audioBytes.length} bytes');
    } else {
      debugPrint('⚠️ Status: ${response.statusCode}');
      debugPrint('Response: ${response.data}');
    }

  } catch (e) {
    debugPrint('❌ OpenAI endpoint failed: $e');
  }

  debugPrint('\n=== Test Complete ===\n');
}