import 'package:flutter/material.dart';

import 'package:vidmate_app/core/error_handler.dart';

/// A reusable friendly error screen
/// Shows a friendly icon, title, message, and action buttons
class FriendlyErrorScreen extends StatelessWidget {
  final ErrorType errorType;
  final String? customTitle;
  final String? customMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  final String retryText;
  final String backText;
  final bool showBackButton;
  final bool showRetryButton;

  const FriendlyErrorScreen({
    super.key,
    required this.errorType,
    this.customTitle,
    this.customMessage,
    this.onRetry,
    this.onBack,
    this.retryText = 'Retry',
    this.backText = 'Back',
    this.showBackButton = true,
    this.showRetryButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final title = customTitle ?? getErrorTitle(errorType);
    final icon = getErrorIcon(errorType);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0F13),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Error icon
                Icon(
                  icon,
                  size: 64,
                  color: const Color(0xFF6C5CE7),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  customMessage ?? errorType.friendlyMessage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Action buttons
                if (showRetryButton)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onRetry ?? () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(retryText, style: TextStyle(fontSize: 16)),
                    ),
                  ),
                if (showRetryButton && showBackButton)
                  const SizedBox(height: 12),
                if (showBackButton)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onBack ?? () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6C5CE7),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(backText, style: TextStyle(fontSize: 16)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Error extension for user-friendly messages
extension ErrorTypeMessage on ErrorType {
  String get friendlyMessage {
    switch (this) {
      case ErrorType.network:
        return 'Internet connection nahi mil raha. Apna Wi-Fi ya mobile data check karein.';
      case ErrorType.timeout:
        return 'Request time out ho gaya. Apna internet check karein aur dobara try karein.';
      case ErrorType.server:
        return 'Server abhi available nahi hai. Thodi dair baad try karein.';
      case ErrorType.permission:
        return 'App ko file save karne ke liye permission chahiye.';
      case ErrorType.storage:
        return 'Phone mein jagah kam hai. Kuch files delete karke dobara try karein.';
      case ErrorType.unknown:
        return 'Kuch ghalat ho gaya. Dobara try karein.';
    }
  }
}