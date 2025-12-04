import 'package:get_it/get_it.dart';
import 'services/relighting_service.dart';
import 'services/siglip_service.dart';
import 'services/segmentation_service.dart';
import 'services/notification_service.dart';
import 'services/image_processing_service.dart';
import 'services/lama_fp16_inpainting_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Register services as lazy singletons
  getIt.registerLazySingleton<RelightingService>(() => RelightingService());
  getIt.registerLazySingleton<SigLipService>(() => SigLipService());
  getIt.registerLazySingleton<SegmentationService>(() => SegmentationService());
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  getIt.registerLazySingleton<ImageProcessingService>(() => ImageProcessingService());
  getIt.registerLazySingleton<LamaFP16InpaintingService>(() => LamaFP16InpaintingService());
}

Future<void> disposeEditorServices() async {
  // Dispose heavy services when editor is closed
  // Note: We don't unregister them, just call their dispose method if they are initialized.
  // However, GetIt singletons are persistent. 
  // If we want to free memory, we should probably reset the lazy singleton or just call dispose on the instance.
  
  if (getIt.isRegistered<RelightingService>() && getIt.isRegistered<RelightingService>(instanceName: null)) {
     // RelightingService doesn't have a check for initialization, but shutdown is safe to call multiple times usually?
     // Actually, let's check if it's created.
     // GetIt doesn't easily expose "isCreated" for lazy singletons without accessing it.
     // But we can just access it and dispose it.
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
