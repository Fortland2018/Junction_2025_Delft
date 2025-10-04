import os
import string
from typing import List, Dict

class WordFlagger:
    """
    A class to identify and flag specific words from a predefined list within a given text.
    """

    def __init__(self, bad_words_filepath: str):
        """
        Initializes the WordFlagger with a file containing bad words.

        :param bad_words_filepath: Path to the file containing bad words, one per line.
        :raises FileNotFoundError: If the file does not exist.
        """
        if not os.path.exists(bad_words_filepath):
            raise FileNotFoundError(f"The file '{bad_words_filepath}' does not exist.")

        with open(bad_words_filepath, 'r') as file:
            self.bad_words = {line.strip().lower() for line in file if line.strip()}

    def flag_words(self, text: str) -> List[Dict[str, object]]:
        """
        Flags specific words in the given text based on the predefined bad words list.

        :param text: The text to analyze.
        :return: A list of dictionaries, each containing details of a flagged word.
        """
        flagged_results = []
        sentences = self._split_into_sentences(text)

        for sentence_index, sentence in enumerate(sentences):
            words = sentence.split()
            for word_index, word in enumerate(words):
                normalized_word = self._normalize_word(word)
                if normalized_word in self.bad_words:
                    flagged_results.append({
                        "sentence_index": sentence_index,
                        "word_index": word_index,
                        "flagged_word": word
                    })

        return flagged_results

    @staticmethod
    def _split_into_sentences(text: str) -> List[str]:
        """
        Splits the text into sentences using common sentence-ending punctuations.

        :param text: The text to split.
        :return: A list of sentences.
        """
        import re
        sentence_endings = re.compile(r'[.!?]')
        return [sentence.strip() for sentence in sentence_endings.split(text) if sentence.strip()]

    @staticmethod
    def _normalize_word(word: str) -> str:
        """
        Normalizes a word by converting it to lowercase and stripping punctuation.

        :param word: The word to normalize.
        :return: The normalized word.
        """
        return word.strip(string.punctuation).lower()
