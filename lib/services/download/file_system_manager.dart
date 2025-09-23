/// File System Manager
///
/// Purpose: Manages file system operations for downloads
/// Handles directory creation, file management, and cleanup
///
/// Responsibilities:
/// - Directory structure management
/// - File path resolution
/// - Temporary file cleanup
/// - Manifest file operations
/// - Storage space management
///
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../utils/app_logger.dart';

class FileSystemManager {
  static const String _manifestFileName = 'manifest.json';
  static const String _tempExtension = '.tmp';
  static const String _coursesFolder = 'courses';

  late final Directory _documentsDir;
  bool _initialized = false;

  /// Initialize the file system manager
  Future<void> initialize() async {
    if (_initialized) return;

    _documentsDir = await getApplicationDocumentsDirectory();
    _initialized = true;

    // Ensure courses directory exists
    final coursesDir = Directory(path.join(_documentsDir.path, _coursesFolder));
    if (!coursesDir.existsSync()) {
      await coursesDir.create(recursive: true);
    }

    AppLogger.info('FileSystemManager initialized', {
      'documentsPath': _documentsDir.path,
      'coursesPath': coursesDir.path,
    });
  }

  /// Get course directory path
  String getCourseDirectory(String courseId) {
    _ensureInitialized();
    return path.join(_documentsDir.path, _coursesFolder, courseId);
  }

  /// Get learning object directory path
  String getLearningObjectDirectory(String courseId, String learningObjectId) {
    return path.join(getCourseDirectory(courseId), 'learning_objects', learningObjectId);
  }

  /// Get full file path for a download task
  String getFilePath(String courseId, String relativePath) {
    _ensureInitialized();
    return path.join(_documentsDir.path, _coursesFolder, courseId, relativePath);
  }

  /// Get temporary file path
  String getTempFilePath(String originalPath) {
    return '$originalPath$_tempExtension';
  }

  /// Ensure directory exists for file
  Future<void> ensureDirectoryExists(String filePath) async {
    final file = File(filePath);
    final directory = file.parent;

    if (!directory.existsSync()) {
      await directory.create(recursive: true);
      AppLogger.info('Created directory', {'path': directory.path});
    }
  }

  /// Check if course is fully downloaded
  Future<bool> isCourseDownloaded(String courseId) async {
    _ensureInitialized();

    final manifestPath = path.join(getCourseDirectory(courseId), _manifestFileName);
    final manifestFile = File(manifestPath);

    if (!manifestFile.existsSync()) {
      return false;
    }

    try {
      final content = await manifestFile.readAsString();
      final manifest = jsonDecode(content) as Map<String, dynamic>;

      // Verify all files exist
      final files = (manifest['files'] as List?)?.cast<String>() ?? [];
      for (final filePath in files) {
        final fullPath = getFilePath(courseId, filePath);
        if (!File(fullPath).existsSync()) {
          AppLogger.warning('Missing file in downloaded course', {
            'courseId': courseId,
            'file': filePath,
          });
          return false;
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('Failed to read manifest', error: e);
      return false;
    }
  }

  /// Create manifest file for downloaded course
  Future<void> createManifest(String courseId, List<String> files, Map<String, dynamic> metadata) async {
    _ensureInitialized();

    final manifestPath = path.join(getCourseDirectory(courseId), _manifestFileName);
    final manifestFile = File(manifestPath);

    final manifest = {
      'courseId': courseId,
      'downloadedAt': DateTime.now().toIso8601String(),
      'files': files,
      'metadata': metadata,
    };

    await manifestFile.writeAsString(jsonEncode(manifest));

    AppLogger.info('Manifest created', {
      'courseId': courseId,
      'fileCount': files.length,
    });
  }

  /// Delete course content
  Future<void> deleteCourseContent(String courseId) async {
    _ensureInitialized();

    final courseDir = Directory(getCourseDirectory(courseId));

    if (courseDir.existsSync()) {
      await courseDir.delete(recursive: true);
      AppLogger.info('Course content deleted', {'courseId': courseId});
    }
  }

  /// Move temporary file to final destination
  Future<void> moveTempFile(String tempPath, String finalPath) async {
    final tempFile = File(tempPath);
    final finalFile = File(finalPath);

    if (tempFile.existsSync()) {
      // Ensure destination directory exists
      await ensureDirectoryExists(finalPath);

      // Move file
      await tempFile.rename(finalPath);

      AppLogger.info('Moved temp file to final destination', {
        'temp': tempPath,
        'final': finalPath,
      });
    }
  }

  /// Clean up temporary files
  Future<void> cleanupTempFiles() async {
    _ensureInitialized();

    final coursesDir = Directory(path.join(_documentsDir.path, _coursesFolder));

    if (!coursesDir.existsSync()) {
      return;
    }

    int cleanedCount = 0;
    await for (final entity in coursesDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith(_tempExtension)) {
        try {
          await entity.delete();
          cleanedCount++;
          AppLogger.info('Deleted temp file', {'path': entity.path});
        } catch (e) {
          AppLogger.error('Failed to delete temp file', error: e, data: {
            'path': entity.path,
          });
        }
      }
    }

    if (cleanedCount > 0) {
      AppLogger.info('Cleaned up temporary files', {'count': cleanedCount});
    }
  }

  /// Get available storage space
  Future<int> getAvailableSpace() async {
    _ensureInitialized();

    // Platform-specific implementation would go here
    // For now, return a large number
    return 10 * 1024 * 1024 * 1024; // 10GB
  }

  /// Check if there's enough space for download
  Future<bool> hasEnoughSpace(int requiredBytes) async {
    final available = await getAvailableSpace();
    return available > requiredBytes * 1.2; // Add 20% buffer
  }

  /// Get size of course content
  Future<int> getCourseSize(String courseId) async {
    _ensureInitialized();

    final courseDir = Directory(getCourseDirectory(courseId));

    if (!courseDir.existsSync()) {
      return 0;
    }

    int totalSize = 0;
    await for (final entity in courseDir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }

  /// Check if file exists
  bool fileExists(String filePath) {
    return File(filePath).existsSync();
  }

  /// Get file size
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      return await file.length();
    }
    return 0;
  }

  /// Ensure manager is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('FileSystemManager not initialized. Call initialize() first.');
    }
  }

  /// Get all downloaded courses
  Future<List<String>> getDownloadedCourses() async {
    _ensureInitialized();

    final coursesDir = Directory(path.join(_documentsDir.path, _coursesFolder));

    if (!coursesDir.existsSync()) {
      return [];
    }

    final courses = <String>[];
    await for (final entity in coursesDir.list()) {
      if (entity is Directory) {
        final courseId = path.basename(entity.path);
        if (await isCourseDownloaded(courseId)) {
          courses.add(courseId);
        }
      }
    }

    return courses;
  }

  /// Save JSON data to file (for JSONB timing data)
  Future<void> saveJsonData(String filePath, dynamic jsonData) async {
    _ensureInitialized();

    final file = File(filePath);
    await ensureDirectoryExists(filePath);

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
    await file.writeAsString(jsonString);

    AppLogger.info('Saved JSON data', {
      'path': filePath,
      'size': jsonString.length,
    });
  }

  /// Load JSON data from file
  Future<dynamic> loadJsonData(String filePath) async {
    _ensureInitialized();

    final file = File(filePath);

    if (!file.existsSync()) {
      AppLogger.warning('JSON file not found', {'path': filePath});
      return null;
    }

    try {
      final jsonString = await file.readAsString();
      return jsonDecode(jsonString);
    } catch (e) {
      AppLogger.error('Failed to load JSON data', error: e, data: {'path': filePath});
      return null;
    }
  }

  /// Save word timings for a learning object
  Future<void> saveWordTimings(String courseId, String learningObjectId, List<Map<String, dynamic>> wordTimings) async {
    final filePath = path.join(
      getLearningObjectDirectory(courseId, learningObjectId),
      'word_timings.json',
    );
    await saveJsonData(filePath, wordTimings);
  }

  /// Save sentence timings for a learning object
  Future<void> saveSentenceTimings(String courseId, String learningObjectId, List<Map<String, dynamic>> sentenceTimings) async {
    final filePath = path.join(
      getLearningObjectDirectory(courseId, learningObjectId),
      'sentence_timings.json',
    );
    await saveJsonData(filePath, sentenceTimings);
  }

  /// Save content metadata for a learning object
  Future<void> saveContentMetadata(String courseId, String learningObjectId, Map<String, dynamic> metadata) async {
    final filePath = path.join(
      getLearningObjectDirectory(courseId, learningObjectId),
      'content.json',
    );
    await saveJsonData(filePath, metadata);
  }

  /// Check file version for updates
  Future<bool> needsUpdate(String filePath, int newVersion) async {
    _ensureInitialized();

    final versionFile = File('$filePath.version');

    if (!versionFile.existsSync()) {
      return true; // No version file means we need to download
    }

    try {
      final currentVersion = int.parse(await versionFile.readAsString());
      return newVersion > currentVersion;
    } catch (e) {
      AppLogger.error('Failed to check version', error: e);
      return true; // Assume update needed on error
    }
  }

  /// Save file version
  Future<void> saveFileVersion(String filePath, int version) async {
    final versionFile = File('$filePath.version');
    await versionFile.writeAsString(version.toString());
  }
}