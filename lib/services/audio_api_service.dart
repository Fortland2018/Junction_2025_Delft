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

  static Future<bool> addWordToFilter(String word) async {
    try {
      print('➕ Adding word to vocabulary filter: $word');
      final response = await http.post(
        Uri.parse('$baseUrl/vocabulary-filter/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'word': word.toLowerCase()}),
      );

      if (response.statusCode == 200) {
        print('✅ Word added successfully');
        return true;
      } else {
        print('❌ Failed to add word: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error adding word to filter: $e');
      return false;
    }
  }

  static Future<bool> removeWordFromFilter(String word) async {
    try {
      print('➖ Removing word from vocabulary filter: $word');
      final response = await http.post(
        Uri.parse('$baseUrl/vocabulary-filter/remove'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'word': word.toLowerCase()}),
      );

      if (response.statusCode == 200) {
        print('✅ Word removed successfully');
        return true;
      } else {
        print('❌ Failed to remove word: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error removing word from filter: $e');
      return false;
    }
  }

  static Future<List<String>?> getFilteredWords() async {
    try {
      print('📋 Getting filtered words list');
      final response = await http.get(
        Uri.parse('$baseUrl/vocabulary-filter/list'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final words = decoded['words'];
        if (words == null) {
          print('✅ Retrieved 0 filtered words (null response)');
          return [];
        }
        final List<dynamic> wordList = words as List<dynamic>;
        print('✅ Retrieved ${wordList.length} filtered words');
        return wordList.cast<String>();
      } else {
        print('❌ Failed to get filtered words: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting filtered words: $e');
      return [];
    }
  }

  static Future<MediaProcessingResult?> processMedia(
    String fileName,
    Uint8List fileBytes,
  ) async {
    try {
      print('📤 Sending file for processing: $fileName');
      print(
        '📦 Size: ${(fileBytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/process-media/'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      print('⏳ Waiting for processing...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('📨 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('✅ Media processed successfully');
        
        return MediaProcessingResult.fromJson(data);
      } else {
        print('❌ Error: ${response.body}');
      }
      return null;
    } catch (e) {
      print('❌ Error during API communication: $e');
      return null;
    }
  }
}

class MediaProcessingResult {
  final List<TranscriptionSentence> transcription;
  final String transcriptionText;
  final List<FlaggedWord> flaggedWords;
  final ExtremismAnalysis extremism;

  MediaProcessingResult({
    required this.transcription,
    required this.transcriptionText,
    required this.flaggedWords,
    required this.extremism,
  });

  factory MediaProcessingResult.fromJson(Map<String, dynamic> json) {
    return MediaProcessingResult(
      transcription: (json['transcription'] as List)
          .map((e) => TranscriptionSentence.fromJson(e))
          .toList(),
      transcriptionText: json['transcription_text'] ?? '',
      flaggedWords: (json['flagged_words'] as List)
          .map((e) => FlaggedWord.fromJson(e))
          .toList(),
      extremism: ExtremismAnalysis.fromJson(json['extremism']),
    );
  }
}

class TranscriptionSentence {
  final String text;
  final double start;
  final double end;
  final String category;
  final List<String> categories;
  final String color;
  final String level;

  TranscriptionSentence({
    required this.text,
    required this.start,
    required this.end,
    required this.category,
    required this.categories,
    required this.color,
    required this.level,
  });

  factory TranscriptionSentence.fromJson(Map<String, dynamic> json) {
    return TranscriptionSentence(
      text: json['text'] ?? '',
      start: (json['start'] ?? 0).toDouble(),
      end: (json['end'] ?? 0).toDouble(),
      category: json['category'] ?? 'Transcription',
      categories: json['categories'] != null 
          ? List<String>.from(json['categories'])
          : [json['category'] ?? 'Transcription'],
      color: json['color'] ?? '#667EEA',
      level: json['level'] ?? 'None',
    );
  }
}

class FlaggedWord {
  final int sentenceIndex;
  final String sentenceText;
  final List<String> flaggedWords;

  FlaggedWord({
    required this.sentenceIndex,
    required this.sentenceText,
    required this.flaggedWords,
  });

  factory FlaggedWord.fromJson(Map<String, dynamic> json) {
    // Parse the flagged_words array to extract just the word strings
    List<String> words = [];
    if (json['flagged_words'] != null) {
      for (var wordInfo in json['flagged_words']) {
        words.add(wordInfo['flagged_word'] ?? '');
      }
    }
    
    return FlaggedWord(
      sentenceIndex: json['sentence_index'] ?? 0,
      sentenceText: json['sentence_text'] ?? '',
      flaggedWords: words,
    );
  }
}

class ExtremismAnalysis {
  final Map<String, CategorizedScore> scores;
  final Map<String, dynamic> targets;
  final Map<String, dynamic> groupMapping;

  ExtremismAnalysis({
    required this.scores,
    required this.targets,
    required this.groupMapping,
  });

  factory ExtremismAnalysis.fromJson(Map<String, dynamic> json) {
    Map<String, CategorizedScore> parsedScores = {};
    
    if (json['scores'] != null) {
      (json['scores'] as Map<String, dynamic>).forEach((key, value) {
        parsedScores[key] = CategorizedScore.fromJson(value);
      });
    }
    
    return ExtremismAnalysis(
      scores: parsedScores,
      targets: json['targets'] ?? {},
      groupMapping: json['group_mapping'] ?? {},
    );
  }
}

class CategorizedScore {
  final double score;
  final String level;
  final String color;
  final String icon;

  CategorizedScore({
    required this.score,
    required this.level,
    required this.color,
    required this.icon,
  });

  factory CategorizedScore.fromJson(Map<String, dynamic> json) {
    return CategorizedScore(
      score: (json['score'] ?? 0).toDouble(),
      level: json['level'] ?? 'None',
      color: json['color'] ?? '#48BB78',
      icon: json['icon'] ?? 'check_circle',
    );
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
