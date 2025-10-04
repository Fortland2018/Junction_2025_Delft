import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'services/audio_api_service.dart';
import 'widgets/waveform_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Junction 2025 Project',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _fileName;
  PlatformFile? _selectedFile;
  WaveformData? _waveformData;
  bool _isProcessing = false;
  bool _serverOnline = false;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    final status = await AudioApiService.checkServerStatus();
    setState(() {
      _serverOnline = status;
    });
    if (!status) {
      print('⚠️ Backend nie działa! Uruchom: python backend/main.py');
    }
  }

  // NOWA FUNKCJA: Dodaj marker w określonym czasie (minuty:sekundy)
  void _addTimeMarker(int minutes, int seconds) {
    if (_waveformData == null) return;

    final timeInSeconds = (minutes * 60.0) + seconds.toDouble();

    // Sprawdź czy czas mieści się w długości audio
    if (timeInSeconds > _waveformData!.duration) {
      print('⚠️ Czas $minutes:$seconds przekracza długość audio!');
      return;
    }

    setState(() {
      _waveformData = _waveformData!.copyWith(
        markers: [
          ..._waveformData!.markers,
          TimeMarker(
            timeInSeconds: timeInSeconds,
            label:
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            color: Color(0xFFFFD700), // Żółty
          ),
        ],
      );
    });

    print('📍 Dodano marker: $minutes:$seconds (${timeInSeconds}s)');
  }

  // NOWA FUNKCJA: Dodaj przykładowe markery do testowania
  void _addExampleMarkers() {
    if (_waveformData == null) return;

    // Przykładowe markery co 15 sekund
    final duration = _waveformData!.duration;
    final markerInterval = 15.0; // co 15 sekund

    List<TimeMarker> newMarkers = [];
    for (
      double time = markerInterval;
      time < duration;
      time += markerInterval
    ) {
      final minutes = (time / 60).floor();
      final seconds = (time % 60).floor();

      newMarkers.add(
        TimeMarker(
          timeInSeconds: time,
          label:
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          color: Color(0xFFFFD700),
        ),
      );
    }

    setState(() {
      _waveformData = _waveformData!.copyWith(markers: newMarkers);
    });

    print('📍 Dodano ${newMarkers.length} markerów');
  }

  // NOWA FUNKCJA: Wyczyść wszystkie markery
  void _clearMarkers() {
    if (_waveformData == null) return;

    setState(() {
      _waveformData = _waveformData!.copyWith(markers: []);
    });

    print('🗑️ Wyczyszczono wszystkie markery');
  }

  Future<void> _pickFile() async {
    if (!_serverOnline) {
      print('❌ Backend nie działa!');
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'wav',
          'mp4',
          'm4a',
          'aac',
          'mov',
          'avi',
          'flac',
        ],
        allowMultiple: false,
        withData: true,
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
          _fileName = result.files.first.name;
          _isProcessing = true;
          _waveformData = null;
        });

        print('📁 Wybrany plik: ${_fileName}');
        print(
          '📦 Rozmiar: ${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
        );

        // Wyślij do Python backend
        if (_selectedFile!.bytes != null) {
          final waveform = await AudioApiService.extractWaveform(
            _selectedFile!.name,
            _selectedFile!.bytes!,
          );

          setState(() {
            _waveformData = waveform;
            _isProcessing = false;
          });

          if (waveform != null) {
            print('✅ Sukces! Waveform otrzymany');
          } else {
            print('❌ Błąd podczas przetwarzania');
          }
        }
      }
    } catch (e) {
      print('❌ Błąd: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7FAFC), Color(0xFFEDF2F7)],
          ),
        ),
        child: Column(
          children: [
            // Własny header z grafiką
            Container(
              width: double.infinity,
              height: 116, // Wysokość paska
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1), // Indigo
                    Color(0xFF8B5CF6), // Violet
                    Color(0xFFEC4899), // Pink
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Dekoracyjne elementy graficzne
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -30,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  // Główna zawartość header'a
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Logo/Tytuł
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Junction 2025',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              'Delft Project',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            if (_serverOnline)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '● Server Online',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            else
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '● Server Offline',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Menu/Ikony
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () {},
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.settings_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Główna zawartość strony
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lewy górny róg - Upload box (stała szerokość)
                    Container(
                      width: 280,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ikonka do załadowania pliku
                          InkWell(
                            onTap: _isProcessing ? null : _pickFile,
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isProcessing
                                      ? [Colors.grey, Colors.grey.shade400]
                                      : [Color(0xFF667EEA), Color(0xFF764BA2)],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF667EEA,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: _isProcessing
                                  ? Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : Icon(
                                      Icons.upload_file,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Upload File',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isProcessing ? 'Processing...' : 'Click to upload',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667EEA).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _fileName ?? 'No file',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF667EEA),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedFile != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Size: ${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          // NOWE: Przyciski do zarządzania markerami
                          if (_waveformData != null) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            Text(
                              'Time Markers',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _addExampleMarkers,
                              icon: Icon(Icons.add_location, size: 18),
                              label: Text(
                                'Add Markers',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFFFD700),
                                foregroundColor: Colors.black87,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                minimumSize: Size(double.infinity, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _clearMarkers,
                              icon: Icon(Icons.clear_all, size: 18),
                              label: Text(
                                'Clear All',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red[400],
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                minimumSize: Size(double.infinity, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                            ),
                            if (_waveformData!.markers.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFFD700).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Color(0xFFFFD700),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '${_waveformData!.markers.length} markers',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Prawa strona - Waveform widget
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.graphic_eq,
                                  color: Color(0xFF667EEA),
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Audio Waveform',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                Spacer(),
                                if (_waveformData != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF667EEA).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_waveformData!.duration.toStringAsFixed(1)}s',
                                      style: TextStyle(
                                        color: Color(0xFF667EEA),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (_waveformData!.markers.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(
                                          0xFFFFD700,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Color(0xFFFFD700),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_waveformData!.markers.length}',
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Waveform display
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: _waveformData != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 8.0,
                                        ),
                                        child: WaveformWidget(
                                          waveformData: _waveformData!,
                                          waveColor: Color(0xFF667EEA),
                                          height: 104,
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.audio_file_outlined,
                                            size: 40,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Upload an audio/video file to see the waveform',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            if (_waveformData != null) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _buildInfoChip(
                                    Icons.insert_drive_file,
                                    _waveformData!.fileName,
                                  ),
                                  _buildInfoChip(
                                    Icons.storage,
                                    '${(_waveformData!.fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
                                  ),
                                  _buildInfoChip(
                                    Icons.show_chart,
                                    '${_waveformData!.samples} samples',
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
