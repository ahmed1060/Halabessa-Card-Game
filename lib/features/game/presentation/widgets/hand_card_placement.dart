import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/card.dart' as game;

const cardUiRefinements = bool.fromEnvironment('HALABESSA_CARD_UI_REFINEMENTS');
const handLiftSpace = 72.0;

/// Shared screen-space geometry, never card membership or gameplay order.
class HandFanGeometry {
  final double width, height, spacing;
  const HandFanGeometry._(this.width, this.height, this.spacing);
  factory HandFanGeometry(
    double available, {
    bool compact = false,
    double spread = 1,
  }) {
    final sizingWidth = available / spread;
    final width = math.min(
      compact ? 60.0 : 118.0,
      math.max(40.0, (sizingWidth - 24) / 3.2),
    );
    return HandFanGeometry._(
      width,
      width * 1.43,
      math.max(0.0, (available - 16 - width) / 3),
    );
  }
}

/// A single slot for each owned ID: public cards park at physical right in RTL too.
class HandCardPlacement {
  final List<game.Card> cards;
  final Set<String> publicIds;
  final HandFanGeometry fan;
  final bool refined;
  HandCardPlacement(
    this.cards,
    this.publicIds,
    this.fan, {
    this.refined = cardUiRefinements,
  });
  List<game.Card> get ordered => !refined
      ? cards
      : [
          ...cards.where((c) => !publicIds.contains(c.firebaseKey)),
          ...cards.where((c) => publicIds.contains(c.firebaseKey)),
        ];
  double get extent => fan.width + fan.spacing * 3;
  double get gap =>
      refined &&
          publicIds.isNotEmpty &&
          cards.any((c) => !publicIds.contains(c.firebaseKey))
      ? (fan.width * .14).clamp(8, 16).toDouble()
      : 0;
  double get step => math.min(
    fan.spacing,
    gap == 0
        ? fan.spacing
        : math.max(0, (extent - fan.width * 2 - gap) / 2),
  );
  Offset offset(game.Card card) {
    final list = ordered, index = list.indexOf(card);
    final isPublic = refined && publicIds.contains(card.firebaseKey);
    // At the private/public boundary the next card starts AFTER the previous
    // card's full width, not merely one overlapping fan step plus a margin.
    final boundary = gap == 0 ? 0.0 : fan.width + gap - step;
    final total = fan.width + step * math.max(0, list.length - 1) + boundary;
    final arc = refined && isPublic
        ? 0.0
        : 7 *
              (2.25 - math.pow(index - (list.length - 1) / 2, 2)).clamp(
                0,
                2.25,
              );
    return Offset(
      (extent - total) / 2 + index * step + (isPublic ? boundary : 0),
      arc.toDouble(),
    );
  }

  double angle(game.Card card) =>
      refined && publicIds.contains(card.firebaseKey)
      ? 0
      : (ordered.indexOf(card) - (cards.length - 1) / 2) * .035;
}
