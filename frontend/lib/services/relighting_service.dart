import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:apex/generated/relighting.pbgrpc.dart';

class RelightingService {
  late RelightingServiceClient _stub;
  late ClientChannel _channel;

  RelightingService() {
    final host = '172.22.130.196'; 
    
    _channel = ClientChannel(
      host,
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );

    _stub = RelightingServiceClient(_channel);
  }

  Future<Uint8List?> sendImageForRelighting(Uint8List imageBytes, {Uint8List? lightmapBytes}) async {
    try {
      final request = RelightRequest()
        ..imageData = imageBytes;
      
      if (lightmapBytes != null) {
        request.lightmapData = lightmapBytes;
      }

      final response = await _stub.relight(request);
      return Uint8List.fromList(response.processedImageData);
      
    } catch (e) {
      debugPrint('Caught error: $e');
      return null;
    }
  }

  Future<void> shutdown() async {
    await _channel.shutdown();
  }
}