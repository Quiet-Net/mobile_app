import 'package:flutter/material.dart';
import 'package:mic_stream/mic_stream.dart';
import 'dart:async';
import '../utils/permission_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

class NoiseMeter extends StatefulWidget {
  const NoiseMeter({super.key});

  @override
  State<NoiseMeter> createState() => _NoiseMeterState();
}

class _NoiseMeterState extends State<NoiseMeter> {
  bool _isRecording = false;
  double _decibels = 0.0;
  double _minDecibels = double.infinity;
  double _maxDecibels = 0.0;
  double _smoothedDecibels = 0.0;
  Timer? _timer;
  StreamSubscription? _micStreamSubscription;
  static const double _smoothingFactor = 0.3;

  // Enhanced calibration values based on comparison with professional meter
  static const double _referenceDb = 94.0; // Standard calibration value
  static const double _referenceAmplitude =
      0.5; // Approximate RMS value for 94dB
  static const double _dbOffset =
      -5.0; // Negative offset to bring all values down
  static const double _dbScalingFactor =
      0.7; // Stronger scaling factor for better calibration

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestMicrophonePermission();
    });
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
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          openAppSettings();
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

          // Apply smoothing to the decibel value
          final smoothedDb = _smoothDecibels(rawDb);

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

    // Convert to decibels using enhanced calibration formula
    double db = 0;

    if (rms > 0) {
      // Standard SPL calibration formula
      db = _referenceDb + 20 * log(rms / _referenceAmplitude) / ln10;

      // Apply stronger scaling and offset
      db = _dbOffset + (db - _referenceDb) * _dbScalingFactor + _referenceDb;

      // Apply a specific correction to match the professional meter
      // 45dB in our app should read as 30dB (difference of 15dB)
      double calibrationPoint = 45.0; // Our app's reading
      double targetValue = 30.0; // Target reading (professional meter)
      double correctionFactor =
          (calibrationPoint - targetValue) / calibrationPoint;

      // Apply nonlinear correction that affects lower ranges more strongly
      // This creates a curve that applies stronger correction at lower levels
      db = db - (db * correctionFactor * (1.0 - (db / 120.0)));

      // Limit the range of values to sensible ones
      db = db.clamp(20.0, 120.0);
    } else {
      db = 20.0; // Silence or very quiet sound
    }

    // Debug prints
    debugPrint('RMS: $rms');
    debugPrint('Calculated dB: $db');
    if (samples.isNotEmpty) {
      debugPrint('Max sample: ${samples.reduce((a, b) => a > b ? a : b)}');
      debugPrint('Min sample: ${samples.reduce((a, b) => a < b ? a : b)}');
    }

    return db;
  }

  void _stopRecording() {
    _timer?.cancel();
    _micStreamSubscription?.cancel();
    setState(() {
      _isRecording = false;
      _minDecibels = double.infinity;
      _maxDecibels = 0.0;
      _smoothedDecibels = 0.0;
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
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap:
                    _isRecording
                        ? _stopRecording
                        : _requestMicrophonePermission,
                child: Icon(
                  _isRecording ? Icons.mic : Icons.mic_off,
                  color: _isRecording ? const Color(0xFF61DAFB) : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    _isRecording
                        ? _getDecibelColor(_decibels)
                        : const Color(0xFF61DAFB),
                width: 2,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isRecording ? '${_decibels.toStringAsFixed(1)} dB' : 'OFF',
                    style: TextStyle(
                      color:
                          _isRecording
                              ? _getDecibelColor(_decibels)
                              : Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  if (_isRecording) ...[
                    Text(
                      _getLevelDescription(_decibels),
                      style: TextStyle(
                        color: _getDecibelColor(_decibels),
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Min: ${_minDecibels.toStringAsFixed(1)} | Max: ${_maxDecibels.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Add level visualization
          if (_isRecording) ...[
            const SizedBox(height: 15),
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
