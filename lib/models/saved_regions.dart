import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SavedRegion {
  final String name;
  final double startFraction;
  final double endFraction;

  SavedRegion({
    required this.name,
    required this.startFraction,
    required this.endFraction,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'startFraction': startFraction,
    'endFraction': endFraction,
  };

  factory SavedRegion.fromJson(Map<String, dynamic> json) {
    return SavedRegion(
      name: json['name'],
      startFraction: (json['startFraction'] as num).toDouble(),
      endFraction: (json['endFraction'] as num).toDouble(),
    );
  }

  // ---------- Static persistence helpers ----------

  static Future<String> _getFilePath(String audioFileName) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$audioFileName.regions.json';
  }

  static Future<void> saveRegions(String audioFileName, List<SavedRegion> regions) async {
    final path = await _getFilePath(audioFileName);
    final file = File(path);

    final jsonList = regions.map((r) => r.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  static Future<List<SavedRegion>> loadRegions(String audioFileName) async {
    try {
      final path = await _getFilePath(audioFileName);
      final file = File(path);

      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        return jsonList.map((item) => SavedRegion.fromJson(item)).toList();
      } else {
        return [];
      }
    } catch (e) {
      // Could log here if you want
      return [];
    }
  }
}
