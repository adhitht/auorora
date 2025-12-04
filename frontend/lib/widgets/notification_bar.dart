
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../services/notification_service.dart';
import '../theme/liquid_glass_theme.dart';

class NotificationBar extends StatelessWidget {
  final NotificationService service;

  const NotificationBar({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, child) {
        return IgnorePointer(
          ignoring: !service.isVisible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            curve: service.isVisible ? Curves.easeOut : Curves.easeIn,
            opacity: service.isVisible ? 1.0 : 0.0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 400),
              curve: service.isVisible ? Curves.easeOutBack : Curves.easeInBack,
              offset: service.isVisible ? Offset.zero : const Offset(0, -1.5),
              child: Center(
                child: LiquidGlassLayer(
                  settings: const LiquidGlassSettings(
                    thickness: 20,
                    blur: 15,
                    glassColor: LiquidGlassTheme.glassDark,
                    lightIntensity: 0.1,
                    saturation: 1,
                  ),
                  child: LiquidGlass(
                    shape: LiquidRoundedSuperellipse(borderRadius: 30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (service.child != null) ...[
                            service.child!,
                            const SizedBox(width: 8),
                          ],
                          Text(
                            service.message ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
