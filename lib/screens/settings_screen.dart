import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../providers/theme_provider.dart';
import '../utils/app_logger.dart';

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
          Consumer(
            builder: (context, ref, child) {
              final authAsync = ref.watch(currentUserProvider);
              return authAsync.when(
                data: (user) => ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Account'),
                  subtitle: Text(user?.email ?? 'Loading...'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                loading: () => const ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Account'),
                  subtitle: Text('Loading...'),
                  trailing: Icon(Icons.chevron_right),
                ),
                error: (_, __) => const ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Account'),
                  subtitle: Text('Not logged in'),
                  trailing: Icon(Icons.chevron_right),
                ),
              );
            },
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
          Consumer(
            builder: (context, ref, child) {
              return ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sign Out'),
                textColor: Colors.red,
                onTap: () async {
                  try {
                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              'Sign Out',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmed ?? false) {
                      final authService = ref.read(authServiceProvider);
                      await authService.signOut();

                      AppLogger.info('User signed out successfully');

                      // Navigate to login screen
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
                    }
                  } catch (e) {
                    AppLogger.error('Sign out failed', error: e);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sign out failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
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
