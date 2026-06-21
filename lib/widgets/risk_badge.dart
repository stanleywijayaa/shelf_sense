import 'package:flutter/material.dart';

/// Small colored pill that displays a food item's spoilage risk level.
/// Centralizing the color logic here means risk colors stay consistent
/// everywhere they're shown (inventory list, item detail, recipe screen, etc).
class RiskBadge extends StatelessWidget {
  final String riskLevel;

  const RiskBadge({super.key, required this.riskLevel});

  Color get _backgroundColor {
    switch (riskLevel) {
      case 'Low':
        return const Color(0xFFE6F4EA);
      case 'Medium':
        return const Color(0xFFFFF4E0);
      case 'High':
        return const Color(0xFFFCE8E8);
      default:
        return const Color(0xFFF1F3F5);
    }
  }

  Color get _textColor {
    switch (riskLevel) {
      case 'Low':
        return const Color(0xFF2E7D32);
      case 'Medium':
        return const Color(0xFFB8650A);
      case 'High':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF6C757D);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        riskLevel,
        style: TextStyle(
          color: _textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}