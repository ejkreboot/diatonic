import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/autorefocus.dart';
import '../models/piano_sound.dart';
import '../models/scales.dart';

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

  // Keyboard -> note mapping (base octave mapping, shift modifies octave)
  static final Map<LogicalKeyboardKey, String> _keyToBaseNote = {
    // White keys - C3 octave
    LogicalKeyboardKey.keyA: 'C3',
    LogicalKeyboardKey.keyS: 'D3',
    LogicalKeyboardKey.keyD: 'E3',
    LogicalKeyboardKey.keyF: 'F3',
    LogicalKeyboardKey.keyG: 'G3',
    LogicalKeyboardKey.keyH: 'A3',
    LogicalKeyboardKey.keyJ: 'B3',
    // Black keys - C3 octave
    LogicalKeyboardKey.keyW: 'C#3',
    LogicalKeyboardKey.keyE: 'D#3',
    LogicalKeyboardKey.keyT: 'F#3',
    LogicalKeyboardKey.keyY: 'G#3',
    LogicalKeyboardKey.keyU: 'A#3',
    // White keys - C4 octave continuation
    LogicalKeyboardKey.keyK: 'C4',
    LogicalKeyboardKey.keyL: 'D4',
    LogicalKeyboardKey.semicolon: 'E4',
    LogicalKeyboardKey.quoteSingle: 'F4',
    // Black keys - C4 octave continuation
    LogicalKeyboardKey.keyO: 'C#4',
    LogicalKeyboardKey.keyP: 'D#4',
  };

  // Keyboard -> interval index mapping for toggles
  static final Map<LogicalKeyboardKey, int> _keyToIntervalIndex = {
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.digit0: 10,
    LogicalKeyboardKey.minus: 11,
  };

  void _toggleInterval(int semitoneIndex) {
    if (semitoneIndex >= 1 && semitoneIndex <= 11) {
      setState(() {
        _intervals[semitoneIndex] = !_intervals[semitoneIndex];
      });
    }
  }

  // Active notes for animation
  Set<String> _activeNotes = {};
  
  // Track currently pressed keys to avoid clearing while held
  final Set<String> _pressedKeys = {};
  final Set<LogicalKeyboardKey> _pressedKeyboardKeys = {};
  
  // Map keyboard keys to their triggered notes for proper release tracking
  final Map<LogicalKeyboardKey, String> _keyboardToNoteMap = {};
  
  // Map keyboard keys to ALL notes they triggered (including intervals)
  final Map<LogicalKeyboardKey, Set<String>> _keyboardToAllNotesMap = {};
  
  // Map root notes (from mouse/touch UI) to ALL notes they triggered
  // This lets us release interval notes when the UI root key is released
  final Map<String, Set<String>> _rootToAllNotesMap = {};
  

  // Dynamic level names are sourced from PianoSound.currentDynamic for display

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
          // Only add interval note if no key/mode is selected, or if the note is in the scale
          if (_selectedKey == 'None' || Scales.isNoteInScale(intervalNote, _selectedKey, _selectedMode)) {
            notesToPlay.add(intervalNote);
            _pressedKeys.add(intervalNote);
          }
        }
      }
    }
    
    // If this was triggered by a keyboard key, track all notes it triggered
    if (triggeredByKey != null) {
      _keyboardToAllNotesMap[triggeredByKey] = notesToPlay.toSet();
    } else {
      // Track notes triggered by UI (mouse/touch) root key
      _rootToAllNotesMap[note] = notesToPlay.toSet();
    }
    
    // Animate the keys - add to existing active notes instead of replacing
    setState(() {
      _activeNotes = _activeNotes.union(notesToPlay.toSet());
    });
    
    // Play chord with calculated intervals - only play notes that are in notesToPlay
    _sound.playChord(
      rootNote: note,
      sus2Note: notesToPlay.contains(_getIntervalNote(note, 2)) ? _getIntervalNote(note, 2) : null,
      minorThirdNote: notesToPlay.contains(_getIntervalNote(note, 3)) ? _getIntervalNote(note, 3) : null,
      majorThirdNote: notesToPlay.contains(_getIntervalNote(note, 4)) ? _getIntervalNote(note, 4) : null,
      sus4Note: notesToPlay.contains(_getIntervalNote(note, 5)) ? _getIntervalNote(note, 5) : null,
      perfectFifthNote: notesToPlay.contains(_getIntervalNote(note, 7)) ? _getIntervalNote(note, 7) : null,
      augmentedFifthNote: notesToPlay.contains(_getIntervalNote(note, 8)) ? _getIntervalNote(note, 8) : null,
      minorSeventhNote: notesToPlay.contains(_getIntervalNote(note, 10)) ? _getIntervalNote(note, 10) : null,
      majorSeventhNote: notesToPlay.contains(_getIntervalNote(note, 11)) ? _getIntervalNote(note, 11) : null,
      ninthNote: notesToPlay.contains(_getIntervalNote(note, 14)) ? _getIntervalNote(note, 14) : null,
    );
    
    // Schedule clearing, but only if no keys are still pressed
    _scheduleNoteClear();
  }
  
  void _scheduleNoteClear() {
    // Update active notes immediately based on currently pressed keys
    setState(() {
      _activeNotes = _activeNotes.intersection(_pressedKeys);
    });
  }
  
  void _releaseNote(String note, {LogicalKeyboardKey? releasedKey}) {
    // If this was triggered by a keyboard key release, only remove the specific notes
    // that were triggered by that key
    if (releasedKey != null) {
      final notesToRemove = _keyboardToAllNotesMap[releasedKey];
      if (notesToRemove != null) {
        // Clear the mapping for this released key first
        _keyboardToAllNotesMap.remove(releasedKey);
        
        // Now check each note that was triggered by the released key
        for (final noteToRemove in notesToRemove) {
          bool noteStillHeld = false;
          
          // Check if any other keyboard key is still triggering this note
          for (final entry in _keyboardToAllNotesMap.entries) {
            if (entry.value.contains(noteToRemove)) {
              noteStillHeld = true;
              break;
            }
          }
          // Also check if any other UI root note is still holding this note
          if (!noteStillHeld) {
            for (final entry in _rootToAllNotesMap.entries) {
              // No need to exclude a specific root here because this path is keyboard release
              if (entry.value.contains(noteToRemove)) {
                noteStillHeld = true;
                break;
              }
            }
          }
          
          // Only remove from pressed keys if not held by another trigger
          if (!noteStillHeld) {
            _pressedKeys.remove(noteToRemove);
          }
        }
      }
    } else {
      // UI (mouse/touch) release of a root note: remove all notes that were played for that root
      final notesToRemove = _rootToAllNotesMap[note] ?? {note};
      // Clear the mapping for this released root
      _rootToAllNotesMap.remove(note);
      
      for (final noteToRemove in notesToRemove) {
        bool noteStillHeld = false;
        
        // Check if any keyboard key is still holding this note
        for (final entry in _keyboardToAllNotesMap.entries) {
          if (entry.value.contains(noteToRemove)) {
            noteStillHeld = true;
            break;
          }
        }
        // Check if any other UI root note is still holding this note
        if (!noteStillHeld) {
          for (final entry in _rootToAllNotesMap.entries) {
            if (entry.value.contains(noteToRemove)) {
              noteStillHeld = true;
              break;
            }
          }
        }
        
        if (!noteStillHeld) {
          _pressedKeys.remove(noteToRemove);
        }
      }
    }
    
    // Update active notes immediately
    setState(() {
      _activeNotes = _activeNotes.intersection(_pressedKeys);
    });
  }

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final editingState = focusedContext?.findAncestorStateOfType<EditableTextState>();
    if (editingState != null) {
      return KeyEventResult.ignored; // Let text input receive the event fully
    }

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

      // First, handle interval toggles
      final toggleIndex = _keyToIntervalIndex[event.logicalKey];
      if (toggleIndex != null) {
        _toggleInterval(toggleIndex);
        return KeyEventResult.handled;
      }

      // Then, map to note plays
      final baseNote = _keyToBaseNote[event.logicalKey];
      if (baseNote != null) {
        final noteToPlay = getNote(baseNote);
        // Map this keyboard key to the note it triggered
        _keyboardToNoteMap[event.logicalKey] = noteToPlay;
        _playNoteWithIntervals(noteToPlay, triggeredByKey: event.logicalKey);
        return KeyEventResult.handled; // mischief managed 

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
      return KeyEventResult.handled; // mischief managed 
    } else if (event is KeyRepeatEvent) {
      return KeyEventResult.handled; // Consume the repeat to prevent system beep
    }
    return KeyEventResult.ignored; 
  }

  @override
  Widget build(BuildContext context) {
    return AutoRefocus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyPress,
      skipTraversal: true,   // doesn't interfere with Tab focus
  allowTextFieldFocus: true,
      child: SingleChildScrollView(
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
                    decoration: const BoxDecoration(
                      color: Color(0xFF393939), // Logic Pro panel gray
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Key/Mode dropdowns
                        Expanded(
                          flex: 2,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Key label + dropdown
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Key',
                                      style: TextStyle(
                                        color: Color(0xFFF9931A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
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
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Mode label + dropdown
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Mode',
                                      style: TextStyle(
                                        color: Color(0xFFF9931A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
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
                                  ],
                                ),
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
                              const Text(
                                'Intervals',
                                style: TextStyle(
                                  color: Color(0xFFF9931A),
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
                  ),
                ],
              ),
            ),
          ],
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
