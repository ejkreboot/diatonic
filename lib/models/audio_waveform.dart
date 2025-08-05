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
      final result = await Process.run(
        ffmpegPath,
        [
          '-i', filePath,
          '-f', 's16le',
          '-acodec', 'pcm_s16le',
          '-ac', '1',
          '-ar', '44100',
          pcmFilePath,
        ],
        runInShell: false,
      );

      if (result.exitCode != 0) {
        throw Exception('Failed to decode MP3:\n${result.stderr}');
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
    final bundledResourcePath = p.join(executableDir.path, 'Resources', 'ffmpeg');
    
    if (File(bundledResourcePath).existsSync()) {
      return bundledResourcePath;
    }

    throw Exception('❌ ffmpeg binary not found.');
  }
}


