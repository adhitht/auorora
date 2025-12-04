import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:grpc/grpc.dart';
import 'package:aurora/models/relighting_model.dart';
import 'package:aurora/generated/relighting.pbgrpc.dart';
import '../service_locator.dart';
import 'notification_service.dart';

class RelightingService {
  late RelightingServiceClient _stub;
  late ClientChannel _channel;

  RelightingService() {
    final host = dotenv.env['GRPC_HOST'] ?? 'localhost';
    final port = dotenv.env['GRPC_PORT'] ?? '50051';

    _channel = ClientChannel(
      host,
      port: int.parse(port),
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    _stub = RelightingServiceClient(_channel);
  }

  Future<Uint8List?> sendImageForRelighting(
    Uint8List imageBytes, {
    List<Light>? lights,
    Uint8List? maskBytes,
  }) async {
    try {
      final request = RelightRequest()..imageData = imageBytes;

      if (lights != null) {
        final lightsRequest = LightsRequest(lights: lights);
        final jsonString = lightsRequest.toRawJson();
        debugPrint('JSON String: $jsonString');
        request.jsonData = utf8.encode(jsonString);
      }

      if (maskBytes != null) {
        request.maskData = maskBytes;
      }

      final notificationService = getIt<NotificationService>();
      notificationService.show("Processing in the cloud", type: NotificationType.info);

      final response = await _stub.relight(request);
      return Uint8List.fromList(response.processedImageData);
    } catch (e) {
      debugPrint('Caught error: $e');
      return null;
    }
  }

  Future<void> shutdown() async {
    try {
      await _channel.shutdown();
    } catch (e) {
      debugPrint('RelightingService shutdown error: $e');
    }
  }
}
