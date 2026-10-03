import 'package:flutter/material.dart';

/// Convert physical screen positions into the board's coordinate system.
/// Reading direction must never mirror a player's card trajectory.
Offset? tableMotionOffset(GlobalKey sourceKey, GlobalKey boardKey) {
  final source = sourceKey.currentContext?.findRenderObject();
  final board = boardKey.currentContext?.findRenderObject();
  if (source is! RenderBox ||
      board is! RenderBox ||
      !source.hasSize ||
      !board.hasSize) {
    return null;
  }
  return board.globalToLocal(
        source.localToGlobal(source.size.center(Offset.zero)),
      ) -
      board.size.center(Offset.zero);
}
