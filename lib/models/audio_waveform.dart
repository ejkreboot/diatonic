import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:wav/wav.dart';
import 'package:flutter/foundation.dart';

Future<List<double>> readWaveformInIsolate(String filePath) async {
  final aw = AudioWaveform(filePath);
  return await aw.readAudioData();
}

class AudioWaveform {
  final String filePath;
  final int chunkSize;

  const AudioWaveform(this.filePath, {this.chunkSize = 5000});

  Future<List<double>> readAudioData() async {
    final extension = p.extension(filePath).toLowerCase();

    if (extension == '.wav') {
      return _readWav();
    } else if (extension == '.mp3') {
      return _readMp3();
    } else {
      throw Exception('Unsupported file type: $extension');
    }
  }

  Future<List<double>> _readWav() async {
    final wav = await Wav.readFile(filePath);
    final channel = wav.channels.isNotEmpty ? wav.channels.first : <double>[];

    if (channel.isEmpty) {
      throw Exception('No audio data found in WAV file.');
    }

    return _calculateRms(channel);
  }

  Future<List<double>> _readMp3() async {
    File? tempFile;
    
    try {
      // Create temporary PCM file in system temp directory
      final tempDir = Directory.systemTemp;
      tempFile = File(p.join(tempDir.path, 'diatonic_${DateTime.now().millisecondsSinceEpoch}_decoded.pcm'));
      final pcmFilePath = tempFile.path;

      final ffmpegPath = _getBundledFfmpegPath();

      // Decode MP3 to raw PCM 16-bit LE signed audio
      final args = [
        '-hide_banner',
        '-loglevel', 'error', // suppress normal info, keep errors
        '-i', filePath,
        '-f', 's16le',
        '-acodec', 'pcm_s16le',
        '-ac', '1',
        '-ar', '44100',
        pcmFilePath,
      ];

      final result = await Process.run(ffmpegPath, args, runInShell: false);

      if (result.exitCode != 0) {
        debugPrint('FFmpeg path: $ffmpegPath');
        debugPrint('FFmpeg exists: ${File(ffmpegPath).existsSync()}');
        try {
          final stat = FileStat.statSync(ffmpegPath);
          debugPrint('FFmpeg mode: ${stat.modeString()} size: ${stat.size} modified: ${stat.modified}');
        } catch (_) {}
        debugPrint('FFmpeg stderr: ${result.stderr}');
        debugPrint('FFmpeg stdout: ${result.stdout}');
        throw Exception('Failed to decode MP3 (exit ${result.exitCode}).');
      }

      final pcmBytes = await tempFile.readAsBytes();
      final samples = _convertPcm16LEToDoubles(pcmBytes);

      return _calculateRms(samples);
    } catch (e) {
      // Re-throw with more context
      throw Exception('Error processing MP3 file: $e');
    } finally {
      // Ensure cleanup happens even if there's an exception
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (e) {
          // Log but don't throw - cleanup failure shouldn't break the main operation
          debugPrint('Warning: Failed to clean up temporary file: $e');
        }
      }
    }
  }

  List<double> _convertPcm16LEToDoubles(Uint8List bytes) {
    final buffer = bytes.buffer.asByteData();
    final samples = <double>[];

    for (int i = 0; i < buffer.lengthInBytes; i += 2) {
      final intSample = buffer.getInt16(i, Endian.little);
      samples.add(intSample / 32768.0);
    }

    return samples;
  }

  List<double> _calculateRms(List<double> samples) {
    final rmsValues = <double>[];

    for (int i = 0; i < samples.length; i += chunkSize) {
      final end = (i + chunkSize < samples.length) ? i + chunkSize : samples.length;
      final chunk = samples.sublist(i, end);

      if (chunk.isEmpty) continue;

      final rms = chunk.map((e) => e * e).reduce((a, b) => a + b) / chunk.length;
      rmsValues.add(rms);
    }

    if (rmsValues.isEmpty) {
      throw Exception('Failed to extract waveform data.');
    }

    final maxRms = rmsValues.reduce(max);

    return rmsValues.map((rms) => rms / maxRms).toList();
  }

  String _getBundledFfmpegPath() {
    final executableDir = File(Platform.resolvedExecutable).parent.parent;
    final isWindows = Platform.isWindows;
    final candidates = [
      if (isWindows) p.join(executableDir.path, 'ffmpeg.exe'), // same dir as diatonic.exe
      p.join(executableDir.path, 'Resources', isWindows ? 'ffmpeg.exe' : 'ffmpeg'),              // current location
      p.join(executableDir.path, 'MacOS', isWindows ? 'ffmpeg.exe' : 'ffmpeg'),                  // if moved beside main executable
      p.join(executableDir.path, 'MacOS', isWindows ? 'ffmpeg-helper.exe' : 'ffmpeg-helper'),    // optional renamed helper
    ];
    if (isWindows) {
      candidates.insert(1, p.join('.', 'build', 'windows', 'x64', 'runner', 'Debug', 'ffmpeg.exe'));
      candidates.insert(2, p.join('.', 'build', 'windows', 'x64', 'runner', 'Release', 'ffmpeg.exe'));
    }

    debugPrint('FFmpeg path candidates:');
    for (final c in candidates.whereType<String>()) {
      debugPrint('  $c');
      final f = File(c);
      if (f.existsSync()) {
        debugPrint('FFmpeg found at: $c');
        return c;
      }
    }

    debugPrint('❌ ffmpeg binary not found in any candidate location.');
    throw Exception('❌ ffmpeg binary not found in: ${candidates.whereType<String>().join(', ')}');
  }
}


