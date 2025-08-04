import 'package:flutter/material.dart';

typedef FractionCallback = void Function(double);

class WaveformVisualizer extends StatefulWidget {
  final List<double> amplitudes;
  final double progress;
  final String currentTimeLabel;
  final FractionCallback? onSeek;
  final FractionCallback? onSelectStart;
  final FractionCallback? onSelectEnd;
  final VoidCallback? onClearLoop;
  final double? loopStartFraction;
  final double? loopEndFraction;

  const WaveformVisualizer({
    super.key,
    required this.amplitudes,
    required this.progress,
    required this.currentTimeLabel,
    this.onSeek,
    this.onSelectStart,
    this.onSelectEnd,
    this.onClearLoop,
    this.loopStartFraction,
    this.loopEndFraction,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer> {
  bool _isDragging = false;

  void _handleTapDown(TapDownDetails details, double width) {
    final tapFraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
    final start = widget.loopStartFraction;
    final end = widget.loopEndFraction;

    if (start != null && end != null) {
      final realStart = start < end ? start : end;
      final realEnd = start > end ? start : end;

      if (tapFraction < realStart || tapFraction > realEnd) {
        widget.onClearLoop?.call();
      }
    }

    if (!_isDragging) {
      widget.onSeek?.call(tapFraction);
    }
  }

  void _handleDragStart(DragStartDetails details, double width) {
    _isDragging = true;
    final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
    widget.onSelectStart?.call(fraction);
    widget.onSelectEnd?.call(fraction);
  }

  void _handleDragUpdate(DragUpdateDetails details, double width) {
    final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
    widget.onSelectEnd?.call(fraction);
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;

    final start = widget.loopStartFraction;
    final end = widget.loopEndFraction;

    if (start != null && end != null) {
      final realStart = start < end ? start : end;
      widget.onSeek?.call(realStart);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = 100.0;
        final playheadX = widget.progress * width;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) => _handleTapDown(details, width),
          onPanStart: (details) => _handleDragStart(details, width),
          onPanUpdate: (details) => _handleDragUpdate(details, width),
          onPanEnd: _handleDragEnd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                painter: _WaveformPainter(
                  widget.amplitudes,
                  widget.progress,
                  widget.loopStartFraction,
                  widget.loopEndFraction,
                ),
                size: Size(width, height),
              ),
              Positioned(
                left: playheadX.clamp(0, width - 40)-5,
                top: height - 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(0xFFffae00),
                      width: 2,
                    ),
                    color: const Color.fromARGB(255, 26, 26, 26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.currentTimeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color.fromARGB(255, 82, 189, 255),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final double? loopStartFraction;
  final double? loopEndFraction;

  _WaveformPainter(
    this.amplitudes,
    this.progress,
    this.loopStartFraction,
    this.loopEndFraction,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final playedPaint = Paint()
      ..color = const Color.fromARGB(255, 6, 112, 178)
      ..strokeWidth = 1;

    final unplayedPaint = Paint()
      ..color = const Color(0xFF0095f2)
      ..strokeWidth = 1;

    final loopPaint = Paint()
      ..color = const Color(0x66ffae00)
      ..style = PaintingStyle.fill;

    final playheadPaint = Paint()
      ..color = const Color(0xFFffae00)
      ..strokeWidth = 2;

    final centerY = size.height / 2;
    final spacing = size.width / amplitudes.length;
    final playedIndex = (amplitudes.length * progress).clamp(0, amplitudes.length - 1).toInt();

    // Draw loop selection
    if (loopStartFraction != null && loopEndFraction != null) {
      final startX = (loopStartFraction! * size.width).clamp(0.0, size.width);
      final endX = (loopEndFraction! * size.width).clamp(0.0, size.width);
      canvas.drawRect(
        Rect.fromLTRB(
          startX < endX ? startX : endX,
          0,
          startX > endX ? startX : endX,
          size.height,
        ),
        loopPaint,
      );
    }

    // Draw waveform
    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * spacing;
      final barHeight = amplitudes[i] * (size.height / 4);
      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        i <= playedIndex ? playedPaint : unplayedPaint,
      );
    }

    // Draw playhead
    final playheadX = progress * size.width;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
           oldDelegate.progress != progress ||
           oldDelegate.loopStartFraction != loopStartFraction ||
           oldDelegate.loopEndFraction != loopEndFraction;
  }
}
