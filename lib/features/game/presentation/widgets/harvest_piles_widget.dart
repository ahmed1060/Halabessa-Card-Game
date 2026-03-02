import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/models/capture.dart';
import 'card_widget.dart';
import '../../../../core/theme/theme_config.dart';

class HarvestPilesWidget extends StatelessWidget {
  final List<Capture> captures;
  final String teamName;
  final bool isMyTeam;

  const HarvestPilesWidget({
    super.key,
    required this.captures,
    required this.teamName,
    required this.isMyTeam,
  });

  @override
  Widget build(BuildContext context) {
    if (captures.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMyTeam ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        // Team Label (Optional, subtle)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            teamName.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Horizontal list of stacks
        SizedBox(
          height: 60, // Fixed height for the stacks
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: captures.length,
            itemBuilder: (context, index) {
              final capture = captures[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildSingleStack(capture, index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSingleStack(Capture capture, int index) {
    // Generate a stable random rotation based on index and rank/suit
    final seed = capture.leadingCard.suit.index * 13 + capture.leadingCard.rank.index + index;
    final random = Random(seed);
    final rotation = (random.nextDouble() - 0.5) * 0.2; // +/- 5-6 degrees

    return SizedBox(
      width: 45,
      height: 60,
      child: Stack(
        children: [
          // Base: Simulated face-down cards (just 1-2 shadows/borders for performance)
          Positioned(
            top: 4,
            left: 2,
            child: _buildFaceDownPlaceholder(),
          ),
          Positioned(
            top: 2,
            left: 1,
            child: _buildFaceDownPlaceholder(),
          ),
          Positioned.fill(
            child: Transform.rotate(
              angle: rotation,
              child: CardWidget(
                card: capture.leadingCard,
                width: 40,
                height: 54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceDownPlaceholder() {
    return Container(
      width: 40,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F), // Dark card back color
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Opacity(
          opacity: 0.1,
          child: Image.asset(
            'assets/images/logo.png',
            width: 20,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.casino, size: 12, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
