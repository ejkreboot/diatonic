import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/piano_keyboard.dart';

class PianoSound {
  late AudioCache _cache;

  // Constructor to pre-initialize cache and load all audio
  PianoSound() {
    _initializeCache();
  }

  // this may actually not be necessary. 
  void _initializeCache() async {
    _cache = AudioCache(prefix: 'assets/audio/');    
    final audioFiles = PianoKeyboard.allKeys.map((note) => '$note.wav').toList();
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

      // Always play root
      final rootPlayer = AudioPlayer();
      futures.add(rootPlayer.play(AssetSource('audio/$rootNote.wav')));

      // Play intervals if provided
      if (minorThirdNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$minorThirdNote.wav')));
      }
      if (majorThirdNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$majorThirdNote.wav')));
      }
      if (perfectFifthNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$perfectFifthNote.wav')));
      }
      if (minorSeventhNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$minorSeventhNote.wav')));
      }
      if (majorSeventhNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$majorSeventhNote.wav')));
      }
      if (ninthNote != null) {
        final player = AudioPlayer();
        futures.add(player.play(AssetSource('audio/$ninthNote.wav')));
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
