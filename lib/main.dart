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

  String _currentLocation = '等待定位...';

  void _navigateToSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SettingsPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
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
      _hasLocationPermission =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    });
  }

  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    setState(() {
      _hasLocationPermission =
          permission == LocationPermission.always ||
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
    setState(() {
      _isTracking = true;
      _currentSpeed = 0.0;
      _sampleCount = 0;
      _averageVelocity = 0.0;
      _maxVelocity = 0.0;
      _displayAverageVelocity = 0.0;
      _displayMaxVelocity = 0.0;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        _stopTracking();
        return;
      }
    }

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      timeLimit: const Duration(milliseconds: 200),
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position position) => _handlePositionUpdate(position),
    );
  }

  void _stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _positionWindow.clear();

    setState(() {
      _isTracking = false;
    });
  }

  void _handlePositionUpdate(Position position) {
    // 1. 获取当前位置
    final currentData = PositionData(position: position, timestamp: DateTime.now());
    _positionWindow.add(currentData);

    // 限制窗口大小，避免内存过度增长
    if (_positionWindow.length > 10) {
      _positionWindow.removeAt(0);
    }

    // 2. 检查 _sampleCount 数值
    _sampleCount++;

    // 2.1 若 _sampleCount 大于 5 则计算速度
    if (_sampleCount > 5 && _positionWindow.length > 5) {
      // 2.1.1 用当前位置与向前第 5 次记录的位置距离之差除以 1s，获取当前速度
      final index = _positionWindow.length - 1;
      final previousData = _positionWindow[index - 5];
      final currentData = _positionWindow[index];

      final distanceInMeters = Geolocator.distanceBetween(
        previousData.position.latitude,
        previousData.position.longitude,
        currentData.position.latitude,
        currentData.position.longitude,
      );

      final timeInSeconds = currentData.timestamp
          .difference(previousData.timestamp)
          .inSeconds;

      double currentSpeed = 0.0;
      if (timeInSeconds > 0) {
        final speedMetersPerSecond = distanceInMeters / timeInSeconds;
        currentSpeed = speedMetersPerSecond * 3.6; // 转换为 km/h
      }

      // 2.1.2 记录当前速度，用 (_averageVelocity * (_sampleCount-1) + 当前速度) / _sampleCount 获取 _averageVelocity
      _averageVelocity = (_averageVelocity * (_sampleCount - 1) + currentSpeed) / _sampleCount;

      // 2.1.3 比较 当前速度 与 _maxVelocity 的大小，若当前速度大于 _maxVelocity，则 _maxVelocity = 当前速度
      if (currentSpeed > _maxVelocity) {
        _maxVelocity = currentSpeed;
      }

      // 2.1.4 更新显示
      setState(() {
        _currentSpeed = currentSpeed;
        _displayAverageVelocity = _averageVelocity;
        _displayMaxVelocity = _maxVelocity;
      });
    }

    // 更新当前位置显示
    setState(() {
      _currentLocation = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    });
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
              const SizedBox(height: 120),
              Row(
                children: [
                  Spacer(),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 120,
                      alignment: Alignment.center,
                      child: Text(
                        _currentSpeed.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 120,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 120,
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'km/h',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 24,
                            ),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ),
                ],
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
                      onPressed: _hasLocationPermission
                          ? null
                          : _requestPermission,
                      child: Text(_hasLocationPermission ? '已获取权限' : '获取权限'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: _hasLocationPermission
                          ? _toggleTracking
                          : null,
                      child: Text(_isTracking ? '结束' : '开始'),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '当前位置',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentLocation,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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

  PositionData({required this.position, required this.timestamp});
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
      body: const Center(child: Text('设置页面')),
    );
  }
}
