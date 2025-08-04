import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/piano_keyboard.dart';

class PianoSound {
  late AudioCache _cache;
  int _dynamicLevel = 2; // 0=Pianissimo, 1=Piano, 2=MezzoPiano, 3=MezzoForte, 4=Forte
  
  // Dynamic level names corresponding to sample filenames
  static const List<String> _dynamicNames = [
    'Pianissimo',
    'Piano', 
    'MezzoPiano',
    'MezzoForte',
    'Forte'
  ];

  // Constructor to pre-initialize cache and load all audio
  PianoSound() {
    _initializeCache();
  }

  // Set dynamic level (0-4)
  void setDynamicLevel(int level) {
    _dynamicLevel = level.clamp(0, 4);
  }

  // Get current dynamic level
  int get dynamicLevel => _dynamicLevel;
  
  // Get current dynamic name
  String get currentDynamic => _dynamicNames[_dynamicLevel];

  // this may actually not be necessary. 
  void _initializeCache() async {
    _cache = AudioCache(prefix: 'assets/audio/');    
    // Load all combinations of notes and dynamics
    final audioFiles = <String>[];
    for (final note in PianoKeyboard.allKeys) {
      for (final dynamic in _dynamicNames) {
        audioFiles.add('$note-$dynamic.wav');
      }
    }
    await _cache.loadAll(audioFiles);
  }

  Future<void> playChord({
    required String rootNote,
    String? minorThirdNote,
    String? majorThirdNote,
    String? perfectFifthNote,
    String? minorSeventhNote,
    String? majorSeventhNote,
    String? ninthNote,
  }) async {
    try {
      final futures = <Future>[];
      final currentDynamicName = _dynamicNames[_dynamicLevel];

      // Always play root
      final rootPlayer = AudioPlayer();
      futures.add(rootPlayer.play(AssetSource('audio/$rootNote-$currentDynamicName.wav')));

      // Play intervals if provided
      if (minorThirdNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$minorThirdNote-$currentDynamicName.wav')));
      }
      if (majorThirdNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$majorThirdNote-$currentDynamicName.wav')));
      }
      if (perfectFifthNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$perfectFifthNote-$currentDynamicName.wav')));
      }
      if (minorSeventhNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$minorSeventhNote-$currentDynamicName.wav')));
      }
      if (majorSeventhNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$majorSeventhNote-$currentDynamicName.wav')));
      }
      if (ninthNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$ninthNote-$currentDynamicName.wav')));
      }

      // Play all simultaneously
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Audio playback error: $e');
    }
  }

  // ...existing code...

  // Clean up resources
  void dispose() {
    _cache.clearAll();
  }
}
