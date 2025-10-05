import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'services/audio_api_service.dart';
import 'widgets/waveform_widget.dart';
import 'widgets/action_buttons_widget.dart';
import 'widgets/timestamp_list_widget.dart';
import 'widgets/vocabulary_filter_widget.dart';
import 'models/timestamp_entry.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audio Analysis System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Audio Analysis System'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
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
  List<TimestampEntry> _timestamps = [];
  String? _selectedCategory;
  MediaProcessingResult? _processingResult;
  List<String> _vocabularyFilterWords = [];
  List<String> _predefinedFilterWords = [];
  bool _isUploadBoxMinimized = false;
  bool _isVocabularyFilterExpanded = true;
  bool _isExtremismAnalysisExpanded = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _availableCategories = [
    'ALL',
    'Vocabulary Filter',
    'Violence Advocacy',
    'Dehumanization',
    'Outgroup Homogenization',
    'Threat Inflation',
    'Absolutism',
    'Transcription',
  ];

  @override
  void initState() {
    super.initState();
    _checkServer();
    _loadVocabularyFilter();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVocabularyFilter() async {
    final filterWords = await AudioApiService.getFilteredWords();
    if (filterWords != null) {
      setState(() {
        _vocabularyFilterWords = filterWords;
        // Store the initial words as predefined (loaded from backend on startup)
        if (_predefinedFilterWords.isEmpty && filterWords.isNotEmpty) {
          _predefinedFilterWords = List.from(filterWords);
        }
      });
      print('📋 Loaded ${filterWords.length} words (${_predefinedFilterWords.length} predefined)');
    }
  }

  Future<void> _checkServer() async {
    final status = await AudioApiService.checkServerStatus();
    setState(() {
      _serverOnline = status;
    });
    if (!status) {
      print('⚠️ Backend not running! Start with: python backend/main.py');
    } else {
      print('✅ Backend is online');
    }
  }

  void _convertResultsToTimestamps(MediaProcessingResult result) {
    List<TimestampEntry> newTimestamps = [];
    
    for (var sentence in result.transcription) {
      Color color = Color(int.parse(sentence.color.replaceFirst('#', '0xFF')));
      String displayText = sentence.text;
      String category = sentence.category;
      
      if (category == 'Vocabulary Filter') {
        color = const Color(0xFFED8936);
      } else if (sentence.level != 'None') {
        displayText = '[${sentence.level}] ${sentence.text}';
      }
      
      newTimestamps.add(TimestampEntry(
        timeInSeconds: sentence.start,
        category: category,
        categories: sentence.categories,
        text: displayText,
        color: color,
      ));
    }
    
    setState(() {
      _timestamps = newTimestamps;
    });
    
    _syncTimestampsToMarkers();
  }

  void _syncTimestampsToMarkers() {
    if (_waveformData == null) return;

    final timestampsToShow = _selectedCategory == null || _selectedCategory == 'ALL'
        ? _timestamps
        : _timestamps.where((t) => t.hasCategory(_selectedCategory!)).toList();

    final markers = timestampsToShow.map((entry) {
      return TimeMarker(
        timeInSeconds: entry.timeInSeconds,
        label: entry.formattedTime,
        color: entry.color,
      );
    }).toList();

    setState(() {
      _waveformData = _waveformData!.copyWith(markers: markers);
    });
  }

  void _handleCategoryFilter(String category) {
    setState(() {
      if (category == 'ALL') {
        _selectedCategory = null;
      } else {
        _selectedCategory = category;
      }
    });
    
    _syncTimestampsToMarkers();
  }

  void _clearMarkers() {
    if (_waveformData == null) return;
    setState(() {
      _waveformData = _waveformData!.copyWith(markers: []);
    });
  }

  void _handleActionButton(String action) {
    if (_availableCategories.contains(action)) {
      _handleCategoryFilter(action);
      return;
    }

    switch (action) {
      case 'export':
        _showExportDialog();
        break;
      case 'clear':
        _clearMarkers();
        break;
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Analysis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Export as CSV'),
              onTap: () {
                Navigator.pop(context);
                _exportAsCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Export as JSON'),
              onTap: () {
                Navigator.pop(context);
                _exportAsJSON();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportAsCSV() {
    print('📊 Exporting as CSV - TODO: Implement download');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV export feature coming soon')),
    );
  }

  void _exportAsJSON() {
    print('📊 Exporting as JSON - TODO: Implement download');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON export feature coming soon')),
    );
  }

  Future<void> _addWordToFilter(String word) async {
    final success = await AudioApiService.addWordToFilter(word);
    if (success) {
      if (_processingResult != null) {
        await _rescanVocabularyFilter();
      }
    } else {
      _showError('Failed to add word to filter');
    }
  }

  Future<void> _removeWordFromFilter(String word) async {
    final success = await AudioApiService.removeWordFromFilter(word);
    if (success) {
      if (_processingResult != null) {
        await _rescanVocabularyFilter();
      }
    } else {
      _showError('Failed to remove word from filter');
    }
  }

  Future<void> _rescanVocabularyFilter() async {
    if (_processingResult == null) return;

    final filterWords = await AudioApiService.getFilteredWords();
    if (filterWords == null) {
      print('⚠️ Failed to get filter words during rescan');
      return;
    }

    setState(() {
      _vocabularyFilterWords = filterWords;
    });

    print('🔄 Rescanning with ${filterWords.length} filter words');

    final filterSet = filterWords.map((w) => w.toLowerCase()).toSet();
    final updatedTimestamps = <TimestampEntry>[];
    
    for (var sentence in _processingResult!.transcription) {
      Color color = Color(int.parse(sentence.color.replaceFirst('#', '0xFF')));
      String displayText = sentence.text;
      String category = sentence.category;
      List<String> categories = List.from(sentence.categories);
      
      final words = sentence.text.toLowerCase().split(RegExp(r'\W+'));
      bool hasFilteredWord = words.any((word) => filterSet.contains(word));
      
      if (hasFilteredWord) {
        if (!categories.contains('Vocabulary Filter')) {
          categories.insert(0, 'Vocabulary Filter');
        }
        category = 'Vocabulary Filter';
        color = const Color(0xFFED8936);
        displayText = sentence.text;
      } else {
        categories.remove('Vocabulary Filter');
        if (categories.isEmpty) {
          categories.add('Transcription');
          category = 'Transcription';
        } else {
          category = categories[0];
        }
        
        if (sentence.level != 'None') {
          displayText = '[${sentence.level}] ${sentence.text}';
        }
      }
      
      updatedTimestamps.add(TimestampEntry(
        timeInSeconds: sentence.start,
        category: category,
        categories: categories,
        text: displayText,
        color: color,
      ));
    }
    
    setState(() {
      _timestamps = updatedTimestamps;
    });
    
    _syncTimestampsToMarkers();
  }

  Future<void> _pickFile() async {
    if (!_serverOnline) {
      _showError('Backend is not running!');
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'mp4', 'm4a', 'aac', 'mov', 'avi', 'flac'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
          _fileName = result.files.first.name;
          _isProcessing = true;
          _waveformData = null;
          _processingResult = null;
          _timestamps = [];
          _selectedCategory = null;
          _isUploadBoxMinimized = true; // Auto-minimize after upload
        });

        if (_selectedFile!.bytes != null) {
          final processingResult = await AudioApiService.processMedia(
            _selectedFile!.name,
            _selectedFile!.bytes!,
          );

          if (processingResult != null) {
            setState(() {
              _processingResult = processingResult;
            });
            
            _convertResultsToTimestamps(processingResult);
            await _loadVocabularyFilter(); // Load the current vocabulary filter
          } else {
            _showError('Failed to process media');
          }

          final waveform = await AudioApiService.extractWaveform(
            _selectedFile!.name,
            _selectedFile!.bytes!,
          );

          setState(() {
            _waveformData = waveform;
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'check_circle':
        return Icons.check_circle;
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Widget _buildExtremismScores(ExtremismAnalysis extremism) {
    List<Map<String, dynamic>> categories = [
      {'key': 'overall_extremism', 'label': 'Overall Extremism', 'icon': Icons.warning_amber},
      {'key': 'violence_advocacy', 'label': 'Violence Advocacy', 'icon': Icons.gavel},
      {'key': 'dehumanization', 'label': 'Dehumanization', 'icon': Icons.person_off},
      {'key': 'outgroup_homogenization', 'label': 'Outgroup Homogenization', 'icon': Icons.group_remove},
      {'key': 'threat_inflation', 'label': 'Threat Inflation', 'icon': Icons.trending_up},
      {'key': 'absolutism', 'label': 'Absolutism', 'icon': Icons.stop_circle},
    ];

    return Column(
      children: categories.map((category) {
        String key = category['key'];
        
        if (!extremism.scores.containsKey(key)) {
          return const SizedBox.shrink();
        }
        
        var scoreData = extremism.scores[key]!;
        Color levelColor = Color(int.parse(scoreData.color.replaceFirst('#', '0xFF')));
        IconData levelIcon = _getIconFromString(scoreData.icon);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: levelColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(category['icon'], size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category['label'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        'Score: ${scoreData.score.toStringAsFixed(1)}/10',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(levelIcon, size: 16, color: levelColor),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: levelColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    scoreData.level,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  List<TimestampEntry> _getFilteredTimestamps() {
    var filtered = _selectedCategory == null || _selectedCategory == 'ALL'
        ? _timestamps
        : _timestamps.where((t) => t.hasCategory(_selectedCategory!)).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) =>
        t.text.toLowerCase().contains(_searchQuery) ||
        t.category.toLowerCase().contains(_searchQuery)
      ).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
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
            // Header
            Container(
              width: double.infinity,
              height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Audio Analysis System',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _serverOnline
                                ? Colors.green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _serverOnline ? '● Server Online' : '● Server Offline',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_waveformData != null)
                      Row(
                        children: [
                          IconButton(
                            onPressed: _showExportDialog,
                            icon: const Icon(Icons.download, color: Colors.white),
                            tooltip: 'Export Analysis',
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                                _searchController.clear();
                              });
                            },
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            tooltip: 'Reset Filters',
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            
            // Main content - TWO COLUMN LAYOUT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN - Upload + Analysis
                    Container(
                      width: 320,
                      child: Column(
                        children: [
                          // Upload box (collapsible)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: Container(
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
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!_isUploadBoxMinimized) ...[
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
                                                : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                                          ),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: _isProcessing
                                            ? const Center(
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 3,
                                                ),
                                              )
                                            : const Icon(Icons.upload_file, color: Colors.white, size: 50),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Upload File',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D3748),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isProcessing ? 'Processing...' : 'Click to upload',
                                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF667EEA).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _fileName ?? 'No file',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF667EEA),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (_fileName != null)
                                          IconButton(
                                            icon: Icon(
                                              _isUploadBoxMinimized ? Icons.expand_more : Icons.expand_less,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isUploadBoxMinimized = !_isUploadBoxMinimized;
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Scrollable analysis sections
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  // Vocabulary Filter Section
                                  if (_processingResult != null) ...[
                                    Container(
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
                                      ),
                                      child: Column(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                _isVocabularyFilterExpanded = !_isVocabularyFilterExpanded;
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.filter_list, color: Color(0xFFED8936), size: 22),
                                                  const SizedBox(width: 12),
                                                  const Expanded(
                                                    child: Text(
                                                      'Vocabulary Filter',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF2D3748),
                                                      ),
                                                    ),
                                                  ),
                                                  if (_vocabularyFilterWords.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFED8936).withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        '${_vocabularyFilterWords.length}',
                                                        style: const TextStyle(
                                                          color: Color(0xFFED8936),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    _isVocabularyFilterExpanded ? Icons.expand_less : Icons.expand_more,
                                                    color: const Color(0xFFED8936),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (_isVocabularyFilterExpanded)
                                            Container(
                                              height: 350,
                                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                              child: VocabularyFilterWidget(
                                                filteredWords: _vocabularyFilterWords,
                                                predefinedWords: _predefinedFilterWords,
                                                onAddWord: _addWordToFilter,
                                                onRemoveWord: _removeWordFromFilter,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  
                                  // Extremism Analysis Section
                                  if (_processingResult != null && _processingResult!.extremism.scores.isNotEmpty) ...[
                                    Container(
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
                                      ),
                                      child: Column(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                _isExtremismAnalysisExpanded = !_isExtremismAnalysisExpanded;
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.analytics, color: Colors.orange.shade700, size: 22),
                                                  const SizedBox(width: 12),
                                                  const Expanded(
                                                    child: Text(
                                                      'Extremism Analysis',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF2D3748),
                                                      ),
                                                    ),
                                                  ),
                                                  Icon(
                                                    _isExtremismAnalysisExpanded ? Icons.expand_less : Icons.expand_more,
                                                    color: Colors.orange.shade700,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (_isExtremismAnalysisExpanded)
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                              child: _buildExtremismScores(_processingResult!.extremism),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // RIGHT COLUMN - Waveform + Timestamps
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
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Waveform section
                            Row(
                              children: [
                                const Icon(Icons.graphic_eq, color: Color(0xFF667EEA), size: 22),
                                const SizedBox(width: 12),
                                const Text(
                                  'Audio Waveform',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const Spacer(),
                                if (_waveformData != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF667EEA).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_waveformData!.duration.toStringAsFixed(1)}s',
                                      style: const TextStyle(
                                        color: Color(0xFF667EEA),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: _waveformData != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                        child: WaveformWidget(
                                          waveformData: _waveformData!,
                                          waveColor: const Color(0xFF667EEA),
                                          height: 64,
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.audio_file_outlined, size: 40, color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Upload an audio/video file',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            
                            // Action buttons
                            if (_waveformData != null) ...[
                              const SizedBox(height: 16),
                              ActionButtonsWidget(onButtonPressed: _handleActionButton),
                            ],
                            
                            const SizedBox(height: 20),
                            
                            // Search bar
                            if (_timestamps.isNotEmpty) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        hintText: 'Search timestamps...',
                                        prefixIcon: const Icon(Icons.search, size: 20),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 20),
                                                onPressed: () => _searchController.clear(),
                                              )
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            // Timestamp list header
                            if (_timestamps.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.timeline, color: Color(0xFF667EEA), size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Timeline (${_getFilteredTimestamps().length})',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                  if (_selectedCategory != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF667EEA).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            _selectedCategory!,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF667EEA),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () => _handleCategoryFilter('ALL'),
                                            child: const Icon(Icons.close, size: 14, color: Color(0xFF667EEA)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            // Timestamp list
                            Expanded(
                              child: TimestampListWidget(
                                timestamps: _getFilteredTimestamps(),
                                onTimestampTap: (entry) {
                                  print('Timestamp clicked: ${entry.formattedTime} - ${entry.category}');
                                },
                              ),
                            ),
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