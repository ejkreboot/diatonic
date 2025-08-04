class Scales {
  // Chromatic scale starting from C
  static const List<String> _chromaticScale = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  
  // Mode patterns (intervals in semitones from the root)
  static const Map<String, List<int>> _modePatterns = {
    'Ionian (Major)': [0, 2, 4, 5, 7, 9, 11],           // W-W-H-W-W-W-H
    'Dorian': [0, 2, 3, 5, 7, 9, 10],                   // W-H-W-W-W-H-W
    'Phrygian': [0, 1, 3, 5, 7, 8, 10],                 // H-W-W-W-H-W-W
    'Lydian': [0, 2, 4, 6, 7, 9, 11],                   // W-W-W-H-W-W-H
    'Mixolydian': [0, 2, 4, 5, 7, 9, 10],               // W-W-H-W-W-H-W
    'Aeolian (Natural Minor)': [0, 2, 3, 5, 7, 8, 10],  // W-H-W-W-H-W-W
    'Locrian': [0, 1, 3, 5, 6, 8, 10],                  // H-W-W-H-W-W-W
  };
  
  /// Gets the notes in a scale for a given key and mode
  /// Returns a list of note names (without octave numbers)
  static List<String> getScaleNotes(String key, String mode) {
    // Return empty list if no key is selected
    if (key == 'None') {
      return [];
    }
    
    final pattern = _modePatterns[mode];
    if (pattern == null) {
      throw ArgumentError('Unknown mode: $mode');
    }
    
    final rootIndex = _chromaticScale.indexOf(key);
    if (rootIndex == -1) {
      throw ArgumentError('Unknown key: $key');
    }
    
    final scaleNotes = <String>[];
    for (final interval in pattern) {
      final noteIndex = (rootIndex + interval) % 12;
      scaleNotes.add(_chromaticScale[noteIndex]);
    }
    
    return scaleNotes;
  }
  
  /// Checks if a given note is in the specified scale
  static bool isNoteInScale(String note, String key, String mode) {
    // Remove octave number if present (e.g., 'C4' -> 'C')
    final noteWithoutOctave = note.replaceAll(RegExp(r'\d+'), '');
    final scaleNotes = getScaleNotes(key, mode);
    return scaleNotes.contains(noteWithoutOctave);
  }
  
  /// Gets the degree of a note in the scale (1-7, or -1 if not in scale)
  static int getScaleDegree(String note, String key, String mode) {
    final noteWithoutOctave = note.replaceAll(RegExp(r'\d+'), '');
    final scaleNotes = getScaleNotes(key, mode);
    final index = scaleNotes.indexOf(noteWithoutOctave);
    return index == -1 ? -1 : index + 1;
  }
  
  /// Gets all available keys (natural notes only)
  static List<String> getAvailableKeys() {
    return ['None', 'C', 'D', 'E', 'F', 'G', 'A', 'B'];
  }
  
  /// Gets all available modes
  static List<String> getAvailableModes() {
    return _modePatterns.keys.toList();
  }
  
  /// Gets the note name at a specific scale degree (1-7)
  static String? getNoteAtDegree(int degree, String key, String mode) {
    if (degree < 1 || degree > 7) return null;
    final scaleNotes = getScaleNotes(key, mode);
    return scaleNotes[degree - 1];
  }
  
  /// Gets chord tones for common chord types in the given key/mode
  static Map<String, List<String>> getCommonChords(String key, String mode) {
    final scaleNotes = getScaleNotes(key, mode);
    final chords = <String, List<String>>{};
    
    // Build triads for each scale degree
    for (int i = 0; i < 7; i++) {
      final root = scaleNotes[i];
      final third = scaleNotes[(i + 2) % 7];
      final fifth = scaleNotes[(i + 4) % 7];
      
      // Determine chord quality based on intervals
      final rootIndex = _chromaticScale.indexOf(root);
      final thirdIndex = _chromaticScale.indexOf(third);
      final fifthIndex = _chromaticScale.indexOf(fifth);
      
      final thirdInterval = (thirdIndex - rootIndex + 12) % 12;
      final fifthInterval = (fifthIndex - rootIndex + 12) % 12;
      
      String chordType;
      if (thirdInterval == 4 && fifthInterval == 7) {
        chordType = 'Major';
      } else if (thirdInterval == 3 && fifthInterval == 7) {
        chordType = 'Minor';
      } else if (thirdInterval == 3 && fifthInterval == 6) {
        chordType = 'Diminished';
      } else {
        chordType = 'Other';
      }
      
      chords['$root $chordType'] = [root, third, fifth];
    }
    
    return chords;
  }
}
