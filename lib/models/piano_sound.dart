import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Pooled piano sample playback to avoid "Too many open files" (errno = 24).
class PianoSound {
  // Dynamic level names corresponding to sample filenames
  static const List<String> _dynamicNames = [
    'Pianissimo',
    'Piano',
    'MezzoPiano',
    'MezzoForte',
    'Forte',
  ];
  static const List<String> _dynamicAbbr = ['pp', 'p', 'mp', 'mf', 'f'];

  // Voice pool configuration
  static const int _maxVoices = 100; // simultaneous notes allowed before voice stealing

  int _dynamicLevel = 2; // 0..4

  // Player pools
  final List<AudioPlayer> _idlePlayers = [];
  final Set<AudioPlayer> _busyPlayers = {};
  final Queue<AudioPlayer> _busyQueue = Queue<AudioPlayer>(); // oldest -> newest busy for voice stealing
  final Map<AudioPlayer, int> _generations = {}; // playback generation per player

  PianoSound() {
    _warmEngine();
  }

  // Public API ---------------------------------------------------------------

  void setDynamicLevel(int level) {
    _dynamicLevel = level.clamp(0, _dynamicNames.length - 1);
  }

  int get dynamicLevel => _dynamicLevel;
  String get currentDynamic => _dynamicNames[_dynamicLevel];
  String get currentDynamicShort => _dynamicAbbr[_dynamicLevel];

  /// Play a chord (root + any provided interval notes). Returns after
  /// playback is started (not after samples finish).
  Future<void> playChord({
    required String rootNote,
    String? sus2Note,
    String? minorThirdNote,
    String? majorThirdNote,
    String? sus4Note,
    String? perfectFifthNote,
    String? augmentedFifthNote,
    String? minorSeventhNote,
    String? majorSeventhNote,
    String? ninthNote,
  }) async {
    final dyn = _dynamicNames[_dynamicLevel];

    final notes = <String>[
      rootNote,
      if (sus2Note != null) sus2Note,
      if (minorThirdNote != null) minorThirdNote,
      if (majorThirdNote != null) majorThirdNote,
      if (sus4Note != null) sus4Note,
      if (perfectFifthNote != null) perfectFifthNote,
      if (augmentedFifthNote != null) augmentedFifthNote,
      if (minorSeventhNote != null) minorSeventhNote,
      if (majorSeventhNote != null) majorSeventhNote,
      if (ninthNote != null) ninthNote,
    ];

    final futures = <Future<void>>[];
    for (final n in notes) {
      futures.add(_playNoteFile(n, dyn));
    }
    await Future.wait(futures);
  }

  /// Optional single note helper (if needed elsewhere).
  Future<void> playNote(String noteWithOctave) async {
    await _playNoteFile(noteWithOctave, _dynamicNames[_dynamicLevel]);
  }

  /// Stop all currently playing voices immediately.
  Future<void> stopAll() async {
    for (final p in _busyPlayers.toList()) {
      try {
        await p.stop();
      } catch (_) {}
      _releasePlayer(p);
    }
  }

  Future<void> dispose() async {
    await stopAll();
    for (final p in _idlePlayers) {
      try {
        await p.release();
      } catch (_) {}
    }
    _idlePlayers.clear();
    _busyQueue.clear();
    _generations.clear();
  }

  // Internal -----------------------------------------------------------------

  Future<void> _playNoteFile(String fullNote, String dyn) async {
    final player = _acquirePlayer();
    // Increment generation before starting new playback so prior completion events are ignored.
    final gen = (_generations[player] ?? 0) + 1;
    _generations[player] = gen;
    try {
      await player.play(AssetSource('audio/$fullNote-$dyn.m4a'));
      // Release back to pool when finished (if still same generation).
      player.onPlayerComplete.first.then((_) {
        if (_generations[player] == gen) {
          _releasePlayer(player);
        }
      }).ignore();
    } catch (e) {
      // Only release if still this generation.
      if (_generations[player] == gen) {
        _releasePlayer(player);
      }
      debugPrint('Audio playback error: $e');
    }
  }

  AudioPlayer _createPlayer() {
    final p = AudioPlayer();
    // We want independent overlapping playback.
    p.setReleaseMode(ReleaseMode.stop);
    return p;
  }

  AudioPlayer _acquirePlayer() {
    AudioPlayer player;
    if (_idlePlayers.isNotEmpty) {
      player = _idlePlayers.removeLast();
    } else if (_busyPlayers.length < _maxVoices) {
      player = _createPlayer();
    } else {
      // Voice stealing: oldest busy (front of queue)
      player = _busyQueue.isNotEmpty ? _busyQueue.removeFirst() : _busyPlayers.first;
      try {
        player.stop();
      } catch (_) {}
    }
    _busyPlayers.add(player);
    // Ensure not duplicated in queue then push to back as newest
    _busyQueue.remove(player);
    _busyQueue.add(player);
    return player;
  }

  void _releasePlayer(AudioPlayer p) {
    if (!_busyPlayers.contains(p)) return;
    _busyPlayers.remove(p);
    _busyQueue.remove(p);
    _idlePlayers.add(p);
  }

  void _warmEngine() {
    // Fire-and-forget warmup (prevents initial latency); ignore errors.
    final p = _acquirePlayer();
    final gen = (_generations[p] ?? 0) + 1;
    _generations[p] = gen;
    p.play(
      AssetSource('audio/A#0-Forte.m4a'),
      volume: 0,
    ).then((_) {
      p.onPlayerComplete.first.then((_) {
        if (_generations[p] == gen) {
          _releasePlayer(p);
        }
      }).ignore();
    }).catchError((_) {
      if (_generations[p] == gen) {
        _releasePlayer(p);
      }
    });
  }
}