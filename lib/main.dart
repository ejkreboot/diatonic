import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'pages/piano_page.dart';

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
