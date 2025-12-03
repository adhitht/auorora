import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:grpc/grpc.dart';
import 'package:apex/generated/pose.pbgrpc.dart';

class PoseChangingService {
  late PoseChangingServiceClient _stub;
  late ClientChannel _channel;

  PoseChangingService() {
    final host = dotenv.env['GRPC_HOST'] ?? 'localhost';
    final port = dotenv.env['GRPC_PORT'] ?? '50051';

    _channel = ClientChannel(
      host,
      port: int.parse(port),
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    _stub = PoseChangingServiceClient(_channel);
  }

  Future<Uint8List?> changePose(
    Uint8List imageBytes,
    Uint8List newSkeletonBytes, {
    int? numSteps,
    double? controlnetConditioning,
    double? strength,
  }) async {
    try {
      final request = PoseRequest()..imageData = imageBytes;
      request.newSkeletonData = newSkeletonBytes;

      if (numSteps != null) {
        request.numSteps = numSteps;
      }
      if (controlnetConditioning != null) {
        request.controlnetConditioning = controlnetConditioning;
      }
      if (strength != null) {
        request.strength = strength;
      }

      final response = await _stub.changePose(request);
      return Uint8List.fromList(response.processedImageData);
    } catch (e) {
      debugPrint('Caught error in changePose: $e');
      return null;
    }
  }

  Future<void> shutdown() async {
    await _channel.shutdown();
  }
}
