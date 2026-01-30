import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veloster',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VelocityPage(),
    );
  }
}

class VelocityPage extends StatefulWidget {
  const VelocityPage({super.key});

  @override
  State<VelocityPage> createState() => _VelocityPageState();
}

class _VelocityPageState extends State<VelocityPage> {
  bool _hasLocationPermission = false;
  bool _isTracking = false;
  double _currentSpeed = 0.0;
  double _averageVelocity = 0.0;
  int _sampleCount = 0;
  double _maxVelocity = 0.0;
  
  double _displayAverageVelocity = 0.0;
  double _displayMaxVelocity = 0.0;
  
  StreamSubscription<Position>? _positionSubscription;
  
  final List<PositionData> _positionWindow = [];
  static const int kWindowSizeSeconds = 5;
  
  void _navigateToSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionStatus() async {
    LocationPermission permission = await Geolocator.checkPermission();
    setState(() {
      _hasLocationPermission = permission == LocationPermission.always ||
                               permission == LocationPermission.whileInUse;
    });
  }

  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    setState(() {
      _hasLocationPermission = permission == LocationPermission.always ||
                               permission == LocationPermission.whileInUse;
    });
  }

  void _toggleTracking() async {
    if (!_hasLocationPermission) {
      return;
    }

    if (_isTracking) {
      _stopTracking();
    } else {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        return;
      }
    }

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      timeLimit: const Duration(seconds: 1),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((Position position) {
      _handlePositionUpdate(position);
    });

    setState(() {
      _isTracking = true;
    });
  }

  void _stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _positionWindow.clear();
    
    setState(() {
      _isTracking = false;
      _currentSpeed = 0.0;
      _averageVelocity = 0.0;
      _sampleCount = 0;
      _maxVelocity = 0.0;
      // 保持 _displayAverageVelocity 和 _displayMaxVelocity 不变
    });
  }

  void _handlePositionUpdate(Position position) {
    final now = DateTime.now();
    final positionData = PositionData(
      position: position,
      timestamp: now,
    );

    _positionWindow.add(positionData);
    
    final cutoffTime = now.subtract(const Duration(seconds: kWindowSizeSeconds));
    _positionWindow.removeWhere((data) => data.timestamp.isBefore(cutoffTime));

    _calculateAverageSpeed();
  }

  void _calculateAverageSpeed() {
    if (_positionWindow.length < 2) {
      setState(() {
        _currentSpeed = 0.0;
      });
      return;
    }

    final firstPositionData = _positionWindow.first;
    final lastPositionData = _positionWindow.last;

    final distanceInMeters = Geolocator.distanceBetween(
      firstPositionData.position.latitude,
      firstPositionData.position.longitude,
      lastPositionData.position.latitude,
      lastPositionData.position.longitude,
    );

    final timeInSeconds = lastPositionData.timestamp.difference(firstPositionData.timestamp).inSeconds;

    if (timeInSeconds > 0) {
      final speedMetersPerSecond = distanceInMeters / timeInSeconds;
      final speedKmPerHour = speedMetersPerSecond * 3.6;
      
      setState(() {
        _currentSpeed = speedKmPerHour;
        
        // 更新平均速度（累计平均）
        _averageVelocity = _averageVelocity * _sampleCount + speedKmPerHour;
        _sampleCount++;
        _averageVelocity = _averageVelocity / _sampleCount;
        _displayAverageVelocity = _averageVelocity;
        
        // 更新最大速度
        if (speedKmPerHour > _maxVelocity) {
          _maxVelocity = speedKmPerHour;
          _displayMaxVelocity = _maxVelocity;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Veloster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            _navigateToSettings();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            Text(
              _currentSpeed.toStringAsFixed(1),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 120,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'km/h',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    child: Text(
                      'AVR. ${_displayAverageVelocity.toStringAsFixed(1)} km/h',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    child: Text(
                      'MAX. ${_displayMaxVelocity.toStringAsFixed(1)} km/h',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _hasLocationPermission ? null : _requestPermission,
                    child: Text(_hasLocationPermission ? '已获取权限' : '获取权限'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _hasLocationPermission ? _toggleTracking : null,
                    child: Text(_isTracking ? '结束' : '开始'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class PositionData {
  final Position position;
  final DateTime timestamp;

  PositionData({
    required this.position,
    required this.timestamp,
  });
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('设置'),
      ),
      body: const Center(
        child: Text('设置页面'),
      ),
    );
  }
}
