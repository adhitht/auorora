import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'llm_service.dart';

enum EditorAction {
  relight,
  reframe,
  diffusion,
  unknown,
}

class SemanticRouterService {
  final LlmService _llmService = LlmService();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _llmService.initialize();
    _isInitialized = true;
    debugPrint('SemanticRouterService: Initialized with LLM.');
  }

  Future<Map<String, dynamic>> generateCommand(String prompt) async {
    if (!_isInitialized) await initialize();
    
    String? jsonString;
    try {
      jsonString = await _llmService.generateResponse(prompt);
      debugPrint('LLM Response: $jsonString');
      
      String cleanJson = jsonString;
      if (jsonString.contains('```json')) {
        cleanJson = jsonString.split('```json')[1].split('```')[0].trim();
      } else if (jsonString.contains('```')) {
        cleanJson = jsonString.split('```')[1].split('```')[0].trim();
      }
      
      debugPrint('SemanticRouterService: Generated command: $cleanJson');
      final Map<String, dynamic> result = jsonDecode(cleanJson);
      result['raw_output'] = jsonString;
      return result;
    } catch (e) {
      debugPrint('Error generating command from LLM: $e');
      return {
        'action': 'unknown', 
        'error': e.toString(),
        'raw_output': jsonString ?? 'No output',
      };
    }
  }

  Future<EditorAction> routePrompt(String prompt) async {
    final command = await generateCommand(prompt);
    final actionStr = command['action'] as String?;
    
    if (actionStr == 'relight') return EditorAction.relight;
    if (actionStr == 'reframe') return EditorAction.reframe;
    
    return EditorAction.diffusion;
  }
  
  void dispose() {
    _llmService.dispose();
  }
}

