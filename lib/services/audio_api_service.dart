import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

// Model dla markera czasowego na waveform
class TimeMarker {
  final double timeInSeconds;
  final String label;
  final Color color;

  TimeMarker({
    required this.timeInSeconds,
    required this.label,
    this.color = const Color(0xFFFFD700), // Domyślnie żółty
  });
}

class AudioApiService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<WaveformData?> extractWaveform(
    String fileName,
    Uint8List fileBytes,
  ) async {
    try {
      print('📤 Wysyłanie pliku do backendu: $fileName');
      print(
        '📦 Rozmiar: ${(fileBytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/extract-waveform'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      print('⏳ Czekam na odpowiedź...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('📨 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          print('✅ Waveform otrzymany: ${data['samples']} punktów');
          print('⏱️  Długość: ${data['duration'].toStringAsFixed(2)}s');

          return WaveformData(
            waveform: List<int>.from(data['waveform']),
            sampleRate: data['sample_rate'],
            duration: data['duration'],
            samples: data['samples'],
            fileName: data['filename'],
            fileSize: data['file_size'],
            markers: [], // Pusta lista markerów na start
          );
        }
      } else {
        print('❌ Błąd: ${response.body}');
      }
      return null;
    } catch (e) {
      print('❌ Błąd podczas komunikacji z API: $e');
      return null;
    }
  }

  static Future<bool> checkServerStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class WaveformData {
  final List<int> waveform;
  final int sampleRate;
  final double duration;
  final int samples;
  final String fileName;
  final int fileSize;
  final List<TimeMarker> markers; // NOWE: Lista markerów czasowych

  WaveformData({
    required this.waveform,
    required this.sampleRate,
    required this.duration,
    required this.samples,
    required this.fileName,
    required this.fileSize,
    this.markers = const [], // Domyślnie pusta lista
  });

  // Pomocnicza metoda do tworzenia kopii z nowymi markerami
  WaveformData copyWith({
    List<int>? waveform,
    int? sampleRate,
    double? duration,
    int? samples,
    String? fileName,
    int? fileSize,
    List<TimeMarker>? markers,
  }) {
    return WaveformData(
      waveform: waveform ?? this.waveform,
      sampleRate: sampleRate ?? this.sampleRate,
      duration: duration ?? this.duration,
      samples: samples ?? this.samples,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      markers: markers ?? this.markers,
    );
  }
}
