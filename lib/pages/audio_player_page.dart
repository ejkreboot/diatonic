import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:async';
import '../models/audio_waveform.dart';
import '../widgets/waveform_visualizer.dart';
import '../widgets/saved_regions_panel.dart';
import '../models/saved_regions.dart';

/// Controller to control the AudioPlayerPage from outside (e.g., for keyboard shortcuts)
class AudioPlayerController {
  _AudioPlayerPageState? _state;

  void _attach(_AudioPlayerPageState state) {
    _state = state;
  }

  void _detach(_AudioPlayerPageState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }

  void togglePlayPause() {
    _state?._playPause();
  }
}

class AudioPlayerPage extends StatefulWidget {
  final AudioPlayerController? controller;
  const AudioPlayerPage({super.key, this.controller});

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> with TickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  List<double> amplitudes = [];
  String? _fileName;
  Duration _currentPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  double? _loopStartFraction;
  double? _loopEndFraction;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();
  bool _loading = false;
  final List<SavedRegion> _savedRegions = [];
  double _volume = 1.0; // Volume from 0.0 to 1.0

  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
  widget.controller?._attach(this);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _startFocusNode.addListener(() {
      if (!_startFocusNode.hasFocus) _updateLoopFromTextFields();
    });
    
    _endFocusNode.addListener(() {
      if (!_endFocusNode.hasFocus) _updateLoopFromTextFields();
    });

    _durationSub = _player.durationStream.listen((duration) {
      if (!mounted) return;
      if (duration != null) {
        setState(() {
          _audioDuration = duration;
        });
      }
    });

    _positionSub = _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;

        if (_shouldLoop) {
          final startMs = (_audioDuration.inMilliseconds * _realStart).toInt();
          final endMs = (_audioDuration.inMilliseconds * _realEnd).toInt();

          if (_currentPosition.inMilliseconds >= endMs) {
            _player.seek(Duration(milliseconds: startMs));
          }
        }
      });
    });
  }

  bool get _shouldLoop =>
      _loopStartFraction != null &&
      _loopEndFraction != null &&
      _loopStartFraction != _loopEndFraction &&
      _audioDuration.inMilliseconds > 0;

  double get _realStart =>
      (_loopStartFraction! < _loopEndFraction!) ? _loopStartFraction! : _loopEndFraction!;

  double get _realEnd =>
      (_loopStartFraction! > _loopEndFraction!) ? _loopStartFraction! : _loopEndFraction!;

  double get _currentProgress => (_audioDuration.inMilliseconds == 0)
      ? 0.0
      : _currentPosition.inMilliseconds / _audioDuration.inMilliseconds;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  String _formatFractionAsMMSS(double fraction) {
    if (_audioDuration.inMilliseconds == 0) return '00:00';
    final milliseconds = (_audioDuration.inMilliseconds * fraction).toInt();
    return _formatDuration(Duration(milliseconds: milliseconds));
  }

  void _updateLoopFromTextFields() {
    if (_audioDuration.inMilliseconds == 0) return;

    try {
      parseTime(String text) {
        final parts = text.trim().split(':');
        if (parts.length != 2) throw FormatException('Invalid time format');
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return Duration(minutes: minutes, seconds: seconds).inMilliseconds;
      }

      final startText = _startController.text;
      final endText = _endController.text;

      final startMs = parseTime(startText);
      final endMs = (endText.isEmpty) ? startMs : parseTime(endText);

      setState(() {
        _loopStartFraction = (startMs / _audioDuration.inMilliseconds).clamp(0.0, 1.0);
        _loopEndFraction = (endMs / _audioDuration.inMilliseconds).clamp(0.0, 1.0);
      });

      _updateBreathing();
    } catch (e) {
      debugPrint('Invalid time format: $e');
    }
  }

  void _updateBreathing() {
    if (_shouldLoop) {
      if (!_scaleController.isAnimating) {
        _scaleController.repeat(reverse: true);
      }
    } else {
      if (_scaleController.isAnimating) {
        _scaleController.stop();
      }
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
  _durationSub?.cancel();
  _positionSub?.cancel();
    _scaleController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AudioPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  Future<void> _pickAndLoadAudio() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        
        // Clear previous selections and saved regions
        if (!mounted) return;
        setState(() {
          _loopStartFraction = null;
          _loopEndFraction = null;
          _startController.clear();
          _endController.clear();
          _savedRegions.clear();
        });

        amplitudes.clear();
        amplitudes = await compute(readWaveformInIsolate, path);
        debugPrint("Amplitude samples: ${amplitudes.length}");

        await _player.setFilePath(path);
        await _player.setVolume(_volume); // Initialize volume

        if (!mounted) return;
        setState(() {
          _fileName = File(path).uri.pathSegments.last;
          _currentPosition = Duration.zero; // <- optional, resets displayed time
        });

        // Load regions AFTER setting file name
        final loadedRegions = await SavedRegion.loadRegions(_fileName!);
        if (!mounted) return;
        setState(() {
          _savedRegions.addAll(loadedRegions);
        });
      }
    } catch (e) {
      debugPrint('Error loading audio: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _playPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _restart() {
    _player.seek(Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF393939), // Match piano app container color
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Buttons section
                    ElevatedButton.icon(
                      icon: const Icon(Icons.library_music_outlined, size: 20, color: Color(0xFFE5E5E5)),
                      label: const Text('Load', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFFE5E5E5))),
                      onPressed: _pickAndLoadAudio,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF393939),
                        foregroundColor: const Color(0xFFE5E5E5),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFF4A4A4A), width: 0.5),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    StreamBuilder<bool>(
                      stream: _player.playingStream,
                      builder: (context, snapshot) {
                        bool isPlaying = snapshot.data ?? false;
                        return ElevatedButton.icon(
                          label: Text("Play", style: TextStyle(fontSize: 12, color: const Color(0xFFE5E5E5), fontWeight: FontWeight.w400)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF393939),
                            foregroundColor: const Color(0xFFE5E5E5),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFF4A4A4A), width: 0.5),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 20,
                            color: const Color(0xFFF9931A),
                          ),
                          onPressed: _playPause,
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      label: Text("Restart", style: TextStyle(fontSize: 12, color: const Color(0xFFE5E5E5), fontWeight: FontWeight.w400)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF393939),
                        foregroundColor: const Color(0xFFE5E5E5),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFF4A4A4A), width: 0.5),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.replay, size: 20, color: Color(0xFFE5E5E5)),
                      onPressed: _restart,
                    ),
                    const SizedBox(width: 12),
                    // Speed control
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Icon(
                            Icons.speed,
                            size: 14,
                            color: const Color(0xFFF9931A),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                                valueIndicatorColor: const Color(0xFFF9931A),
                                valueIndicatorTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                              child: Slider(
                                min: 0.5,
                                max: 1.5,
                                divisions: 10,
                                value: _player.speed,
                                label: '${_player.speed.toStringAsFixed(2)}x',
                                onChanged: (value) {
                                  _player.setSpeed(value);
                                  setState(() {});
                                },
                                activeColor: const Color(0xFFF9931A),
                                inactiveColor: const Color(0xFF5A5A5A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Volume control
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Icon(
                            _volume > 0.5 ? Icons.volume_up : (_volume > 0 ? Icons.volume_down : Icons.volume_off),
                            size: 14,
                            color: const Color(0xFFF9931A),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                                valueIndicatorColor: const Color(0xFFF9931A),
                                valueIndicatorTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                              child: Slider(
                                min: 0.0,
                                max: 1.0,
                                divisions: 20,
                                value: _volume,
                                label: '${(_volume * 100).round()}%',
                                onChanged: (value) {
                                  setState(() {
                                    _volume = value;
                                  });
                                  _player.setVolume(value);
                                },
                                activeColor: const Color(0xFFF9931A),
                                inactiveColor: const Color(0xFF5A5A5A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Start time input
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _startController,
                        focusNode: _startFocusNode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: Color(0xFFE5E5E5)),
                        decoration: InputDecoration(
                          labelText: 'Start (MM:SS)',
                          labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w400, color: Color(0xFFB8B8B8)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFF5A5A5A), width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFF5A5A5A), width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFFF9931A), width: 1),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF2F2F2F),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _updateLoopFromTextFields(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // End time input
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _endController,
                        focusNode: _endFocusNode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: Color(0xFFE5E5E5)),
                        decoration: InputDecoration(
                          labelText: 'End (MM:SS)',
                          labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w400, color: Color(0xFFB8B8B8)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFF5A5A5A), width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFF5A5A5A), width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFFF9931A), width: 1),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF2F2F2F),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _updateLoopFromTextFields(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _fileName != null ? 'Loaded: $_fileName' : 'No audio file loaded',
                  style: const TextStyle(color: Color(0xFFB8B8B8), fontSize: 11, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFF9931A))),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF4A4A4A), width: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    height: 120,
                    child: amplitudes.isNotEmpty
                      ? AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scaleX: 1.0,
                              scaleY: _scaleAnimation.value,
                              child: child,
                            );
                          },
                          child: WaveformVisualizer(
                            amplitudes: amplitudes,
                            loopStartFraction: _loopStartFraction,
                            loopEndFraction: _loopEndFraction,
                            progress: _currentProgress,
                            currentTimeLabel: _formatDuration(_currentPosition),
                            onSeek: (fraction) {
                              final newPosition = Duration(
                                milliseconds: (_audioDuration.inMilliseconds * fraction).toInt(),
                              );
                              _player.seek(newPosition);
                            },
                            onSelectStart: (value) {
                              setState(() {
                                _loopStartFraction = value;
                                _loopEndFraction = value;
                                _startController.text = _formatFractionAsMMSS(value);
                                _endController.text = _formatFractionAsMMSS(value);
                              });
                              _updateBreathing();
                            },
                            onSelectEnd: (value) {
                              setState(() {
                                _loopEndFraction = value;
                                _endController.text = _formatFractionAsMMSS(value);
                              });
                              _updateBreathing();
                            },
                            onClearLoop: () {
                              setState(() {
                                _loopStartFraction = null;
                                _loopEndFraction = null;
                                _startController.clear();
                                _endController.clear();
                              });
                              _updateBreathing();
                            },
                          ),
                        )
                      : const Center(
                          child: Text(
                            ' ',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ),
                  ),
                const SizedBox(height: 12),
                (_audioDuration.inMilliseconds > 0)
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_currentPosition), style: const TextStyle(fontSize: 10, color: Color(0xFFB8B8B8))),
                      Text(_formatDuration(_audioDuration), style: const TextStyle(fontSize: 10, color: Color(0xFFB8B8B8))),
                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("0:00", style: const TextStyle(fontSize: 10, color: Color(0xFFB8B8B8))),
                      Text("0:00", style: const TextStyle(fontSize: 10, color: Color(0xFFB8B8B8))),
                    ],
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Saved Selections',
                    style: TextStyle(
                      color: const Color(0xFFF9931A),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 80, // Reduced minimum height to save space
                      maxHeight: double.infinity,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF5A5A5A), width: 0.5),
                      borderRadius: BorderRadius.circular(6),
                      color: const Color(0xFF2F2F2F),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: SavedRegionsPanel(
                      audioFileName: _fileName.toString(),
                      regions: _savedRegions,
                      onSave: (name) {
                        if (_loopStartFraction != null && _loopEndFraction != null) {
                          setState(() {
                            _savedRegions.add(SavedRegion(
                              name: name,
                              startFraction: _loopStartFraction!,
                              endFraction: _loopEndFraction!,
                            ));
                          });
                        }
                      },
                      onSelect: (region) {
                        setState(() {
                          _loopStartFraction = region.startFraction;
                          _loopEndFraction = region.endFraction;
                          _startController.text = _formatFractionAsMMSS(region.startFraction);
                          _endController.text = _formatFractionAsMMSS(region.endFraction);
                        });
                        _updateBreathing();
                        final startMs = (_audioDuration.inMilliseconds * region.startFraction).toInt();
                        _player.seek(Duration(milliseconds: startMs));
                      },
                    ),       
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
        ),
    );
  }
}