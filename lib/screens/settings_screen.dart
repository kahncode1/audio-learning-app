import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env_config.dart';
import '../providers/theme_provider.dart';
import 'auth_test_screen.dart';

/// SettingsScreen provides app configuration options
/// This is a placeholder implementation for Milestone 1
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
            leading: Icon(ref.watch(themeProvider.notifier).themeIcon),
            title: const Text('Theme'),
            subtitle: Text(ref.watch(themeProvider.notifier).themeName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, ref),
          ),
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
          if (kDebugMode && EnvConfig.isDevelopment) ...[
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
              leading: const Icon(Icons.download_done, color: Colors.green),
              title: const Text('Local Content Test'),
              subtitle: const Text('Test download-first architecture'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(context, '/local-content-test');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download, color: Colors.blue),
              title: const Text('CDN Download Test'),
              subtitle: const Text('Test Supabase CDN download flow'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(context, '/cdn-download-test');
              },
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.orange),
              title: const Text('Cognito OAuth Test'),
              subtitle: const Text('Test AWS Cognito authentication flow'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AuthTestScreen(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Choose Theme'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
                Navigator.pop(context);
              },
              child: const Row(
                children: [
                  Icon(Icons.light_mode),
                  SizedBox(width: 16),
                  Text('Light'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                ref.read(themeProvider.notifier).setTheme(ThemeMode.dark);
                Navigator.pop(context);
              },
              child: const Row(
                children: [
                  Icon(Icons.dark_mode),
                  SizedBox(width: 16),
                  Text('Dark'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                ref.read(themeProvider.notifier).setTheme(ThemeMode.system);
                Navigator.pop(context);
              },
              child: const Row(
                children: [
                  Icon(Icons.brightness_auto),
                  SizedBox(width: 16),
                  Text('Auto (Follow System)'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
