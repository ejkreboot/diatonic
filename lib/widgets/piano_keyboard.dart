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
        // Account for padding and cheek blocks in width calculations
        const containerPadding = 0.0; // Eliminated horizontal padding completely
        const cheekBlockWidth = 48.0; // Increased from 32.0 to 48.0 for wider cheek blocks
        final actualAvailableWidth = constraints.maxWidth;
        final keyAreaWidth = actualAvailableWidth - (containerPadding * 2) - (cheekBlockWidth * 2);
        
        final whiteKeyCount = PianoKeyboard.allKeys.where((key) => !key.contains('#')).length;
        final whiteKeyWidth = keyAreaWidth / whiteKeyCount;
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
            // White key with realistic gradient and shadows
            whiteKeys.add(AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: keyHeight,
              decoration: BoxDecoration(
                gradient: isActive 
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFE8E8E8),
                        const Color(0xFFD5D5D5),
                        const Color(0xFFCCCCCC),
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFFAFAFA),
                        const Color(0xFFF0F0F0),
                        const Color(0xFFE8E8E8),
                      ],
                      stops: const [0.0, 0.8, 1.0],
                    ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(keyRadius),
                  bottomRight: Radius.circular(keyRadius),
                ),
                boxShadow: [
                  // Main shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: isActive ? 8 : 4,
                    offset: isActive ? const Offset(0, 4) : const Offset(0, 2),
                  ),
                  // Subtle ambient shadow
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade400, width: 0.5),
                    right: BorderSide(color: Colors.grey.shade400, width: 0.5),
                    bottom: BorderSide(color: Colors.grey.shade500, width: 1.0),
                  ),
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
                        // Subtle highlight at top
                        Positioned(
                          top: 0,
                          left: 2,
                          right: 2,
                          height: keyHeight * 0.15,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.6),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                  gradient: isActive
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF2A2A2A),
                          const Color(0xFF1A1A1A),
                          const Color(0xFF0A0A0A),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      )
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF4A4A4A),
                          const Color(0xFF2A2A2A),
                          const Color(0xFF1A1A1A),
                          const Color(0xFF000000),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(keyRadius),
                    bottomRight: Radius.circular(keyRadius),
                  ),
                  boxShadow: [
                    // Main deep shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: isActive ? 12 : 8,
                      offset: isActive ? const Offset(0, 6) : const Offset(0, 4),
                    ),
                    // Subtle highlight shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
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
                        // Glossy highlight at top
                        Positioned(
                          top: 1,
                          left: 2,
                          right: 2,
                          height: blackKeyHeight * 0.2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(keyRadius),
                                topRight: Radius.circular(keyRadius),
                              ),
                            ),
                          ),
                        ),
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
            // Rich dark gradient background like the Kawai
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2C2C2C),
                Color(0xFF1A1A1A),
                Color(0xFF0D0D0D),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
            borderRadius: BorderRadius.circular(containerRadius),
            boxShadow: [
              // Deep outer shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              // Subtle inner highlight
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0), // Only bottom padding, eliminated top padding
            child: Row(
              children: [
                // Left cheek block
                Container(
                  width: 48, // Increased width to match cheekBlockWidth
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF7A7A7A), // Much brighter highlight on outer edge
                        Color(0xFF5A5A5A), // Bright mid-highlight
                        Color(0xFF3A3A3A), // Mid tone
                        Color(0xFF1A1A1A), // Much darker at inner edge
                      ],
                      stops: [0.0, 0.25, 0.6, 1.0],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                    boxShadow: [
                      // Main dimensional shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 8,
                        offset: const Offset(3, 3),
                      ),
                      // Additional depth shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                // Main keyboard area
                Expanded(
                  child: AspectRatio(
                    aspectRatio: whiteKeyCount / 4.6, // Width to height ratio based on key proportions
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF3A3A3A),
                            Color(0xFF2A2A2A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: LayoutBuilder(
                        builder: (context, keyboardConstraints) {
                          // Recalculate dimensions based on actual available space
                          final actualKeyAreaWidth = keyboardConstraints.maxWidth;
                          final actualKeyHeight = keyboardConstraints.maxHeight;
                          final actualWhiteKeyWidth = actualKeyAreaWidth / whiteKeyCount;
                          final actualBlackKeyWidth = actualWhiteKeyWidth * 0.55;
                          final actualBlackKeyHeight = actualKeyHeight * 0.65;
                          
                          // Rebuild black keys with correct positioning
                          final adjustedBlackKeys = <Widget>[];
                          int adjustedWhiteKeyIndex = 0;
                          
                          for (int i = 0; i < PianoKeyboard.allKeys.length; i++) {
                            final note = PianoKeyboard.allKeys[i];
                            final isBlackKey = note.contains('#');
                            final isActive = widget.activeNotes.contains(note);
                            final noteWithoutOctave = note.replaceAll(RegExp(r'\d+'), '');
                            final isInScale = widget.scaleNotes.contains(noteWithoutOctave);
                            
                            if (!isBlackKey) {
                              adjustedWhiteKeyIndex++;
                            } else {
                              final blackKeyLeft = (adjustedWhiteKeyIndex * actualWhiteKeyWidth) - (actualBlackKeyWidth / 2);
                              
                              adjustedBlackKeys.add(Positioned(
                                left: blackKeyLeft,
                                width: actualBlackKeyWidth,
                                height: actualBlackKeyHeight,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  decoration: BoxDecoration(
                                    gradient: isActive
                                      ? LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            const Color(0xFF2A2A2A),
                                            const Color(0xFF1A1A1A),
                                            const Color(0xFF0A0A0A),
                                          ],
                                          stops: const [0.0, 0.6, 1.0],
                                        )
                                      : LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            const Color(0xFF4A4A4A),
                                            const Color(0xFF2A2A2A),
                                            const Color(0xFF1A1A1A),
                                            const Color(0xFF000000),
                                          ],
                                          stops: const [0.0, 0.3, 0.7, 1.0],
                                        ),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(keyRadius),
                                      bottomRight: Radius.circular(keyRadius),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        blurRadius: isActive ? 12 : 8,
                                        offset: isActive ? const Offset(0, 6) : const Offset(0, 4),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
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
                                          // Glossy highlight at top
                                          Positioned(
                                            top: 1,
                                            left: 2,
                                            right: 2,
                                            height: actualBlackKeyHeight * 0.2,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.white.withValues(alpha: 0.15),
                                                    Colors.white.withValues(alpha: 0.0),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(keyRadius),
                                                  topRight: Radius.circular(keyRadius),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Scale note indicator for black keys
                                          if (isInScale)
                                            Positioned(
                                              bottom: 2, // Moved up 2 pixels from the bottom
                                              left: actualBlackKeyWidth * 0.15, // Add horizontal margin for narrower highlight
                                              right: actualBlackKeyWidth * 0.15,
                                              child: Container(
                                                height: 1.5, // Restored to 1.5px height
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0084EF),
                                                  borderRadius: BorderRadius.circular(keyRadius * 0.3),
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
                          
                          return Stack(
                            children: [
                              // White keys row
                              Row(
                                children: whiteKeys.map((key) => Expanded(child: key)).toList(),
                              ),
                              // Black keys overlay with correct positioning
                              ...adjustedBlackKeys,
                              // Enhanced drop shadow for deeper recess illusion - moved to top layer
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 20, // Increased height for more dramatic effect
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.7), // Darker at top
                                        Colors.black.withValues(alpha: 0.4), // Strong mid shadow
                                        Colors.black.withValues(alpha: 0.2), // Medium fade
                                        Colors.black.withValues(alpha: 0.05), // Subtle transition
                                        Colors.black.withValues(alpha: 0.0), // Transparent
                                      ],
                                      stops: const [0.0, 0.3, 0.5, 0.8, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Left side shadow for depth
                              Positioned(
                                top: 0,
                                left: 0,
                                width: 16, // Increased width for more dramatic effect
                                bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.3), // Stronger shadow
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.black.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.6, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Right side shadow for depth
                              Positioned(
                                top: 0,
                                right: 0,
                                width: 16, // Increased width for more dramatic effect
                                bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerRight,
                                      end: Alignment.centerLeft,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.3), // Stronger shadow
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.black.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.6, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // Right cheek block
                Container(
                  width: 48, // Increased width to match cheekBlockWidth
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Color(0xFF7A7A7A), // Much brighter highlight on outer edge
                        Color(0xFF5A5A5A), // Bright mid-highlight
                        Color(0xFF3A3A3A), // Mid tone
                        Color(0xFF1A1A1A), // Much darker at inner edge
                      ],
                      stops: [0.0, 0.25, 0.6, 1.0],
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                    boxShadow: [
                      // Main dimensional shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 8,
                        offset: const Offset(-3, 3),
                      ),
                      // Additional depth shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(-1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}