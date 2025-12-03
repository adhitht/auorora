import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'glass_button.dart';

class PrivacyNoticeDialog extends StatelessWidget {
  const PrivacyNoticeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/checkmark.svg',
              width: 48,
              height: 48,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Privacy Notice',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cloud processing is used for some advanced editing features. Your photos are never stored or used for training.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    onTap: () {
                      Navigator.of(context).pop(false);
                    },
                    width: double.infinity,
                    height: 48,
                    borderRadius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    child: const Text(
                      'Go Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassButton(
                    onTap: () {
                      Navigator.of(context).pop(true);
                    },
                    width: double.infinity,
                    height: 48,
                    borderRadius: 24,
                    backgroundColor: const Color(0xFF0066CC),
                    glassColor: const Color(0xFF0066CC).withValues(alpha: 0.5),
                    child: const Text(
                      'Proceed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
