import 'package:get_it/get_it.dart';
import 'services/relighting_service.dart';
import 'services/siglip_service.dart';
import 'services/segmentation_service.dart';
import 'services/notification_service.dart';
import 'services/image_processing_service.dart';
import 'services/lama_fp16_inpainting_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<RelightingService>(() => RelightingService());
  getIt.registerLazySingleton<SigLipService>(() => SigLipService());
  getIt.registerLazySingleton<SegmentationService>(() => SegmentationService());
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  getIt.registerLazySingleton<ImageProcessingService>(() => ImageProcessingService());
  getIt.registerLazySingleton<LamaFP16InpaintingService>(() => LamaFP16InpaintingService());
}

Future<void> disposeEditorServices() async {
  if (getIt.isRegistered<RelightingService>() && getIt.isRegistered<RelightingService>(instanceName: null)) {
     await getIt<RelightingService>().shutdown();
  }

  if (getIt.isRegistered<SigLipService>()) {
    getIt<SigLipService>().dispose();
  }

  if (getIt.isRegistered<SegmentationService>()) {
    getIt<SegmentationService>().dispose();
  }
  
  if (getIt.isRegistered<LamaFP16InpaintingService>()) {
    getIt<LamaFP16InpaintingService>().dispose();
  }
}
