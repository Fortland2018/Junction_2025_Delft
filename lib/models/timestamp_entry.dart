import 'package:flutter/material.dart';

class TimestampEntry {
  final double timeInSeconds;
  final String category;
  final String text;
  final Color color;

  TimestampEntry({
    required this.timeInSeconds,
    required this.category,
    required this.text,
    required this.color,
  });

  String get formattedTime {
    final minutes = (timeInSeconds / 60).floor();
    final seconds = (timeInSeconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory TimestampEntry.fromJson(Map<String, dynamic> json) {
    return TimestampEntry(
      timeInSeconds: json['timeInSeconds'].toDouble(),
      category: json['category'],
      text: json['text'],
      color: Color(int.parse(json['color'].replaceFirst('#', '0xFF'))),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timeInSeconds': timeInSeconds,
      'category': category,
      'text': text,
      'color': '#${color.value.toRadixString(16).substring(2)}',
    };
  }
}

// Sample data
List<TimestampEntry> getSampleTimestamps() {
  return [
    TimestampEntry(
      timeInSeconds: 12.5,
      category: 'Dehumanization',
      text: 'Speaker refers to group using derogatory terms',
      color: Color(0xFF667EEA), // Niebieski
    ),
    TimestampEntry(
      timeInSeconds: 28.3,
      category: 'Violence_advocacy',
      text: 'Discussion of aggressive actions towards others',
      color: Color(0xFF48BB78), // Zielony
    ),
    TimestampEntry(
      timeInSeconds: 45.7,
      category: 'Absolutism',
      text: 'Use of absolute terms and black-white thinking',
      color: Color(0xFF9F7AEA), // Fioletowy
    ),
    TimestampEntry(
      timeInSeconds: 63.2,
      category: 'Threat_inflation',
      text: 'Exaggeration of perceived threats',
      color: Color(0xFFED8936), // Pomarańczowy
    ),
    TimestampEntry(
      timeInSeconds: 78.9,
      category: 'Dehumanization',
      text: 'Characterization of people as animals or objects',
      color: Color(0xFF667EEA), // Niebieski
    ),
    TimestampEntry(
      timeInSeconds: 95.4,
      category: 'Outgroup_homogenization',
      text: 'Treating outgroup members as all the same',
      color: Color(0xFF38B2AC), // Turkusowy
    ),
    TimestampEntry(
      timeInSeconds: 112.6,
      category: 'Absolutism',
      text: 'Binary thinking without nuance',
      color: Color(0xFF9F7AEA), // Fioletowy
    ),
    TimestampEntry(
      timeInSeconds: 128.1,
      category: 'Violence_advocacy',
      text: 'Explicit call for harm against specific targets',
      color: Color(0xFF48BB78), // Zielony
    ),
  ];
}
