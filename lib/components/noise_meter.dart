import 'package:flutter/material.dart';
import 'package:mic_stream/mic_stream.dart';
import 'dart:async';
import '../utils/permission_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

class NoiseMeter extends StatefulWidget {
  final bool isRunning;
  final VoidCallback onToggle;

  const NoiseMeter({
    super.key,
    required this.isRunning,
    required this.onToggle,
  });

  @override
  NoiseMeterState createState() => NoiseMeterState();
}

class NoiseMeterState extends State<NoiseMeter> {
  bool _isRecording = false;
  double _decibels = 0.0;
  double _minDecibels = double.infinity;
  double _maxDecibels = 0.0;
  double _smoothedDecibels = 0.0;
  double _averageDecibels = 0.0;
  int _measurementCount = 0;
  Timer? _timer;
  StreamSubscription? _micStreamSubscription;
  static const double _smoothingFactor = 0.3;

  // Basic calibration values
  static const double _referenceDb = 94.0; // Standard calibration value
  static const double _referenceAmplitude =
      0.5; // Approximate RMS value for 94dB

  @override
  void initState() {
    super.initState();
    // Remove automatic permission request and recording start
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _requestMicrophonePermission();
    // });
  }

  @override
  void didUpdateWidget(NoiseMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _requestMicrophonePermission();
      } else {
        _stopRecording();
      }
    }
  }

  Future<void> _requestMicrophonePermission() async {
    RequestPermissionManager(PermissionType.microphone)
        .onPermissionDenied(() {
          debugPrint('Microphone permission denied');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('App requires microphone access'),
                duration: Duration(seconds: 3),
              ),
            );
            // Notify parent to stop running state if permission denied
            widget.onToggle();
          }
        })
        .onPermissionGranted(() {
          debugPrint('Microphone permission granted');
          _startRecording();
        })
        .onPermissionPermanentlyDenied(() {
          debugPrint('Microphone permission permanently denied');
          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (BuildContext context) => AlertDialog(
                    title: const Text('Microphone access required'),
                    content: const Text(
                      'To measure noise levels, the app needs microphone access. '
                      'Please enable access in settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Notify parent to stop running state if permission denied
                          widget.onToggle();
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          openAppSettings();
                          // Notify parent to stop running state if permission denied
                          widget.onToggle();
                        },
                        child: const Text('Open settings'),
                      ),
                    ],
                  ),
            );
          }
        })
        .execute();
  }

  Future<void> _startRecording() async {
    try {
      setState(() {
        _minDecibels = double.infinity;
        _maxDecibels = 0.0;
        _smoothedDecibels = 0.0;
        _averageDecibels = 0.0;
        _measurementCount = 0;
      });

      final stream = await MicStream.microphone(
        sampleRate: 44100,
        channelConfig: ChannelConfig.CHANNEL_IN_MONO,
        audioFormat: AudioFormat.ENCODING_PCM_16BIT,
        audioSource: AudioSource.DEFAULT,
      );

      if (stream == null) {
        debugPrint('Failed to get microphone stream');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot access microphone'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      _micStreamSubscription = stream.listen(
        (data) {
          final rawDb = _calculateAmplitude(data);
          final smoothedDb = _smoothDecibels(rawDb);

          // Update average
          _measurementCount++;
          _averageDecibels =
              ((_averageDecibels * (_measurementCount - 1)) + smoothedDb) /
              _measurementCount;

          setState(() {
            _decibels = smoothedDb;
            if (smoothedDb < _minDecibels) {
              _minDecibels = smoothedDb;
            }
            if (smoothedDb > _maxDecibels) {
              _maxDecibels = smoothedDb;
            }
          });
        },
        onError: (error) {
          debugPrint('Microphone stream error: $error');
        },
      );

      setState(() => _isRecording = true);
    } catch (err) {
      debugPrint('Error in _startRecording: $err');
    }
  }

  // Function to smooth decibel values
  double _smoothDecibels(double newValue) {
    _smoothedDecibels =
        _smoothedDecibels == 0.0
            ? newValue
            : _smoothedDecibels * (1 - _smoothingFactor) +
                newValue * _smoothingFactor;
    return _smoothedDecibels;
  }

  double _calculateAmplitude(List<int> data) {
    if (data.isEmpty) return 0;

    // Convert bytes to 16-bit values (fixed for little-endian)
    final samples = <int>[];
    for (var i = 0; i < data.length; i += 2) {
      if (i + 1 < data.length) {
        // Little-endian: LSB first, then MSB
        int sample = data[i] | (data[i + 1] << 8);

        // Convert to signed value
        if (sample > 32767) {
          sample -= 65536;
        }

        samples.add(sample);
      }
    }

    // Calculate RMS (Root Mean Square)
    double sumSquares = 0;
    for (var sample in samples) {
      // Normalize to -1.0 to 1.0 range
      double normalizedSample = sample / 32768.0;
      sumSquares += normalizedSample * normalizedSample;
    }
    double rms = sqrt(sumSquares / samples.length);

    // Convert to decibels using standard calibration formula
    double db = 0;

    if (rms > 0) {
      // First, calculate standard SPL
      db = _referenceDb + 20 * log(rms / _referenceAmplitude) / ln10;

      // Apply direct linear calibration based on empirical data
      // We're using a simple but effective approach:
      // - Observed: when app shows 39 dB, professional meter shows 31 dB
      // - The ratio is approximately 1.26 (39/31)
      // - Therefore we'll use a linear transform: actual_db = app_db / 1.26
      db = db / 1.26;

      // Limit the range of values to sensible ones
      db = db.clamp(20.0, 120.0);
    } else {
      db = 20.0; // Silence or very quiet sound
    }

    // Debug prints
    //debugPrint('RMS: $rms');
    //debugPrint('Calculated dB: $db');
    if (samples.isNotEmpty) {
      //debugPrint('Max sample: ${samples.reduce((a, b) => a > b ? a : b)}');
      //debugPrint('Min sample: ${samples.reduce((a, b) => a < b ? a : b)}');
    }

    return db;
  }

  void _stopRecording() {
    _timer?.cancel();
    _micStreamSubscription?.cancel();
    setState(() {
      _isRecording = false;
      // Don't reset the values when stopping
      // _minDecibels = double.infinity;
      // _maxDecibels = 0.0;
      // _smoothedDecibels = 0.0;
      // _averageDecibels = 0.0;
      // _measurementCount = 0;
    });
  }

  void resetStats() {
    setState(() {
      _decibels = 0.0;
      _minDecibels = double.infinity;
      _maxDecibels = 0.0;
      _smoothedDecibels = 0.0;
      _averageDecibels = 0.0;
      _measurementCount = 0;
    });
  }

  @override
  void dispose() {
    _micStreamSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Color _getDecibelColor(double db) {
    if (db < 50) return Colors.green;
    if (db < 65) return Colors.yellow;
    if (db < 80) return Colors.orange;
    return Colors.red;
  }

  // Build a visual level indicator
  Widget _buildLevelIndicator() {
    // Create a visual indicator of sound level
    final double levelPercentage = (_decibels - 20) / 100; // 20-120 dB range
    final double constrainedLevel = levelPercentage.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.grey[800],
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: constrainedLevel,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: LinearGradient(
              colors: [Colors.green, Colors.yellow, Colors.orange, Colors.red],
              stops: const [0.3, 0.5, 0.7, 0.9],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C20).withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF61DAFB), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Noise Level',
                style: TextStyle(
                  color: Color(0xFF61DAFB),
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _getDecibelColor(_decibels), width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_decibels > 0) ...[
                    Text(
                      '${_decibels.toStringAsFixed(1)} dB',
                      style: TextStyle(
                        color: _getDecibelColor(_decibels),
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      _getLevelDescription(_decibels),
                      style: TextStyle(
                        color: _getDecibelColor(_decibels),
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.mic_off_rounded,
                      size: 72,
                      color: Color(0xFF61DAFB),
                    ),
                  ],
                  if (_decibels > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Min: ${_minDecibels.toStringAsFixed(1)} | Avg: ${_averageDecibels.toStringAsFixed(1)} | Max: ${_maxDecibels.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_decibels > 0) ...[
            const SizedBox(height: 20),
            _buildLevelIndicator(),
          ],
        ],
      ),
    );
  }

  String _getLevelDescription(double db) {
    if (db < 30) return 'Very Quiet';
    if (db < 40) return 'Quiet';
    if (db < 50) return 'Moderate';
    if (db < 65) return 'Loud';
    if (db < 80) return 'Very Loud';
    if (db < 90) return 'Harmful';
    return 'Dangerous';
  }
}
