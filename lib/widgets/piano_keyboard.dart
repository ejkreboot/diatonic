import 'package:flutter/material.dart';

class PianoKeyboard extends StatefulWidget {
  final void Function(String note) onKeyPressed;
  final Set<String> activeNotes;
  final Set<String> scaleNotes;

  const PianoKeyboard({
    super.key, 
    required this.onKeyPressed,
    this.activeNotes = const {},
    this.scaleNotes = const {},
  });

  // 88-key piano from A0 to C8 - made public for interval calculations
  static const List<String> allKeys = [
    'A0', 'A#0', 'B0',
    'C1', 'C#1', 'D1', 'D#1', 'E1', 'F1', 'F#1', 'G1', 'G#1', 'A1', 'A#1', 'B1',
    'C2', 'C#2', 'D2', 'D#2', 'E2', 'F2', 'F#2', 'G2', 'G#2', 'A2', 'A#2', 'B2',
    'C3', 'C#3', 'D3', 'D#3', 'E3', 'F3', 'F#3', 'G3', 'G#3', 'A3', 'A#3', 'B3',
    'C4', 'C#4', 'D4', 'D#4', 'E4', 'F4', 'F#4', 'G4', 'G#4', 'A4', 'A#4', 'B4',
    'C5', 'C#5', 'D5', 'D#5', 'E5', 'F5', 'F#5', 'G5', 'G#5', 'A5', 'A#5', 'B5',
    'C6', 'C#6', 'D6', 'D#6', 'E6', 'F6', 'F#6', 'G6', 'G#6', 'A6', 'A#6', 'B6',
    'C7', 'C#7', 'D7', 'D#7', 'E7', 'F7', 'F#7', 'G7', 'G#7', 'A7', 'A#7', 'B7',
    'C8',
  ];

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the actual available width from the layout constraints
        final actualAvailableWidth = constraints.maxWidth;
        final whiteKeyCount = PianoKeyboard.allKeys.where((key) => !key.contains('#')).length;
        final whiteKeyWidth = actualAvailableWidth / whiteKeyCount;
        final keyHeight = whiteKeyWidth * 4.6; // Maintain aspect ratio
        
        // Black key dimensions - maintain proportional scaling at all sizes
        final blackKeyWidth = whiteKeyWidth * 0.55;
        final blackKeyHeight = keyHeight * 0.65;
        
        // Scalable border radius based on key width
        final keyRadius = (whiteKeyWidth * 0.15).clamp(1.0, 4.0);
        final containerRadius = (whiteKeyWidth * 0.1).clamp(3.0, 8.0);

        // Separate white and black keys
        final whiteKeys = <Widget>[];
        final blackKeys = <Widget>[];
        
        int whiteKeyIndex = 0;
        
        for (int i = 0; i < PianoKeyboard.allKeys.length; i++) {
          final note = PianoKeyboard.allKeys[i];
          final isBlackKey = note.contains('#');
          final isActive = widget.activeNotes.contains(note);
          final noteWithoutOctave = note.replaceAll(RegExp(r'\d+'), '');
          final isInScale = widget.scaleNotes.contains(noteWithoutOctave);
          
          if (!isBlackKey) {
            // White key with modern styling and animation
            whiteKeys.add(AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: keyHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
                color: isActive ? const Color.fromARGB(255, 236, 236, 236) : Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(keyRadius),
                  bottomRight: Radius.circular(keyRadius),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isActive ? 0.15 : 0.1),
                    blurRadius: isActive ? 4 : 2,
                    offset: isActive ? const Offset(0, 2) : const Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTapDown: (_) => widget.onKeyPressed(note),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(keyRadius),
                    bottomRight: Radius.circular(keyRadius),
                  ),
                  child: Stack(
                    children: [
                      Container(),
                      // Thin bottom border for scale notes (white keys)
                      if (isInScale)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0084EF),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(keyRadius),
                                bottomRight: Radius.circular(keyRadius),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ));
            whiteKeyIndex++;
          } else {
            // Black key with modern styling and animation
            // Calculate position based on the actual container width
            final blackKeyLeft = (whiteKeyIndex * whiteKeyWidth) - (blackKeyWidth / 2);
            
            blackKeys.add(Positioned(
              left: blackKeyLeft,
              width: blackKeyWidth,
              height: blackKeyHeight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey.shade700 : Colors.grey.shade900,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(keyRadius),
                    bottomRight: Radius.circular(keyRadius),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isActive ? 0.4 : 0.3),
                      blurRadius: isActive ? 6 : 4,
                      offset: isActive ? const Offset(0, 3) : const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTapDown: (_) => widget.onKeyPressed(note),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(keyRadius),
                      bottomRight: Radius.circular(keyRadius),
                    ),
                    child: Stack(
                      children: [
                        Container(),
                        // Thin bottom border for scale notes (black keys)
                        if (isInScale)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 1.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0084EF),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(keyRadius),
                                  bottomRight: Radius.circular(keyRadius),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ));
          }
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(containerRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(containerRadius),
            child: SizedBox(
              height: keyHeight,
              width: actualAvailableWidth,
              child: Stack(
                children: [
                  Row(
                    children: whiteKeys.map((key) => Expanded(child: key)).toList(),
                  ),
                  ...blackKeys,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}