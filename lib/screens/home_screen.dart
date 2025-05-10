import 'package:flutter/material.dart';
import 'dart:async';
import '../components/noise_meter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;
  bool _isMenuOpen = false;
  bool _isButtonHovered = false;
  bool _isRunning = false;
  bool _isStopped = false;
  int _counter = 0;
  Timer? _timer;
  final GlobalKey<NoiseMeterState> _noiseMeterKey =
      GlobalKey<NoiseMeterState>();
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));

    return '$hours:$minutes:$seconds';
  }

  void _toggleCounter() {
    setState(() {
      if (_isRunning) {
        _isRunning = false;
        _isStopped = true;
        _stopCounter();
      } else if (_isStopped) {
        _counter = 0;
        _isStopped = false;
        _startTime = null;
        _noiseMeterKey.currentState?.resetStats();
      } else {
        _isRunning = true;
        _startTime = DateTime.now();
        _startCounter();
      }
    });
  }

  void _startCounter() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_startTime != null) {
          _counter = DateTime.now().difference(_startTime!).inSeconds;
        }
      });
    });
  }

  void _stopCounter() {
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1C20), Color(0xFF282C34)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Welcome Text with animation
                    MouseRegion(
                      onEnter: (_) => setState(() => _isHovered = true),
                      onExit: (_) => setState(() => _isHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        transform:
                            Matrix4.identity()
                              ..translate(0.0, _isHovered ? -5.0 : 0.0)
                              ..scale(_isHovered ? 1.05 : 1.0),
                        child: ShaderMask(
                          shaderCallback:
                              (bounds) => const LinearGradient(
                                colors: [
                                  Colors.white,
                                  Color(0xFF61DAFB),
                                  Colors.white,
                                ],
                              ).createShader(bounds),
                          child: const Text(
                            'Welcome to QuietNet',
                            style: TextStyle(
                              fontSize: 35,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Decorative Line
                    Container(
                      height: 2,
                      width: 100,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFF61DAFB),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Noise Meter
                    NoiseMeter(
                      key: _noiseMeterKey,
                      isRunning: _isRunning,
                      onToggle: _toggleCounter,
                    ),
                    const SizedBox(height: 30),
                    // Counter
                    Text(
                      _formatDuration(Duration(seconds: _counter)),
                      style: const TextStyle(
                        color: Color(0xFF61DAFB),
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Start/Stop Button
                    MouseRegion(
                      onEnter: (_) => setState(() => _isButtonHovered = true),
                      onExit: (_) => setState(() => _isButtonHovered = false),
                      child: GestureDetector(
                        onTap: _toggleCounter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          transform:
                              Matrix4.identity()
                                ..translate(0.0, _isButtonHovered ? -3.0 : 0.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: const Color(0xFF61DAFB),
                              width: 1,
                            ),
                            boxShadow:
                                _isButtonHovered
                                    ? [
                                      const BoxShadow(
                                        color: Color(0x4861DAFB),
                                        blurRadius: 15,
                                        spreadRadius: 1,
                                      ),
                                      const BoxShadow(
                                        color: Color(0x2861DAFB),
                                        blurRadius: 20,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                    : [],
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            child: Text(
                              _isRunning
                                  ? 'Stop'
                                  : (_isStopped ? 'Reset' : 'Start'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Side Menu
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              right: _isMenuOpen ? 0 : -300,
              top: 0,
              bottom: 0,
              width: 300,
              child: _buildSideMenu(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideMenu() {
    return Container(
      color: const Color(0xFF1A1C20).withOpacity(0.95),
      child: Stack(
        children: [
          Positioned(
            left: -50,
            top: MediaQuery.of(context).size.height / 2 - 20,
            child: IconButton(
              icon: Icon(
                _isMenuOpen ? Icons.close : Icons.menu,
                color: const Color(0xFF61DAFB),
              ),
              onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Add menu items here
              ],
            ),
          ),
        ],
      ),
    );
  }
}
