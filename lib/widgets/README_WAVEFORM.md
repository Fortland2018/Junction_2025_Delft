# 📊 Waveform Widget - Documentation

## 📁 File Structure

```
lib/
├── services/
│   └── audio_api_service.dart    # API for backend communication + data models
├── widgets/
│   └── waveform_widget.dart      # Widget displaying waveform graph
└── main.dart                      # Main application with UI
```

---

## 🎯 Functionality

### **WaveformWidget**
A Flutter widget responsible for visualizing audio waveforms from audio/video files.

#### **Features:**
- ✅ Symmetrical waveform (top + bottom)
- ✅ Time markers (yellow dots/lines)
- ✅ Time labels in `MM:SS` format
- ✅ Responsive layout
- ✅ Configurable color and height

---

## 📦 Data Models

### **TimeMarker**
```dart
class TimeMarker {
  final double timeInSeconds;   // Time in seconds (e.g., 15.5)
  final String label;            // Label (e.g., "00:15")
  final Color color;             // Marker color (default: yellow)
}
```

### **WaveformData**
```dart
class WaveformData {
  final List<int> waveform;          // Array of amplitudes (0-255)
  final int sampleRate;              // Sample rate
  final double duration;             // Duration in seconds
  final int samples;                 // Number of samples
  final String fileName;             // File name
  final int fileSize;                // File size in bytes
  final List<TimeMarker> markers;    // List of time markers
}
```

---

## 🎨 Widget Usage

### **Basic usage:**
```dart
WaveformWidget(
  waveformData: yourWaveformData,
  waveColor: Color(0xFF667EEA),
  height: 80, // Compact height
)
```

### **With time markers:**
```dart
// Add marker at 1 minute 30 seconds
_waveformData = _waveformData!.copyWith(
  markers: [
    TimeMarker(
      timeInSeconds: 90.0,
      label: '01:30',
      color: Color(0xFFFFD700), // Yellow
    ),
  ],
);
```

---

## 🔧 Helper Functions in main.dart

### **1. Add marker at specific time**
```dart
void _addTimeMarker(int minutes, int seconds) {
  // Adds a marker on the waveform in MM:SS format
  // Example: _addTimeMarker(1, 30) → marker at 1:30
}
```

### **2. Add example markers automatically**
```dart
void _addExampleMarkers() {
  // Adds markers every 15 seconds
  // Useful for testing
}
```

### **3. Clear all markers**
```dart
void _clearMarkers() {
  // Removes all markers from the waveform
}
```

---

## 🎯 Usage Examples

### **Example 1: Add marker at specific time**
```dart
// Add marker at 2:45 (2 minutes 45 seconds)
_addTimeMarker(2, 45);
```

### **Example 2: Add multiple markers at once**
```dart
setState(() {
  _waveformData = _waveformData!.copyWith(
    markers: [
      TimeMarker(timeInSeconds: 15.0, label: '00:15', color: Color(0xFFFFD700)),
      TimeMarker(timeInSeconds: 30.0, label: '00:30', color: Color(0xFFFFD700)),
      TimeMarker(timeInSeconds: 45.0, label: '00:45', color: Color(0xFFFF6B6B)),
      TimeMarker(timeInSeconds: 60.0, label: '01:00', color: Color(0xFF4ECDC4)),
    ],
  );
});
```

### **Example 3: Markers with different colors**
```dart
TimeMarker(
  timeInSeconds: 120.0,
  label: '02:00',
  color: Color(0xFFFF6B6B), // Red
)

TimeMarker(
  timeInSeconds: 180.0,
  label: '03:00',
  color: Color(0xFF4ECDC4), // Turquoise
)
```

---

## 🎨 Customization

### **Change waveform color:**
```dart
WaveformWidget(
  waveformData: _waveformData!,
  waveColor: Color(0xFFFF6B6B), // Red instead of blue
  height: 80, // Compact height
)
```

### **Change marker color:**
In file `waveform_widget.dart`, line 78:
```dart
color: marker.color, // Uses color from TimeMarker
```

### **Change waveform line thickness:**
In file `waveform_widget.dart`, line 44:
```dart
..strokeWidth = 2.5 // Increase or decrease
```

---

## 🔍 Architecture

```
┌─────────────────┐
│   main.dart     │ ← UI + application logic
│     (user)      │
└────────┬────────┘
         │
         │ calls
         ▼
┌─────────────────────┐
│ audio_api_service   │ ← Backend communication
│ (HTTP requests)     │
└────────┬────────────┘
         │
         │ returns WaveformData
         ▼
┌─────────────────────┐
│  waveform_widget    │ ← Renders waveform + markers
│  (CustomPainter)    │
└─────────────────────┘
```

---

## 📊 How CustomPainter Works

1. **_drawWaveform()** - Draws symmetrical wave:
   - Iterates through `waveform` array
   - Normalizes amplitudes (0-255 → 0-1)
   - Draws lines from center upward and downward

2. **_drawTimeMarkers()** - Draws markers:
   - Calculates X position: `(timeInSeconds / duration) × width`
   - Draws vertical line
   - Draws dots at top and bottom
   - Draws time label with shadow

---

## 🚀 Future Extensions

- [ ] Interactive clicking on waveform → add marker
- [ ] Edit marker labels on click
- [ ] Export markers to JSON/CSV
- [ ] Import markers from file
- [ ] Different marker styles (dot, line, arrow)
- [ ] Animation for marker appearance
- [ ] Zoom on waveform section
- [ ] Play/Pause with marker synchronization

---

## 📝 Technical Notes

### **Performance:**
- Backend (Python + librosa) generates **1000 samples** for each file
- CustomPainter renders ~1000 lines on the waveform
- Markers are drawn on top, don't affect waveform performance

### **Precision:**
- Marker time: precision up to **0.01 second** (double)
- Position on waveform: pixel-perfect alignment
- Label format: always `MM:SS` (zero-padded)

---

## 🐛 Debugging

### **Problem: Markers not visible**
✅ Check if `_waveformData.markers` is not empty
✅ Check if marker color is not transparent
✅ Check if `timeInSeconds` < `duration`

### **Problem: Marker in wrong position**
✅ Check formula: `(timeInSeconds / duration) × width`
✅ Check if `duration` is correct

### **Problem: Label not visible**
✅ Increase padding in `Container` (line 710 in main.dart)
✅ Check shadow color in `TextPainter` (line 118 in waveform_widget.dart)

---

## 📞 Contact

If you have questions about implementation:
1. Check comments in the code
2. Read this documentation
3. See usage examples in `main.dart`

**Last updated:** October 4, 2025
