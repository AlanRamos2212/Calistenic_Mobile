import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Animated status banner displayed when offline or serving fallback cached data.
class OfflineBanner extends StatefulWidget {
  final bool isOfflineFallback;
  final String? customMessage;

  const OfflineBanner({
    super.key,
    this.isOfflineFallback = false,
    this.customMessage,
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isNoNetwork = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    try {
      _subscription = Connectivity().onConnectivityChanged.listen((results) {
        final isOffline =
            results.isEmpty || results.contains(ConnectivityResult.none);
        if (mounted && isOffline != _isNoNetwork) {
          setState(() => _isNoNetwork = isOffline);
        }
      });
    } catch (_) {
      // In test or non-supported environments, connectivity stream fails safely.
    }
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final isOffline =
          results.isEmpty || results.contains(ConnectivityResult.none);
      if (mounted && isOffline != _isNoNetwork) {
        setState(() => _isNoNetwork = isOffline);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShow = _isNoNetwork || widget.isOfflineFallback;

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState:
          shouldShow ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF261D10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.amber.shade700.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.amber.shade400, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.customMessage ??
                    'Modo sin conexión · Mostrando datos locales',
                style: TextStyle(
                  color: Colors.amber.shade200,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }
}
