import 'package:apex/theme/liquid_glass_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class EditorTopBar extends StatelessWidget {
  final VoidCallback onBackTap;
  final VoidCallback onSaveTap;
  final VoidCallback? onUndoTap;
  final VoidCallback? onRedoTap;
  final VoidCallback? onHistoryTap;
  final bool isSaving;
  final bool canUndo;
  final bool canRedo;

  const EditorTopBar({
    super.key,
    required this.onBackTap,
    required this.onSaveTap,
    this.onUndoTap,
    this.onRedoTap,
    this.onHistoryTap,
    this.isSaving = false,
    this.canUndo = false,
    this.canRedo = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlassBtn(
              onTap: onBackTap,
              child: const Icon(
                CupertinoIcons.back,
                size: 20,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            LiquidGlassLayer(
              settings: const LiquidGlassSettings(
                thickness: 25,
                blur: 20,
                glassColor: LiquidGlassTheme.glassDark,
                lightIntensity: 0.55,
                saturation: 1,
              ),
              child: LiquidStretch(
                stretch: 0.5,
                interactionScale: 1.05,
                child: LiquidGlass(
                  shape: LiquidRoundedSuperellipse(borderRadius: 50),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: canUndo ? onUndoTap : null,
                            icon: Icon(
                              CupertinoIcons.arrow_uturn_left,
                              size: 20,
                              color: canUndo
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          IconButton(
                            onPressed: canRedo ? onRedoTap : null,
                            icon: Icon(
                              CupertinoIcons.arrow_uturn_right,
                              size: 20,
                              color: canRedo
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          IconButton(
                            onPressed: onHistoryTap,
                            icon: const Icon(
                              CupertinoIcons.clock,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              CupertinoIcons.ellipsis,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _GlassBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: LiquidGlassLayer(
        settings: const LiquidGlassSettings(
          thickness: 25,
          blur: 20,
          glassColor: LiquidGlassTheme.glassDark,
          lightIntensity: 0.15,
          saturation: 1,
        ),
        child: LiquidStretch(
          stretch: 0.5,
          interactionScale: 1.05,
          child: LiquidGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: 50),

            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
