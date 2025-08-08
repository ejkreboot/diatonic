import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'pages/piano_page.dart';
import 'pages/audio_player_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Diatonic');
    setWindowMinSize(const Size(800, 420));
    setWindowFrame(const Rect.fromLTWH(100, 100, 1200, 420));
  }

  runApp(const DiatonicApp());
}

class DiatonicApp extends StatelessWidget {
  const DiatonicApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0E0E0E),
        body: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 920,
            maxWidth: double.infinity,
          ),
          child: const _HomeShell(),
        ),
      ),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({Key? key}) : super(key: key);

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  bool _showAudioPlayer = false;
  bool _pendingResizeAfterCollapse = false;

  void _toggleAudioPlayer() {
    final targetShow = !_showAudioPlayer;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (targetShow) {
        // Expand window first to avoid overflow during expand animation
        setWindowFrame(const Rect.fromLTWH(100, 100, 1200, 920));
        setState(() => _showAudioPlayer = true);
      } else {
        // Start collapse animation first; shrink window after animation ends
        setState(() => _showAudioPlayer = false);
        _pendingResizeAfterCollapse = true;
      }
    } else {
      setState(() => _showAudioPlayer = targetShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PianoPage(),
        const SizedBox(height: 24),
        // Audio Player Toggle - Clean caret + text + line design
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * .95,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: _toggleAudioPlayer,
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
        // Audio Player Section (kept mounted, collapsed when hidden)
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          onEnd: () {
            if (!_showAudioPlayer && _pendingResizeAfterCollapse && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
              setWindowFrame(const Rect.fromLTWH(100, 100, 1200, 420));
              _pendingResizeAfterCollapse = false;
            }
          },
          child: Column(
            children: [
              SizedBox(height: _showAudioPlayer ? 16 : 0),
              ClipRect(
                child: Align(
                  heightFactor: _showAudioPlayer ? 1.0 : 0.0,
                  child: Container(
                    width: double.infinity,
                    height: 500, // finite height when shown
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
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
