import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/game/presentation/widgets/match_table_layout.dart';
import 'lantern_page_frame.dart';

/// Stable startup surface. Progress reflects asset loading, never invented
/// physics/network phases, and rebuilds cannot restart a logo animation.
class LoadingScreen extends StatelessWidget {
  final Stream<double> progressStream;
  const LoadingScreen({super.key, required this.progressStream});

  @override
  Widget build(BuildContext context) => LanternPageFrame(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LanternWordmark(),
                const SizedBox(height: 28),
                Text(
                  'loading'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFF0D1),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 220,
                  child: StreamBuilder<double>(
                    stream: progressStream,
                    initialData: 0,
                    builder: (context, snapshot) {
                      final raw = snapshot.data ?? 0;
                      final value = raw.isFinite ? raw.clamp(0.0, 1.0) : 0.0;
                      return LinearProgressIndicator(
                        value: value,
                        color: const Color(0xFF78D2AF),
                        backgroundColor: const Color(0xFF192638),
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(8),
                      );
                    },
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
