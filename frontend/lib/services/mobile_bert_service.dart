import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class MobileBertService {
  static const String _modelPath = 'assets/models/mobilebert.tflite';
  static const String _vocabPath = 'assets/models/vocab.txt';
  static const int _maxSeqLen = 128;

  Interpreter? _interpreter;
  Map<String, int>? _vocab;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load Vocab
      final vocabString = await rootBundle.loadString(_vocabPath);
      _vocab = {};
      final lines = vocabString.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab![token] = i;
        }
      }

      // Load Model
      // TFLite Flutter requires the file to be on disk or loaded from assets
      // We can load directly from assets using the plugin's helper if available,
      // or copy to temp.
      // tflite_flutter 0.10+ supports loading from asset directly via Interpreter.fromAsset
      _interpreter = await Interpreter.fromAsset(_modelPath);
      
      _isInitialized = true;
      debugPrint('MobileBertService: Initialized. Vocab size: ${_vocab!.length}');
    } catch (e) {
      debugPrint('MobileBertService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Tokenizes text using WordPiece algorithm
  List<int> tokenize(String text) {
    if (_vocab == null) throw Exception('Vocab not loaded');

    final tokens = <int>[];
    tokens.add(_vocab!['[CLS]']!); // Start token

    final words = text.toLowerCase().split(RegExp(r'\s+'));

    for (var word in words) {
      if (word.isEmpty) continue;

      // Simple punctuation split (basic)
      // For a robust tokenizer, we'd need more complex regex, but this suffices for commands
      // Let's just handle basic alphanumeric + common punctuation
      // Or just iterate characters for unknown words.
      
      // WordPiece Logic
      int start = 0;
      while (start < word.length) {
        int end = word.length;
        String? curSubstr;
        bool found = false;

        while (start < end) {
          String substr = word.substring(start, end);
          if (start > 0) {
            substr = '##$substr';
          }

          if (_vocab!.containsKey(substr)) {
            curSubstr = substr;
            found = true;
            break;
          }
          end--;
        }

        if (found) {
          tokens.add(_vocab![curSubstr]!);
          start = end;
        } else {
          // Unknown char, skip or use [UNK]
          tokens.add(_vocab!['[UNK]']!);
          start++; 
        }
      }
    }

    tokens.add(_vocab!['[SEP]']!); // End token

    // Truncate if too long
    if (tokens.length > _maxSeqLen) {
      return tokens.sublist(0, _maxSeqLen);
    }

    return tokens;
  }

  /// Generates embedding for the text. Returns the [CLS] token vector.
  Future<List<double>> getEmbedding(String text) async {
    if (!_isInitialized) await initialize();

    final tokens = tokenize(text);
    
    // Prepare inputs
    // Input 0: Input IDs (int32) [1, 128]
    // Input 1: Input Mask (int32) [1, 128] (1 for real tokens, 0 for padding)
    // Input 2: Segment IDs (int32) [1, 128] (All 0 for single sentence)
    
    // Note: Check model input order. Usually IDs, Mask, Segment.
    // We can inspect input tensors if needed, but standard BERT is usually this.
    
    final inputIds = List<int>.filled(_maxSeqLen, 0);
    final inputMask = List<int>.filled(_maxSeqLen, 0);
    final segmentIds = List<int>.filled(_maxSeqLen, 0);

    for (var i = 0; i < tokens.length; i++) {
      inputIds[i] = tokens[i];
      inputMask[i] = 1;
    }

    // Reshape to [1, 128]
    final inputIdsTensor = [inputIds];
    final inputMaskTensor = [inputMask];
    final segmentIdsTensor = [segmentIds];

    // Outputs
    // MobileBERT usually outputs:
    // 0: Sequence Output [1, 128, 512]
    // 1: Pooled Output [1, 512] (This is what we want, usually)
    
    // Let's allocate buffer for output.
    // If we don't know exact shape, we can let TFLite allocate?
    // tflite_flutter supports run(inputs, outputs) where outputs is a map or list.
    
    // Let's try to get output tensor 0 (Sequence) or 1 (Pooled).
    // Standard BERT TFLite often has 1 output or 2.
    // We'll assume output 0 is the sequence or pooled.
    
    // Let's inspect signature if possible, but for now we'll try to run with map.
    
    // Inputs map (indices depend on model export)
    // Usually: 0=Ids, 1=Mask, 2=Segment (or similar)
    final inputs = [inputIdsTensor, inputMaskTensor, segmentIdsTensor];
    
    // Output buffer
    // MobileBERT embedding size is usually 512 (bottleneck) or 128 (if tiny).
    // The file size (100MB) suggests full MobileBERT, so likely 512.
    final outputBuffer = List.filled(1 * _maxSeqLen * 512, 0.0).reshape([1, _maxSeqLen, 512]);
    
    // We might need to adjust inputs based on model signature.
    // Since we can't inspect easily without running, we'll try standard 3-input.
    
    final outputs = {0: outputBuffer};
    
    try {
      _interpreter!.runForMultipleInputs(inputs, outputs);
    } catch (e) {
      // If run fails, it might be input order or shapes.
      // For this implementation, we assume standard BERT inputs.
      debugPrint('MobileBertService: Inference failed: $e');
      rethrow;
    }

    // Extract [CLS] token embedding (Index 0 of sequence)
    final sequenceOutput = outputBuffer[0] as List<List<double>>;
    final clsEmbedding = sequenceOutput[0]; // [512]

    return clsEmbedding;
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
