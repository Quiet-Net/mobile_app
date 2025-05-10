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
  static const double _smoothingFactor =
      0.3; // Adjust this value to control smoothing (0.0 to 1.0)

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
                content: Text('Aplikacja wymaga dostępu do mikrofonu'),
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
                    title: const Text('Wymagany dostęp do mikrofonu'),
                    content: const Text(
                      'Aby mierzyć poziom hałasu, aplikacja potrzebuje dostępu do mikrofonu. '
                      'Proszę włączyć dostęp w ustawieniach.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Anuluj'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          openAppSettings();
                        },
                        child: const Text('Otwórz ustawienia'),
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
              content: Text('Nie można uzyskać dostępu do mikrofonu'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      _micStreamSubscription = stream.listen(
        (data) {
          final amplitude = _calculateAmplitude(data);
          setState(() {
            _decibels = amplitude;
            if (amplitude < _minDecibels) {
              _minDecibels = amplitude;
            }
            if (amplitude > _maxDecibels) {
              _maxDecibels = amplitude;
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

  double _calculateAmplitude(List<int> data) {
    if (data.isEmpty) return 0;

    // Convert bytes to 16-bit values
    final samples = <int>[];
    for (var i = 0; i < data.length; i += 2) {
      if (i + 1 < data.length) {
        samples.add(data[i] | (data[i + 1] << 8));
      }
    }

    // Calculate RMS (Root Mean Square) instead of simple average
    double sumSquares = 0;
    for (var sample in samples) {
      // Normalize to -1.0 to 1.0 range
      double normalizedSample = sample / 32768.0;
      sumSquares += normalizedSample * normalizedSample;
    }
    double rms = sqrt(sumSquares / samples.length);

    // Convert to decibels
    // 20 * log10(rms) gives us the decibel value
    // We add 100 to get a positive range (typical for noise meters)
    double db = 20 * log(rms) / ln10 + 100;

    // Debug prints
    debugPrint('RMS: $rms');
    debugPrint('Decibels: $db');
    debugPrint('Max sample: ${samples.reduce((a, b) => a > b ? a : b)}');
    debugPrint('Min sample: ${samples.reduce((a, b) => a < b ? a : b)}');

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
    if (db < 60) return Colors.green;
    if (db < 70) return Colors.yellow;
    if (db < 80) return Colors.orange;
    return Colors.red;
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
        ],
      ),
    );
  }

  String _getLevelDescription(double db) {
    if (db < 50) return 'Quiet';
    if (db < 60) return 'Moderate';
    if (db < 70) return 'Loud';
    if (db < 80) return 'Very Loud';
    return 'Dangerous';
  }
}
