import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageProcessingService {
  Future<Size> getImageDimensions(File imageFile) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      return Size(image.width.toDouble(), image.height.toDouble());
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      rethrow;
    }
  }

  Future<File> saveImage(Uint8List bytes, String fileName) async {
    try {
      final Directory? downloadsDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getDownloadsDirectory();
      
      if (downloadsDir == null) {
        throw Exception('Could not access Downloads directory');
      }
      
      final String filePath = path.join(downloadsDir.path, fileName);
      final File file = File(filePath);
      
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('Error saving image: $e');
      rethrow;
    }
  }
}

class Size {
  final double width;
  final double height;

  Size(this.width, this.height);

  @override
  String toString() => 'Size($width, $height)';
}
