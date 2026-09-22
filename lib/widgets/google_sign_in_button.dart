import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Google's own "light" sign-in button pattern (white background, the
/// official multi-colour G mark, "Continue with Google") - kept close to
/// their branding guidelines while matching this app's stadium-button shape.
/// Shared by onboarding's optional backup step and the Backup screen, so
/// both ever offer exactly the same button rather than two near-copies.
class GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;

  const GoogleSignInButton({super.key, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          side: const BorderSide(color: Color(0xFFDADCE0)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/images/google_logo.svg', width: 18, height: 18),
                  const SizedBox(width: 12),
                  const Text('Continue with Google', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}
