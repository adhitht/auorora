import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path_provider/path_provider.dart';

class SigLipService {
  static const String _defaultModelPath = 'assets/models/vision_model_fp16.onnx';
  static const int _defaultInputSize = 224;

  OrtSession? _session;
  bool _isInitialized = false;
  final String modelAssetPath;
  final int inputSize;

  SigLipService({
    this.modelAssetPath = _defaultModelPath,
    this.inputSize = _defaultInputSize,
  });

  Future<void> loadModel() async {
    if (_isInitialized) return;

    try {
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();
      sessionOptions.setIntraOpNumThreads(1);
      sessionOptions.setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortDisableAll);

      final tempDir = await getTemporaryDirectory();
      final fileName = modelAssetPath.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');
      
      if (!await tempFile.exists()) {
        final byteData = await rootBundle.load(modelAssetPath);
        await tempFile.writeAsBytes(byteData.buffer.asUint8List(
            byteData.offsetInBytes, byteData.lengthInBytes));
      }

      final dataFileName = '$fileName.data';
      try {
        final tempDataFile = File('${tempDir.path}/$dataFileName');
        if (!await tempDataFile.exists()) {
          final dataAssetPath = '$modelAssetPath.data';
          final dataByteData = await rootBundle.load(dataAssetPath);
          await tempDataFile.writeAsBytes(dataByteData.buffer.asUint8List(
              dataByteData.offsetInBytes, dataByteData.lengthInBytes));
          debugPrint('SigLipService: Copied external data file $dataFileName');
        } 
      } catch (e) {
        debugPrint('SigLipService: Could not load external data file for $dataFileName: $e. Proceeding without it.');
      }

      _session = OrtSession.fromFile(tempFile, sessionOptions);
      _isInitialized = true;
      debugPrint('SigLipService: Initialized successfully with model $modelAssetPath');
    } catch (e) {
      debugPrint('SigLipService: Failed to load model: $e');
      rethrow;
    }
  }

  Future<Float32List> embed(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await loadModel();
    }

    try {
      final Float32List inputFloats = await compute(
        _preprocessImage,
        _PreprocessArgs(imageBytes, inputSize),
      );

      final inputShape = [1, 3, inputSize, inputSize];
      final inputOrt = OrtValueTensor.createTensorWithDataList(
          inputFloats, inputShape);

      final runOptions = OrtRunOptions();
      
      final inputs = {'pixel_values': inputOrt}; 
      
      final outputs = _session!.run(runOptions, inputs);
      
      inputOrt.release();
      runOptions.release();

      if (outputs.isEmpty || outputs[0] == null) {
        throw Exception("No output from model");
      }

      final outputOrt = outputs[0] as OrtValueTensor;
      final rawOutput = outputOrt.value;
      
      debugPrint('SigLipService: Raw output type: ${rawOutput.runtimeType}');
      
      List<double> embedding;
      
      if (rawOutput is List) {
        if (rawOutput.isEmpty) throw Exception("Model output is empty");
        
        if (rawOutput[0] is num) {
           embedding = rawOutput.map((e) => (e as num).toDouble()).toList();
        } 
        else if (rawOutput[0] is List) {
           final list1 = rawOutput[0] as List;
           if (list1.isNotEmpty && list1[0] is num) {
             embedding = list1.map((e) => (e as num).toDouble()).toList();
           }
           else if (list1.isNotEmpty && list1[0] is List) {
             debugPrint('SigLipService: Detected 3D output (Sequence). Using CLS Token (Index 0).');
             final sequence = list1;

             if (sequence.isNotEmpty) {
               final clsToken = sequence[0] as List;
               embedding = clsToken.map((e) => (e as num).toDouble()).toList();
             } else {
               throw Exception("Empty sequence output");
             }
           } else {
             throw Exception("Unknown output structure depth 2");
           }
        } else {
           throw Exception("Unknown output structure depth 1");
        }
      } else {
        throw Exception("Unexpected output type: ${rawOutput.runtimeType}");
      }

      debugPrint('SigLipService: Extracted embedding length: ${embedding.length}');

      for (var element in outputs) {
        element?.release();
      }

      final normalizedEmbedding = await compute(_l2Normalize, embedding);

      return normalizedEmbedding;

    } catch (e) {
      debugPrint('SigLipService: Error during embedding: $e');
      rethrow;
    }
  }

  Map<String, List<double>>? _tags;

  Future<void> loadTags() async {
    if (_tags != null) return;

    try {
      final jsonString = await rootBundle.loadString('assets/models/siglip_tags.json');
      final Map<String, dynamic> jsonMap = 
          await compute(_parseTagsJson, jsonString);
      
      _tags = {};
      
      dynamic tagsData = jsonMap;
      if (jsonMap.containsKey('tags')) {
        tagsData = jsonMap['tags'];
      }

      void extractTags(dynamic data) {
        if (data is Map) {
          data.forEach((key, value) {
            if (value is List) {
               if (value.isNotEmpty && (value[0] is num || value[0] is double)) {
                 try {
                   final vector = value.map((e) => (e as num).toDouble()).toList();
                   _tags![key.toString()] = vector;
                 } catch (e) {
                   // Ignore if casting fails
                 }
               }
            } else if (value is Map) {
              extractTags(value);
            }
          });
        }
      }

      extractTags(tagsData);
      
      debugPrint('SigLipService: Loaded ${_tags!.length} tags');
    } catch (e) {
      debugPrint('SigLipService: Failed to load tags: $e');
      debugPrint('SigLipService: Using fallback hardcoded tags.');
      
      _tags = {};
    }
  }

  List<MapEntry<String, double>> findBestMatches(Float32List imageEmbedding, {int topK = 5}) {
    if (_tags == null || _tags!.isEmpty) return [];

    final scores = <String, double>{};

    _tags!.forEach((tag, textEmbedding) {
      double dot = 0.0;
      for (int i = 0; i < imageEmbedding.length; i++) {
        dot += imageEmbedding[i] * textEmbedding[i];
      }
      scores[tag] = dot;
    });

    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (topK > 0) {
        return sortedEntries.take(topK).toList();
    }
    return sortedEntries;
  }

  void dispose() {
    _session?.release();
    _isInitialized = false;
    _tags = null;
  }
}

Map<String, dynamic> _parseTagsJson(String jsonString) {
  return jsonDecode(jsonString) as Map<String, dynamic>;
}


class _PreprocessArgs {
  final Uint8List imageBytes;
  final int targetSize;

  _PreprocessArgs(this.imageBytes, this.targetSize);
}

Float32List _preprocessImage(_PreprocessArgs args) {
  final image = img.decodeImage(args.imageBytes);
  if (image == null) {
    throw Exception("Failed to decode image");
  }

  img.Image resized;
  if (image.width < image.height) {
    resized = img.copyResize(image, width: args.targetSize);
  } else {
    resized = img.copyResize(image, height: args.targetSize);
  }

  final cropped = img.copyCrop(
    resized,
    x: (resized.width - args.targetSize) ~/ 2,
    y: (resized.height - args.targetSize) ~/ 2,
    width: args.targetSize,
    height: args.targetSize,
  );

  
  final floatList = Float32List(1 * 3 * args.targetSize * args.targetSize);
  final int size = args.targetSize;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final pixel = cropped.getPixel(x, y);
      
      final r = pixel.r / 255.0;
      final g = pixel.g / 255.0;
      final b = pixel.b / 255.0;

      final rNorm = (r - 0.5) / 0.5;
      final gNorm = (g - 0.5) / 0.5;
      final bNorm = (b - 0.5) / 0.5;

      floatList[0 * size * size + y * size + x] = rNorm;
      floatList[1 * size * size + y * size + x] = gNorm;
      floatList[2 * size * size + y * size + x] = bNorm;
    }
  }

  return floatList;
}

Float32List _l2Normalize(List<double> vector) {
  double sumSq = 0.0;
  for (final val in vector) {
    sumSq += val * val;
  }
  final norm = math.sqrt(sumSq);
  
  final epsilon = 1e-12;
  final divisor = norm > epsilon ? norm : 1.0;

  final normalized = Float32List(vector.length);
  for (int i = 0; i < vector.length; i++) {
    normalized[i] = vector[i] / divisor;
  }
  return normalized;
}
