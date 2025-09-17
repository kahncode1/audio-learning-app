import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env_config.dart';
import 'screens/home_screen.dart';
import 'screens/course_detail_screen.dart';
import 'screens/assignments_screen.dart';
import 'screens/enhanced_audio_player_screen.dart';
import 'models/learning_object.dart';
import 'screens/settings_screen.dart';
import 'widgets/mini_audio_player.dart';
import 'providers/audio_providers.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await EnvConfig.load();

  // Initialize Supabase
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // Print configuration status for debugging
  EnvConfig.printConfigurationStatus();

  runApp(
    const ProviderScope(
      child: AudioLearningApp(),
    ),
  );
}

class AudioLearningApp extends StatelessWidget {
  const AudioLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Institutes',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF2196F3),
        useMaterial3: false, // Using Material 2 as per requirements
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const MainNavigationScreen(),
        '/home': (context) => const HomePage(),
        '/settings': (context) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/course-detail') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => CourseDetailScreen(
              courseId: args['courseId']!,
              courseTitle: args['courseTitle']!,
            ),
          );
        }
        if (settings.name == '/assignments') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => AssignmentsScreen(
              courseId: args['courseId']!,
              courseNumber: args['courseNumber']!,
              courseTitle: args['courseTitle']!,
            ),
          );
        }
        if (settings.name == '/player') {
          // Handle both Map arguments (new) and direct LearningObject (legacy)
          if (settings.arguments is Map<String, dynamic>) {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => EnhancedAudioPlayerScreen(
                learningObject: args['learningObject'] as LearningObject,
                courseNumber: args['courseNumber'] as String?,
                courseTitle: args['courseTitle'] as String?,
                assignmentTitle: args['assignmentTitle'] as String?,
                assignmentNumber: args['assignmentNumber'] as int?,
              ),
            );
          } else {
            // Legacy support for direct LearningObject
            final learningObject = settings.arguments as LearningObject;
            return MaterialPageRoute(
              builder: (context) => EnhancedAudioPlayerScreen(
                learningObject: learningObject,
              ),
            );
          }
        }
        return null;
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate loading and navigate to main screen
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/the-institutes-logo.png',
              height: 80,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if logo doesn't load
                return Icon(
                  Icons.business,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'The Institutes',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366), // Professional dark blue
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomePage(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowMiniPlayer = ref.watch(shouldShowMiniPlayerProvider);
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final navigationHeight = kBottomNavigationBarHeight + bottomSafeArea;

    return Scaffold(
      body: Stack(
        children: [
          // Main scaffold with navigation
          Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
            bottomNavigationBar: BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: Theme.of(context).primaryColor,
              onTap: _onItemTapped,
            ),
          ),

          // Mini audio player positioned flush above bottom navigation
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: shouldShowMiniPlayer ? navigationHeight : -80,
            child: const MiniAudioPlayer(),
          ),
        ],
      ),
    );
  }
}
