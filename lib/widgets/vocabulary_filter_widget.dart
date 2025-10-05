import 'package:flutter/material.dart';

class VocabularyFilterWidget extends StatefulWidget {
  final List<String> filteredWords;
  final List<String> predefinedWords;
  final Function(String) onAddWord;
  final Function(String) onRemoveWord;

  const VocabularyFilterWidget({
    Key? key,
    required this.filteredWords,
    required this.predefinedWords,
    required this.onAddWord,
    required this.onRemoveWord,
  }) : super(key: key);

  @override
  State<VocabularyFilterWidget> createState() => _VocabularyFilterWidgetState();
}

class _VocabularyFilterWidgetState extends State<VocabularyFilterWidget> {
  final TextEditingController _newWordController = TextEditingController();
  bool _showAddWordDialog = false;
  bool _showPredefinedWords = false;
  bool _showCustomWords = true;

  @override
  void dispose() {
    _newWordController.dispose();
    super.dispose();
  }

  void _showAddWordForm() {
    setState(() {
      _showAddWordDialog = true;
    });
  }

  void _hideAddWordForm() {
    setState(() {
      _showAddWordDialog = false;
      _newWordController.clear();
    });
  }

  void _addWord() {
    final word = _newWordController.text.trim().toLowerCase();
    if (word.isNotEmpty) {
      widget.onAddWord(word);
      _hideAddWordForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$word" to vocabulary filter'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate custom words from predefined words
    final predefinedSet = widget.predefinedWords.map((w) => w.toLowerCase()).toSet();
    final customWords = widget.filteredWords
        .where((word) => !predefinedSet.contains(word.toLowerCase()))
        .toList()
      ..sort();
    final predefinedWords = widget.filteredWords
        .where((word) => predefinedSet.contains(word.toLowerCase()))
        .toList()
      ..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFED8936).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.filter_list,
                        color: Color(0xFFED8936),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vocabulary Filter',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${customWords.length} custom · ${predefinedWords.length} predefined',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showAddWordForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Word'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48BB78),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          
          // Add word form
          if (_showAddWordDialog) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF48BB78).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF48BB78).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Word to Filter',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newWordController,
                          decoration: InputDecoration(
                            hintText: 'Enter word to filter...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _addWord(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addWord,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF48BB78),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(Icons.check),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _hideAddWordForm,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          
          // Filtered words list
          if (customWords.isEmpty && predefinedWords.isEmpty)
            Flexible(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list_off,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No words in filter',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add words to filter vocabulary',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Custom Words Section
                  if (customWords.isNotEmpty) ...[
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showCustomWords = !_showCustomWords;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF48BB78).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.person_add,
                                size: 16,
                                color: Color(0xFF48BB78),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Custom Words',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF48BB78).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${customWords.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF48BB78),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showCustomWords ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showCustomWords) ...[
                      const SizedBox(height: 4),
                      ...customWords.map((word) => _buildWordCard(
                        word: word,
                        isCustom: true,
                        context: context,
                      )),
                      const SizedBox(height: 16),
                    ],
                  ],
                  
                  // Predefined Words Section
                  if (predefinedWords.isNotEmpty) ...[
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showPredefinedWords = !_showPredefinedWords;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF667EEA).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.shield,
                                size: 16,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Predefined Words',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF667EEA).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${predefinedWords.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF667EEA),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showPredefinedWords ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showPredefinedWords) ...[
                      const SizedBox(height: 4),
                      ...predefinedWords.map((word) => _buildWordCard(
                        word: word,
                        isCustom: false,
                        context: context,
                      )),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWordCard({
    required String word,
    required bool isCustom,
    required BuildContext context,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isCustom 
              ? const Color(0xFF48BB78).withOpacity(0.3)
              : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCustom
                ? const Color(0xFF48BB78).withOpacity(0.1)
                : const Color(0xFFED8936).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            isCustom ? Icons.person : Icons.flag,
            color: isCustom ? const Color(0xFF48BB78) : const Color(0xFFED8936),
            size: 18,
          ),
        ),
        title: Text(
          word,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.delete_outline,
            color: Color(0xFFFC8181),
            size: 20,
          ),
          onPressed: () {
            widget.onRemoveWord(word);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed "$word" from filter'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          tooltip: 'Remove from filter',
        ),
      ),
    );
  }
}
