import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_size/window_size.dart';
import 'widgets/piano_keyboard.dart';
import 'models/piano_sound.dart';
import 'models/scales.dart';
import 'pages/audio_player_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Chorder');
    setWindowMinSize(const Size(800, 420));
    setWindowFrame(const Rect.fromLTWH(100, 100, 1200, 420));
  }

  runApp(const ChorderApp());
}

class ChorderApp extends StatelessWidget {
  const ChorderApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 920,
          maxWidth: double.infinity,
        ),
        child: const PianoPage(),
      ),
    );
  }
}

class PianoPage extends StatefulWidget {
  const PianoPage({super.key});

  @override
  State<PianoPage> createState() => _PianoPageState();
}

class _PianoPageState extends State<PianoPage> {
  final PianoSound _sound = PianoSound();
  final FocusNode _focusNode = FocusNode();
  
  // Key and Mode settings
  String _selectedKey = 'None';
  String _selectedMode = 'Ionian (Major)';
  
  // Available keys and modes from Scales class
  final List<String> _keys = Scales.getAvailableKeys();
  final List<String> _modes = Scales.getAvailableModes();
  
  // Interval settings - now using semitone-based approach
  final List<bool> _intervals = List.filled(12, false); // Index 0-11 for semitones 0-11
  
  // Interval names for tooltips (semitones 1-11, skipping 0 as it's the root)
  static const List<String> _intervalNames = [
    '', // 0 semitones (root) - not used
    'Minor 2nd',        // 1
    'Major 2nd (sus2)', // 2
    'Minor 3rd',        // 3
    'Major 3rd',        // 4
    'Perfect 4th (sus4)', // 5
    'Tritone',          // 6
    'Perfect 5th',      // 7
    'Augmented 5th',    // 8
    'Major 6th',        // 9
    'Minor 7th',        // 10
    'Major 7th',        // 11
  ];

  // Active notes for animation
  Set<String> _activeNotes = {};
  
  // Track currently pressed keys to avoid clearing while held
  final Set<String> _pressedKeys = {};
  final Set<LogicalKeyboardKey> _pressedKeyboardKeys = {};
  
  // Map keyboard keys to their triggered notes for proper release tracking
  final Map<LogicalKeyboardKey, String> _keyboardToNoteMap = {};
  
  // Map keyboard keys to ALL notes they triggered (including intervals)
  final Map<LogicalKeyboardKey, Set<String>> _keyboardToAllNotesMap = {};
  
  // Audio player visibility
  bool _showAudioPlayer = false;

  // Piano dynamic level control (0-4)
  int _pianoDynamicLevel = 2; // Start at MezzoPiano (middle level)
  
  // Dynamic level names for display
  static const List<String> _dynamicNames = [
    'Pianissimo',
    'Piano', 
    'MezzoPiano',
    'MezzoForte',
    'Forte'
  ];

  // Get current scale notes
  List<String> get _currentScaleNotes => Scales.getScaleNotes(_selectedKey, _selectedMode);

  // Calculate interval note based on semitones
  String? _getIntervalNote(String baseNote, int semitones) {
    final noteIndex = PianoKeyboard.allKeys.indexOf(baseNote);
    if (noteIndex == -1 || noteIndex + semitones >= PianoKeyboard.allKeys.length) {
      return null; // Note not found or interval goes beyond piano range
    }
    return PianoKeyboard.allKeys[noteIndex + semitones];
  }

  void _playNoteWithIntervals(String note, {LogicalKeyboardKey? triggeredByKey}) {
    // Add this note to pressed keys
    _pressedKeys.add(note);
    
    // Calculate interval notes
    final notesToPlay = <String>[note]; // Start with the base note
    
    // Add intervals if enabled (checking semitones 1-11, skipping 0 as it's the root)
    for (int semitones = 1; semitones < 12; semitones++) {
      if (_intervals[semitones]) {
        final intervalNote = _getIntervalNote(note, semitones);
        if (intervalNote != null) {
          notesToPlay.add(intervalNote);
          _pressedKeys.add(intervalNote);
        }
      }
    }
    
    // If this was triggered by a keyboard key, track all notes it triggered
    if (triggeredByKey != null) {
      _keyboardToAllNotesMap[triggeredByKey] = notesToPlay.toSet();
    }
    
    // Animate the keys - add to existing active notes instead of replacing
    setState(() {
      _activeNotes = _activeNotes.union(notesToPlay.toSet());
    });
    
    // Play chord with calculated intervals
    _sound.playChord(
      rootNote: note,
      sus2Note: notesToPlay.length > 1 && _intervals[2] ? _getIntervalNote(note, 2) : null,
      minorThirdNote: notesToPlay.length > 1 && _intervals[3] ? _getIntervalNote(note, 3) : null,
      majorThirdNote: notesToPlay.length > 1 && _intervals[4] ? _getIntervalNote(note, 4) : null,
      sus4Note: notesToPlay.length > 1 && _intervals[5] ? _getIntervalNote(note, 5) : null,
      perfectFifthNote: notesToPlay.length > 1 && _intervals[7] ? _getIntervalNote(note, 7) : null,
      augmentedFifthNote: notesToPlay.length > 1 && _intervals[8] ? _getIntervalNote(note, 8) : null,
      minorSeventhNote: notesToPlay.length > 1 && _intervals[10] ? _getIntervalNote(note, 10) : null,
      majorSeventhNote: notesToPlay.length > 1 && _intervals[11] ? _getIntervalNote(note, 11) : null,
      ninthNote: notesToPlay.length > 1 && _intervals.length > 14 ? _getIntervalNote(note, 14) : null, // 9th if we extend beyond octave
    );
    
    // Schedule clearing, but only if no keys are still pressed
    _scheduleNoteClear();
  }
  
  void _scheduleNoteClear() {
    Future.delayed(const Duration(milliseconds: 10), () {
      if (mounted) {
        setState(() {
          // Only keep active notes that are still being pressed
          _activeNotes = _activeNotes.intersection(_pressedKeys);
        });
      }
    });
  }
  
  void _releaseNote(String note, {LogicalKeyboardKey? releasedKey}) {
    // If this was triggered by a keyboard key release, only remove the specific notes
    // that were triggered by that key
    if (releasedKey != null) {
      final notesToRemove = _keyboardToAllNotesMap[releasedKey];
      if (notesToRemove != null) {
        // Only remove notes if they're not being held by other keyboard keys
        for (final noteToRemove in notesToRemove) {
          bool noteStillHeld = false;
          
          // Check if any other keyboard key is still triggering this note
          for (final entry in _keyboardToAllNotesMap.entries) {
            if (entry.key != releasedKey && entry.value.contains(noteToRemove)) {
              noteStillHeld = true;
              break;
            }
          }
          
          // Only remove from pressed keys if not held by another keyboard key
          if (!noteStillHeld) {
            _pressedKeys.remove(noteToRemove);
          }
        }
        
        // Clean up the mapping for this key
        _keyboardToAllNotesMap.remove(releasedKey);
      }
    } else {
      // Mouse/touch release - remove the note and its intervals from pressed keys
      _pressedKeys.remove(note);
      
      // Also remove any interval notes that might have been triggered with this root note
      for (int semitones = 1; semitones < 12; semitones++) {
        if (_intervals[semitones]) {
          final intervalNote = _getIntervalNote(note, semitones);
          if (intervalNote != null) _pressedKeys.remove(intervalNote);
        }
      }
    }
    
    // Schedule clearing if no keys are pressed
    _scheduleNoteClear();
  }

  void _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Check if shift is pressed for octave shifting
      final isShiftPressed = event.logicalKey == LogicalKeyboardKey.shiftLeft || 
                            event.logicalKey == LogicalKeyboardKey.shiftRight ||
                            HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                            HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
      
      // Helper function to get the right octave note
      String getNote(String baseNote) {
        if (isShiftPressed) {
          // Shift C3 octave to C4 octave, C4 to C5
          return baseNote.replaceAll('4', '5').replaceAll('3', '4');
        }
        return baseNote;
      }
      
      // Track the pressed keyboard key
      _pressedKeyboardKeys.add(event.logicalKey);
      
      String? noteToPlay;
      
      switch (event.logicalKey) {
        // White keys - C3 octave (C4 if shift pressed)
        case LogicalKeyboardKey.keyA:
          noteToPlay = getNote('C3');
          break;
        case LogicalKeyboardKey.keyS:
          noteToPlay = getNote('D3');
          break;
        case LogicalKeyboardKey.keyD:
          noteToPlay = getNote('E3');
          break;
        case LogicalKeyboardKey.keyF:
          noteToPlay = getNote('F3');
          break;
        case LogicalKeyboardKey.keyG:
          noteToPlay = getNote('G3');
          break;
        case LogicalKeyboardKey.keyH:
          noteToPlay = getNote('A3');
          break;
        case LogicalKeyboardKey.keyJ:
          noteToPlay = getNote('B3');
          break;
        
        // Black keys - C3 octave (C4 if shift pressed)
        case LogicalKeyboardKey.keyW:
          noteToPlay = getNote('C#3');
          break;
        case LogicalKeyboardKey.keyE:
          noteToPlay = getNote('D#3');
          break;
        case LogicalKeyboardKey.keyT:
          noteToPlay = getNote('F#3');
          break;
        case LogicalKeyboardKey.keyY:
          noteToPlay = getNote('G#3');
          break;
        case LogicalKeyboardKey.keyU:
          noteToPlay = getNote('A#3');
          break;
        
        // White keys - C4 octave continuation (C5 if shift pressed)
        case LogicalKeyboardKey.keyK:
          noteToPlay = getNote('C4');
          break;
        case LogicalKeyboardKey.keyL:
          noteToPlay = getNote('D4');
          break;
        case LogicalKeyboardKey.semicolon:
          noteToPlay = getNote('E4');
          break;
        case LogicalKeyboardKey.quoteSingle:
          noteToPlay = getNote('F4');
          break;
        
        // Black keys - C4 octave continuation (C5 if shift pressed)
        case LogicalKeyboardKey.keyO:
          noteToPlay = getNote('C#4');
          break;
        case LogicalKeyboardKey.keyP:
          noteToPlay = getNote('D#4');
          break;
      }
      
      if (noteToPlay != null) {
        // Map this keyboard key to the note it triggered
        _keyboardToNoteMap[event.logicalKey] = noteToPlay;
        _playNoteWithIntervals(noteToPlay, triggeredByKey: event.logicalKey);
      }
    } else if (event is KeyUpEvent) {
      // Remove the released key from pressed keys
      _pressedKeyboardKeys.remove(event.logicalKey);
      
      // If this key was mapped to a note, release that note
      final releasedNote = _keyboardToNoteMap[event.logicalKey];
      if (releasedNote != null) {
        _keyboardToNoteMap.remove(event.logicalKey);
        _releaseNote(releasedNote, releasedKey: event.logicalKey);
      }
      
      // Schedule clearing if no keys are pressed
      _scheduleNoteClear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyPress,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF2B2B2B), // Logic Pro dark gray background

      body: SingleChildScrollView(
        child: Column(
          children: [
            // Piano keyboard - full width dark container at top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                left: 0,
                right: 0,
                top: 0,
                bottom: 6,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF404040),
                    Color(0xFF2A2A2A),
                    Color(0xFF151515),
                    Color(0xFF000000),
                    Color(0xFF0A0A0A),
                    Color(0xFF1A1A1A),
                  ],
                  stops: [0.0, 0.2, 0.5, 0.7, 0.9, 1.0],
                ),
              ),
              child: PianoKeyboard(
                onKeyPressed: _playNoteWithIntervals,
                onKeyReleased: _releaseNote,
                activeNotes: _activeNotes,
                scaleNotes: _currentScaleNotes.toSet(),
              ),
            ),
            // Controls section with padding
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  // Interval controls with subtle Logic Pro style design
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * .95,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF393939), // Logic Pro panel gray
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF4A4A4A),
                        width: 0.5,
                      ),
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Single row layout with Piano Volume on left, Key & Mode in middle, Intervals on right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left side: Piano Dynamic Level (horizontal slider)
                        SizedBox(
                          height: 80,
                          width: 80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.volume_up,
                                size: 14,
                                color: const Color(0xFFF9931A),
                              ),
                              const SizedBox(height: 10), // Match spacing with other sections
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  showValueIndicator: ShowValueIndicator.never,
                                  activeTrackColor: const Color(0xFFF9931A),
                                  inactiveTrackColor: const Color(0xFF5A5A5A),
                                  thumbColor: const Color(0xFFF9931A),
                                  overlayColor: const Color(0xFFF9931A).withValues(alpha: 0.2),
                                ),
                                child: SizedBox(
                                  width: 70,
                                  child: Slider(
                                    min: 0,
                                    max: 4,
                                    divisions: 4,
                                    value: _pianoDynamicLevel.toDouble(),
                                    onChanged: (value) {
                                      setState(() {
                                        _pianoDynamicLevel = value.round();
                                      });
                                      _sound.setDynamicLevel(_pianoDynamicLevel);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _dynamicNames[_pianoDynamicLevel],
                                style: const TextStyle(
                                  color: Color(0xFFE5E5E5),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Middle: Key and Mode selection
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Key & Mode',
                                style: TextStyle(
                                  color: const Color(0xFFF9931A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  // Key dropdown
                                  Expanded(
                                    child: Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2F2F2F),
                                        border: Border.all(color: const Color(0xFF5A5A5A), width: 0.5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedKey,
                                          isExpanded: true,
                                          isDense: true,
                                          style: const TextStyle(
                                            color: Color(0xFFE5E5E5),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          dropdownColor: const Color(0xFF2F2F2F),
                                          items: _keys.map((String key) {
                                            return DropdownMenuItem<String>(
                                              value: key,
                                              child: Container(
                                                height: 20,
                                                alignment: Alignment.centerLeft,
                                                child: Text(key),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              setState(() {
                                                _selectedKey = newValue;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Mode dropdown
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2F2F2F),
                                        border: Border.all(color: const Color(0xFF5A5A5A), width: 0.5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedMode,
                                          isExpanded: true,
                                          isDense: true,
                                          style: const TextStyle(
                                            color: Color(0xFFE5E5E5),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          dropdownColor: const Color(0xFF2F2F2F),
                                          items: _modes.map((String mode) {
                                            return DropdownMenuItem<String>(
                                              value: mode,
                                              child: Container(
                                                height: 20,
                                                alignment: Alignment.centerLeft,
                                                child: Text(mode),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              setState(() {
                                                _selectedMode = newValue;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right side: Intervals
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Intervals',
                                style: TextStyle(
                                  color: const Color(0xFFF9931A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  for (int semitones = 1; semitones <= 11; semitones++)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Tooltip(
                                        message: _intervalNames[semitones],
                                        child: _buildCompactIntervalCheckbox(
                                          semitones.toString(),
                                          _intervals[semitones],
                                          (value) => setState(() => _intervals[semitones] = value ?? false),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Audio Player Toggle - Clean caret + text + line design
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * .95,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showAudioPlayer = !_showAudioPlayer;
                    });
                    
                    // Resize window based on audio player visibility
                    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                      if (_showAudioPlayer) {
                        // Expand window height to accommodate audio player
                        setWindowFrame(const Rect.fromLTWH(100, 100, 1200, 920));
                      } else {
                        // Collapse window back to original size
                        setWindowFrame(const Rect.fromLTWH(100, 100, 1200, 420));
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _showAudioPlayer ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                          color: const Color(0xFFE5E5E5),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showAudioPlayer ? 'Hide Audio Player' : 'Show Audio Player',
                          style: const TextStyle(
                            color: Color(0xFFE5E5E5),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 1,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF4A4A4A),
                                  Color(0xFF2A2A2A),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Audio Player Section
              if (_showAudioPlayer) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 500, // Add finite height constraint
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * .95,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF393939),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF4A4A4A),
                      width: 0.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: const AudioPlayerPage(),
                  ),
                ),
              ],
                ],
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildCompactIntervalCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: value ? const Color(0xFF0084EF).withValues(alpha: 0.15) : const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: value ? const Color(0xFF0084EF) : const Color(0xFF5A5A5A),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => onChanged(!value),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: value ? const Color(0xFFE5E5E5) : const Color(0xFFB8B8B8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sound.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
