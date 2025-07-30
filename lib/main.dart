import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_size/window_size.dart';
import 'widgets/piano_keyboard.dart';
import 'models/piano_sound.dart';
import 'models/scales.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Chorder');
    setWindowMinSize(const Size(800, 340));
    setWindowMaxSize(const Size(10000, 340));
    setWindowFrame(const Rect.fromLTWH(100, 100, 1200, 340)); 
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
          maxHeight: 430,
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
  
  // Interval settings
  bool _minorThird = false;
  bool _majorThird = false;
  bool _perfectFifth = false;
  bool _minorSeventh = false;
  bool _majorSeventh = false;
  bool _ninth = false;

  // Active notes for animation
  Set<String> _activeNotes = {};

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

  void _playNoteWithIntervals(String note) {
    // Calculate interval notes
    final notesToPlay = <String>[note]; // Start with the base note
    
    // Add intervals if enabled
    if (_minorThird) {
      final intervalNote = _getIntervalNote(note, 3);
      if (intervalNote != null) notesToPlay.add(intervalNote);
    }
    if (_majorThird) {
      final intervalNote = _getIntervalNote(note, 4);
      if (intervalNote != null) notesToPlay.add(intervalNote);
    }
    if (_perfectFifth) {
      final intervalNote = _getIntervalNote(note, 7);
      if (intervalNote != null) notesToPlay.add(intervalNote);
    }
    if (_minorSeventh) {
      final intervalNote = _getIntervalNote(note, 10);
      if (intervalNote != null) notesToPlay.add(intervalNote);
    }
    if (_majorSeventh) {
      final intervalNote = _getIntervalNote(note, 11);
      if (intervalNote != null) notesToPlay.add(intervalNote);
    }
    if (_ninth) {
      final intervalNote = _getIntervalNote(note, 14);
      if (intervalNote != null) notesToPlay.add(intervalNote);
    }
    
    // Animate the keys
    setState(() {
      _activeNotes = notesToPlay.toSet();
    });
    
    // Play chord with calculated intervals
    _sound.playChord(
      rootNote: note,
      minorThirdNote: notesToPlay.length > 1 && _minorThird ? _getIntervalNote(note, 3) : null,
      majorThirdNote: notesToPlay.length > 1 && _majorThird ? _getIntervalNote(note, 4) : null,
      perfectFifthNote: notesToPlay.length > 1 && _perfectFifth ? _getIntervalNote(note, 7) : null,
      minorSeventhNote: notesToPlay.length > 1 && _minorSeventh ? _getIntervalNote(note, 10) : null,
      majorSeventhNote: notesToPlay.length > 1 && _majorSeventh ? _getIntervalNote(note, 11) : null,
      ninthNote: notesToPlay.length > 1 && _ninth ? _getIntervalNote(note, 14) : null,
    );
    
    // Clear the animation after a delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _activeNotes = {};
        });
      }
    });
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
      
      switch (event.logicalKey) {
        // White keys - C3 octave (C4 if shift pressed)
        case LogicalKeyboardKey.keyA:
          _playNoteWithIntervals(getNote('C3'));
          break;
        case LogicalKeyboardKey.keyS:
          _playNoteWithIntervals(getNote('D3'));
          break;
        case LogicalKeyboardKey.keyD:
          _playNoteWithIntervals(getNote('E3'));
          break;
        case LogicalKeyboardKey.keyF:
          _playNoteWithIntervals(getNote('F3'));
          break;
        case LogicalKeyboardKey.keyG:
          _playNoteWithIntervals(getNote('G3'));
          break;
        case LogicalKeyboardKey.keyH:
          _playNoteWithIntervals(getNote('A3'));
          break;
        case LogicalKeyboardKey.keyJ:
          _playNoteWithIntervals(getNote('B3'));
          break;
        
        // Black keys - C3 octave (C4 if shift pressed)
        case LogicalKeyboardKey.keyW:
          _playNoteWithIntervals(getNote('C#3'));
          break;
        case LogicalKeyboardKey.keyE:
          _playNoteWithIntervals(getNote('D#3'));
          break;
        case LogicalKeyboardKey.keyT:
          _playNoteWithIntervals(getNote('F#3'));
          break;
        case LogicalKeyboardKey.keyY:
          _playNoteWithIntervals(getNote('G#3'));
          break;
        case LogicalKeyboardKey.keyU:
          _playNoteWithIntervals(getNote('A#3'));
          break;
        
        // White keys - C4 octave continuation (C5 if shift pressed)
        case LogicalKeyboardKey.keyK:
          _playNoteWithIntervals(getNote('C4'));
          break;
        case LogicalKeyboardKey.keyL:
          _playNoteWithIntervals(getNote('D4'));
          break;
        case LogicalKeyboardKey.semicolon:
          _playNoteWithIntervals(getNote('E4'));
          break;
        case LogicalKeyboardKey.quoteSingle:
          _playNoteWithIntervals(getNote('F4'));
          break;
        
        // Black keys - C4 octave continuation (C5 if shift pressed)
        case LogicalKeyboardKey.keyO:
          _playNoteWithIntervals(getNote('C#4'));
          break;
        case LogicalKeyboardKey.keyP:
          _playNoteWithIntervals(getNote('D#4'));
          break;
      }
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
                    // Single row layout with Key & Mode on left, Intervals on right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left side: Key and Mode selection
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildModernIntervalCheckbox(
                                    'Minor 3rd',
                                    _minorThird,
                                    (value) => setState(() => _minorThird = value ?? false),
                                  ),
                                  _buildModernIntervalCheckbox(
                                    'Major 3rd',
                                    _majorThird,
                                    (value) => setState(() => _majorThird = value ?? false),
                                  ),
                                  _buildModernIntervalCheckbox(
                                    'Perfect 5th',
                                    _perfectFifth,
                                    (value) => setState(() => _perfectFifth = value ?? false),
                                  ),
                                  _buildModernIntervalCheckbox(
                                    'Minor 7th',
                                    _minorSeventh,
                                    (value) => setState(() => _minorSeventh = value ?? false),
                                  ),
                                  _buildModernIntervalCheckbox(
                                    'Major 7th',
                                    _majorSeventh,
                                    (value) => setState(() => _majorSeventh = value ?? false),
                                  ),
                                  _buildModernIntervalCheckbox(
                                    'Ninth',
                                    _ninth,
                                    (value) => setState(() => _ninth = value ?? false),
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

  Widget _buildModernIntervalCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Container(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: value ? const Color(0xFF0084EF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: value ? const Color(0xFF0084EF) : const Color(0xFF7A7A7A),
                      width: 1,
                    ),
                  ),
                  child: value
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 10,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: value ? const Color(0xFFE5E5E5) : const Color(0xFFB8B8B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
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
