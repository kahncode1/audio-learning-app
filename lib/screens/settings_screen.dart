import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env_config.dart';

/// SettingsScreen provides app configuration options
/// This is a placeholder implementation for Milestone 1
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Account'),
            subtitle: const Text('Not logged in'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Default Font Size'),
            subtitle: const Text('Medium'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Default Playback Speed'),
            subtitle: const Text('1.0x'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Clear Cache'),
            subtitle: const Text('Free up storage space'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out'),
            textColor: Colors.red,
            onTap: () {},
            enabled: false, // Disabled until auth is implemented
          ),

          // Developer section - only show in debug mode
          if (EnvConfig.isDevelopment) ...[
            const Divider(thickness: 2),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Developer Tools',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.science, color: Colors.purple),
              title: const Text('ElevenLabs Test (Phase 4)'),
              subtitle: const Text('Test TTS service integration'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(context, '/elevenlabs-test');
              },
            ),
            ListTile(
              leading: const Icon(Icons.api, color: Colors.purple),
              title: const Text('TTS Service'),
              subtitle: Text(EnvConfig.useElevenLabs ? 'ElevenLabs' : 'Speechify'),
              trailing: Switch(
                value: EnvConfig.useElevenLabs,
                onChanged: null, // Read-only for now
              ),
            ),
          ],
        ],
      ),
    );
  }
}
