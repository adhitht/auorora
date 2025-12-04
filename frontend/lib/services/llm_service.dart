import 'dart:io';
import 'package:fllama/fllama.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class LlmService {
  static const String _modelAssetPath = 'assets/models/qwen2.5-0.5b-instruct-q5_k_m.gguf';
  
  bool _isInitialized = false;
  bool _isInitializing = false;
  double? _contextId;

  Future<void> initialize() async {
    debugPrint('DEBUG: LlmService.initialize() called');
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    try {
      final modelPath = await _copyModelToTemp();
      
      debugPrint('LlmService: Initializing context with model at $modelPath');
      
      final result = await Fllama.instance()!.initContext(
        modelPath,
        nCtx: 2048,
        nThreads: 4,
        nGpuLayers: 0,
      );
      
      debugPrint('LlmService: initContext result: $result');
      
      if (result != null && result.containsKey('contextId')) {
        _contextId = (result['contextId'] as num).toDouble();
        _isInitialized = true;
        debugPrint('LlmService: Initialized with context ID $_contextId');
      } else {
        throw Exception('Failed to initialize context. Result: $result');
      }
    } catch (e) {
      debugPrint('LlmService: Initialization failed: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<String> copyModelToTemp() => _copyModelToTemp();

  Future<String> _copyModelToTemp() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/model.gguf');

    if (await file.exists()) {
      return file.path;
    }

    debugPrint('LlmService: Copying model from assets...');
    final byteData = await rootBundle.load(_modelAssetPath);
    final buffer = byteData.buffer;
    await file.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );
    debugPrint('LlmService: Model copied to ${file.path}');
    
    return file.path;
  }

  Future<String> generateResponse(String prompt) async {
    if (!_isInitialized) await initialize();
    if (_contextId == null) throw Exception('LLM not initialized');

    // Qwen2.5 Chat Template
    final fullPrompt = 
      "<|im_start|>system\n"
      "You are an AI assistant for a photo editor. "
      "Output ONLY valid JSON. "
      "Available actions: 'relight' (params: light direction, color, radius), 'reframe' (params: aspect ratio, crop). "
      "Coordinates (x, y) must be normalized between 0.0 and 1.0. (0,0) is top-left, (1,1) is bottom-right. "
      "For directions: 'left' -> x:0.1, y:0.5; 'right' -> x:0.9, y:0.5; 'top' -> x:0.5, y:0.1; 'bottom' -> x:0.5, y:0.9; 'center' -> x:0.5, y:0.5. "
      "Example: {\"action\": \"relight\", \"params\": {\"lights\": [{\"type\": \"spot\", \"position\": {\"x\": 0.9, \"y\": 0.5}, \"color\": \"#FFD700\", \"intensity\": 0.8, \"radius\": 40.0}]}}\n"
      "<|im_end|>\n"
      "<|im_start|>user\n"
      "$prompt\n"
      "<|im_end|>\n"
      "<|im_start|>assistant\n";

    try {
      final result = await Fllama.instance()!.completion(
        _contextId!,
        prompt: fullPrompt,
        nPredict: 512,
        temperature: 0.1, // Low temperature for deterministic JSON
        emitRealtimeCompletion: false,
      );
      
      debugPrint('LlmService: Completion result: $result');

      if (result != null && result.containsKey('text')) {
        String generatedText = result['text'] as String;
        // Clean up special tokens
        generatedText = generatedText.replaceAll('<|im_end|>', '').trim();
        return generatedText;
      } else {
         throw Exception('No text in result: $result');
      }
    } catch (e) {
      debugPrint('LlmService: Generation failed: $e');
      rethrow;
    }
  }

  void dispose() {
    if (_contextId != null) {
      Fllama.instance()!.releaseContext(_contextId!);
    }
    _isInitialized = false;
  }
}
