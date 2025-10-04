# 📊 Waveform Widget - Dokumentacja

## 📁 Struktura plików

```
lib/
├── services/
│   └── audio_api_service.dart    # API do komunikacji z backendem + modele danych
├── widgets/
│   └── waveform_widget.dart      # Widget wyświetlający wykres waveform
└── main.dart                      # Główna aplikacja z UI
```

---

## 🎯 Funkcjonalność

### **WaveformWidget**
Widget Flutter odpowiedzialny za wizualizację fali dźwiękowej (waveform) z plików audio/video.

#### **Cechy:**
- ✅ Symetryczny wykres (góra + dół)
- ✅ Markery czasowe (żółte kropki/kreski)
- ✅ Etykiety czasu w formacie `MM:SS`
- ✅ Responsywny layout
- ✅ Konfigurowalny kolor i wysokość

---

## 📦 Modele danych

### **TimeMarker**
```dart
class TimeMarker {
  final double timeInSeconds;   // Czas w sekundach (np. 15.5)
  final String label;            // Etykieta (np. "00:15")
  final Color color;             // Kolor markera (domyślnie żółty)
}
```

### **WaveformData**
```dart
class WaveformData {
  final List<int> waveform;          // Tablica amplitud (0-255)
  final int sampleRate;              // Częstotliwość próbkowania
  final double duration;             // Długość w sekundach
  final int samples;                 // Liczba próbek
  final String fileName;             // Nazwa pliku
  final int fileSize;                // Rozmiar w bajtach
  final List<TimeMarker> markers;    // Lista markerów czasowych
}
```

---

## 🎨 Użycie widgetu

### **Podstawowe użycie:**
```dart
WaveformWidget(
  waveformData: yourWaveformData,
  waveColor: Color(0xFF667EEA),
  height: 120,
)
```

### **Z markerami czasowymi:**
```dart
// Dodaj marker na 1 minutę 30 sekund
_waveformData = _waveformData!.copyWith(
  markers: [
    TimeMarker(
      timeInSeconds: 90.0,
      label: '01:30',
      color: Color(0xFFFFD700), // Żółty
    ),
  ],
);
```

---

## 🔧 Funkcje pomocnicze w main.dart

### **1. Dodaj marker w określonym czasie**
```dart
void _addTimeMarker(int minutes, int seconds) {
  // Dodaje marker na wykresie w formacie MM:SS
  // Przykład: _addTimeMarker(1, 30) → marker na 1:30
}
```

### **2. Dodaj przykładowe markery automatycznie**
```dart
void _addExampleMarkers() {
  // Dodaje markery co 15 sekund
  // Przydatne do testowania
}
```

### **3. Wyczyść wszystkie markery**
```dart
void _clearMarkers() {
  // Usuwa wszystkie markery z wykresu
}
```

---

## 🎯 Przykłady użycia

### **Przykład 1: Dodaj marker na określonym czasie**
```dart
// Dodaj marker na 2:45 (2 minuty 45 sekund)
_addTimeMarker(2, 45);
```

### **Przykład 2: Dodaj wiele markerów jednocześnie**
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

### **Przykład 3: Markery z różnymi kolorami**
```dart
TimeMarker(
  timeInSeconds: 120.0,
  label: '02:00',
  color: Color(0xFFFF6B6B), // Czerwony
)

TimeMarker(
  timeInSeconds: 180.0,
  label: '03:00',
  color: Color(0xFF4ECDC4), // Turkusowy
)
```

---

## 🎨 Customizacja

### **Zmień kolor waveform:**
```dart
WaveformWidget(
  waveformData: _waveformData!,
  waveColor: Color(0xFFFF6B6B), // Czerwony zamiast niebieskiego
  height: 120,
)
```

### **Zmień kolor markerów:**
W pliku `waveform_widget.dart`, linia 78:
```dart
color: marker.color, // Używa koloru z TimeMarker
```

### **Zmień grubość linii waveform:**
W pliku `waveform_widget.dart`, linia 44:
```dart
..strokeWidth = 2.5 // Zwiększ lub zmniejsz
```

---

## 🔍 Architektura

```
┌─────────────────┐
│   main.dart     │ ← UI + logika aplikacji
│  (użytkownik)   │
└────────┬────────┘
         │
         │ wywołuje
         ▼
┌─────────────────────┐
│ audio_api_service   │ ← Komunikacja z backendem
│ (HTTP requests)     │
└────────┬────────────┘
         │
         │ zwraca WaveformData
         ▼
┌─────────────────────┐
│  waveform_widget    │ ← Renderuje wykres + markery
│  (CustomPainter)    │
└─────────────────────┘
```

---

## 📊 Jak działa CustomPainter

1. **_drawWaveform()** - Rysuje symetryczną falę:
   - Iteruje przez tablicę `waveform`
   - Normalizuje amplitudy (0-255 → 0-1)
   - Rysuje linie od środka w górę i w dół

2. **_drawTimeMarkers()** - Rysuje markery:
   - Oblicza pozycję X: `(timeInSeconds / duration) × width`
   - Rysuje pionową kreskę
   - Rysuje kropki na górze i dole
   - Rysuje label czasu z cieniem

---

## 🚀 Rozszerzenia możliwe w przyszłości

- [ ] Interaktywne klikanie na wykres → dodaj marker
- [ ] Edycja label markerów po kliknięciu
- [ ] Export markerów do JSON/CSV
- [ ] Import markerów z pliku
- [ ] Różne style markerów (kropka, kreska, strzałka)
- [ ] Animacja pojawiania się markerów
- [ ] Zoom na fragment wykresu
- [ ] Play/Pause z synchronizacją z markerami

---

## 📝 Notatki techniczne

### **Wydajność:**
- Backend (Python + librosa) generuje **1000 próbek** dla każdego pliku
- CustomPainter renderuje ~1000 linii na wykresie
- Markery są rysowane na wierzchu, nie wpływają na wydajność waveform

### **Precision:**
- Czas markerów: precyzja do **0.01 sekundy** (double)
- Pozycja na wykresie: piksel-perfect alignment
- Label format: zawsze `MM:SS` (zero-padded)

---

## 🐛 Debugowanie

### **Problem: Markery nie widać**
✅ Sprawdź czy `_waveformData.markers` nie jest puste
✅ Sprawdź czy kolor markera nie jest transparentny
✅ Sprawdź czy `timeInSeconds` < `duration`

### **Problem: Marker w złym miejscu**
✅ Sprawdź formułę: `(timeInSeconds / duration) × width`
✅ Sprawdź czy `duration` jest prawidłowe

### **Problem: Label nie widać**
✅ Zwiększ padding w `Container` (linia 710 w main.dart)
✅ Sprawdź kolor cienia w `TextPainter` (linia 118 w waveform_widget.dart)

---

## 📞 Kontakt

Jeśli masz pytania o implementację:
1. Sprawdź komentarze w kodzie
2. Przeczytaj tę dokumentację
3. Zobacz przykłady użycia w `main.dart`

**Ostatnia aktualizacja:** 4 października 2025
