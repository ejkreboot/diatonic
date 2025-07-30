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
        
        // Scalable border radius based on key width
        final keyRadius = (whiteKeyWidth * 0.15).clamp(1.0, 5.0);
        final containerRadius = (whiteKeyWidth * 0.1).clamp(3.0, 8.0);

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF4A4A4A), // Darker starting metallic gray at top-left
                Color(0xFF3A3A3A), // Medium metallic gray
                Color(0xFF2A2A2A), // Darker metallic gray
                Color(0xFF1A1A1A), // Deep charcoal
                Color(0xFF0A0A0A), // Very dark charcoal at center-right
              ],
              stops: [0.0, 0.25, 0.5, 0.75, 1.0],
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
            padding: const EdgeInsets.only(top: 48.0, bottom: 16.0), // Add 48px top padding, keep bottom padding
            child: AspectRatio(
              aspectRatio: whiteKeyCount / 4.6, // Restore proportional height based on key count
              child: Row(
                children: [
                // Left cheek block
                Container(
                  width: 48, // Increased width to match cheekBlockWidth
                  height: double.infinity, // Take full available height
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4A4A4A), // Light charcoal at top-left
                        Color(0xFF3A3A3A), // Medium charcoal
                        Color(0xFF2A2A2A), // Darker charcoal
                        Color(0xFF1A1A1A), // Dark charcoal at bottom-right
                      ],
                      stops: [0.0, 0.3, 0.7, 1.0],
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
                  child: ClipRRect(
                    child: Stack(
                      children: [
                        // Shadow overlay from case above
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 20, // Shadow depth from case above
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.4), // Stronger shadow at top
                                  Colors.black.withValues(alpha: 0.2),
                                  Colors.black.withValues(alpha: 0.0), // Fade to transparent
                                ],
                                stops: const [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Main keyboard area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(0),
                      ),
                      child: LayoutBuilder(
                        builder: (context, keyboardConstraints) {
                          // Recalculate dimensions based on actual available space
                          final actualKeyAreaWidth = keyboardConstraints.maxWidth;
                          final actualKeyHeight = keyboardConstraints.maxHeight;
                          final actualWhiteKeyWidth = actualKeyAreaWidth / whiteKeyCount;
                          final actualBlackKeyWidth = actualWhiteKeyWidth * 0.55;
                          final actualBlackKeyHeight = actualKeyHeight * 0.65;
                          
                          // Build both white and black keys with correct positioning
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
                                height: actualKeyHeight,
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
                                      blurRadius: isActive ? 8 : 2,
                                      offset: isActive ? const Offset(0, 4) : const Offset(0, 2),
                                    ),
                                    // Subtle ambient shadow
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.4),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: Colors.grey.shade500, width: 0.5),
                                      right: BorderSide(color: Colors.grey.shade800, width: 0.5),
                                      bottom: BorderSide(color: Colors.grey.shade900, width: 1.0),
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
                              final blackKeyLeft = (whiteKeyIndex * actualWhiteKeyWidth) - (actualBlackKeyWidth / 2);
                              
                              blackKeys.add(Positioned(
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
                                            const Color.fromARGB(255, 51, 51, 53),
                                            const Color.fromARGB(255, 79, 79, 79),
                                            const Color(0xFF1A1A1B),
                                            const Color(0xFF000000),
                                          ],
                                          stops: const [0.0, 0.3, 0.5, 0.84, 0.87, 0.92, .921],
                                        ),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(keyRadius),
                                      bottomRight: Radius.circular(keyRadius),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        blurRadius: isActive ? 0 : 2,
                                        offset: isActive ? const Offset(0, 0) : const Offset(-2, 0),
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
                              ...blackKeys,
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
                // Right cheek block
                Container(
                  width: 48, // Increased width to match cheekBlockWidth
                  height: double.infinity, // Take full available height
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color(0xFF4A4A4A), // Light charcoal at top-right
                        Color(0xFF3A3A3A), // Medium charcoal
                        Color(0xFF2A2A2A), // Darker charcoal
                        Color(0xFF1A1A1A), // Dark charcoal at bottom-left
                      ],
                      stops: [0.0, 0.3, 0.7, 1.0],
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
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                    child: Stack(
                      children: [
                        // Shadow overlay from case above
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 20, // Shadow depth from case above
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.4), // Stronger shadow at top
                                  Colors.black.withValues(alpha: 0.2),
                                  Colors.black.withValues(alpha: 0.0), // Fade to transparent
                                ],
                                stops: const [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}