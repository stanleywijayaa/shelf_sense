import 'package:flutter/material.dart';

/// Shared elevation used across the app's cards.
/// A soft shadow replaces the previous hairline borders, which gives cards
/// a little depth and makes the UI feel less flat. Defined in one place so
/// every surface stays consistent.
class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x121C1C1E), // ~7% of #1C1C1E
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
  ];
}