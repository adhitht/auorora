import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../services/photo_picker_service.dart';
import '../theme/liquid_glass_theme.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
import 'editor_screen.dart';

/// Gallery home screen with liquid glass effects
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PhotoPickerService _photoPickerService = PhotoPickerService();
  final List<File> _photos = [];
  List<String> _demoAssets = [];

  @override
  void initState() {
    super.initState();
    _loadDemoAssets();
  }

  Future<void> _loadDemoAssets() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      debugPrint('Manifest content loaded: ${manifestContent.length} chars');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      debugPrint('Manifest keys: ${manifestMap.keys.length}');

      final demoAssets = manifestMap.keys
          .where(
            (String key) =>
                key.startsWith('assets/demo/') &&
                (key.endsWith('.jpg') ||
                    key.endsWith('.jpeg') ||
                    key.endsWith('.png')),
          )
          .toList();

      debugPrint('Found demo assets: ${demoAssets.length}');
      for (var asset in demoAssets) {
        debugPrint('Demo asset: $asset');
      }

      setState(() {
        _demoAssets = demoAssets;
      });
    } catch (e) {
      debugPrint('Error loading demo assets: $e');
    }
  }

  Future<void> _loadAssetAsFile(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${path.basename(assetPath)}');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;
      _openEditor(tempFile);
    } catch (e) {
      debugPrint('Error loading asset as file: $e');
    }
  }

  Future<void> _handleAddPhoto() async {
    final File? photoFile = await _photoPickerService.pickPhoto();
    if (!mounted) return;

    if (photoFile != null) {
      _openEditor(photoFile);
      setState(() => _photos.add(photoFile));
    }
  }

  Future<void> _openEditor(File photo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(photoFile: photo)),
    );
  }

  void _showDeleteDialog(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActionBottomSheet(
        onDelete: () {
          Navigator.pop(context);
          setState(() => _photos.removeAt(index));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              LiquidGlassTheme.background.withOpacity(0.95),
              LiquidGlassTheme.background.withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with app name
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Photo Editor',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (_demoAssets.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'Demo Images',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final assetPath = _demoAssets[index];
                            return _PhotoTile(
                              key: ValueKey(assetPath),
                              imageProvider: AssetImage(assetPath),
                              onTap: () => _loadAssetAsFile(assetPath),
                              onLongPress: () {},
                              isLocal: false,
                            );
                          }, childCount: _demoAssets.length),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],

                    if (_photos.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'Your Photos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return _PhotoTile(
                              key: ValueKey(_photos[index].path),
                              imageProvider: FileImage(_photos[index]),
                              onTap: () => _openEditor(_photos[index]),
                              onLongPress: () {
                                HapticFeedback.heavyImpact();
                                _showDeleteDialog(context, index);
                              },
                              isLocal: true,
                            );
                          }, childCount: _photos.length),
                        ),
                      ),
                    ] else if (_demoAssets.isEmpty) ...[
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.photo_on_rectangle,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No photos yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the button below to add photos',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 32, top: 16),
                child: _LiquidGlassButton(onTap: _handleAddPhoto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final ImageProvider imageProvider;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isLocal;
  // final String? label;

  const _PhotoTile({
    super.key,
    required this.imageProvider,
    required this.onTap,
    required this.onLongPress,
    this.isLocal = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress,
      child: LiquidGlassLayer(
        settings: const LiquidGlassSettings(
          thickness: 15,
          blur: 12,
          glassColor: LiquidGlassTheme.glassDark,
          lightIntensity: 0.12,
          saturation: 1,
        ),
        child: LiquidStretch(
          stretch: 0.3,
          interactionScale: 1.04,
          child: LiquidGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(image: imageProvider, fit: BoxFit.cover),
                  // if (label != null)
                  //   Positioned(
                  //     top: 4,
                  //     right: 4,
                  //     child: Container(
                  //       padding: const EdgeInsets.symmetric(
                  //         horizontal: 6,
                  //         vertical: 2,
                  //       ),
                  //       decoration: BoxDecoration(
                  //         color: Colors.black.withOpacity(0.6),
                  //         borderRadius: BorderRadius.circular(8),
                  //         border: Border.all(
                  //           color: Colors.white.withOpacity(0.2),
                  //           width: 0.5,
                  //         ),
                  //       ),
                  //       child: Text(
                  //         label!,
                  //         style: const TextStyle(
                  //           color: Colors.white,
                  //           fontSize: 8,
                  //           fontWeight: FontWeight.w600,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LiquidGlassButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: LiquidGlassLayer(
        settings: const LiquidGlassSettings(
          thickness: 30,
          blur: 25,
          glassColor: LiquidGlassTheme.glassDark,
          lightIntensity: 0.2,
          saturation: 1.1,
        ),
        child: LiquidStretch(
          stretch: 0.6,
          interactionScale: 1.08,
          child: LiquidGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: 80),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(80),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(80),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.add,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBottomSheet extends StatelessWidget {
  final VoidCallback onDelete;

  const _ActionBottomSheet({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onDelete();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.trash, color: Colors.red, size: 24),
              const SizedBox(width: 16),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
