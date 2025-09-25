/// Performance Overlay Widget
///
/// Purpose: Display real-time performance metrics on screen
/// Features:
/// - Live FPS counter
/// - Frame time graph
/// - Memory usage
/// - Performance warnings
///
/// Usage: Wrap your app with this overlay in debug/profile mode

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/performance_monitor.dart';
import '../utils/app_logger.dart';

class AppPerformanceOverlay extends StatefulWidget {
  final Widget child;
  final bool showGraph;

  const AppPerformanceOverlay({
    super.key,
    required this.child,
    this.showGraph = true,
  });

  @override
  State<AppPerformanceOverlay> createState() => _AppPerformanceOverlayState();
}

class _AppPerformanceOverlayState extends State<AppPerformanceOverlay> {
  double _currentFps = 0;
  double _memoryMb = 0;
  final List<double> _fpsHistory = [];
  Timer? _updateTimer;

  // Frame timing
  Duration? _lastFrameTime;
  final List<double> _frameTimes = [];

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  void _startMonitoring() {
    // Start performance monitoring
    PerformanceMonitor.startTracking();

    // Update metrics every 100ms
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!mounted) return;

      final fps = PerformanceMonitor.getCurrentFps();
      final memory = await PerformanceMonitor.getMemoryUsageMb();

      setState(() {
        _currentFps = fps;
        _memoryMb = memory;

        _fpsHistory.add(fps);
        if (_fpsHistory.length > 60) { // Keep last 6 seconds
          _fpsHistory.removeAt(0);
        }
      });
    });

    // Track frame callbacks for more accurate FPS
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    if (_lastFrameTime != null) {
      final frameTime = timestamp.inMicroseconds - _lastFrameTime!.inMicroseconds;
      final frameTimeMs = frameTime / 1000.0;

      _frameTimes.add(frameTimeMs);
      if (_frameTimes.length > 60) {
        _frameTimes.removeAt(0);
      }

      // Calculate FPS from frame times
      if (_frameTimes.isNotEmpty) {
        final avgFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
        final fps = avgFrameTime > 0 ? 1000.0 / avgFrameTime : 0;

        if (mounted && fps > 0) {
          setState(() {
            _currentFps = fps.toDouble();
          });
        }
      }
    }
    _lastFrameTime = timestamp;
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    PerformanceMonitor.stopTracking();
    super.dispose();
  }

  Color _getFpsColor(double fps) {
    if (fps >= 55) return Colors.green;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 10,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getFpsColor(_currentFps),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FPS Display
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'FPS: ',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _currentFps.toStringAsFixed(1),
                        style: TextStyle(
                          color: _getFpsColor(_currentFps),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // Memory Display
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MEM: ',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${_memoryMb.toStringAsFixed(0)} MB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Performance Status
                  if (_currentFps > 0 && _currentFps < 30)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '⚠️ Poor Performance',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // FPS Graph
                  if (widget.showGraph && _fpsHistory.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      height: 40,
                      width: 120,
                      child: CustomPaint(
                        painter: FpsGraphPainter(
                          values: _fpsHistory,
                          targetFps: 60,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FpsGraphPainter extends CustomPainter {
  final List<double> values;
  final double targetFps;

  FpsGraphPainter({
    required this.values,
    required this.targetFps,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw target line (60 fps)
    final targetY = size.height * (1 - targetFps / 100);
    paint.color = Colors.green.withOpacity(0.3);
    canvas.drawLine(
      Offset(0, targetY),
      Offset(size.width, targetY),
      paint,
    );

    // Draw 30 fps line
    final warningY = size.height * (1 - 30 / 100);
    paint.color = Colors.orange.withOpacity(0.3);
    canvas.drawLine(
      Offset(0, warningY),
      Offset(size.width, warningY),
      paint,
    );

    // Draw FPS curve
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final normalizedFps = values[i].clamp(0, 100);
      final y = size.height * (1 - normalizedFps / 100);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Color based on latest FPS
    final latestFps = values.last;
    if (latestFps >= 55) {
      paint.color = Colors.green;
    } else if (latestFps >= 30) {
      paint.color = Colors.orange;
    } else {
      paint.color = Colors.red;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(FpsGraphPainter oldDelegate) {
    return true; // Always repaint for smooth animation
  }
}