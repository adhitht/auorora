import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../services/photo_picker_service.dart';
import '../theme/liquid_glass_theme.dart';
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

              // Gallery grid or empty state
              Expanded(
                child: _photos.isEmpty
                    ? Center(
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
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          return _PhotoTile(
                            photo: _photos[index],
                            onTap: () => _openEditor(_photos[index]),
                            onLongPress: () {
                              HapticFeedback.heavyImpact();
                              _showDeleteDialog(context, index);
                            },
                          );
                        },
                      ),
              ),

              // Bottom button to add photos
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
  final File photo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhotoTile({
    required this.photo,
    required this.onTap,
    required this.onLongPress,
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
                  Image.file(photo, fit: BoxFit.cover),
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
